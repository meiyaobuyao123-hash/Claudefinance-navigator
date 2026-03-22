import 'package:flutter_test/flutter_test.dart';
import 'package:finance_navigator/features/stock_tracker/data/models/stock_holding.dart';

void main() {
  group('StockHolding', () {
    const base = StockHolding(
      id: 'sh-001',
      symbol: 'sh600519',
      stockName: '贵州茅台',
      market: 'A',
      shares: 10.0,
      costPrice: 1800.0,
      addedDate: '2026-01-01',
    );

    // ── 序列化 ──────────────────────────────────────────
    test('toJson 包含所有核心字段', () {
      final j = base.toJson();
      expect(j['id'], 'sh-001');
      expect(j['symbol'], 'sh600519');
      expect(j['stock_name'], '贵州茅台');
      expect(j['market'], 'A');
      expect(j['shares'], 10.0);
      expect(j['cost_price'], 1800.0);
      expect(j['added_date'], '2026-01-01');
    });

    test('fromJson 往返一致', () {
      final r = StockHolding.fromJson(base.toJson());
      expect(r.id, base.id);
      expect(r.symbol, base.symbol);
      expect(r.stockName, base.stockName);
      expect(r.market, base.market);
      expect(r.shares, base.shares);
      expect(r.costPrice, base.costPrice);
      expect(r.addedDate, base.addedDate);
      expect(r.alertUp, isNull);
    });

    test('fromJsonString / toJsonString 往返一致', () {
      final r = StockHolding.fromJsonString(base.toJsonString());
      expect(r.id, base.id);
      expect(r.shares, base.shares);
    });

    test('预警字段序列化往返', () {
      const withAlert = StockHolding(
        id: 'sh-002',
        symbol: 'AAPL',
        stockName: 'Apple',
        market: 'US',
        shares: 5.0,
        costPrice: 180.0,
        addedDate: '2026-01-01',
        alertUp: 30.0,
        alertDown: -20.0,
        alertTriggeredDate: '2026-03-22',
      );
      final r = StockHolding.fromJson(withAlert.toJson());
      expect(r.alertUp, 30.0);
      expect(r.alertDown, -20.0);
      expect(r.alertTriggeredDate, '2026-03-22');
    });

    test('added_date 缺失时默认为空字符串', () {
      final json = base.toJson()..remove('added_date');
      final r = StockHolding.fromJson(json);
      expect(r.addedDate, '');
    });

    // ── 计算属性 ────────────────────────────────────────
    test('costAmount = shares × costPrice', () {
      expect(base.costAmount, 18000.0);
    });

    test('currentValue 无行情时使用 costPrice', () {
      expect(base.currentValue, 18000.0); // currentPrice=0, fallback to costPrice
    });

    test('currentValue 有行情时使用 currentPrice', () {
      final h = base.copyWith(currentPrice: 2000.0);
      expect(h.currentValue, closeTo(20000.0, 0.001));
    });

    test('totalReturnRate 计算正确', () {
      final h = base.copyWith(currentPrice: 2000.0);
      expect(h.totalReturnRate, closeTo(11.11, 0.01));
    });

    test('todayGain = shares × changeAmount（有行情时）', () {
      final h = base.copyWith(currentPrice: 2000.0, changeAmount: 50.0);
      expect(h.todayGain, closeTo(500.0, 0.001));
    });

    test('todayGain 无行情时为 0', () {
      expect(base.todayGain, 0.0);
    });

    // ── copyWithHolding ──────────────────────────────────
    test('copyWithHolding 更新份额和成本，保留预警', () {
      const withAlert = StockHolding(
        id: 'sh-001', symbol: 'sh600519', stockName: '贵州茅台',
        market: 'A', shares: 10.0, costPrice: 1800.0, addedDate: '2026-01-01',
        alertUp: 20.0,
      );
      final updated = withAlert.copyWithHolding(shares: 20.0, costPrice: 1900.0);
      expect(updated.shares, 20.0);
      expect(updated.costPrice, 1900.0);
      expect(updated.alertUp, 20.0); // 预警保留
    });

    // ── copyWithAlert ────────────────────────────────────
    test('copyWithAlert clearAlertDown 清除止损', () {
      const withAlert = StockHolding(
        id: 'sh-001', symbol: 'sh600519', stockName: '贵州茅台',
        market: 'A', shares: 10.0, costPrice: 1800.0, addedDate: '2026-01-01',
        alertDown: -15.0,
      );
      final cleared = withAlert.copyWithAlert(clearAlertDown: true);
      expect(cleared.alertDown, isNull);
    });
  });
}
