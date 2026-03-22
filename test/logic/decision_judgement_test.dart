import 'package:flutter_test/flutter_test.dart';
import 'package:finance_navigator/features/decisions/data/models/decision_record.dart';
import 'package:finance_navigator/features/decisions/data/decision_judgement.dart';

/// 创建测试用的 DecisionRecord
DecisionRecord _makeRecord({
  required String type,
  required String category,
  required String expectation,
  double amount = 100000,
  double? csi300AtDecision,
  double? moneyYieldAtDecision,
  List<DecisionCheckpoint> checkpoints = const [],
}) {
  return DecisionRecord(
    id: 'test-id',
    type: type,
    productCategory: category,
    amount: amount,
    rationale: '测试理由',
    expectation: expectation,
    csi300AtDecision: csi300AtDecision,
    moneyYieldAtDecision: moneyYieldAtDecision,
    createdAt: DateTime(2026, 1, 1),
    checkpoints: checkpoints,
  );
}

void main() {
  group('generateJudgement — 固定收益类（利率下降预期）', () {
    test('利率下降 >0.05% → verdict=correct，包含多收益金额', () {
      final r = _makeRecord(
        type: DecisionType.buy,
        category: '大额存单',
        expectation: DecisionExpectation.rateDown,
        amount: 100000,
        moneyYieldAtDecision: 2.0,
      );
      final result = generateJudgement(
        record: r,
        period: '3个月',
        currentYield: 1.5, // 利率下降 0.5%
      );
      expect(result['verdict'], 'correct');
      expect(result['text'], contains('成功锁定了更高的利率'));
    });

    test('利率上升 >0.05% → verdict=incorrect', () {
      final r = _makeRecord(
        type: DecisionType.buy,
        category: '国债',
        expectation: DecisionExpectation.rateDown,
        moneyYieldAtDecision: 1.5,
      );
      final result = generateJudgement(
        record: r,
        period: '3个月',
        currentYield: 2.5, // 利率上升 1.0%
      );
      expect(result['verdict'], 'incorrect');
      expect(result['text'], contains('不降反升'));
    });

    test('利率变化 <=0.05% → verdict=neutral', () {
      final r = _makeRecord(
        type: DecisionType.buy,
        category: '银行理财',
        expectation: DecisionExpectation.rateDown,
        moneyYieldAtDecision: 1.80,
      );
      final result = generateJudgement(
        record: r,
        period: '3个月',
        currentYield: 1.82, // 差值 -0.02，在中性范围内
      );
      expect(result['verdict'], 'neutral');
      expect(result['text'], contains('变化不明显'));
    });

    test('利率数据缺失（currentYield=null）→ neutral + 提示手动对比', () {
      final r = _makeRecord(
        type: DecisionType.buy,
        category: '定期存款',
        expectation: DecisionExpectation.rateDown,
        moneyYieldAtDecision: 1.8,
      );
      final result = generateJudgement(
        record: r,
        period: '3个月',
        currentYield: null,
      );
      expect(result['verdict'], 'neutral');
      expect(result['text'], contains('无法自动评估'));
    });

    test('非 buy 类型的固定收益不触发专项逻辑 → 通用 neutral', () {
      final r = _makeRecord(
        type: DecisionType.sell, // 卖出，不触发利率逻辑
        category: '大额存单',
        expectation: DecisionExpectation.rateDown,
        moneyYieldAtDecision: 1.8,
      );
      final result = generateJudgement(
        record: r,
        period: '3个月',
        currentYield: 1.0,
      );
      // sell 不匹配固定收益 buy 分支，落入通用逻辑
      expect(result['verdict'], 'neutral');
      expect(result['text'], contains('建议对比当前市场情况'));
    });
  });

  group('generateJudgement — 权益类（价格上涨预期）', () {
    test('沪深300上涨 >3% → verdict=correct', () {
      final r = _makeRecord(
        type: DecisionType.buy,
        category: 'A股ETF',
        expectation: DecisionExpectation.priceUp,
        csi300AtDecision: 3500.0,
      );
      final result = generateJudgement(
        record: r,
        period: '3个月',
        currentCSI300: 3700.0, // 涨 5.7%
      );
      expect(result['verdict'], 'correct');
      expect(result['text'], contains('印证了你的判断'));
    });

    test('沪深300轻度下跌（-3% ~ -15%）→ verdict=neutral', () {
      final r = _makeRecord(
        type: DecisionType.buy,
        category: '主动基金',
        expectation: DecisionExpectation.priceUp,
        csi300AtDecision: 3500.0,
      );
      final result = generateJudgement(
        record: r,
        period: '3个月',
        currentCSI300: 3350.0, // 跌 4.3%
      );
      expect(result['verdict'], 'neutral');
      expect(result['text'], contains('若持仓周期为长期'));
    });

    test('沪深300大幅下跌（<-15%）→ verdict=incorrect', () {
      final r = _makeRecord(
        type: DecisionType.buy,
        category: '港股',
        expectation: DecisionExpectation.priceUp,
        csi300AtDecision: 4000.0,
      );
      final result = generateJudgement(
        record: r,
        period: '6个月',
        currentCSI300: 3200.0, // 跌 20%
      );
      expect(result['verdict'], 'incorrect');
    });

    test('沪深300基本持平（-3% ~ +3%）→ verdict=neutral', () {
      final r = _makeRecord(
        type: DecisionType.buy,
        category: '美股ETF',
        expectation: DecisionExpectation.priceUp,
        csi300AtDecision: 3500.0,
      );
      final result = generateJudgement(
        record: r,
        period: '3个月',
        currentCSI300: 3510.0, // 涨 0.3%，持平
      );
      expect(result['verdict'], 'neutral');
      expect(result['text'], contains('基本持平'));
    });

    test('市场数据缺失（currentCSI300=null）→ neutral + 提示无数据', () {
      final r = _makeRecord(
        type: DecisionType.buy,
        category: 'A股ETF',
        expectation: DecisionExpectation.priceUp,
        csi300AtDecision: 3500.0,
      );
      final result = generateJudgement(
        record: r,
        period: '3个月',
        currentCSI300: null,
      );
      expect(result['verdict'], 'neutral');
      expect(result['text'], contains('暂无市场价格数据'));
    });
  });

  group('generateJudgement — 通用逻辑', () {
    test('其他类别/预期 → 通用中性文字 + neutral', () {
      final r = _makeRecord(
        type: DecisionType.buy,
        category: '黄金',
        expectation: DecisionExpectation.riskHedge,
      );
      final result = generateJudgement(
        record: r,
        period: '1年',
        currentCSI300: 3500.0,
        currentYield: 1.5,
      );
      expect(result['verdict'], 'neutral');
      expect(result['text'], contains('建议对比当前市场情况'));
      expect(result['text'], contains('测试理由'));
    });

    test('通用逻辑 period 文字包含在 text 中', () {
      final r = _makeRecord(
        type: DecisionType.rebalance,
        category: '保险',
        expectation: DecisionExpectation.other,
      );
      final result = generateJudgement(
        record: r,
        period: '6个月',
      );
      expect(result['text'], contains('6个月'));
    });
  });
}
