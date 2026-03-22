/// [M04] 对话摘要器 — 防 context rot
/// 当 messageCount >= 20 或 estimatedTokens >= 8000 时，
/// 将早期对话压缩为摘要，保留最近5条。
class ConversationSummarizer {
  /// 将历史消息压缩为摘要 + 最近5条
  /// [callAI] 注入 AI 调用函数，便于测试时 mock
  static Future<List<Map<String, String>>> summarize({
    required List<Map<String, String>> history,
    required Future<String> Function(String prompt) callAI,
  }) async {
    if (history.length <= 5) return history;

    final toSummarize = history.sublist(0, history.length - 5);
    final recent = history.sublist(history.length - 5);

    final summaryPrompt = '''请将以下对话摘要成3-5句话，包含：
1. 用户确认的关键信息（资产情况/目标/风险偏好）
2. 已经讨论过的主要话题
3. 尚未解决的问题

对话：
${toSummarize.map((m) => '${m['role']}: ${m['content']}').join('\n')}
''';

    final summary = await callAI(summaryPrompt);

    return [
      {'role': 'assistant', 'content': '[对话摘要] $summary'},
      ...recent,
    ];
  }
}
