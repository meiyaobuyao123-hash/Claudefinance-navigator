/// [M09] 对话历史滑动窗口
/// 保留最近8条消息，超出时压缩旧消息为 AI 摘要
/// PRD 验收：第10条对话 history token < 2000
class HistoryManager {
  static const int _maxMessages = 8;
  static const int _maxTokensEstimate = 4000;

  /// 裁剪历史：同时超过条数和 token 阈值时才压缩
  /// [callAI] 注入 AI 调用函数（便于测试 mock）
  static Future<List<Map<String, String>>> trim({
    required List<Map<String, String>> fullHistory,
    required Future<String> Function(String prompt) callAI,
  }) async {
    if (fullHistory.length <= _maxMessages) return fullHistory;

    final estimatedTokens = estimateTokens(fullHistory);
    if (estimatedTokens <= _maxTokensEstimate) return fullHistory;

    // 压缩最旧消息，保留最近 _maxMessages 条
    final toCompress =
        fullHistory.sublist(0, fullHistory.length - _maxMessages);
    final recent = fullHistory.sublist(fullHistory.length - _maxMessages);

    final summaryPrompt = '''请将以下对话摘要成3-5句话，包含：
1. 用户确认的关键信息（资产情况/目标/风险偏好）
2. 已经讨论过的主要话题
3. 尚未解决的问题

对话：
${toCompress.map((m) => '${m['role']}: ${m['content']}').join('\n')}
''';

    final summaryText = await callAI(summaryPrompt);

    return [
      {'role': 'assistant', 'content': '[历史摘要] $summaryText'},
      ...recent,
    ];
  }

  /// 估算历史消息的 token 数（粗略：字符数 / 1.5）
  static int estimateTokens(List<Map<String, String>> history) {
    final totalChars = history
        .map((m) => (m['content'] ?? '').length)
        .fold(0, (a, b) => a + b);
    return (totalChars / 1.5).round();
  }
}
