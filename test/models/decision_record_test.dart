import 'package:flutter_test/flutter_test.dart';
import 'package:finance_navigator/features/decisions/data/models/decision_record.dart';

void main() {
  group('DecisionRecord', () {
    final baseRecord = DecisionRecord(
      id: 'dr-001',
      type: DecisionType.buy,
      productCategory: 'A股ETF',
      amount: 50000,
      rationale: '看好A股长期走势',
      expectation: DecisionExpectation.priceUp,
      createdAt: DateTime(2026, 1, 1),
    );

    // ── 序列化 ──────────────────────────────────────────
    test('toJson 包含所有必填字段', () {
      final j = baseRecord.toJson();
      expect(j['id'], 'dr-001');
      expect(j['type'], 'buy');
      expect(j['productCategory'], 'A股ETF');
      expect(j['amount'], 50000.0);
      expect(j['rationale'], '看好A股长期走势');
      expect(j['expectation'], 'price_up');
      expect(j['createdAt'], isNotNull);
      expect(j['checkpoints'], isEmpty);
    });

    test('toJson 不包含 null 的 linkedHoldingId', () {
      final j = baseRecord.toJson();
      expect(j.containsKey('linkedHoldingId'), isFalse);
    });

    test('toJson 包含非 null 的 linkedHoldingId', () {
      final withLink = DecisionRecord(
        id: 'dr-002',
        type: DecisionType.buy,
        productCategory: 'A股ETF',
        amount: 10000,
        rationale: '加仓',
        expectation: DecisionExpectation.priceUp,
        linkedHoldingId: 'holding-abc',
        createdAt: DateTime(2026, 1, 1),
      );
      expect(withLink.toJson()['linkedHoldingId'], 'holding-abc');
    });

    test('fromJson → toJson 往返一致', () {
      final json = baseRecord.toJson();
      final restored = DecisionRecord.fromJson(json);
      expect(restored.id, baseRecord.id);
      expect(restored.type, baseRecord.type);
      expect(restored.productCategory, baseRecord.productCategory);
      expect(restored.amount, baseRecord.amount);
      expect(restored.rationale, baseRecord.rationale);
      expect(restored.expectation, baseRecord.expectation);
      expect(restored.linkedHoldingId, isNull);
      expect(restored.checkpoints, isEmpty);
    });

    test('toJsonString / fromJsonString 往返一致', () {
      final s = baseRecord.toJsonString();
      final restored = DecisionRecord.fromJsonString(s);
      expect(restored.id, baseRecord.id);
      expect(restored.amount, baseRecord.amount);
    });

    test('带 checkpoint 的序列化往返', () {
      final checkpoint = DecisionCheckpoint(
        period: '3个月',
        date: DateTime(2026, 4, 1),
        csi300: 3800.0,
        moneyYield: 1.5,
        judgement: '上涨了10%',
        verdict: 'correct',
      );
      final withCp = baseRecord.copyWith(checkpoints: [checkpoint]);
      final restored = DecisionRecord.fromJsonString(withCp.toJsonString());
      expect(restored.checkpoints.length, 1);
      expect(restored.checkpoints.first.period, '3个月');
      expect(restored.checkpoints.first.verdict, 'correct');
      expect(restored.checkpoints.first.csi300, 3800.0);
    });

    test('市场快照字段序列化往返', () {
      final withSnapshot = DecisionRecord(
        id: 'dr-003',
        type: DecisionType.buy,
        productCategory: '大额存单',
        amount: 200000,
        rationale: '利率即将下降',
        expectation: DecisionExpectation.rateDown,
        csi300AtDecision: 3600.5,
        moneyYieldAtDecision: 1.85,
        createdAt: DateTime(2026, 1, 1),
      );
      final restored = DecisionRecord.fromJsonString(withSnapshot.toJsonString());
      expect(restored.csi300AtDecision, 3600.5);
      expect(restored.moneyYieldAtDecision, 1.85);
    });

    // ── copyWith ────────────────────────────────────────
    test('copyWith 只更新 checkpoints，其余字段不变', () {
      final cp = DecisionCheckpoint(
        period: '6个月',
        date: DateTime(2026, 7, 1),
        judgement: '市场持平',
        verdict: 'neutral',
      );
      final updated = baseRecord.copyWith(checkpoints: [cp]);
      expect(updated.id, baseRecord.id);
      expect(updated.type, baseRecord.type);
      expect(updated.checkpoints.length, 1);
      expect(updated.checkpoints.first.period, '6个月');
    });

    // ── hasPendingReview ────────────────────────────────
    test('新创建的记录（刚买入）不应有待复盘', () {
      expect(baseRecord.hasPendingReview, isFalse);
    });

    test('超过90天无复盘的记录应有待复盘', () {
      final old = DecisionRecord(
        id: 'dr-old',
        type: DecisionType.buy,
        productCategory: 'A股ETF',
        amount: 10000,
        rationale: '测试',
        expectation: DecisionExpectation.priceUp,
        createdAt: DateTime.now().subtract(const Duration(days: 100)),
      );
      expect(old.hasPendingReview, isTrue);
    });

    test('已完成所有3个复盘节点的记录不再有待复盘', () {
      final fullyReviewed = baseRecord.copyWith(
        checkpoints: [
          DecisionCheckpoint(period: '3个月', date: DateTime(2026, 4, 1), judgement: 'j1', verdict: 'correct'),
          DecisionCheckpoint(period: '6个月', date: DateTime(2026, 7, 1), judgement: 'j2', verdict: 'neutral'),
          DecisionCheckpoint(period: '1年', date: DateTime(2027, 1, 1), judgement: 'j3', verdict: 'incorrect'),
        ],
      );
      expect(fullyReviewed.hasPendingReview, isFalse);
      expect(fullyReviewed.nextCheckpointDue, isNull);
    });

    // ── latestVerdict ───────────────────────────────────
    test('无复盘时 latestVerdict 为 null', () {
      expect(baseRecord.latestVerdict, isNull);
    });

    test('有复盘时 latestVerdict 返回最后一个 verdict', () {
      final withTwo = baseRecord.copyWith(checkpoints: [
        DecisionCheckpoint(period: '3个月', date: DateTime(2026, 4, 1), judgement: 'j1', verdict: 'correct'),
        DecisionCheckpoint(period: '6个月', date: DateTime(2026, 7, 1), judgement: 'j2', verdict: 'incorrect'),
      ]);
      expect(withTwo.latestVerdict, 'incorrect');
    });

    // ── nextCheckpointDue ───────────────────────────────
    test('0个复盘时 nextCheckpointDue 为创建时间+90天', () {
      final due = baseRecord.nextCheckpointDue;
      expect(due, DateTime(2026, 1, 1).add(const Duration(days: 90)));
    });

    test('1个复盘后 nextCheckpointDue 为创建时间+180天', () {
      final one = baseRecord.copyWith(checkpoints: [
        DecisionCheckpoint(period: '3个月', date: DateTime(2026, 4, 1), judgement: 'j', verdict: 'neutral'),
      ]);
      expect(one.nextCheckpointDue, DateTime(2026, 1, 1).add(const Duration(days: 180)));
    });
  });

  group('DecisionType', () {
    test('label 返回中文', () {
      expect(DecisionType.label('buy'), '买入');
      expect(DecisionType.label('sell'), '卖出/赎回');
      expect(DecisionType.label('rebalance'), '调仓');
      expect(DecisionType.label('renew'), '续期');
      expect(DecisionType.label('pass'), '放弃操作');
    });
  });

  group('DecisionExpectation', () {
    test('label 返回中文', () {
      expect(DecisionExpectation.label('rate_down'), '预期利率下降');
      expect(DecisionExpectation.label('price_up'), '预期价格上涨');
      expect(DecisionExpectation.label('risk_hedge'), '规避风险');
    });
  });

  group('DecisionCheckpoint', () {
    test('fromJson/toJson 往返一致', () {
      final cp = DecisionCheckpoint(
        period: '1年',
        date: DateTime(2027, 1, 1, 10, 30),
        csi300: 4200.0,
        moneyYield: 1.3,
        judgement: '上涨了15%',
        verdict: 'correct',
      );
      final restored = DecisionCheckpoint.fromJson(cp.toJson());
      expect(restored.period, cp.period);
      expect(restored.date, cp.date);
      expect(restored.csi300, cp.csi300);
      expect(restored.verdict, cp.verdict);
    });

    test('可选字段 csi300/moneyYield 为 null 时正确序列化', () {
      final cp = DecisionCheckpoint(
        period: '3个月',
        date: DateTime(2026, 4, 1),
        judgement: '无数据',
        verdict: 'neutral',
      );
      final restored = DecisionCheckpoint.fromJson(cp.toJson());
      expect(restored.csi300, isNull);
      expect(restored.moneyYield, isNull);
    });
  });
}
