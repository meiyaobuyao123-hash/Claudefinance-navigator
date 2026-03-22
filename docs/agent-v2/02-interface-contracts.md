# 明理 Agent v2 — 模块间接口契约

> 版本：v1.0 | 最后更新：2026-03-22

本文档定义所有模块的公开接口（输入/输出/异常），作为跨模块开发的契约。接口一旦确认，各模块可并行开发。

---

## 1. M01 冷启动引导

### `UserProfile`（输出数据结构）

```dart
class UserProfile {
  final AssetRange assetRange;           // 资产量级
  final List<FinancialGoal> goals;       // 理财目标（1-2个）
  final RiskReaction riskReaction;       // 风险反应
  final DateTime createdAt;
  final DateTime updatedAt;

  // 输出给 M03 Layer 3
  String toPromptSnippet();              // 返回 ~50 token 的中文文本

  // 序列化（持久化）
  Map<String, dynamic> toJson();
  factory UserProfile.fromJson(Map<String, dynamic> json);
}
```

### `UserProfileNotifier`（Provider 接口）

```dart
// 读取
UserProfile? state                        // null = 未完成引导
bool get isStale                          // 超 180 天 = true

// 写入
Future<void> save(UserProfile profile)
Future<void> markSkipped()
Future<bool> shouldShowOnboarding()
```

**约定**：
- `state == null` 时 M03 Layer 3 返回空字符串，不报错
- `markSkipped()` 后 `shouldShowOnboarding()` 永远返回 false

---

## 2. M02 持仓上下文注入

### `PortfolioContextBuilder`（核心接口）

```dart
class PortfolioContextBuilder {
  // 构造参数
  final List<FundHolding> fundHoldings;
  final List<StockHolding> stockHoldings;

  // 判断是否注入完整持仓
  bool shouldInjectFull(String userMessage);   // 关键词匹配

  // 输出给 M03 Layer 4
  String buildFullSnapshot();    // 完整快照，~100-150 token，持仓为空时返回 ''
  String buildSummaryOnly();     // 摘要，~20 token，持仓为空时返回 ''
}
```

**约定**：
- 两个 build 方法永远不抛异常，持仓为空时返回 `''`
- `buildFullSnapshot()` 持仓超过 8 支时自动截断，末尾追加 `（另有N支未展示）`

---

## 3. M03 分层 Prompt 架构

### `PromptBuilder`（核心接口）

```dart
class PromptBuilder {
  // 构造参数（均可为 null，null 时对应层返回 ''）
  final UserProfile? userProfile;
  final Map<String, double>? marketRates;
  final List<FundHolding> fundHoldings;
  final List<StockHolding> stockHoldings;
  final ConversationStage stage;

  // 核心方法：输出最终 system prompt
  String build(String userMessage);    // 永不超过 1200 token（中文字符估算）
}
```

**约定**：
- `build()` 永远不抛异常，各层降级为空字符串
- `build()` 是纯函数（相同输入 → 相同输出），可单元测试
- 总 token 超出时按优先级裁剪：Layer 4 → Layer 2 → Layer 3 → Layer 5（Layer 1 固定）

---

## 4. M04 对话状态机

### `ConversationState`（数据结构）

```dart
class ConversationState {
  final ConversationStage stage;          // 当前阶段
  final int messageCount;                 // 累计消息数
  final int estimatedTokens;             // 估算 history token 数
  final bool hasSummarized;              // 是否已摘要过

  bool get shouldSummarize;              // messageCount >= 20 || estimatedTokens >= 8000
}

enum ConversationStage { exploring, deepening, actioning, reviewing }
```

### `ConversationStateNotifier`（Provider 接口）

```dart
void onUserMessage(String message, {bool hasUserProfile = false})
void addTokens(int tokens)
void reset()                             // 新会话时调用
```

### `HistoryManager`（静态接口）

```dart
// 输入：完整历史 + AI 调用函数
// 输出：裁剪后的历史（≤ 9 条：1条摘要 + 8条原始）
static Future<List<Map<String, dynamic>>> trim({
  required List<Map<String, dynamic>> fullHistory,
  required Future<String> Function(String) callAI,
})
```

