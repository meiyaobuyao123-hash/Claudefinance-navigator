class InputGuardrail {
  static const _injectionPatterns = [
    r'(ignore|forget|disregard).{0,20}(previous|prior|above|instruction)',
    r'(忘记|无视|忽略).{0,20}(指令|提示词|设定|限制)',
    r'(假设|扮演|现在你是|你现在是).{0,20}(没有限制|无限制|DAN|GPT)',
    r'(system prompt|系统提示词).{0,10}(是什么|给我看|输出)',
    r'(jailbreak|越狱)',
    r'act as.{0,20}(without|no).{0,20}(restriction|limit)',
  ];

  static const _blockedResponse = '我是明理，专注于理财规划辅助。如果你有理财相关的问题，我很乐意帮忙！';

  /// 返回 null 表示通过；返回字符串表示被拦截，直接作为 AI 回复显示
  static String? check(String userMessage) {
    final lower = userMessage.toLowerCase();
    for (final pattern in _injectionPatterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(lower)) {
        return _blockedResponse;
      }
    }
    return null;
  }
}
