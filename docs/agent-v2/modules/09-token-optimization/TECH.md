# M09 Token 优化 — 技术实现文档

> 版本：v1.0 | 最后更新：2026-03-22

---

## 1. Prompt Caching（改动最小，收益最大）

### 原理

Anthropic Messages API 支持在 system prompt 的内容块上标记 `cache_control`，5分钟内相同内容命中缓存后：
- cache_read_input_tokens 费用 = 原价的 **10%**
- cache_write_input_tokens 费用 = 原价的 **125%**（首次写入，值得）

5分钟内同一用户连续对话，system prompt 命中率接近 100%。

### 实现

```dart
// lib/features/ai_chat/data/claude_client.dart
// 修改 API 请求体，将 system 从字符串改为带 cache_control 的数组

Map<String, dynamic> buildRequest({
  required String systemPrompt,
  required List<Map<String, dynamic>> messages,
  bool enableCaching = true,
}) {
  final systemContent = enableCaching
      ? [
          {
            'type': 'text',
            'text': systemPrompt,
            'cache_control': {'type': 'ephemeral'}, // ← 关键
          }
        ]
      : systemPrompt; // 不缓存时传字符串（兼容旧逻辑）

  return {
    'model': 'claude-sonnet-4-20250514',
    'max_tokens': 1024,
    'system': systemContent,
    'messages': messages,
  };
}
```

### 费用对比示例

假设 system prompt = 800 token，用户连续对话 10 次：

| | 无缓存 | 有缓存（5min内） |
|--|-------|----------------|
| 第1次 | 800 tok input | 800 tok cache_write |
| 第2-10次 | 800×9=7200 tok input | 800×9=7200 tok cache_read |
| **费用倍率** | 1x | **0.125×1 + 0.10×9 = 10.25% ≈ 0.1x** |

---

## 2. 对话历史滑动窗口

```dart
// lib/features/ai_chat/data/history_manager.dart

class HistoryManager {
  static const int _maxMessages = 8;
  static const int _maxTokensEstimate = 4000;

  /// 裁剪历史，返回适合发送给 API 的消息列表
  static Future<List<Map<String, dynamic>>> trim({
    required List<Map<String, dynamic>> fullHistory,
    required Future<String> Function(String) callAI,
  }) async {
    if (fullHistory.length <= _maxMessages) return fullHistory;

    // 估算当前 token（粗略：中文字符数 / 1.5）
    final estimatedTokens = _estimateTokens(fullHistory);
    if (estimatedTokens <= _maxTokensEstimate) return fullHistory;

    // 超出阈值，压缩最旧的消息
    final toCompress = fullHistory.sublist(0, fullHistory.length - _maxMessages);
    final recent = fullHistory.sublist(fullHistory.length - _maxMessages);

    final summaryText = await ConversationSummarizer.summarize(
      history: toCompress.cast(),
      callAI: callAI,
    );

    // 用摘要替换旧消息
    return [
      {'role': 'assistant', 'content': '[历史摘要] $summaryText'},
      ...recent,
    ];
  }

  static int _estimateTokens(List<Map<String, dynamic>> history) {
    final totalChars = history
        .map((m) => (m['content'] as String? ?? '').length)
        .fold(0, (a, b) => a + b);
    return (totalChars / 1.5).round();
  }
}
```

---

## 3. 市场数据话题相关性过滤

```dart
// lib/features/ai_chat/data/prompt_builder.dart 中 _layer2MarketData() 修改

String _layer2MarketData(String userMessage) {
  if (marketRates == null || marketRates!.isEmpty) return '';

  // 话题不相关时跳过
  if (!_isMarketDataRelevant(userMessage)) return '';

  // ... 原有构建逻辑 ...
}

bool _isMarketDataRelevant(String message) {
  // 明确不相关的纯规划话题
  const irrelevantKeywords = [
    '养老', '退休', '子女教育', '教育金', '保险规划',
    '遗产', '财富传承', '风险偏好', '风险测评', '目标规划',
  ];
  if (irrelevantKeywords.any(message.contains)) return false;

  // 默认注入（保守策略：不确定时宁可多注入）
  return true;
}
```

---

## 4. Token 使用监控（Debug 模式）

```dart
// lib/features/ai_chat/data/token_monitor.dart

class TokenMonitor {
  static void logUsage(Map<String, dynamic> apiResponse) {
    if (!kDebugMode) return;

    final usage = apiResponse['usage'] as Map<String, dynamic>?;
    if (usage == null) return;

    final inputTokens = usage['input_tokens'] ?? 0;
    final outputTokens = usage['output_tokens'] ?? 0;
    final cacheRead = usage['cache_read_input_tokens'] ?? 0;
    final cacheWrite = usage['cache_creation_input_tokens'] ?? 0;

    debugPrint('''
=== Token 使用报告 ===
输入 tokens:      $inputTokens
输出 tokens:      $outputTokens
缓存命中 tokens:  $cacheRead  (节省 ${(cacheRead * 0.9).round()} token 费用)
缓存写入 tokens:  $cacheWrite
缓存命中率:       ${inputTokens > 0 ? (cacheRead / (inputTokens + cacheRead) * 100).toStringAsFixed(1) : 0}%
''');
  }
}
```

---

## 5. 各优化项实施顺序

| 步骤 | 改动文件 | 预估工时 |
|------|---------|---------|
| 1. Prompt Caching | `claude_client.dart` | 1小时 |
| 2. 历史滑动窗口 | `history_manager.dart` + `ai_chat_page.dart` | 2小时 |
| 3. 市场数据过滤 | `prompt_builder.dart` | 1小时 |
| 4. System prompt 精简 | `prompt_builder.dart` 人格层文字 | 0.5小时 |

---

## 6. 测试计划

| 用例 | 预期 |
|------|------|
| 连续发送2条消息，第2条有 cache_read_input_tokens > 0 | API 响应验证 |
| 历史超8条后，传给 API 的 messages.length <= 9（8条+1条摘要） | 单元测试 |
| 问"养老规划"，Layer2 market data 为空 | 单元测试 |
| 问"黄金涨了吗"，Layer2 market data 非空 | 单元测试 |

---

## 7. 文件清单

```
lib/features/ai_chat/data/
├── history_manager.dart        # 新增：滑动窗口裁剪
├── token_monitor.dart          # 新增：debug 监控
└── prompt_builder.dart         # 修改：Prompt Caching + 市场数据过滤

test/logic/
├── history_manager_test.dart
└── token_monitor_test.dart
```
