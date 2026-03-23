---
name: topic_agent_v2
description: Agent v2 架构设计和实现进度——9个模块全部完成，测试376/376
type: project
---

Agent v2 是对明理AI顾问的全面升级，核心目标：让AI真正认识用户持仓和个人情况，提供个性化建议。

**Why:** v1 的 AI 是"无记忆的通用助手"，不了解用户持仓和风险偏好，建议缺乏针对性。

**How to apply:** 所有模块已全部完成。如需修改任一模块，先读对应的 docs/agent-v2/modules/XX/TECH.md。模块间接口见 docs/agent-v2/02-interface-contracts.md。

## 架构设计（已定）

5层分层 Prompt 架构，token 总量 < 1200（实测 341/1200）：
- L1 人格层（~165 token，固定）
- L2 市场数据层（~46 token，15min缓存，按话题按需注入）
- L3 用户档案层（~43 token，M01提供）
- L4 持仓快照层（~20-200 token，关键词触发全量/摘要）
- L5 对话阶段层（~25 token，M04提供）

三级AI降级：Claude主Key → Claude备用Key → DeepSeek（已实现）

## 实现进度（全部完成）

| 模块 | 状态 | 测试 | commit |
|------|------|------|--------|
| M07 护栏 | ✅ | 40/40 | main |
| M03 分层Prompt | ✅ | 21/21 | bf9e866 |
| M01 冷启动 | ✅ | 26/26 | main |
| M06 流式输出 | ✅ | 15/15 | 9c09713 |
| M04 对话状态机 | ✅ | 35/35 | e7925b8 |
| M05 Tool Use | ✅ | 29/29 | d3211fb |
| M09 Token优化 | ✅ | 35/35 | 5fd6021 |
| M08 评估反馈 | ✅ | 18/18 | 93fc842 |
| M02 持仓注入 | ✅ | 43/43 | b76550c |

集成测试（T1-1/T1-2/T1-3）: 34/34，commit 27cf18a

全量测试：单元 342/342 + 集成 34/34 = **376/376**

## 关键文件

| 文件 | 说明 |
|------|------|
| `lib/features/ai_chat/data/prompt_builder.dart` | PromptBuilder 5层架构核心 |
| `lib/features/ai_chat/data/portfolio_context_builder.dart` | 持仓快照构建（关键词触发全量/摘要）|
| `lib/features/ai_chat/data/claude_streaming_client.dart` | SSE流式 + 三级降级 |
| `lib/features/ai_chat/data/claude_agent.dart` | Tool Use agentic loop（最多3轮）|
| `lib/features/ai_chat/data/history_manager.dart` | 滑动窗口（>8条+>4000token触发压缩）|
| `lib/features/ai_chat/data/token_monitor.dart` | Prompt Caching 监控 |
| `lib/features/ai_chat/data/models/message_feedback.dart` | 反馈数据模型 |
| `lib/features/ai_chat/data/services/feedback_service.dart` | POST 上报到腾讯云 |
| `lib/features/ai_chat/presentation/widgets/message_feedback_bar.dart` | 👍/👎 Widget |
| `lib/features/ai_chat/presentation/providers/feedback_providers.dart` | sessionId/deviceId/feedbackState |
| `lib/features/ai_chat/data/guardrails/input_guardrail.dart` | 输入护栏（Prompt注入检测）|
| `lib/features/ai_chat/data/guardrails/output_guardrail.dart` | 输出护栏（条件性免责声明）|
| `docs/agent-v2/02-interface-contracts.md` | 所有模块接口契约 |

## 服务端（腾讯云 43.156.207.26）

- `ai_feedback` 表已建，POST /api/finance/feedback 接口上线
- 服务文件：/opt/finance-nav-api/main.py
- 进程：/opt/venv/bin/uvicorn main:app --host 127.0.0.1 --port 8001
