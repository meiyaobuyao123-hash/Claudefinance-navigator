# 理财导航 · 产品与技术文档中心

> 版本管理：所有文档通过 Git 管理，重大版本使用 tag（如 `docs-v1.0`）标记。
> 修改文档时请同步更新文件头部的 `版本` 和 `最后更新` 字段。

---

## 文档结构

```
docs/
├── README.md                    # 本文件（索引）
└── agent-v2/
    ├── 00-overview.md           # 明理 Agent v2 整体架构设计
    └── modules/
        ├── 01-cold-start/       # 冷启动引导
        ├── 02-portfolio-injection/  # 持仓上下文自动注入
        ├── 03-layered-prompt/   # 分层 Prompt 架构
        ├── 04-conversation-state/  # 对话阶段状态机
        ├── 05-tool-use/         # Tool Use 混合触发架构
        ├── 06-streaming/        # 流式输出
        ├── 07-guardrails/       # 护栏机制
        └── 08-evaluation/       # 评估与反馈系统
```

每个模块包含：
- `PRD.md`：产品需求文档（用户故事 / 验收标准 / 优先级）
- `TECH.md`：技术实现文档（架构决策 / 接口设计 / 代码示例）

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

---

## 版本历史

| 版本 | 日期 | 说明 |
|------|------|------|
| v1.0 | 2026-03-22 | 初始版本，基于两轮架构挑战后的完善方案 |
