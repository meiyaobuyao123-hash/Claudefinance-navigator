---
name: topic_product_prd_plan
description: 各产品模块 PRD 写作计划——优先级/拆分方式/每个模块要覆盖的内容框架
type: project
---

目标：给已实现但无 PRD 的模块补齐文档，要求"又全又细"——能作为后续迭代的参考基准。

**Why:** 目前只有 Agent v2 有完整 PRD+TECH，其他模块是直接写代码上的，没有设计依据文档，迭代和回溯困难。

**How to apply:** 写每个模块 PRD 时，先读对应的代码（lib/features/XXX），再根据框架补充业务逻辑、边界条件、验收标准。

## PRD 写作顺序（按业务核心度排）

| 优先级 | 模块 | 理由 |
|--------|------|------|
| P0 | decisions（决策日记）| 核心护城河，逻辑最复杂（复盘引擎/持仓联动）|
| P0 | fund_tracker（基金持仓）| 最高频功能，持仓计算/API刷新/预警逻辑多 |
| P0 | stock_tracker（股票持仓）| 同上，多市场（A/港/美）逻辑差异大 |
| P1 | products（产品导航）| 15+产品/实时行情/跳转逻辑 |
| P1 | planning（规划 Tab）| 目前较空，要定义完整的规划功能边界 |
| P2 | watchlist（自选股）| 相对简单，但预警逻辑需要精确描述 |
| P2 | profile（用户设置）| 认证/删账户/设置项 |
| P3 | tools（工具 Tab）| 入口聚合页，取决于后续加什么工具 |

## 每个 PRD 的标准框架

```
1. 问题陈述（这个模块解决什么痛点）
2. 目标用户 + 用户故事（US-01/02/03）
3. 功能需求
   3.1 核心数据模型（字段定义+计算逻辑）
   3.2 主要操作流程（增删改查）
   3.3 边界条件（空数据/异常/离线）
   3.4 与其他模块的联动（如持仓→决策日记）
4. 验收标准（可测试的 AC）
5. 不做的范围（明确排除项）
```

## 写作方式

每次会话聚焦一个模块，顺序：
1. 读对应代码（lib/features/XXX）理解现有实现
2. 根据框架起草 PRD
3. 保存到 docs/features/XXX/PRD.md
4. 有复杂逻辑时同步写 TECH.md

## 进度记录（截至 2026-03-23）

| 模块 | PRD | TECH |
|------|-----|------|
| decisions | ✅ commit 5caa118（已校对修复8处） | ⬜ |
| fund_tracker | ✅ commit fd5819d（已校对修复3处：OCR加仓/减持/清仓阈值）| ⬜ |
| stock_tracker | ✅ commit 218a082 | ⬜ |
| products | ✅ commit f29a808（23产品/4实时行情/三级过滤）| ⬜ |
| planning | ✅ commit（5资产类/评分引擎/个性化阈值/AI入口）| ⬜ |
| watchlist | ✅ commit 3a3d28b（14字段/价格预警/同日防重）| ⬜ |
| profile | ✅ commit（Supabase Auth + UserProfile本地 + 删账户三步链）| ⬜ |
| tools | ✅ commit 5857366（2入口Banner + 4计算器）| ⬜ |
