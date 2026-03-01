import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../stock_tracker/data/services/stock_api_service.dart';
import '../../../stock_tracker/presentation/providers/stock_tracker_provider.dart';
import '../../data/models/watch_item.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/services/notification_service.dart';

final watchlistProvider =
    StateNotifierProvider<WatchlistNotifier, List<WatchItem>>(
  (ref) => WatchlistNotifier(ref.read(stockApiServiceProvider)),
);

class WatchlistNotifier extends StateNotifier<List<WatchItem>> {
  final StockApiService _api;
  final SupabaseService _supabase = SupabaseService.instance;
  final NotificationService _notify = NotificationService.instance;
  static const _boxName = 'watchlist';
  static const _key = 'items';

  WatchlistNotifier(this._api) : super([]) {
    _loadData();
  }

  // ── 云端优先，降级 Hive ──
  Future<void> _loadData() async {
    await _loadFromHive();

    final cloudData = await _supabase.loadWatchlist();
    if (cloudData != null && cloudData.isNotEmpty) {
      state = cloudData.map((row) => WatchItem.fromJson(row)).toList();
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
          .map((e) => WatchItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {}
  }

  Future<void> _saveToHive() async {
    final box = await Hive.openBox<String>(_boxName);
    await box.put(_key, jsonEncode(state.map((w) => w.toJson()).toList()));
  }

  // ── 添加自选（去重）──
  Future<void> addItem(WatchItem item) async {
    if (state.any((w) => w.symbol == item.symbol)) return;
    state = [...state, item];
    await _saveToHive();
    await _supabase.upsertWatchItem(item.toJson());
    _refreshOne(item);
  }

  // ── 删除自选 ──
  Future<void> removeItem(String id) async {
    state = state.where((w) => w.id != id).toList();
    await _saveToHive();
    await _supabase.deleteWatchItem(id);
  }

  // ── 设置价格提醒 ──
  Future<void> setAlert(
    String id, {
    required double? alertUp,
    required double? alertDown,
  }) async {
    state = state.map((w) {
      if (w.id == id) {
        return w.copyWith(
          alertUp: alertUp,
          alertDown: alertDown,
          clearAlertUp: alertUp == null,
          clearAlertDown: alertDown == null,
          clearAlertTriggeredDate: true,
        );
      }
      return w;
    }).toList();
    await _saveToHive();
    final updated = state.firstWhere((w) => w.id == id);
    await _supabase.upsertWatchItem(updated.toJson());
  }

  // ── 刷新单只行情 ──
  Future<void> _refreshOne(WatchItem item) async {
    state = state
        .map((w) => w.id == item.id ? w.copyWith(isLoading: true) : w)
        .toList();

    try {
      final data = await _api.refreshQuote(item.symbol, item.market);
      if (data == null) throw Exception('无数据');

      final newPrice = (data['current'] as num).toDouble();
      final today = DateTime.now().toIso8601String().substring(0, 10);

      WatchItem? updatedItem;
      state = state.map((w) {
        if (w.id == item.id) {
          updatedItem = w.copyWith(
            currentPrice: newPrice,
            changeRate: (data['changeRate'] as num).toDouble(),
            changeAmount: (data['changeAmount'] as num).toDouble(),
            isLoading: false,
            clearError: true,
          );
          return updatedItem!;
        }
        return w;
      }).toList();

      // 检查预警（当天未触发过才检查）
      if (updatedItem != null && updatedItem!.alertTriggeredDate != today) {
        await _checkPriceAlert(updatedItem!, today);
      }
    } catch (_) {
      state = state
          .map((w) => w.id == item.id
              ? w.copyWith(isLoading: false, errorMsg: '行情获取失败')
              : w)
          .toList();
    }
  }

  // ── 检查并发送价格预警 ──
  Future<void> _checkPriceAlert(WatchItem item, String today) async {
    final price = item.currentPrice;
    String title = '';
    String body = '';
    bool triggered = false;

    if (item.alertUp != null && price >= item.alertUp!) {
      triggered = true;
      title = '涨价提醒 · ${item.name}';
      body =
          '当前 ${price.toStringAsFixed(2)}，已触达上涨提醒价 ${item.alertUp!.toStringAsFixed(2)}';
    } else if (item.alertDown != null && price <= item.alertDown!) {
      triggered = true;
      title = '跌价提醒 · ${item.name}';
      body =
          '当前 ${price.toStringAsFixed(2)}，已触达下跌提醒价 ${item.alertDown!.toStringAsFixed(2)}';
    }

    if (triggered) {
      await _notify.showPriceAlert(title: title, body: body);
      // 标记今日已触发，避免重复推送
      state = state
          .map((w) =>
              w.id == item.id ? w.copyWith(alertTriggeredDate: today) : w)
          .toList();
      await _saveToHive();
    }
  }

  // ── 刷新所有自选行情 ──
  Future<void> refreshAll() async {
    for (final item in List<WatchItem>.from(state)) {
      await _refreshOne(item);
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }
}
