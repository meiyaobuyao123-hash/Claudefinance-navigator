/// [M09] Token 使用监控（仅 Debug 模式输出）
/// PRD 验收：Prompt Caching 命中时显示 cache_read_input_tokens
import 'package:flutter/foundation.dart';

class TokenMonitor {
  /// 打印 API 响应中的 token 使用情况（debug only）
  static void logUsage(Map<String, dynamic>? usage) {
    if (!kDebugMode) return;
    if (usage == null) return;

    final inputTokens = (usage['input_tokens'] as num?)?.toInt() ?? 0;
    final outputTokens = (usage['output_tokens'] as num?)?.toInt() ?? 0;
    final cacheRead =
        (usage['cache_read_input_tokens'] as num?)?.toInt() ?? 0;
    final cacheWrite =
        (usage['cache_creation_input_tokens'] as num?)?.toInt() ?? 0;

    final totalBillable = inputTokens + cacheRead;
    final hitRate = totalBillable > 0
        ? (cacheRead / totalBillable * 100).toStringAsFixed(1)
        : '0.0';

    debugPrint('=== Token 使用报告 ===');
    debugPrint('输入 tokens:     $inputTokens');
    debugPrint('输出 tokens:     $outputTokens');
    debugPrint(
        '缓存命中 tokens: $cacheRead  (节省 ${(cacheRead * 0.9).round()} token 费用)');
    debugPrint('缓存写入 tokens: $cacheWrite');
    debugPrint('缓存命中率:      $hitRate%');
  }

  /// 根据 usage 计算节省百分比（测试辅助方法）
  static double savingPercent(Map<String, dynamic> usage) {
    final input = (usage['input_tokens'] as num?)?.toInt() ?? 0;
    final cacheRead =
        (usage['cache_read_input_tokens'] as num?)?.toInt() ?? 0;
    final total = input + cacheRead;
    if (total == 0) return 0.0;
    return cacheRead * 0.9 / total * 100;
  }

  /// 是否有缓存命中（用于测试断言）
  static bool hasCacheHit(Map<String, dynamic> usage) {
    final cacheRead =
        (usage['cache_read_input_tokens'] as num?)?.toInt() ?? 0;
    return cacheRead > 0;
  }
}
