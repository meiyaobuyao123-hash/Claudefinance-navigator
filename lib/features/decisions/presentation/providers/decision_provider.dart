import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/decision_record.dart';
import '../../../../core/services/market_rate_service.dart';

final decisionRecordsProvider =
    StateNotifierProvider<DecisionNotifier, List<DecisionRecord>>(
  (ref) => DecisionNotifier(),
);

class DecisionNotifier extends StateNotifier<List<DecisionRecord>> {
  static const _boxName = 'decision_records';
  static const _supabaseTable = 'decision_records';

  DecisionNotifier() : super([]) {
    _load();
  }

  SupabaseClient get _db => Supabase.instance.client;

  // ─── 加载：Supabase 优先，降级 Hive ───
  Future<void> _load() async {
    final box = await Hive.openBox<String>(_boxName);
    final local = box.values
        .map((s) => DecisionRecord.fromJsonString(s))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (local.isNotEmpty) state = local;

    try {
      final user = _db.auth.currentUser;
      final ownerId = user?.id ??
          (box.get('__device_id__') ?? _generateDeviceId(box));
      final rows = await _db
          .from(_supabaseTable)
          .select()
          .eq('device_id', ownerId)
          .order('created_at', ascending: false);
      if ((rows as List).isEmpty) return;
      final remote = rows
          .map((r) => DecisionRecord.fromJson(
              jsonDecode(r['payload'] as String) as Map<String, dynamic>))
          .toList();
      state = remote;
      // 同步到本地
      await box.clear();
      for (final r in remote) {
        await box.put(r.id, r.toJsonString());
      }
    } catch (_) {}
  }

  // ─── 新增决策 ───
  Future<void> addDecision(DecisionRecord record) async {
    // 采集市场快照
    final withSnapshot = await _attachSnapshot(record);
    state = [withSnapshot, ...state];
    await _persist(withSnapshot);
  }

  // ─── 执行复盘（生成 checkpoint）───
  Future<void> runReview(DecisionRecord record) async {
    if (!record.hasPendingReview) return;
    final svc = MarketRateService();

    // 获取当前市场数据
    double? currentCSI300;
    double? currentYield;
    try {
      final csi = await svc.fetchETFQuote('sz510300');
      currentCSI300 = csi?['current'] as double?;
    } catch (_) {}
    try {
      currentYield = await svc.fetchMoneyFundYield('000198');
    } catch (_) {}

    final periodLabels = ['3个月', '6个月', '1年'];
    final period = periodLabels[record.checkpoints.length];

    final judgement = _generateJudgement(
      record: record,
      period: period,
      currentCSI300: currentCSI300,
      currentYield: currentYield,
    );

    final checkpoint = DecisionCheckpoint(
      period: period,
      date: DateTime.now(),
      csi300: currentCSI300,
      moneyYield: currentYield,
      judgement: judgement['text']!,
      verdict: judgement['verdict']!,
    );

    final updated = record.copyWith(
      checkpoints: [...record.checkpoints, checkpoint],
    );
    state = [
      for (final r in state) r.id == record.id ? updated : r
    ];
    await _persist(updated);
  }

  // ─── 删除 ───
  Future<void> deleteDecision(String id) async {
    state = state.where((r) => r.id != id).toList();
    final box = await Hive.openBox<String>(_boxName);
    await box.delete(id);
    try {
      await _db.from(_supabaseTable).delete().eq('record_id', id);
    } catch (_) {}
  }

  // ─── 内部：采集市场快照 ───
  Future<DecisionRecord> _attachSnapshot(DecisionRecord record) async {
    final svc = MarketRateService();
    double? csi300;
    double? moneyYield;
    try {
      final q = await svc.fetchETFQuote('sz510300');
      csi300 = q?['current'] as double?;
    } catch (_) {}
    try {
      moneyYield = await svc.fetchMoneyFundYield('000198');
    } catch (_) {}
    return DecisionRecord(
      id: record.id,
      type: record.type,
      productCategory: record.productCategory,
      amount: record.amount,
      rationale: record.rationale,
      expectation: record.expectation,
      linkedHoldingId: record.linkedHoldingId,
      csi300AtDecision: csi300,
      moneyYieldAtDecision: moneyYield,
      createdAt: record.createdAt,
      checkpoints: record.checkpoints,
    );
  }

