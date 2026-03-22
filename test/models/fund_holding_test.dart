import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:finance_navigator/features/fund_tracker/data/models/fund_holding.dart';

void main() {
  group('FundHolding', () {
    final base = FundHolding(
      id: 'fh-001',
      fundCode: '000001',
      fundName: '华夏成长',
      shares: 1000.0,
      costNav: 2.0,
      addedDate: '2026-01-01',
    );

    // ── 序列化 ──────────────────────────────────────────
    test('toJson 包含所有核心字段', () {
      final j = base.toJson();
      expect(j['id'], 'fh-001');
      expect(j['fundCode'], '000001');
      expect(j['fundName'], '华夏成长');
      expect(j['shares'], 1000.0);
      expect(j['costNav'], 2.0);
      expect(j['addedDate'], '2026-01-01');
    });

    test('toJson 不包含实时字段（currentNav/estimatedNav 等）', () {
      final j = base.toJson();
      expect(j.containsKey('currentNav'), isFalse);
      expect(j.containsKey('estimatedNav'), isFalse);
      expect(j.containsKey('isLoading'), isFalse);
    });

    test('fromJson 往返一致', () {
      final j = base.toJson();
      final r = FundHolding.fromJson(j);
      expect(r.id, base.id);
      expect(r.fundCode, base.fundCode);
      expect(r.shares, base.shares);
      expect(r.costNav, base.costNav);
      expect(r.addedDate, base.addedDate);
      expect(r.alertUp, isNull);
      expect(r.alertDown, isNull);
    });

    test('toJsonString / fromJson(jsonDecode) 往返一致', () {
      final s = base.toJsonString();
      final r = FundHolding.fromJson(jsonDecode(s) as Map<String, dynamic>);
      expect(r.id, base.id);
      expect(r.fundName, base.fundName);
    });

    test('预警字段序列化往返', () {
      final withAlert = FundHolding(
        id: 'fh-002',
        fundCode: '000001',
        fundName: '华夏成长',
        shares: 500.0,
        costNav: 1.8,
        addedDate: '2026-01-01',
        alertUp: 20.0,
        alertDown: -10.0,
        alertTriggeredDate: '2026-03-22',
      );
      final r = FundHolding.fromJson(withAlert.toJson());
      expect(r.alertUp, 20.0);
      expect(r.alertDown, -10.0);
      expect(r.alertTriggeredDate, '2026-03-22');
    });

    // ── 计算属性 ────────────────────────────────────────
    test('costAmount = shares × costNav', () {
      expect(base.costAmount, 2000.0);
    });

    test('currentValue 无估值时使用 currentNav', () {
      final h = base.copyWith(currentNav: 2.5, hasEstimate: false);
      expect(h.currentValue, closeTo(2500.0, 0.001));
    });

    test('currentValue 有估值时使用 estimatedNav', () {
      final h = base.copyWith(estimatedNav: 2.2, currentNav: 2.0, hasEstimate: true);
      expect(h.currentValue, closeTo(2200.0, 0.001));
    });

    test('totalReturn 计算正确', () {
      final h = base.copyWith(currentNav: 2.5, hasEstimate: false);
      expect(h.totalReturn, closeTo(500.0, 0.001));
    });

    test('totalReturnRate 计算正确（%）', () {
      final h = base.copyWith(currentNav: 2.5, hasEstimate: false);
      expect(h.totalReturnRate, closeTo(25.0, 0.001));
    });

    test('todayGain 无估值时为 0', () {
      final h = base.copyWith(currentNav: 2.5, changeRate: 1.0, hasEstimate: false);
      expect(h.todayGain, 0.0);
    });

    test('todayGain 有估值时正确计算', () {
      final h = base.copyWith(estimatedNav: 2.1, currentNav: 2.0, changeRate: 5.0, hasEstimate: true);
      // shares * estimatedNav * changeRate / 100 = 1000 * 2.1 * 5 / 100 = 105
      expect(h.todayGain, closeTo(105.0, 0.001));
    });

    test('costAmount 为 0 时 totalReturnRate 不抛异常', () {
      final zero = FundHolding(
        id: 'x', fundCode: '000001', fundName: 'test', shares: 0, costNav: 0, addedDate: '',
      );
      expect(zero.totalReturnRate, 0.0);
    });

    // ── copyWithHolding ──────────────────────────────────
    test('copyWithHolding 更新份额和成本', () {
      final updated = base.copyWithHolding(shares: 1500.0, costNav: 1.9);
      expect(updated.shares, 1500.0);
      expect(updated.costNav, 1.9);
      expect(updated.fundCode, base.fundCode);
    });

    // ── copyWithAlert ────────────────────────────────────
    test('copyWithAlert 设置预警', () {
      final alerted = base.copyWithAlert(alertUp: 25.0, alertDown: -15.0);
      expect(alerted.alertUp, 25.0);
      expect(alerted.alertDown, -15.0);
    });

    test('copyWithAlert clearAlertUp 清除止盈', () {
      final withAlert = base.copyWithAlert(alertUp: 20.0);
      final cleared = withAlert.copyWithAlert(clearAlertUp: true);
      expect(cleared.alertUp, isNull);
    });
  });
}
