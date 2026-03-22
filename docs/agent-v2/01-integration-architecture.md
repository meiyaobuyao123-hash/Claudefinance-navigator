# 明理 Agent v2 — 集成架构设计

> 版本：v1.0 | 最后更新：2026-03-22

---

## 1. 整体数据流

```
用户输入
    │
    ▼
┌─────────────────────────────────┐
│  [M07] InputGuardrail.check()   │ ← 拦截 prompt injection
│  命中 → 返回固定提示，终止流程    │
└────────────────┬────────────────┘
                 │ 通过
    ▼
┌─────────────────────────────────┐
│  [M04] ConversationStateNotifier│ ← 更新对话阶段 + 消息计数
│  .onUserMessage(input)          │
└────────────────┬────────────────┘
                 │
    ▼
┌─────────────────────────────────┐
│  [M04] HistoryManager.trim()    │ ← 滑动窗口裁剪（超8条摘要）
│  + [M09] Token 预算控制          │
└────────────────┬────────────────┘
                 │
    ▼
┌─────────────────────────────────┐
│  [M05] RuleTrigger              │ ← 关键词预判断
│  .getTriggeredTools(input)      │
│  → 预执行工具，结果缓存           │
└────────────────┬────────────────┘
                 │
    ▼
┌─────────────────────────────────┐
│  [M03] PromptBuilder.build()    │ ← 5层分层组装
│                                 │
│  L1 人格层（固定）               │ ← api_keys.dart 人格文本
│  L2 市场数据层（按需）           │ ← [M09] 话题过滤
│  L3 用户档案层                   │ ← [M01] UserProfile
│  L4 持仓快照层（按需）           │ ← [M02] PortfolioContextBuilder
│  L5 对话阶段层                   │ ← [M04] ConversationStage
│                                 │
│  → system prompt < 1200 token  │
└────────────────┬────────────────┘
                 │
    ▼
┌─────────────────────────────────┐
│  [M06] ClaudeStreamingClient    │ ← SSE 流式 + Prompt Caching
│  三级降级：主Key → 备Key → DS   │ ← [M09] cache_control
│                                 │
│  [M05] ClaudeAgent agentic loop │ ← tool_use 响应处理
│  (最多3轮 tool 调用)             │
└────────────────┬────────────────┘
                 │ AI 响应（stream）
    ▼
┌─────────────────────────────────┐
│  [M07] OutputGuardrail.process()│ ← 追加免责声明
└────────────────┬────────────────┘
                 │
    ▼
┌─────────────────────────────────┐
│  UI：flutter_markdown 渲染       │ ← [M06] 流式增量渲染
│  + [M08] MessageFeedbackBar     │ ← 👍👎 反馈按钮
└─────────────────────────────────┘
```

---

## 2. 模块依赖关系

```
M01 冷启动引导
  └─► M03 (提供 UserProfile → Layer 3)

M02 持仓注入
  └─► M03 (提供 PortfolioSnapshot → Layer 4)
  └─► M05 (提供 get_portfolio_summary Tool 数据)

M03 分层 Prompt 架构
  ├─ 依赖 M01, M02, M04
  └─► M06 (输出 systemPrompt)

M04 对话状态机
  ├─ 依赖 M03 (ConversationStage → Layer 5)
  └─► M09 (提供 history 裁剪)

M05 Tool Use
  ├─ 依赖 M03 (system prompt 已组装好)
  └─► M06 (流式 + tool_use 协同)

M06 流式输出
  └─► M08 (每条 AI 消息挂载 FeedbackBar)

M07 护栏机制
  独立，不依赖其他模块，最先执行（输入）和最后执行（输出）

M08 评估反馈
  └─ 依赖 M04 (conversationStage 上报)
  └─ 依赖 M06 (每条消息 ID)

M09 Token 优化
  └─ 依赖 M03 (Prompt Caching 在请求层)
  └─ 依赖 M04 (history 滑动窗口)
```

---

## 3. 核心数据流动图

