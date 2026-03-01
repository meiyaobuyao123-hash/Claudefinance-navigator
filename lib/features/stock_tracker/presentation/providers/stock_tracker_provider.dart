import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../data/models/stock_holding.dart';
import '../../data/services/stock_api_service.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/services/notification_service.dart';

final stockApiServiceProvider =
    Provider<StockApiService>((_) => StockApiService());

final stockHoldingsProvider =
    StateNotifierProvider<StockHoldingsNotifier, List<StockHolding>>(
  (ref) => StockHoldingsNotifier(ref.read(stockApiServiceProvider)),
);

class StockHoldingsNotifier extends StateNotifier<List<StockHolding>> {
  final StockApiService _api;
  final SupabaseService _supabase = SupabaseService.instance;
  static const _boxName = 'stock_holdings';
  static const _key = 'holdings';

  StockHoldingsNotifier(this._api) : super([]) {
    _loadData();
  }

  // ── 云端优先，降级 Hive ──
  Future<void> _loadData() async {
    await _loadFromHive();

    final cloudData = await _supabase.loadStockHoldings();
    if (cloudData != null && cloudData.isNotEmpty) {
      final list = cloudData
          .map((row) => StockHolding.fromJson(row))
          .toList();
      state = list;
      await _saveToHive();
    }

    if (state.isNotEmpty) refreshAll();
  }

  Future<void> _loadFromHive() async {
    final box = await Hive.openBox<String>(_boxName);
    final raw = box.get(_key);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw) as List;
      state = decoded
          .map((e) => StockHolding.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {}
  }

  Future<void> _saveToHive() async {
    final box = await Hive.openBox<String>(_boxName);
    await box.put(_key, jsonEncode(state.map((s) => s.toJson()).toList()));
  }

  // ── CRUD ──
  Future<void> addHolding(StockHolding holding) async {
    state = [...state, holding];
    await _saveToHive();
    await _supabase.upsertStockHolding(holding.toJson());
    _refreshOne(holding.symbol, holding.market);
  }

  Future<void> removeHolding(String id) async {
    state = state.where((s) => s.id != id).toList();
    await _saveToHive();
    await _supabase.deleteStockHolding(id);
  }

  Future<void> updateHolding(
    String id, {
    required double newShares,
    required double newCostPrice,
  }) async {
    state = state.map((s) {
      if (s.id == id) {
        return s.copyWithHolding(shares: newShares, costPrice: newCostPrice);
      }
      return s;
    }).toList();
    await _saveToHive();
    try {
      final updated = state.firstWhere((s) => s.id == id);
      await _supabase.upsertStockHolding(updated.toJson());
    } on StateError {
      // 极端竞态：id 已从 state 中移除，跳过云同步
    }
  }

  // ── 刷新单只行情 ──
  Future<void> _refreshOne(String symbol, String market) async {
    state = state.map((s) {
      if (s.symbol == symbol) return s.copyWith(isLoading: true);
      return s;
    }).toList();

    try {
      final data = await _api.refreshQuote(symbol, market);
      if (data == null) throw Exception('无数据');
      // 安全转换：API 字段可能缺失或类型不一致
      final price = (data['current'] as num?)?.toDouble() ?? 0.0;
      final changeRate = (data['changeRate'] as num?)?.toDouble() ?? 0.0;
      final changeAmount = (data['changeAmount'] as num?)?.toDouble() ?? 0.0;
      if (price <= 0) throw Exception('行情数据无效');
      state = state.map((s) {
        if (s.symbol == symbol) {
          return s.copyWith(
            currentPrice: price,
            changeRate: changeRate,
            changeAmount: changeAmount,
            isLoading: false,
            clearError: true,
          );
        }
        return s;
      }).toList();

      // 单仓止盈/止损预警检查
      for (final s in state) {
        if (s.symbol == symbol) {
          await _checkHoldingAlert(s);
        }
      }
    } catch (_) {
      state = state.map((s) {
        if (s.symbol == symbol) {
          return s.copyWith(isLoading: false, errorMsg: '行情获取失败');
        }
        return s;
      }).toList();
    }
  }

  // ── 设置单仓止盈/止损预警 ──
  Future<void> setHoldingAlert(
    String id, {
    required double? alertUp,
    required double? alertDown,
  }) async {
    state = state.map((s) {
      if (s.id == id) {
        return s.copyWithAlert(
          alertUp: alertUp,
          alertDown: alertDown,
          clearAlertUp: alertUp == null,
          clearAlertDown: alertDown == null,
          clearTriggeredDate: true,
        );
      }
      return s;
    }).toList();
    await _saveToHive();
  }

  // ── 检查单仓止盈/止损预警（_refreshOne 成功后调用）──
  Future<void> _checkHoldingAlert(StockHolding s) async {
    if (s.alertUp == null && s.alertDown == null) return;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (s.alertTriggeredDate == today) return;

    final rate = s.totalReturnRate;
    String title = '';
    String body = '';
    bool triggered = false;

    if (s.alertUp != null && rate >= s.alertUp!) {
      triggered = true;
      title = '止盈提醒 · ${s.stockName}';
      body =
          '累计浮盈已达 ${rate.toStringAsFixed(1)}%，触达止盈线 +${s.alertUp!.toStringAsFixed(1)}%';
    } else if (s.alertDown != null && rate <= s.alertDown!) {
      triggered = true;
      title = '止损提醒 · ${s.stockName}';
      body =
          '累计亏损已达 ${rate.toStringAsFixed(1)}%，触达止损线 ${s.alertDown!.toStringAsFixed(1)}%';
    }

    if (triggered) {
      await NotificationService.instance.showPriceAlert(
          title: title, body: body);
      state = state.map((h) {
        if (h.id == s.id) {
          return h.copyWithAlert(alertTriggeredDate: today);
        }
        return h;
      }).toList();
      await _saveToHive();
    }
  }

  // ── 刷新所有持仓 ──
  Future<void> refreshAll() async {
    final symbols = state.map((s) => (s.symbol, s.market)).toSet();
    for (final pair in symbols) {
      await _refreshOne(pair.$1, pair.$2);
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }
}
