import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../data/models/fund_holding.dart';
import '../../data/services/fund_api_service.dart';
import '../../../../core/services/supabase_service.dart';

// ─── 全局单例 ───
final fundApiServiceProvider = Provider<FundApiService>((_) => FundApiService());

final fundHoldingsProvider =
    StateNotifierProvider<FundHoldingsNotifier, List<FundHolding>>(
  (ref) => FundHoldingsNotifier(ref.read(fundApiServiceProvider)),
);

// ─── 汇总数据 ───
final portfolioSummaryProvider = Provider<Map<String, double>>((ref) {
  final holdings = ref.watch(fundHoldingsProvider);
  double totalCost = 0;
  double totalValue = 0;
  double todayGain = 0;

  for (final h in holdings) {
    if (h.currentNav > 0 || h.estimatedNav > 0) {
      totalCost += h.costAmount;
      totalValue += h.currentValue;
      todayGain += h.todayGain;
    }
  }

  return {
    'totalCost': totalCost,
    'totalValue': totalValue,
    'totalReturn': totalValue - totalCost,
    'totalReturnRate': totalCost > 0 ? (totalValue - totalCost) / totalCost * 100 : 0,
    'todayGain': todayGain,
  };
});

// ─── StateNotifier ───
class FundHoldingsNotifier extends StateNotifier<List<FundHolding>> {
  final FundApiService _api;
  final SupabaseService _supabase = SupabaseService.instance;
  static const _boxName = 'fund_holdings';
  static const _key = 'holdings';

  FundHoldingsNotifier(this._api) : super([]) {
    _loadData();
  }

  // ── 启动加载策略：云端优先，降级 Hive ──
  Future<void> _loadData() async {
    // 1. 先从 Hive 加载（本地缓存，立即可用）
    await _loadFromHive();

    // 2. 尝试从 Supabase 同步最新数据（若网络可用）
    final cloudData = await _supabase.loadHoldings();
    if (cloudData != null && cloudData.isNotEmpty) {
      // 将云端字段名（snake_case）映射到模型（camelCase）
      final list = cloudData.map((row) => FundHolding(
            id: row['id'] as String,
            fundCode: row['fund_code'] as String,
            fundName: row['fund_name'] as String,
            shares: (row['shares'] as num).toDouble(),
            costNav: (row['cost_nav'] as num).toDouble(),
            addedDate: row['added_date'] as String,
          )).toList();
      state = list;
      // 同步到 Hive（保持本地缓存最新）
      await _saveToHive();
    }

    // 3. 刷新行情
    if (state.isNotEmpty) refreshAll();
  }

  // ── 从 Hive 加载持仓 ──
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

  // ── 保存到 Hive ──
  Future<void> _saveToHive() async {
    final box = await Hive.openBox<String>(_boxName);
    final json = jsonEncode(state.map((h) => h.toJson()).toList());
    await box.put(_key, json);
  }

  // ── 添加持仓 ──
  Future<void> addHolding(FundHolding holding) async {
    state = [...state, holding];
    // 双写：本地 + 云端
    await _saveToHive();
    await _supabase.upsertHolding(holding.toJson());
    // 立刻拉取该基金行情
    _refreshOne(holding.fundCode);
  }

  // ── 删除持仓 ──
  Future<void> removeHolding(String id) async {
    state = state.where((h) => h.id != id).toList();
    // 双写：本地 + 云端
    await _saveToHive();
    await _supabase.deleteHolding(id);
  }

  // ── 刷新单只基金行情 ──
  Future<void> _refreshOne(String fundCode) async {
    state = state.map((h) {
      if (h.fundCode == fundCode) return h.copyWith(isLoading: true, errorMsg: null);
      return h;
    }).toList();

    try {
      final info = await _api.fetchFundInfo(fundCode);
      final currentNav = double.tryParse(info['dwjz']?.toString() ?? '') ?? 0;
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
    } catch (e) {
      state = state.map((h) {
        if (h.fundCode == fundCode) {
          return h.copyWith(isLoading: false, errorMsg: '行情获取失败');
        }
        return h;
      }).toList();
    }
  }

  // ── 刷新全部持仓行情 ──
  Future<void> refreshAll() async {
    final codes = state.map((h) => h.fundCode).toSet();
    for (final code in codes) {
      await _refreshOne(code);
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }
}
