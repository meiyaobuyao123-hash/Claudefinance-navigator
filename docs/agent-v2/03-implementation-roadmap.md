# 明理 Agent v2 — 实施路线图

> 版本：v1.0 | 最后更新：2026-03-22

---

## 原则

- 每个阶段交付后，App **可独立运行**，不出现半成品状态
- 阶段内的模块可并行开发，阶段间严格串行
- 每个模块交付前必须通过对应的单元测试

---

## Phase 0 — 基础设施（前置，1-2天）

> 不涉及 AI 功能，纯代码结构搭建

| 任务 | 文件 | 完成标准 |
|------|------|---------|
| 创建 `lib/features/ai_chat/data/` 目录结构 | 按集成架构文档建好空文件 | `flutter analyze` 无报错 |
| 创建 `lib/features/onboarding/` 目录结构 | 空文件占位 | 编译通过 |
| 添加依赖 | `anthropic_sdk_dart` + `flutter_markdown` | `flutter pub get` 通过 |

---

## Phase 1 — P0 核心（约1周）

> 完成后：明理认识你、知道你的持仓、prompt 不再膨胀

### 1.1 M07 护栏（先做，风险最高）

| 任务 | 文件 | 完成标准 |
|------|------|---------|
| 实现 `InputGuardrail` | `data/guardrails/input_guardrail.dart` | 10个 injection 变体全部拦截 |
| 实现 `OutputGuardrail` | `data/guardrails/output_guardrail.dart` | 股票代码 + 承诺语言检测通过 |
| 接入 `ai_chat_page.dart` | 发送前/回复后各插一次 | 人工测试通过 |
| 单元测试 | `test/logic/guardrail_test.dart` | 100条正常问题误判 < 1% |

### 1.2 M03 分层 Prompt 架构

| 任务 | 文件 | 完成标准 |
|------|------|---------|
| 实现 `PromptBuilder`（5层） | `data/prompt_builder.dart` | 单元测试：各层独立可空 |
| 替换 `ai_chat_page.dart` 的硬编码 prompt | 修改 `_sendMessage()` | system prompt < 1200 token |

### 1.3 M02 持仓上下文注入

| 任务 | 文件 | 完成标准 |
|------|------|---------|
| 实现 `PortfolioContextBuilder` | `data/portfolio_context_builder.dart` | 单元测试：格式/截断/空持仓 |
| 接入 `PromptBuilder` Layer 4 | 修改 `prompt_builder.dart` | 问持仓问题时注入，通用问题不注入 |

### 1.4 M01 冷启动引导

| 任务 | 文件 | 完成标准 |
|------|------|---------|
| 实现 `UserProfile` 模型 | `onboarding/models/user_profile.dart` | 序列化往返测试通过 |
| 实现 `UserProfileNotifier` | `onboarding/providers/user_profile_provider.dart` | SharedPreferences 持久化 |
| 实现 3步引导 UI | `onboarding/pages/onboarding_page.dart` | 30秒内完成引导，可跳过 |
| 接入 App 启动流程 | `app.dart` | 首次启动显示引导，跳过后不再显示 |
| 接入 `PromptBuilder` Layer 3 | 修改 `prompt_builder.dart` | 明理第一条消息引用用户档案 |

**Phase 1 验收**：新用户完成引导 → 问"我的配置合理吗" → 明理能说出用户的资金量级和持仓情况。

---

## Phase 2 — P1 核心升级（约1周）

> 完成后：流式输出、有记忆的对话、工具调用

### 2.1 M06 流式输出（可独立，优先级高）

| 任务 | 文件 | 完成标准 |
|------|------|---------|
| 实现 `ClaudeStreamingClient` | `data/claude_streaming_client.dart` | TTFT < 500ms（WiFi）|
| 替换 `ai_chat_page.dart` 的请求方式 | 修改 `_sendMessage()` | 流式渲染，无空白等待 |
| 添加 `flutter_markdown` 渲染 | 修改气泡 Widget | 加粗/列表正常显示 |
| 断网处理 | 修改错误处理 | 截断提示 + 重试按钮 |

