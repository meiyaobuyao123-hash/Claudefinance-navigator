# 理财导航 · 产品与技术文档中心

> 版本管理：所有文档通过 Git 管理，重大版本使用 tag（如 `docs-v1.0`）标记。
> 修改文档时请同步更新文件头部的 `版本` 和 `最后更新` 字段。

---

## 文档结构

```
docs/
├── README.md                         # 本文件（索引）
└── agent-v2/
    ├── 00-overview.md                # 整体架构设计
    ├── 01-integration-architecture.md # 集成架构（模块串联 + 数据流）
    ├── 02-interface-contracts.md     # 模块间接口契约
    ├── 03-implementation-roadmap.md  # 实施路线图（Phase 1–4）
    ├── 04-error-handling.md          # 统一错误处理与降级策略
    ├── 05-security.md                # 安全设计
    ├── 06-observability.md           # 可观测性方案
    └── modules/
        ├── 01-cold-start/            # 冷启动引导
        ├── 02-portfolio-injection/   # 持仓上下文自动注入
        ├── 03-layered-prompt/        # 分层 Prompt 架构
        ├── 04-conversation-state/    # 对话阶段状态机
        ├── 05-tool-use/              # Tool Use 混合触发架构
        ├── 06-streaming/             # 流式输出
        ├── 07-guardrails/            # 护栏机制
        ├── 08-evaluation/            # 评估与反馈系统
        └── 09-token-optimization/    # Token 优化
```

每个模块包含：
- `PRD.md`：产品需求文档（用户故事 / 验收标准 / 优先级）
- `TECH.md`：技术实现文档（架构决策 / 接口设计 / 代码示例）

---

## 架构文档索引

| 文档 | 说明 |
|------|------|
| [整体架构](./agent-v2/00-overview.md) | 背景、目标、模块优先级 |
| [集成架构](./agent-v2/01-integration-architecture.md) | 模块串联方式、数据流、时序 |
| [接口契约](./agent-v2/02-interface-contracts.md) | 所有模块的公开接口定义 |
| [实施路线图](./agent-v2/03-implementation-roadmap.md) | Phase 1–4 分阶段任务和验收标准 |
| [错误处理](./agent-v2/04-error-handling.md) | 统一降级策略和异常类 |
| [安全设计](./agent-v2/05-security.md) | 威胁模型、API Key 管理、合规边界 |
| [可观测性](./agent-v2/06-observability.md) | 日志埋点、监控 SQL、排查手册 |

---

## 模块索引

| # | 模块 | 优先级 | 状态 |
|---|------|--------|------|
| 01 | [冷启动引导](./agent-v2/modules/01-cold-start/PRD.md) | P0 | 📋 规划中 |
| 02 | [持仓上下文注入](./agent-v2/modules/02-portfolio-injection/PRD.md) | P0 | 📋 规划中 |
| 03 | [分层 Prompt 架构](./agent-v2/modules/03-layered-prompt/PRD.md) | P0 | 📋 规划中 |
| 04 | [对话阶段状态机](./agent-v2/modules/04-conversation-state/PRD.md) | P1 | 📋 规划中 |
| 05 | [Tool Use 混合触发](./agent-v2/modules/05-tool-use/PRD.md) | P1 | 📋 规划中 |
| 06 | [流式输出](./agent-v2/modules/06-streaming/PRD.md) | P1 | 📋 规划中 |
| 07 | [护栏机制](./agent-v2/modules/07-guardrails/PRD.md) | P1 | 📋 规划中 |
| 08 | [评估与反馈](./agent-v2/modules/08-evaluation/PRD.md) | P2 | 📋 规划中 |
| 09 | [Token 优化](./agent-v2/modules/09-token-optimization/PRD.md) | P1 | 📋 规划中 |

---

## 版本历史

| 版本 | 日期 | 说明 |
|------|------|------|
| v1.0 | 2026-03-22 | 初始版本，基于两轮架构挑战后的完善方案 |
| v1.1 | 2026-03-22 | 新增 M09 Token 优化模块 |
| v1.2 | 2026-03-22 | 新增 6 个架构文档（集成架构/接口契约/路线图/错误处理/安全/可观测性）|
