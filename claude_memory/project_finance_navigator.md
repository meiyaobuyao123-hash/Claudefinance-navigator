---
name: finance_navigator_project
description: Flutter理财导航App项目上下文——技术栈、路径、当前状态
type: project
---

主项目路径：`/Users/wenruiwei/Desktop/testclaude/finance_navigator`

**Why:** 用户正在开发一个面向50万-1000万人民币用户群的Flutter理财导航App，核心价值是AI诊断需求→匹配产品类型→跳转平台购买，不接触资金。

**How to apply:** 每次涉及该项目的代码修改，直接去该目录读取代码，不要问用户路径。CLAUDE.md在项目根目录，有完整的功能清单和技术决策记录。

技术栈：Flutter 3.41.2 + Riverpod + Hive + Supabase + Claude API + DeepSeek备用

已完成核心功能（截至2026-03-22）：
- 持仓监控（基金+A股+港股+美股+自选股）
- 资产配置评估 + R1-R5风险测评
- 产品导航库（15+产品，实时行情已接入）
- AI明理对话（claude-sonnet-4-6）
- 决策日记 + 3/6/12月自动复盘系统
- Supabase Auth + 腾讯云PostgreSQL双写
- Agent v2 设计文档（M01-M09 + 6个架构文档）全部完成

Agent v2 实现进度：
- ✅ M07 护栏（InputGuardrail + OutputGuardrail，40/40测试通过）
- ✅ M03 分层Prompt（PromptBuilder 5层架构，21/21测试通过）
- ✅ M01 冷启动引导（OnboardingPage + UserProfileNotifier，26/26测试通过）
- ✅ M06 流式输出（ClaudeStreamingClient SSE + Markdown渲染，15/15测试通过）
- ✅ M04 状态机（ConversationStateNotifier 4阶段+摘要，35/35测试通过，commit e7925b8）
- ✅ M05 Tool Use（RuleTrigger+ToolExecutor+ClaudeAgent混合触发，29/29测试通过，commit d3211fb）
- ✅ M09 Token优化（Prompt Caching+8条滑动窗口+市场数据过滤，35/35测试通过，commit 5fd6021）
- ✅ M08 评估反馈（MessageFeedback+FeedbackService+MessageFeedbackBar，18/18测试通过，commit 93fc842）
- ✅ M02 持仓注入（PortfolioContextBuilder+PromptBuilder Layer4已接入，43/43测试通过，commit b76550c）
- 服务端 ai_feedback 表已建，POST /api/finance/feedback 接口已上线并验证写库正常

全量测试（截至M02完成后）：单元 342/342 + 集成 19/19

Agent v2 全部9个模块（M01-M09）已全部完成。
