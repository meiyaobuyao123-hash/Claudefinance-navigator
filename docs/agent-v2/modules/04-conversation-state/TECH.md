# M04 对话阶段状态机 — 技术实现文档

> 版本：v1.0 | 最后更新：2026-03-22

---

## 1. 状态定义

```dart
// lib/features/ai_chat/data/conversation_state.dart

enum ConversationStage { exploring, deepening, actioning, reviewing }

class ConversationState {
  final ConversationStage stage;
  final int messageCount;
  final int estimatedTokens;
  final bool hasSummarized;

  const ConversationState({
    this.stage = ConversationStage.exploring,
    this.messageCount = 0,
    this.estimatedTokens = 0,
    this.hasSummarized = false,
  });

  ConversationState copyWith({
    ConversationStage? stage,
    int? messageCount,
    int? estimatedTokens,
    bool? hasSummarized,
  }) => ConversationState(
    stage: stage ?? this.stage,
    messageCount: messageCount ?? this.messageCount,
    estimatedTokens: estimatedTokens ?? this.estimatedTokens,
    hasSummarized: hasSummarized ?? this.hasSummarized,
  );

  bool get shouldSummarize => messageCount >= 20 || estimatedTokens >= 8000;
}
```

---

## 2. 状态机 Provider

```dart
// lib/features/ai_chat/presentation/providers/conversation_state_provider.dart

@riverpod
class ConversationStateNotifier extends _$ConversationStateNotifier {
  @override
  ConversationState build() => const ConversationState();

  void onUserMessage(String message, {bool hasUserProfile = false}) {
    final newCount = state.messageCount + 1;
    final newStage = _computeStage(message, newCount, hasUserProfile);
    state = state.copyWith(stage: newStage, messageCount: newCount);
  }

  void addTokens(int tokens) {
    state = state.copyWith(estimatedTokens: state.estimatedTokens + tokens);
  }

  void reset() => state = const ConversationState();

  ConversationStage _computeStage(String message, int count, bool hasProfile) {
    // 复盘关键词优先级最高
    const reviewKeywords = ['当时', '之前', '我买了', '那次', '上次', '已经买'];
    if (reviewKeywords.any(message.contains)) return ConversationStage.reviewing;

    // 行动意图
    const actionKeywords = ['怎么买', '下一步', '我想', '准备', '打算', '操作', '去哪买'];
    if (actionKeywords.any(message.contains)) return ConversationStage.actioning;

    // 已有档案或对话数足够 → 深化
    if (hasProfile || count >= 3) {
      // 但如果当前是行动阶段且用户在问分析性问题，回到深化
      if (state.stage == ConversationStage.actioning) {
        const analyticKeywords = ['为什么', '分析', '比较', '区别', '原理'];
        if (analyticKeywords.any(message.contains)) return ConversationStage.deepening;
        return ConversationStage.actioning; // 保持行动阶段
      }
      return ConversationStage.deepening;
    }

    return ConversationStage.exploring;
  }
}
```

---

## 3. 对话摘要逻辑

```dart
// lib/features/ai_chat/data/conversation_summarizer.dart

class ConversationSummarizer {
  /// 将历史消息压缩为摘要
  /// 返回新的 history（摘要 + 最近5条）
  static Future<List<Map<String, String>>> summarize({
    required List<Map<String, String>> history,
    required Future<String> Function(String prompt) callAI,
  }) async {
    if (history.length <= 5) return history;

    final toSummarize = history.sublist(0, history.length - 5);
    final recent = history.sublist(history.length - 5);

    final summaryPrompt = '''
请将以下对话摘要成3-5句话，包含：
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
```

---

## 4. 集成到 ai_chat_page.dart

```dart
// _sendMessage() 修改

Future<void> _sendMessage(String userInput) async {
  // 更新对话状态
  ref.read(conversationStateNotifierProvider.notifier).onUserMessage(
    userInput,
    hasUserProfile: ref.read(userProfileNotifierProvider) != null,
  );

  // 检查是否需要摘要
  final convState = ref.read(conversationStateNotifierProvider);
  if (convState.shouldSummarize && !convState.hasSummarized) {
    _history = await ConversationSummarizer.summarize(
      history: _history,
      callAI: (prompt) async => await _callClaude([
        {'role': 'user', 'content': prompt}
      ]),
    );
    ref.read(conversationStateNotifierProvider.notifier)
        .state = convState.copyWith(hasSummarized: true, estimatedTokens: 2000);
  }

  // 构建 prompt（使用当前阶段）
  final stage = ref.read(conversationStateNotifierProvider).stage;
  // ... 调用 PromptBuilder(stage: stage) ...
}
```

---

## 5. 测试计划

| 用例 | 预期 |
|------|------|
| 新会话，第1条消息 → exploring | ✅ |
| 第3条消息 → deepening | ✅ |
| 消息含"我想买" → actioning | ✅ |
| 消息含"当时买的" → reviewing | ✅ |
| 20轮后触发摘要 | ✅ |
| 摘要后 messageCount 不重置 | ✅ |

---

## 6. 文件清单

```
lib/features/ai_chat/data/
├── conversation_state.dart
└── conversation_summarizer.dart

lib/features/ai_chat/presentation/providers/
└── conversation_state_provider.dart

test/logic/
└── conversation_state_test.dart
```