**约定**：
- `trim()` 在 history ≤ 8 条时直接返回原列表，不调用 AI
- 摘要失败时返回原始的最近 8 条（降级，不抛异常）

---

## 5. M05 Tool Use

### `RuleTrigger`（静态接口）

```dart
// 输入：用户消息
// 输出：需要预执行的工具名列表（可能为空）
static List<String> getTriggeredTools(String message)
```

### `ToolExecutor`（接口）

```dart
// 输入：工具名 + 参数
// 输出：JSON 字符串（永不抛异常，失败时返回 error JSON）
Future<String> execute(String toolName, Map<String, dynamic> input)
```

### `ClaudeAgent`（接口）

```dart
// 完整的 agentic loop，处理 tool_use 循环
// 输入：system prompt + history + api key
// 输出：最终文本回复
Future<String> run({
  required String systemPrompt,
  required List<Map<String, dynamic>> history,
  required String apiKey,
})
```

**约定**：
- `execute()` 超时 5 秒，超时返回 `{"error": "timeout", "cached": true}`
- `run()` 最多 3 轮 tool 循环，超出返回降级文本
- 工具结果不直接暴露给用户，只用于构建下一轮请求

---

## 6. M06 流式输出

### `ClaudeStreamingClient`（接口）

```dart
// 输入：system prompt + history + 可选参数
// 输出：字符 chunk 的 Stream
Stream<String> streamMessage({
  required String systemPrompt,
  required List<Map<String, dynamic>> messages,
  String model = 'claude-sonnet-4-20250514',
  int maxTokens = 1024,
})
```

**约定**：
- Stream 抛异常时 UI 层 catch，显示截断提示
- 网络断开时 Stream 会 `addError()`，不会静默结束
- 支持 Prompt Caching（通过 `cache_control` 在 system 字段）

---

## 7. M07 护栏机制

### `InputGuardrail`（静态接口）

```dart
// 返回 null = 通过；返回字符串 = 被拦截，直接作为 AI 回复显示
static String? check(String userMessage)
```

### `OutputGuardrail`（静态接口）

```dart
// 检测是否需要追加免责声明
static bool needsDisclaimer(String response)

// 处理：必要时追加免责声明
static String process(String response)
```

**约定**：
- 两个类均无状态，所有方法为纯函数
- `check()` 和 `process()` 执行时间 < 5ms（同步正则）
- `process()` 追加免责声明后不修改原有内容

---

## 8. M08 评估反馈

### `MessageFeedback`（数据结构）

```dart
class MessageFeedback {
  final String sessionId;
  final String messageId;
  final String userQuestion;
  final String aiResponsePreview;    // 前 50 字
  final FeedbackRating rating;       // thumbsUp / thumbsDown
  final FeedbackReason? reason;      // thumbsDown 时必填
  final String conversationStage;
  final DateTime timestamp;
  final String deviceId;

  Map<String, dynamic> toJson();
}
```

### `FeedbackService`（接口）

```dart
// 异步上报，失败静默处理（不影响 UI）
Future<void> submit(MessageFeedback feedback)
```

---

## 9. M09 Token 优化

### Prompt Caching（API 层约定）

```dart
// system 字段格式（启用缓存时）
List<Map<String, dynamic>> systemWithCache = [
  {
    'type': 'text',
    'text': systemPrompt,
    'cache_control': {'type': 'ephemeral'},
  }
];
// 传入 API 请求的 'system' 字段使用此 List，而非字符串
```

### Token 估算约定

```dart
// 项目内统一使用此公式（粗略估算）
int estimateTokens(String text) => (text.length / 1.5).round();
// 中文字符：1 token ≈ 1.5 字符
// 英文字符：1 token ≈ 4 字符
// 混合文本取中间值
```

---

## 10. 接口变更流程

1. 变更接口前，在此文档标注 `⚠️ 待变更` 并描述变更内容
2. 所有依赖该接口的模块开发者确认
3. 更新接口定义，同步更新相关 TECH.md
4. 相关单元测试同步更新
