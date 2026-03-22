# 理财导航 — Claude 项目记忆

> 此文件由 Claude 自动读取，每次新会话无需任何操作即可加载项目背景。
> 详细设计文档在 `docs/` 目录，按需 Read，不全量加载。

---

## 产品定位

Flutter 理财导航 App，目标用户：中国大陆持有 **50万–1000万人民币**的人群。
核心价值：AI 摸清需求 → 匹配产品类型 → 跳转主流平台自主购买。
**不接触资金，不推荐具体代码，合规导航工具。AI 顾问角色名：明理。**

---

## 技术栈

- Flutter 3.41.2 + Dart 3.7.2（iOS + Android 双端）
- 状态管理：flutter_riverpod（无代码生成）
- HTTP：Dio
- 本地存储：Hive
- AI：`claude-sonnet-4-20250514`（主 + 备用 Key）→ `deepseek-chat`（降级）
- 云端：腾讯云轻量服务器（43.156.207.26）FastAPI + PostgreSQL（端口 8001，Nginx 代理 /api/finance/）
- Auth：Supabase（仅登录/注册，数据存储已迁移腾讯云）
- 本地路径：`/Users/wenruiwei/Desktop/testclaude/finance_navigator`
- GitHub：`https://github.com/meiyaobuyao123-hash/Claudefinance-navigator.git`
- 当前分支：`main`

---

## 运行命令

```bash
cd /Users/wenruiwei/Desktop/testclaude/finance_navigator
flutter run   # 热重启 R，热加载 r
flutter test test/models/ test/logic/   # 单元测试（101/101）
flutter test test/integration/          # 集成测试（19/19，需服务器在线）
```

---

## 当前状态（2026-03-22）

**已完成功能**：
- 4 Tab 底部导航（规划/导航/工具/我的）
- AI 对话页（全屏，Riverpod，三级降级）
- 持仓追踪：基金（天天基金 API）+ 股票（新浪/Yahoo）+ 自选股
- 产品导航页：实时行情接入
- 决策日记 + 复盘规则引擎
- 用户认证（Supabase Auth）+ 删除账户
- 测试：单元 217/217 + 集成 19/19 全通过

**Agent v2 设计文档（docs/ 目录）已全部完成**：
- 9 个功能模块（M01–M09）各有 PRD + TECH
- 6 个架构文档（集成架构/接口契约/路线图/错误处理/安全/可观测性）
- tag：`docs-v1.0`

**Agent v2 实现进度**：
- ✅ M07 护栏（InputGuardrail + OutputGuardrail，40/40测试）
- ✅ M03 分层 Prompt（PromptBuilder 5层，21/21测试，commit bf9e866）
- ✅ M01 冷启动（OnboardingPage + UserProfileNotifier，26/26测试）
- ✅ M06 流式输出（ClaudeStreamingClient SSE + Markdown渲染，15/15测试，commit 9c09713）
- ✅ M04 状态机（ConversationStateNotifier 4阶段+摘要，35/35测试，commit e7925b8）
- 🟡 M02 持仓注入（PortfolioContextBuilder已完成并接入，UI层待扩展）

**待实现**：
- Phase 2：M05 Tool Use（**下一步**）
- Phase 3：M09 Token 优化（Prompt Caching + 滑动窗口）
- Phase 3：M09 Token 优化（Prompt Caching + 滑动窗口）
- Phase 4：M08 评估反馈

---

## 关键文件索引

| 文件 | 说明 |
|------|------|
| `lib/core/config/api_keys.dart` | ⚠️ Key 文件（gitignored，本地才有）|
| `lib/core/router/app_router.dart` | 路由配置 |
| `lib/features/ai_chat/presentation/pages/ai_chat_page.dart` | AI 对话核心（M07+M03已接入）|
| `lib/features/ai_chat/data/prompt_builder.dart` | PromptBuilder 5层分层架构 |
| `lib/features/ai_chat/data/portfolio_context_builder.dart` | 持仓快照构建（关键词触发）|
| `lib/features/ai_chat/data/conversation_stage.dart` | 对话阶段枚举 |
| `lib/features/onboarding/models/user_profile.dart` | UserProfile模型（M01待接UI）|
| `lib/features/ai_chat/data/guardrails/input_guardrail.dart` | 输入护栏（Prompt注入检测）|
| `lib/features/ai_chat/data/guardrails/output_guardrail.dart` | 输出护栏（合规免责声明）|
| `lib/features/planning/presentation/pages/planning_page.dart` | 规划 Tab |
| `lib/features/fund_tracker/presentation/pages/fund_tracker_page.dart` | 持仓总览（5 Tab）|
| `lib/features/decisions/data/decision_judgement.dart` | 复盘判断引擎（纯函数）|
| `lib/core/utils/uuid_util.dart` | UUID v4 工具函数 |
| `lib/core/services/market_rate_service.dart` | 实时行情服务 |
| `docs/README.md` | 文档索引 |
| `docs/agent-v2/01-integration-architecture.md` | 集成架构（模块串联方式）|
| `docs/agent-v2/02-interface-contracts.md` | 模块间接口契约 |
| `docs/agent-v2/03-implementation-roadmap.md` | 实施路线图（Phase 1–4）|

---

## 重要决策（已定）

| 决策 | 结论 |
|------|------|
| 前端框架 | Flutter |
| 状态管理 | flutter_riverpod（无 build_runner）|
| 记忆方式 | System Prompt 注入（非 RAG）|
| Agent 模式 | 单 Agent + Tool Use |
| 护栏实现 | 客户端确定性规则（不依赖 AI）|
| Token 优化 | Prompt Caching + 滑动窗口（首选）|
| 数据存储 | Hive 本地 + 腾讯云 PostgreSQL 双写 |
| 环境 | macOS 26.2，iPhone 17 Pro Max 模拟器，iOS 26.2 |