### 2.2 M04 对话状态机

| 任务 | 文件 | 完成标准 |
|------|------|---------|
| 实现 `ConversationState` + 枚举 | `data/conversation_state.dart` | 单元测试：4阶段转换正确 |
| 实现 `ConversationStateNotifier` | `providers/conversation_state_provider.dart` | 关键词触发测试通过 |
| 实现 `HistoryManager` | `data/history_manager.dart` | 超8条后正确摘要+裁剪 |
| 接入 `ai_chat_page.dart` | 发送前调用 `.onUserMessage()` | 不影响现有对话逻辑 |
| 接入 `PromptBuilder` Layer 5 | 阶段提示注入 | 新用户前3轮不主动给建议 |

### 2.3 M05 Tool Use

| 任务 | 文件 | 完成标准 |
|------|------|---------|
| 定义工具 schema | `data/tools/tool_definitions.dart` | JSON 格式校验通过 |
| 实现 `RuleTrigger` | `data/tools/rule_trigger.dart` | 单元测试：关键词命中率 |
| 实现 `ToolExecutor` | `data/tools/tool_executor.dart` | 超时降级，不抛异常 |
| 实现 `ClaudeAgent` agentic loop | `data/claude_agent.dart` | 最多3轮，强制退出 |
| 接入 `ai_chat_page.dart` | 替换单次 API 调用 | 实时行情问题返回当前价格 |

**Phase 2 验收**：连续对话10轮，首字符延迟 < 500ms；问"黄金多少钱"返回实时价格；历史消息 > 8条后自动摘要。

---

## Phase 3 — P1 优化（约3天）

> 完成后：成本降低，生产可用

### 3.1 M09 Token 优化

| 任务 | 文件 | 完成标准 |
|------|------|---------|
| Prompt Caching 接入 | 修改 API 请求构建 | API 响应有 cache_read_input_tokens |
| 市场数据话题过滤 | 修改 `prompt_builder.dart` | 养老/教育话题不注入行情 |
| Token 监控日志 | `data/token_monitor.dart` | Debug 模式打印 token 分布 |

**Phase 3 验收**：连续10轮对话，第2轮起 cache_read_input_tokens > 0；system prompt 费用降低 > 80%。

---

## Phase 4 — P2 质量（约2天）

> 完成后：有反馈数据，可持续改进

### 4.1 M08 评估反馈

| 任务 | 文件 | 完成标准 |
|------|------|---------|
| 实现 `MessageFeedback` 模型 | `data/models/message_feedback.dart` | 序列化测试通过 |
| 实现 `FeedbackService` | `data/services/feedback_service.dart` | 上报接口联调通过 |
| 实现 `MessageFeedbackBar` Widget | `presentation/widgets/message_feedback_bar.dart` | 点赞/点踩 UI 正常 |
| 服务端新增 `/feedback` 接口 | 腾讯云 `main.py` + 建表 | 数据落库验证 |

**Phase 4 验收**：点踩后数据在腾讯云 `ai_feedback` 表可见；断网时点踩不崩溃。

---

## 模块交付 Done 标准（通用）

每个模块交付前必须满足：

- [ ] 对应 TECH.md 中的单元测试全部通过
- [ ] `flutter analyze` 无 error（warning 可以有但需记录）
- [ ] 在 iPhone 模拟器上人工走通主流程
- [ ] 未引入新的 API Key / 密钥硬编码
- [ ] CLAUDE.md「当前状态」章节已更新

---

## 里程碑时间线（参考）

```
Week 1: Phase 0 + Phase 1（护栏 + 分层 Prompt + 持仓注入 + 冷启动）
Week 2: Phase 2（流式 + 状态机 + Tool Use）
Week 3: Phase 3 + Phase 4（Token 优化 + 反馈系统）
```
