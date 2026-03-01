import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../data/models/fund_holding.dart';
import '../../data/services/fund_api_service.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/services/notification_service.dart';
import '../pages/alert_settings_page.dart';
import '../../../../features/stock_tracker/presentation/providers/stock_tracker_provider.dart';

// ─── 全局单例 ───
final fundApiServiceProvider = Provider<FundApiService>((_) => FundApiService());

final fundHoldingsProvider =
    StateNotifierProvider<FundHoldingsNotifier, List<FundHolding>>(
  (ref) => FundHoldingsNotifier(ref.read(fundApiServiceProvider), ref),
);

// ─── 合并汇总数据（基金 + 股票）───
final portfolioSummaryProvider = Provider<Map<String, double>>((ref) {
  final funds = ref.watch(fundHoldingsProvider);
  final stocks = ref.watch(stockHoldingsProvider);
  double totalCost = 0;
  double totalValue = 0;
  double todayGain = 0;

  for (final h in funds) {
    if (h.currentNav > 0 || h.estimatedNav > 0) {
      totalCost += h.costAmount;
      totalValue += h.currentValue;
      todayGain += h.todayGain;
    }
  }
  for (final s in stocks) {
    if (s.currentPrice > 0) {
      totalCost += s.costAmount;
      totalValue += s.currentValue;
      todayGain += s.todayGain;
    }
  }

  return {
    'totalCost': totalCost,
    'totalValue': totalValue,
    'totalReturn': totalValue - totalCost,
    'totalReturnRate':
        totalCost > 0 ? (totalValue - totalCost) / totalCost * 100 : 0,
    'todayGain': todayGain,
  };
});

// ─── 30 日快照数据（用于走势图）───
final portfolioSnapshotsProvider =
    StateNotifierProvider<SnapshotNotifier, List<double>>(
  (ref) => SnapshotNotifier(),
);

class SnapshotNotifier extends StateNotifier<List<double>> {
  SnapshotNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final data = await SupabaseService.instance.loadSnapshots(days: 30);
    if (data != null && data.isNotEmpty) {
      state = data
          .map((row) => (row['total_value'] as num).toDouble())
          .toList();
    }
  }

  /// 刷新快照（每次刷新行情后调用）
  Future<void> refresh() async => await _load();
}

// ─── StateNotifier ───
class FundHoldingsNotifier extends StateNotifier<List<FundHolding>> {
  final FundApiService _api;
  final Ref _ref;
  final SupabaseService _supabase = SupabaseService.instance;
  static const _boxName = 'fund_holdings';
  static const _key = 'holdings';

  FundHoldingsNotifier(this._api, this._ref) : super([]) {
    _loadData();
  }

  // ── 启动加载策略：云端优先，降级 Hive ──
  Future<void> _loadData() async {
    await _loadFromHive();

    final cloudData = await _supabase.loadHoldings();
    if (cloudData != null && cloudData.isNotEmpty) {
      final list = cloudData
          .map((row) => FundHolding(
                id: row['id'] as String,
                fundCode: row['fund_code'] as String,
                fundName: row['fund_name'] as String,
                shares: (row['shares'] as num).toDouble(),
                costNav: (row['cost_nav'] as num).toDouble(),
                addedDate: row['added_date'] as String,
              ))
          .toList();
      state = list;
      await _saveToHive();
    }

    if (state.isNotEmpty) refreshAll();
  }

  Future<void> _loadFromHive() async {
    final box = await Hive.openBox<String>(_boxName);
    final raw = box.get(_key);
    if (raw != null) {
      final list = (jsonDecode(raw) as List)
          .map((e) => FundHolding.fromJson(e as Map<String, dynamic>))
          .toList();
      state = list;
    }
  }

  Future<void> _saveToHive() async {
    final box = await Hive.openBox<String>(_boxName);
    final json = jsonEncode(state.map((h) => h.toJson()).toList());
    await box.put(_key, json);
  }

  // ── 添加持仓 ──
  Future<void> addHolding(FundHolding holding) async {
    state = [...state, holding];
    await _saveToHive();
    await _supabase.upsertHolding(holding.toJson());
    _refreshOne(holding.fundCode);
  }

