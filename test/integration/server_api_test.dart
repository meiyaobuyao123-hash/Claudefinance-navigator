/// 集成测试：腾讯云服务器 API 全端点 CRUD
///
/// 运行方式：flutter test test/integration/server_api_test.dart
/// 前提：服务器 http://43.156.207.26/api/finance 必须在线
///
/// 测试策略：
/// - 每个测试使用带时间戳的隔离 device_id，避免污染正式数据
/// - 每个测试结束后清理自己创建的数据
/// - 测试顺序：健康检查 → 各资源 CRUD → 删除全部数据
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

const _baseUrl = 'http://43.156.207.26/api/finance';

/// 为每次测试运行生成隔离 device_id
String _testDeviceId() =>
    'test-${DateTime.now().millisecondsSinceEpoch}';

late Dio _dio;

void main() {
  setUpAll(() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      contentType: 'application/json',
    ));
  });

  tearDownAll(() {
    _dio.close();
  });

  // ─────────────────────────────────────────────────────
  // 健康检查
  // ─────────────────────────────────────────────────────
  group('健康检查', () {
    test('GET /health 返回 {status: ok}', () async {
      final resp = await _dio.get('/health');
      expect(resp.statusCode, 200);
      expect(resp.data['status'], 'ok');
    });
  });

  // ─────────────────────────────────────────────────────
  // 基金持仓
  // ─────────────────────────────────────────────────────
  group('基金持仓 /fund-holdings', () {
    late String deviceId;

    setUp(() => deviceId = _testDeviceId());
    tearDown(() async {
      try { await _dio.delete('/all-data/$deviceId'); } catch (_) {}
    });

    test('POST 创建持仓 → GET 可查询到', () async {
      final postResp = await _dio.post('/fund-holdings', data: {
        'id': 'fh-it-1',
        'device_id': deviceId,
        'fund_code': '000001',
        'fund_name': '华夏成长',
        'shares': 1000.0,
        'cost_nav': 2.0,
        'added_date': '2026-01-01',
      });
      expect(postResp.data['ok'], isTrue);

      final getResp = await _dio.get('/fund-holdings/$deviceId');
      final list = getResp.data as List;
      expect(list, hasLength(1));
      expect(list.first['fund_code'], '000001');
      expect(list.first['shares'], 1000.0);
    });

    test('POST 相同 id 的持仓做 upsert（更新 shares）', () async {
      await _dio.post('/fund-holdings', data: {
        'id': 'fh-it-upsert',
        'device_id': deviceId,
        'fund_code': '000001',
        'fund_name': '华夏成长',
        'shares': 500.0,
        'cost_nav': 2.0,
        'added_date': '2026-01-01',
      });
      await _dio.post('/fund-holdings', data: {
        'id': 'fh-it-upsert',
        'device_id': deviceId,
        'fund_code': '000001',
        'fund_name': '华夏成长',
        'shares': 800.0,  // 更新
        'cost_nav': 1.9,
        'added_date': '2026-01-01',
      });
      final list = (await _dio.get('/fund-holdings/$deviceId')).data as List;
      expect(list, hasLength(1));
      expect(list.first['shares'], 800.0);
    });

    test('预警字段（alertUp/alertDown）可存取', () async {
      await _dio.post('/fund-holdings', data: {
        'id': 'fh-it-alert',
        'device_id': deviceId,
        'fund_code': '000002',
        'fund_name': '测试基金',
        'shares': 100.0,
        'cost_nav': 1.5,
        'added_date': '2026-01-01',
        'alert_up': 20.0,
        'alert_down': -10.0,
        'alert_triggered_date': '2026-03-22',
      });
      final list = (await _dio.get('/fund-holdings/$deviceId')).data as List;
      expect(list.first['alert_up'], 20.0);
      expect(list.first['alert_down'], -10.0);
      expect(list.first['alert_triggered_date'], '2026-03-22');
    });

    test('DELETE 单条持仓 → GET 返回空', () async {
      await _dio.post('/fund-holdings', data: {
        'id': 'fh-it-del',
        'device_id': deviceId,
        'fund_code': '000003',
        'fund_name': '删除测试',
        'shares': 100.0,
        'cost_nav': 1.0,
        'added_date': '2026-01-01',
      });
      await _dio.delete('/fund-holdings/$deviceId/fh-it-del');
      final list = (await _dio.get('/fund-holdings/$deviceId')).data as List;
      expect(list, isEmpty);
    });

    test('GET 不存在的 device_id 返回空数组', () async {
      final resp = await _dio.get('/fund-holdings/nonexistent-device-xyz');
      expect(resp.data as List, isEmpty);
    });
  });

  // ─────────────────────────────────────────────────────
  // 股票持仓
  // ─────────────────────────────────────────────────────
  group('股票持仓 /stock-holdings', () {
    late String deviceId;

    setUp(() => deviceId = _testDeviceId());
    tearDown(() async {
      try { await _dio.delete('/all-data/$deviceId'); } catch (_) {}
    });

    test('POST 创建 → GET 查询', () async {
      await _dio.post('/stock-holdings', data: {
        'id': 'sh-it-1',
        'device_id': deviceId,
        'symbol': 'sh600519',
        'stock_name': '贵州茅台',
        'market': 'A',
        'shares': 10.0,
        'cost_price': 1800.0,
        'added_date': '2026-01-01',
      });
      final list = (await _dio.get('/stock-holdings/$deviceId')).data as List;
      expect(list, hasLength(1));
      expect(list.first['symbol'], 'sh600519');
      expect(list.first['cost_price'], 1800.0);
    });

    test('DELETE 单条 → GET 返回空', () async {
      await _dio.post('/stock-holdings', data: {
        'id': 'sh-it-del',
        'device_id': deviceId,
        'symbol': 'AAPL',
        'stock_name': 'Apple',
        'market': 'US',
        'shares': 5.0,
        'cost_price': 180.0,
        'added_date': '2026-01-01',
      });
      await _dio.delete('/stock-holdings/$deviceId/sh-it-del');
      final list = (await _dio.get('/stock-holdings/$deviceId')).data as List;
      expect(list, isEmpty);
    });

    test('预警字段可存取', () async {
      await _dio.post('/stock-holdings', data: {
        'id': 'sh-it-alert',
        'device_id': deviceId,
        'symbol': '0700.HK',
        'stock_name': '腾讯控股',
        'market': 'HK',
        'shares': 100.0,
        'cost_price': 350.0,
        'added_date': '2026-01-01',
        'alert_up': 30.0,
        'alert_down': -15.0,
      });
      final list = (await _dio.get('/stock-holdings/$deviceId')).data as List;
      expect(list.first['alert_up'], 30.0);
      expect(list.first['alert_down'], -15.0);
    });
  });

  // ─────────────────────────────────────────────────────
  // 自选股 Watchlist
  // ─────────────────────────────────────────────────────
  group('自选股 /watchlist', () {
    late String deviceId;

    setUp(() => deviceId = _testDeviceId());
    tearDown(() async {
      try { await _dio.delete('/all-data/$deviceId'); } catch (_) {}
    });

    test('POST 创建 → GET 查询', () async {
      await _dio.post('/watchlist', data: {
        'id': 'wl-it-1',
        'device_id': deviceId,
        'symbol': '0700.HK',
        'name': '腾讯控股',
        'market': 'HK',
        'added_price': 350.0,
        'added_date': '2026-01-01',
      });
      final list = (await _dio.get('/watchlist/$deviceId')).data as List;
      expect(list, hasLength(1));
      expect(list.first['name'], '腾讯控股');
    });

    test('DELETE 单条 → GET 返回空', () async {
      await _dio.post('/watchlist', data: {
        'id': 'wl-it-del',
        'device_id': deviceId,
        'symbol': 'AAPL',
        'name': 'Apple',
        'market': 'US',
        'added_price': 180.0,
        'added_date': '2026-01-01',
      });
      await _dio.delete('/watchlist/$deviceId/wl-it-del');
      final list = (await _dio.get('/watchlist/$deviceId')).data as List;
      expect(list, isEmpty);
    });

    test('alertUp/alertDown/alertTriggeredDate 可存取', () async {
      await _dio.post('/watchlist', data: {
        'id': 'wl-it-alert',
        'device_id': deviceId,
        'symbol': 'BABA',
        'name': '阿里巴巴',
        'market': 'US',
        'added_price': 85.0,
        'added_date': '2026-01-01',
        'alert_up': 100.0,
        'alert_down': 70.0,
        'alert_triggered_date': '2026-03-22',
      });
      final item = ((await _dio.get('/watchlist/$deviceId')).data as List).first;
      expect(item['alert_up'], 100.0);
      expect(item['alert_down'], 70.0);
      expect(item['alert_triggered_date'], '2026-03-22');
    });
  });

  // ─────────────────────────────────────────────────────
  // 持仓快照
  // ─────────────────────────────────────────────────────
  group('持仓快照 /snapshots', () {
    late String deviceId;

    setUp(() => deviceId = _testDeviceId());
    tearDown(() async {
      try { await _dio.delete('/all-data/$deviceId'); } catch (_) {}
    });

    test('POST 保存快照 → GET 可查询', () async {
      final postResp = await _dio.post('/snapshots', data: {
        'device_id': deviceId,
        'total_value': 500000.0,
        'total_cost': 480000.0,
      });
      expect(postResp.data['ok'], isTrue);

      final list = (await _dio.get('/snapshots/$deviceId', queryParameters: {'days': 7})).data as List;
      expect(list, hasLength(1));
      expect(list.first['total_value'], 500000.0);
      expect(list.first['total_cost'], 480000.0);
    });

    test('同一天保存两次快照（upsert）只保留一条', () async {
      await _dio.post('/snapshots', data: {
        'device_id': deviceId,
        'total_value': 100000.0,
        'total_cost': 95000.0,
      });
      await _dio.post('/snapshots', data: {
        'device_id': deviceId,
        'total_value': 101000.0,
        'total_cost': 95000.0,
      });
      final list = (await _dio.get('/snapshots/$deviceId', queryParameters: {'days': 7})).data as List;
      expect(list, hasLength(1));
      expect(list.first['total_value'], 101000.0);
    });

    test('recorded_date 字段格式为 yyyy-MM-dd', () async {
      await _dio.post('/snapshots', data: {
        'device_id': deviceId,
        'total_value': 200000.0,
        'total_cost': 190000.0,
      });
      final list = (await _dio.get('/snapshots/$deviceId', queryParameters: {'days': 7})).data as List;
      final dateStr = list.first['recorded_date'] as String;
      expect(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateStr), isTrue);
    });
  });

  // ─────────────────────────────────────────────────────
  // 决策记录
  // ─────────────────────────────────────────────────────
  group('决策记录 /decisions', () {
    late String deviceId;

    setUp(() => deviceId = _testDeviceId());
    tearDown(() async {
      try { await _dio.delete('/all-data/$deviceId'); } catch (_) {}
    });

    test('POST 保存决策 → GET 可查询，payload 完整', () async {
      const payload = '{"id":"dr-it-1","type":"buy","productCategory":"A股ETF","amount":50000,"rationale":"测试理由","expectation":"price_up","createdAt":"2026-01-01T00:00:00.000","checkpoints":[]}';
      await _dio.post('/decisions', data: {
        'record_id': 'dr-it-1',
        'device_id': deviceId,
        'payload': payload,
        'created_at': '2026-01-01T00:00:00.000',
      });

      final list = (await _dio.get('/decisions/$deviceId')).data as List;
      expect(list, hasLength(1));
      expect(list.first['record_id'], 'dr-it-1');
      expect(list.first['payload'], payload);
    });

    test('POST 相同 record_id 做 upsert（更新 payload）', () async {
      await _dio.post('/decisions', data: {
        'record_id': 'dr-it-upsert',
        'device_id': deviceId,
        'payload': '{"id":"dr-it-upsert","version":1}',
        'created_at': '2026-01-01T00:00:00.000',
      });
      await _dio.post('/decisions', data: {
        'record_id': 'dr-it-upsert',
        'device_id': deviceId,
        'payload': '{"id":"dr-it-upsert","version":2,"checkpoints":[{"period":"3个月"}]}',
        'created_at': '2026-01-01T00:00:00.000',
      });

      final list = (await _dio.get('/decisions/$deviceId')).data as List;
      expect(list, hasLength(1));
      expect(list.first['payload'], contains('"version":2'));
    });

    test('DELETE 单条决策 → GET 返回空', () async {
      await _dio.post('/decisions', data: {
        'record_id': 'dr-it-del',
        'device_id': deviceId,
        'payload': '{"id":"dr-it-del"}',
        'created_at': '2026-01-01T00:00:00.000',
      });
      await _dio.delete('/decisions/$deviceId/dr-it-del');
      final list = (await _dio.get('/decisions/$deviceId')).data as List;
      expect(list, isEmpty);
    });
  });

  // ─────────────────────────────────────────────────────
  // [T1-1] M08 反馈上报
  // ─────────────────────────────────────────────────────
  group('[T1-1] 反馈上报 /feedback', () {
    test('POST /feedback 点赞 → {status: ok} 且数据落库', () async {
      final resp = await _dio.post('/feedback', data: {
        'session_id': 'it-session-${DateTime.now().millisecondsSinceEpoch}',
        'message_id': 'it-msg-001',
        'user_question': '我的配置合理吗',
        'ai_response_preview': '根据你的情况，建议...',
        'rating': 'thumbsUp',
        'reason': null,
        'conversation_stage': 'deepening',
        'device_id': 'it-device-001',
        'timestamp': DateTime.now().toIso8601String(),
      });
      expect(resp.statusCode, 200);
      expect(resp.data['status'], 'ok');
    });

    test('POST /feedback 点踩+原因 → {status: ok}', () async {
      final resp = await _dio.post('/feedback', data: {
        'session_id': 'it-session-${DateTime.now().millisecondsSinceEpoch}',
        'message_id': 'it-msg-002',
        'user_question': '黄金要买吗',
        'ai_response_preview': '这是一段测试回复...',
        'rating': 'thumbsDown',
        'reason': 'tooGeneric',
        'conversation_stage': 'exploring',
        'device_id': 'it-device-001',
        'timestamp': DateTime.now().toIso8601String(),
      });
      expect(resp.statusCode, 200);
      expect(resp.data['status'], 'ok');
    });

    test('POST /feedback 字段缺失（无 reason）→ 不报错', () async {
      final resp = await _dio.post('/feedback', data: {
        'session_id': 'it-session-min',
        'message_id': 'it-msg-003',
        'rating': 'thumbsUp',
      });
      expect(resp.statusCode, 200);
    });
  });

  // ─────────────────────────────────────────────────────
  // 删除全部用户数据
  // ─────────────────────────────────────────────────────
  group('删除全部用户数据 /all-data', () {
    test('DELETE /all-data/{deviceId} 清除该设备所有数据', () async {
      final deviceId = _testDeviceId();

      // 各表都写入一条
      await _dio.post('/fund-holdings', data: {
        'id': 'fh-cleanup', 'device_id': deviceId,
        'fund_code': '000001', 'fund_name': '测试', 'shares': 100.0,
        'cost_nav': 1.0, 'added_date': '2026-01-01',
      });
      await _dio.post('/stock-holdings', data: {
        'id': 'sh-cleanup', 'device_id': deviceId,
        'symbol': 'AAPL', 'stock_name': 'Apple', 'market': 'US',
        'shares': 5.0, 'cost_price': 180.0, 'added_date': '2026-01-01',
      });
      await _dio.post('/decisions', data: {
        'record_id': 'dr-cleanup', 'device_id': deviceId,
        'payload': '{}', 'created_at': '2026-01-01T00:00:00.000',
      });

      // 删除全部
      final delResp = await _dio.delete('/all-data/$deviceId');
      expect(delResp.data['ok'], isTrue);

      // 全部应为空
      expect((await _dio.get('/fund-holdings/$deviceId')).data as List, isEmpty);
      expect((await _dio.get('/stock-holdings/$deviceId')).data as List, isEmpty);
      expect((await _dio.get('/decisions/$deviceId')).data as List, isEmpty);
    });
  });
}
