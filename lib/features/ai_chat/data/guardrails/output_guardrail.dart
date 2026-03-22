class OutputGuardrail {
  static const _disclaimer =
      '\n\n⚠️ 以上内容仅供参考，不构成投资建议。投资有风险，决策请谨慎。';

  /// 检测输出是否含有需要追加免责声明的风险内容
  static bool needsDisclaimer(String response) {
    // 具体A股代码 + 买卖动词
    final stockCodePattern = RegExp(r'(买|卖|持有|推荐).{0,5}[036]\d{5}');
    if (stockCodePattern.hasMatch(response)) return true;

    // 承诺性收益语言
    const guaranteeKeywords = ['保证收益', '稳赚', '一定涨', '必涨', '无风险'];
    if (guaranteeKeywords.any(response.contains)) return true;

    // 具体涨跌幅预测（数字+%+时间词）
    final predictionPattern = RegExp(r'\d+%[^\n]{0,20}(明年|今年|年底|季度|本月)');
    if (predictionPattern.hasMatch(response)) return true;

    return false;
  }

  /// 处理输出：必要时追加免责声明
  static String process(String response) {
    if (needsDisclaimer(response)) {
      return '$response$_disclaimer';
    }
    return response;
  }
}