```
┌──────────────┐     UserProfile      ┌──────────────┐
│  M01 冷启动  │ ─────────────────►  │              │
└──────────────┘                      │              │
                                      │   M03        │
┌──────────────┐  PortfolioSnapshot  │   Prompt     │  systemPrompt  ┌──────────────┐
│  M02 持仓    │ ─────────────────►  │   Builder    │ ──────────────►│  M06 流式    │
└──────────────┘                      │              │                │  Client      │
                                      │              │                └──────┬───────┘
┌──────────────┐  ConversationStage  │              │                       │
│  M04 状态机  │ ─────────────────►  │              │                       │ stream
└──────────────┘                      └──────────────┘                       │
                                                                              ▼
┌──────────────┐  toolResults                                        ┌──────────────┐
│  M05 工具    │ ─────────────────────────────────────────────────►  │  UI + M08    │
└──────────────┘                                                      │  反馈        │
                                                                      └──────────────┘
```

---

## 4. 关键时序：一次完整对话

```
用户点击发送
    │ t=0ms
    ▼
InputGuardrail.check()          │ ~1ms（纯正则，同步）
    │
ConversationStateNotifier       │ ~1ms（Riverpod 状态更新）
    │
HistoryManager.trim()           │ ~200ms（如触发AI摘要）/ ~1ms（未触发）
    │
RuleTrigger 预执行工具           │ ~300ms（网络请求，并行）
    │
PromptBuilder.build()           │ ~2ms（纯内存计算）
    │ t≈300ms
    ▼
Claude API 请求（SSE 开始）
    │ t≈800ms（网络RTT）
    ▼
首字节到达 → UI 开始渲染          │ TTFT 目标 < 500ms（WiFi）
    │
流式 chunks 持续渲染
    │
stop_reason = end_turn
    │
OutputGuardrail.process()       │ ~1ms（纯正则）
    │
MessageFeedbackBar 挂载
    │
FeedbackService.submit()        │ 后台异步，不阻塞 UI
```

---

## 5. 状态管理架构（Riverpod）

```dart
// 全局 Provider 依赖树

userProfileNotifierProvider          // M01
    └── fundHoldingsProvider         // M02
    └── stockHoldingsProvider        // M02
marketRatesProvider                  // M02/M03 Layer 2
conversationStateNotifierProvider    // M04
messageFeedbackProvider(messageId)   // M08
currentSessionIdProvider             // M08
deviceIdProvider                     // M08

// ai_chat_page.dart 消费所有上述 Provider，组装 PromptBuilder
```

---

## 6. 文件结构全景

```
lib/features/ai_chat/
├── data/
│   ├── prompt_builder.dart           # M03 分层构建器（核心）
│   ├── portfolio_context_builder.dart # M02 持仓快照
│   ├── conversation_state.dart        # M04 状态定义
│   ├── conversation_summarizer.dart   # M04 摘要工具
│   ├── history_manager.dart           # M09 滑动窗口
│   ├── token_monitor.dart             # M09 监控
│   ├── claude_streaming_client.dart   # M06 流式客户端
│   ├── claude_agent.dart              # M05 Agentic Loop
│   ├── models/
│   │   └── message_feedback.dart      # M08 反馈模型
│   ├── services/
│   │   └── feedback_service.dart      # M08 上报服务
│   ├── tools/
│   │   ├── tool_definitions.dart      # M05 工具定义
│   │   ├── tool_executor.dart         # M05 工具执行
│   │   └── rule_trigger.dart          # M05 规则触发
│   └── guardrails/
│       ├── input_guardrail.dart       # M07 输入护栏
│       └── output_guardrail.dart      # M07 输出护栏
├── presentation/
│   ├── pages/
│   │   └── ai_chat_page.dart          # 主页面（集成所有模块）
│   ├── providers/
│   │   └── conversation_state_provider.dart  # M04
│   └── widgets/
│       └── message_feedback_bar.dart  # M08 反馈 Widget

lib/features/onboarding/              # M01 冷启动
lib/features/decisions/               # 决策日记（已有）
lib/core/services/
│   ├── market_rate_service.dart       # M02/M05 行情数据
│   └── notification_service.dart     # 已有
```