  // ── 删除持仓 ──
  Future<void> removeHolding(String id) async {
    state = state.where((h) => h.id != id).toList();
    await _saveToHive();
    await _supabase.deleteHolding(id);
  }

  // ── 更新持仓（加仓/减持后调用）──
  Future<void> updateHolding(
    String id, {
    required double newShares,
    required double newCostNav,
  }) async {
    state = state.map((h) {
      if (h.id == id) {
        return h.copyWithHolding(shares: newShares, costNav: newCostNav);
      }
      return h;
    }).toList();
    await _saveToHive();
    final updated = state.firstWhere((h) => h.id == id);
    await _supabase.upsertHolding(updated.toJson());
  }

  // ── 刷新单只基金行情 ──
  Future<void> _refreshOne(String fundCode) async {
    state = state.map((h) {
      if (h.fundCode == fundCode) {
        return h.copyWith(isLoading: true, errorMsg: null);
      }
      return h;
    }).toList();

    try {
      final info = await _api.fetchFundInfo(fundCode);
      final currentNav =
          double.tryParse(info['dwjz']?.toString() ?? '') ?? 0;
      final navDate = info['jzrq']?.toString() ?? '';

      final gztime = info['gztime']?.toString() ?? '';
      final now = DateTime.now();
      final todayPrefix =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final hasEstimate = gztime.startsWith(todayPrefix);

      final estimatedNav = hasEstimate
          ? (double.tryParse(info['gsz']?.toString() ?? '') ?? currentNav)
          : currentNav;
      final changeRate = hasEstimate
          ? (double.tryParse(info['gszzl']?.toString() ?? '') ?? 0.0)
          : 0.0;

      state = state.map((h) {
        if (h.fundCode == fundCode) {
          return h.copyWith(
            currentNav: currentNav,
            estimatedNav: estimatedNav,
            changeRate: changeRate,
            navDate: navDate,
            hasEstimate: hasEstimate,
            isLoading: false,
          );
        }
        return h;
      }).toList();
    } catch (_) {
      state = state.map((h) {
        if (h.fundCode == fundCode) {
          return h.copyWith(isLoading: false, errorMsg: '行情获取失败');
        }
        return h;
      }).toList();
    }
  }

  // ── 刷新全部持仓行情 + 触发留存功能 ──
  Future<void> refreshAll() async {
    final codes = state.map((h) => h.fundCode).toSet();
    for (final code in codes) {
      await _refreshOne(code);
      await Future.delayed(const Duration(milliseconds: 300));
    }

    // 刷新完成后：计算汇总
    double totalCost = 0, totalValue = 0, todayGain = 0;
    bool anyEstimate = false;
    for (final h in state) {
      if (h.currentNav > 0 || h.estimatedNav > 0) {
        totalCost += h.costAmount;
        totalValue += h.currentValue;
        todayGain += h.todayGain;
        if (h.hasEstimate) anyEstimate = true;
      }
    }

    // 合并股票持仓数据（一并计入快照和通知）
    final stocks = _ref.read(stockHoldingsProvider);
    for (final s in stocks) {
      if (s.currentPrice > 0) {
        totalCost += s.costAmount;
        totalValue += s.currentValue;
        todayGain += s.todayGain;
      }
    }

    if (totalCost <= 0) return; // 没有有效数据，跳过

    final totalReturn = totalValue - totalCost;
    final totalReturnRate = totalReturn / totalCost * 100;

    // ── 留存功能 1：保存今日快照 ──
    await _supabase.saveSnapshot(
      totalValue: totalValue,
      totalCost: totalCost,
    );
    // 刷新快照 Provider
    _ref.read(portfolioSnapshotsProvider.notifier).refresh();

    // ── 留存功能 2：每日收益播报通知 ──
    await NotificationService.instance.showPnlSummary(
      todayGain: todayGain,
      totalReturn: totalReturn,
      totalReturnRate: totalReturnRate,
      hasEstimate: anyEstimate,
    );

    // ── 留存功能 3：止盈止损预警 ──
    await _ref.read(alertSettingsProvider.notifier).checkAndAlert(
          totalReturnRate: totalReturnRate,
        );
  }
}