  // ─── 内部：生成复盘判断 ───
  Map<String, String> _generateJudgement({
    required DecisionRecord record,
    required String period,
    double? currentCSI300,
    double? currentYield,
  }) {
    final type = record.type;
    final exp = record.expectation;
    final category = record.productCategory;
    final buf = StringBuffer();
    String verdict = 'neutral';

    // 固定收益类产品 + 预期利率下降
    if ((category == '大额存单' ||
            category == '定期存款' ||
            category == '国债' ||
            category == '银行理财') &&
        exp == DecisionExpectation.rateDown &&
        type == DecisionType.buy) {
      final yieldNow = currentYield;
      final yieldThen = record.moneyYieldAtDecision;
      if (yieldNow != null && yieldThen != null) {
        final diff = yieldThen - yieldNow;
        if (diff > 0.05) {
          buf.write('利率已较决策时下降约${diff.toStringAsFixed(2)}%，你成功锁定了更高的利率，'
              '按${record.amount ~/ 10000}万元计算，每年多收益约'
              '${(record.amount * diff / 100).toStringAsFixed(0)}元。');
          verdict = 'correct';
        } else if (diff < -0.05) {
          buf.write('利率不降反升约${(-diff).toStringAsFixed(2)}%，当时锁定长期产品的时机偏早，'
              '如果等待可能获得更高利率。');
          verdict = 'incorrect';
        } else {
          buf.write('利率变化不明显（约${diff.toStringAsFixed(2)}%），当时决策在利率判断上基本中性。');
          verdict = 'neutral';
        }
      } else {
        buf.write('利率数据暂无法获取，无法自动评估。建议手动对比当前市场利率。');
        verdict = 'neutral';
      }
    }
    // 权益类 + 预期价格上涨
    else if ((category == 'A股ETF' ||
            category == '主动基金' ||
            category == '港股' ||
            category == '美股ETF') &&
        exp == DecisionExpectation.priceUp) {
      final csiNow = currentCSI300;
      final csiThen = record.csi300AtDecision;
      if (csiNow != null && csiThen != null && csiThen > 0) {
        final changePct = (csiNow - csiThen) / csiThen * 100;
        if (changePct > 3) {
          buf.write('沪深300自决策以来上涨了约${changePct.toStringAsFixed(1)}%，'
              '市场整体走势印证了你的判断。');
          verdict = 'correct';
        } else if (changePct < -3) {
          buf.write('沪深300自决策以来下跌了约${(-changePct).toStringAsFixed(1)}%，'
              '若持仓周期为长期（3年以上），当前波动属正常；若短期持仓需注意风险。');
          verdict = changePct < -15 ? 'incorrect' : 'neutral';
        } else {
          buf.write('沪深300自决策以来基本持平（${changePct >= 0 ? '+' : ''}${changePct.toStringAsFixed(1)}%），市场方向尚不明确。');
          verdict = 'neutral';
        }
      } else {
        buf.write('暂无市场价格数据，无法自动对比。');
        verdict = 'neutral';
      }
    }
    // 通用逻辑
    else {
      final months = record.checkpoints.length + 1;
      buf.write('$period（${months * 3}个月）复盘：你的决策理由是"${record.rationale}"。'
          '建议对比当前市场情况，自主判断这次决策是否达到预期。');
      verdict = 'neutral';
    }

    return {'text': buf.toString(), 'verdict': verdict};
  }

  // ─── 内部：写 Hive + Supabase ───
  Future<void> _persist(DecisionRecord record) async {
    final box = await Hive.openBox<String>(_boxName);
    await box.put(record.id, record.toJsonString());
    try {
      final ownerId = _db.auth.currentUser?.id ?? box.get('__device_id__') ?? '';
      await _db.from(_supabaseTable).upsert({
        'record_id': record.id,
        'device_id': ownerId,
        'payload': record.toJsonString(),
        'created_at': record.createdAt.toIso8601String(),
      }, onConflict: 'record_id');
    } catch (_) {}
  }

  String _generateDeviceId(Box box) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final id = List.generate(
        16, (i) => chars[(DateTime.now().microsecondsSinceEpoch + i) % chars.length]).join();
    box.put('__device_id__', id);
    return id;
  }

  /// 有待复盘的决策数量
  int get pendingReviewCount => state.where((r) => r.hasPendingReview).length;
}
