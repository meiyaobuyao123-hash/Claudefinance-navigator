import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase 云端数据库服务
/// 使用设备唯一 ID 隔离不同用户的数据（MVP 阶段，无账号体系）
/// 后续接入 Auth 后，替换为 user_id 即可
class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  final _storage = const FlutterSecureStorage();
  SupabaseClient get _client => Supabase.instance.client;

  static const _deviceIdKey = 'finance_nav_device_id';
  static const _table = 'fund_holdings';

  String? _cachedDeviceId;

  // ─── 获取/生成设备唯一 ID ───
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

  // ─── 当前有效 owner ID：已登录用 user_id，未登录用 device_id ───
  Future<String> get currentOwnerId async {
    final user = _client.auth.currentUser;
    if (user != null) return user.id;
    return deviceId;
  }

  String _generateUuid() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant
    final hex =
        bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  // ─── 从云端加载持仓列表 ───
  // 返回 null 表示网络不可用，调用方降级使用 Hive
  Future<List<Map<String, dynamic>>?> loadHoldings() async {
    try {
      final id = await currentOwnerId;
      final response = await _client
          .from(_table)
          .select('id, fund_code, fund_name, shares, cost_nav, added_date')
          .eq('device_id', id)
          .order('created_at');
      return List<Map<String, dynamic>>.from(response);
    } catch (_) {
      return null;
    }
  }

  // ─── 上传单条持仓（upsert：存在则更新，不存在则插入）───
  Future<void> upsertHolding(Map<String, dynamic> holding) async {
    try {
      final id = await currentOwnerId;
      await _client.from(_table).upsert({
        'id': holding['id'],
        'device_id': id,
        'fund_code': holding['fundCode'],
        'fund_name': holding['fundName'],
        'shares': holding['shares'],
        'cost_nav': holding['costNav'],
        'added_date': holding['addedDate'],
      });
    } catch (_) {
      // 网络失败静默处理，Hive 已保存本地数据
    }
  }

  // ─── 删除单条持仓 ───
  Future<void> deleteHolding(String holdingId) async {
    try {
      final id = await currentOwnerId;
      await _client
          .from(_table)
          .delete()
          .eq('id', holdingId)
          .eq('device_id', id);
    } catch (_) {}
  }

  // ──────────────────────────────────────────────────
  // ── 持仓快照 CRUD ──
  // ──────────────────────────────────────────────────
  // Supabase 建表 SQL（首次使用前在 SQL Editor 执行一次）：
  // CREATE TABLE IF NOT EXISTS portfolio_snapshots (
  //   id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  //   device_id text NOT NULL,
  //   total_value decimal(15,4) NOT NULL,
  //   total_cost  decimal(15,4) NOT NULL,
  //   recorded_date date NOT NULL,
  //   created_at timestamptz DEFAULT now(),
  //   UNIQUE(device_id, recorded_date)
  // );
  // ALTER TABLE portfolio_snapshots ENABLE ROW LEVEL SECURITY;
  // CREATE POLICY "allow all for anon" ON portfolio_snapshots
  //   FOR ALL TO anon USING (true) WITH CHECK (true);

  static const _snapTable = 'portfolio_snapshots';

  /// 保存今日快照（upsert，每设备每天只存一条）
  Future<void> saveSnapshot({
    required double totalValue,
    required double totalCost,
  }) async {
    try {
      final id = await currentOwnerId;
      final today = DateTime.now();
      final dateStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      await _client.from(_snapTable).upsert(
        {
          'device_id': id,
          'total_value': totalValue,
          'total_cost': totalCost,
          'recorded_date': dateStr,
        },
        onConflict: 'device_id,recorded_date',
      );
    } catch (_) {
      // 静默处理，快照失败不影响主流程
    }
  }

  /// 加载最近 N 天快照，按日期升序返回
  Future<List<Map<String, dynamic>>?> loadSnapshots({int days = 30}) async {
    try {
      final id = await currentOwnerId;
      final since = DateTime.now().subtract(Duration(days: days));
      final sinceStr =
          '${since.year}-${since.month.toString().padLeft(2, '0')}-${since.day.toString().padLeft(2, '0')}';
      final response = await _client
          .from(_snapTable)
          .select('total_value, total_cost, recorded_date')
          .eq('device_id', id)
          .gte('recorded_date', sinceStr)
          .order('recorded_date');
      return List<Map<String, dynamic>>.from(response);
    } catch (_) {
      return null;
    }
  }

  // ─── 全量同步（本地 → 云端，换设备后可用于恢复）───
  Future<void> syncAll(List<Map<String, dynamic>> holdings) async {
    try {
      final id = await currentOwnerId;
      await _client.from(_table).delete().eq('device_id', id);
      if (holdings.isNotEmpty) {
        await _client.from(_table).insert(
          holdings
              .map((h) => {
                    'id': h['id'],
                    'device_id': id,
                    'fund_code': h['fundCode'],
                    'fund_name': h['fundName'],
                    'shares': h['shares'],
                    'cost_nav': h['costNav'],
                    'added_date': h['addedDate'],
                  })
              .toList(),
        );
      }
    } catch (_) {}
  }
}
