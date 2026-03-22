import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../data/models/decision_record.dart';
import '../../data/decision_judgement.dart'; // generateJudgement()
import '../../../../core/services/market_rate_service.dart';
import '../../../../core/services/supabase_service.dart';

final decisionRecordsProvider =
    StateNotifierProvider<DecisionNotifier, List<DecisionRecord>>(
  (ref) => DecisionNotifier(),
);

class DecisionNotifier extends StateNotifier<List<DecisionRecord>> {
  static const _boxName = 'decision_records';

  DecisionNotifier() : super([]) {
    _load();
  }

  final _dio = Dio(BaseOptions(
    baseUrl: 'http://43.156.207.26/api/finance',
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
    contentType: 'application/json',
  ));

  // ─── 加载：服务器优先，降级 Hive ───
  Future<void> _load() async {
    final box = await Hive.openBox<String>(_boxName);
    final local = box.values
        .where((s) => !s.startsWith('{') == false || true)
        .map((s) {
          try {
            return DecisionRecord.fromJsonString(s);
          } catch (_) {
            return null;
          }
        })
        .whereType<DecisionRecord>()
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (local.isNotEmpty) state = local;

    try {
      final ownerId = await SupabaseService.instance.deviceId;
      final resp = await _dio.get('/decisions/$ownerId');
      final rows = resp.data as List;
      if (rows.isEmpty) return;
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

    final judgement = generateJudgement(
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
      final ownerId = await SupabaseService.instance.deviceId;
      await _dio.delete('/decisions/$ownerId/$id');
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

  // ─── 内部：写 Hive + 服务器 ───
  Future<void> _persist(DecisionRecord record) async {
    final box = await Hive.openBox<String>(_boxName);
    await box.put(record.id, record.toJsonString());
    try {
      final ownerId = await SupabaseService.instance.deviceId;
      await _dio.post('/decisions', data: {
        'record_id': record.id,
        'device_id': ownerId,
        'payload': record.toJsonString(),
        'created_at': record.createdAt.toIso8601String(),
      });
    } catch (_) {}
  }

  /// 有待复盘的决策数量
  int get pendingReviewCount => state.where((r) => r.hasPendingReview).length;
}
