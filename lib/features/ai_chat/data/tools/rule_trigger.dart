/// [M05] 规则触发层 — 基于关键词的工具预触发
/// 规则触发 < 100ms（本地纯文本匹配），PRD 验收标准 AC-4
import 'tool_definitions.dart';

class RuleTrigger {
  /// 根据用户消息返回应预先执行的工具名称列表
  /// 复盘：触发行情 → 注入最新行情到 system prompt；触发持仓 → 注入持仓快照
  static List<String> getTriggeredTools(String message) {
    final triggered = <String>[];

    const marketKeywords = [
      '黄金', 'A股', '沪深', '港股', '美股', '行情',
      '涨跌', '指数', '货基', '利率', '基准',
    ];
    if (marketKeywords.any(message.contains)) {
      triggered.add(kToolMarketRates);
    }

    const portfolioKeywords = [
      '我的持仓', '我的基金', '我的股票', '我的配置',
      '帮我看看', '我现在',
    ];
    if (portfolioKeywords.any(message.contains)) {
      triggered.add(kToolPortfolioSummary);
    }

    return triggered;
  }
}
