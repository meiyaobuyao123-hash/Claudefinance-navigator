import 'package:flutter_test/flutter_test.dart';
import 'package:finance_navigator/features/watchlist/data/models/watch_item.dart';

void main() {
  group('WatchItem', () {
    const base = WatchItem(
      id: 'wi-001',
      symbol: '0700.HK',
      name: '腾讯控股',
      market: 'HK',
      addedPrice: 350.0,
      addedDate: '2026-01-01',
    );

    // ── 序列化 ──────────────────────────────────────────
    test('toJson 包含核心字段', () {
      final j = base.toJson();
      expect(j['id'], 'wi-001');
      expect(j['symbol'], '0700.HK');
      expect(j['name'], '腾讯控股');
      expect(j['market'], 'HK');
      expect(j['added_price'], 350.0);
      expect(j['added_date'], '2026-01-01');
    });

    test('toJson 无 alert 时不包含 alert 键', () {
      final j = base.toJson();
      expect(j.containsKey('alert_up'), isFalse);
      expect(j.containsKey('alert_down'), isFalse);
      expect(j.containsKey('alert_triggered_date'), isFalse);
    });

    test('toJson 有 alert 时包含 alert 键', () {
      const withAlert = WatchItem(
        id: 'wi-002', symbol: '0700.HK', name: '腾讯控股',
        market: 'HK', addedPrice: 350.0, addedDate: '2026-01-01',
        alertUp: 400.0, alertDown: 300.0,
      );
      final j = withAlert.toJson();
      expect(j['alert_up'], 400.0);
      expect(j['alert_down'], 300.0);
    });

    test('fromJson 往返一致（无 alert）', () {
      final r = WatchItem.fromJson(base.toJson());
      expect(r.id, base.id);
      expect(r.symbol, base.symbol);
      expect(r.name, base.name);
      expect(r.addedPrice, base.addedPrice);
      expect(r.alertUp, isNull);
      expect(r.alertDown, isNull);
    });

    test('fromJson 往返一致（有 alert）', () {
      const withAlert = WatchItem(
        id: 'wi-003', symbol: 'AAPL', name: 'Apple',
        market: 'US', addedPrice: 180.0, addedDate: '2026-01-01',
        alertUp: 220.0, alertDown: 150.0, alertTriggeredDate: '2026-03-22',
      );
      final r = WatchItem.fromJson(withAlert.toJson());
      expect(r.alertUp, 220.0);
      expect(r.alertDown, 150.0);
      expect(r.alertTriggeredDate, '2026-03-22');
    });

    test('added_date 缺失时默认为空字符串', () {
      final json = base.toJson()..remove('added_date');
      final r = WatchItem.fromJson(json);
      expect(r.addedDate, '');
    });

    test('toJsonString 可被 fromJson(jsonDecode) 还原', () {
      final s = base.toJsonString();
      expect(s, contains('0700.HK'));
      expect(s, contains('腾讯控股'));
    });

    // ── 计算属性 ────────────────────────────────────────
    test('sinceAddedRate 正确计算上涨百分比', () {
      final h = base.copyWith(currentPrice: 385.0);
      expect(h.sinceAddedRate, closeTo(10.0, 0.001));
    });

    test('sinceAddedRate 正确计算下跌百分比', () {
      final h = base.copyWith(currentPrice: 315.0);
      expect(h.sinceAddedRate, closeTo(-10.0, 0.001));
    });

    test('sinceAddedRate addedPrice 为 0 时返回 0', () {
      const zero = WatchItem(
        id: 'z', symbol: 'X', name: 'X', market: 'A',
        addedPrice: 0, addedDate: '2026-01-01', currentPrice: 100,
      );
      expect(zero.sinceAddedRate, 0.0);
    });

    // ── copyWith ────────────────────────────────────────
    test('copyWith 更新实时价格', () {
      final updated = base.copyWith(currentPrice: 380.0, changeRate: 8.6);
      expect(updated.currentPrice, 380.0);
      expect(updated.changeRate, 8.6);
      expect(updated.name, base.name); // 不变
    });

    test('copyWith clearAlertUp 清除止盈', () {
      const withAlert = WatchItem(
        id: 'wi-001', symbol: '0700.HK', name: '腾讯', market: 'HK',
        addedPrice: 350.0, addedDate: '2026-01-01', alertUp: 400.0,
      );
      final cleared = withAlert.copyWith(clearAlertUp: true);
      expect(cleared.alertUp, isNull);
    });

    test('copyWith clearError 清除错误信息', () {
      const withErr = WatchItem(
        id: 'wi-001', symbol: '0700.HK', name: '腾讯', market: 'HK',
        addedPrice: 350.0, addedDate: '2026-01-01', errorMsg: '网络错误',
      );
      final cleared = withErr.copyWith(clearError: true);
      expect(cleared.errorMsg, isNull);
    });
  });
}
