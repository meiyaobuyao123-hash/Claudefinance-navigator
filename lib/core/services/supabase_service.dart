import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 自托管云同步服务（腾讯云服务器 + PostgreSQL）
/// 接口：http://43.156.207.26/api/finance/
/// 与原 SupabaseService 接口完全兼容，调用方无需改动
class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  final _storage = const FlutterSecureStorage();
  final _dio = Dio(BaseOptions(
    baseUrl: 'http://43.156.207.26/api/finance',
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
    contentType: 'application/json',
  ));

  static const _deviceIdKey = 'finance_nav_device_id';
  String? _cachedDeviceId;

  // ─── 设备唯一 ID（本地生成，持久化）───
  Future<String> get deviceId async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;
    var id = await _storage.read(key: _deviceIdKey);
    if (id == null) {
      id = _generateUuid();
      await _storage.write(key: _deviceIdKey, value: id);
    }
    _cachedDeviceId = id;
    return id;
  }

  // 兼容旧调用方（之前会检查 Supabase Auth user，现在统一用 device_id）
  Future<String> get currentOwnerId => deviceId;

  String _generateUuid() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex =
        bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  // ──────────────────────────────────────────────────
  // ── 基金持仓 ──
  // ──────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>?> loadHoldings() async {
    try {
      final id = await deviceId;
      final resp = await _dio.get('/fund-holdings/$id');
      return List<Map<String, dynamic>>.from(resp.data as List);
    } catch (_) {
      return null;
    }
  }

  Future<void> upsertHolding(Map<String, dynamic> holding) async {
    try {
      final id = await deviceId;
      await _dio.post('/fund-holdings', data: {
        'id': holding['id'],
        'device_id': id,
        'fund_code': holding['fundCode'],
        'fund_name': holding['fundName'],
        'shares': holding['shares'],
        'cost_nav': holding['costNav'],
        'added_date': holding['addedDate'],
        'alert_up': holding['alertUp'],
        'alert_down': holding['alertDown'],
        'alert_triggered_date': holding['alertTriggeredDate'],
      });
    } catch (_) {}
  }

  Future<void> deleteHolding(String holdingId) async {
    try {
      final id = await deviceId;
      await _dio.delete('/fund-holdings/$id/$holdingId');
    } catch (_) {}
  }

  // ──────────────────────────────────────────────────
  // ── 持仓快照 ──
  // ──────────────────────────────────────────────────

  Future<void> saveSnapshot({
    required double totalValue,
    required double totalCost,
  }) async {
    try {
      final id = await deviceId;
      await _dio.post('/snapshots', data: {
        'device_id': id,
        'total_value': totalValue,
        'total_cost': totalCost,
      });
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>?> loadSnapshots({int days = 30}) async {
    try {
      final id = await deviceId;
      final resp =
          await _dio.get('/snapshots/$id', queryParameters: {'days': days});
      return List<Map<String, dynamic>>.from(resp.data as List);
    } catch (_) {
      return null;
    }
  }

  // ──────────────────────────────────────────────────
  // ── 股票持仓 ──
  // ──────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>?> loadStockHoldings() async {
    try {
      final id = await deviceId;
      final resp = await _dio.get('/stock-holdings/$id');
      return List<Map<String, dynamic>>.from(resp.data as List);
    } catch (_) {
      return null;
    }
  }

  Future<void> upsertStockHolding(Map<String, dynamic> stock) async {
    try {
      final id = await deviceId;
      await _dio.post('/stock-holdings', data: {
        'id': stock['id'],
        'device_id': id,
        'symbol': stock['symbol'],
        'stock_name': stock['stock_name'],
        'market': stock['market'],
        'shares': stock['shares'],
        'cost_price': stock['cost_price'],
        'added_date': stock['added_date'],
        'alert_up': stock['alertUp'],
        'alert_down': stock['alertDown'],
        'alert_triggered_date': stock['alertTriggeredDate'],
      });
    } catch (_) {}
  }

  Future<void> deleteStockHolding(String stockId) async {
    try {
      final id = await deviceId;
      await _dio.delete('/stock-holdings/$id/$stockId');
    } catch (_) {}
  }

  // ──────────────────────────────────────────────────
  // ── 自选 Watchlist ──
  // ──────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>?> loadWatchlist() async {
    try {
      final id = await deviceId;
      final resp = await _dio.get('/watchlist/$id');
      return List<Map<String, dynamic>>.from(resp.data as List);
    } catch (_) {
      return null;
    }
  }

  Future<void> upsertWatchItem(Map<String, dynamic> item) async {
    try {
      final id = await deviceId;
      await _dio.post('/watchlist', data: {
        'id': item['id'],
        'device_id': id,
        'symbol': item['symbol'],
        'name': item['name'],
        'market': item['market'],
        'added_price': item['added_price'],
        'added_date': item['added_date'],
        'alert_up': item['alert_up'],
        'alert_down': item['alert_down'],
        'alert_triggered_date': item['alert_triggered_date'],
      });
    } catch (_) {}
  }

  Future<void> deleteWatchItem(String itemId) async {
    try {
      final id = await deviceId;
      await _dio.delete('/watchlist/$id/$itemId');
    } catch (_) {}
  }

  // ──────────────────────────────────────────────────
  // ── 删除账户：清除所有用户数据 ──
  // ──────────────────────────────────────────────────

  Future<bool> deleteAllUserData() async {
    try {
      final id = await deviceId;
      await _dio.delete('/all-data/$id');
      return true;
    } catch (_) {
      return false;
    }
  }

  // ─── 全量同步（逐条 upsert）───
  Future<void> syncAll(List<Map<String, dynamic>> holdings) async {
    for (final h in holdings) {
      await upsertHolding(h);
    }
  }
}
