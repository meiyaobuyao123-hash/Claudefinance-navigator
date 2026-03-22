import 'models/decision_record.dart';

/// 根据当前市场数据，为一条决策生成复盘判断文字和判决结果。
/// 抽取为纯函数，便于单元测试。
Map<String, String> generateJudgement({
  required DecisionRecord record,
  required String period,
  double? currentCSI300,
  double? currentYield,
}) {
  final type = record.type;
  final exp = record.expectation;
  final category = record.productCategory;
  final buf = StringBuffer();
  String verdict = 'neutral';

  // 固定收益类产品 + 预期利率下降
  if ((category == '大额存单' ||
          category == '定期存款' ||
          category == '国债' ||
          category == '银行理财') &&
      exp == DecisionExpectation.rateDown &&
      type == DecisionType.buy) {
    final yieldNow = currentYield;
    final yieldThen = record.moneyYieldAtDecision;
    if (yieldNow != null && yieldThen != null) {
      final diff = yieldThen - yieldNow;
      if (diff > 0.05) {
        buf.write('利率已较决策时下降约${diff.toStringAsFixed(2)}%，你成功锁定了更高的利率，'
            '按${record.amount ~/ 10000}万元计算，每年多收益约'
            '${(record.amount * diff / 100).toStringAsFixed(0)}元。');
        verdict = 'correct';
      } else if (diff < -0.05) {
        buf.write('利率不降反升约${(-diff).toStringAsFixed(2)}%，当时锁定长期产品的时机偏早，'
            '如果等待可能获得更高利率。');
        verdict = 'incorrect';
      } else {
        buf.write('利率变化不明显（约${diff.toStringAsFixed(2)}%），当时决策在利率判断上基本中性。');
        verdict = 'neutral';
      }
    } else {
      buf.write('利率数据暂无法获取，无法自动评估。建议手动对比当前市场利率。');
      verdict = 'neutral';
    }
  }
  // 权益类 + 预期价格上涨
  else if ((category == 'A股ETF' ||
          category == '主动基金' ||
          category == '港股' ||
          category == '美股ETF') &&
      exp == DecisionExpectation.priceUp) {
    final csiNow = currentCSI300;
    final csiThen = record.csi300AtDecision;
    if (csiNow != null && csiThen != null && csiThen > 0) {
      final changePct = (csiNow - csiThen) / csiThen * 100;
      if (changePct > 3) {
        buf.write('沪深300自决策以来上涨了约${changePct.toStringAsFixed(1)}%，'
            '市场整体走势印证了你的判断。');
        verdict = 'correct';
      } else if (changePct < -3) {
        buf.write('沪深300自决策以来下跌了约${(-changePct).toStringAsFixed(1)}%，'
            '若持仓周期为长期（3年以上），当前波动属正常；若短期持仓需注意风险。');
        verdict = changePct < -15 ? 'incorrect' : 'neutral';
      } else {
        buf.write('沪深300自决策以来基本持平（${changePct >= 0 ? '+' : ''}${changePct.toStringAsFixed(1)}%），市场方向尚不明确。');
        verdict = 'neutral';
      }
    } else {
      buf.write('暂无市场价格数据，无法自动对比。');
      verdict = 'neutral';
    }
  }
  // 通用逻辑
  else {
    final months = record.checkpoints.length + 1;
    buf.write('$period（${months * 3}个月）复盘：你的决策理由是"${record.rationale}"。'
        '建议对比当前市场情况，自主判断这次决策是否达到预期。');
    verdict = 'neutral';
  }

  return {'text': buf.toString(), 'verdict': verdict};
}
