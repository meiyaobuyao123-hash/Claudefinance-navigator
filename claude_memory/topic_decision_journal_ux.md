---
name: topic_decision_journal_ux
description: 决策日记功能的UX设计原则和所有用户场景分析
type: project
---

决策日记是理财导航App的核心留存功能——记录每次决策理由，3/6/12个月后自动复盘。

**Why:** 这是该App独立生存的核心竞争力之一：数据积累形成迁移成本 + 反馈循环建立AI可信度。

**How to apply:** 开发决策日记相关功能时，遵循以下设计原则。

## 核心设计原则

1. **不强制双重录入**：用户在持仓追踪器的操作（买入/卖出/加仓/减持）应自动触发决策记录提示，而非要用户在两个地方分别录入
2. **可选非强制**：决策记录提示总是有「跳过」选项，不增加核心操作的摩擦
3. **独立层与关联层并存**：决策日记是独立记录层（可记录银行产品等无API产品），持仓追踪器是资产监控层，两者可关联但不依赖

## 所有用户场景

| 场景 | 触发点 | 处理方式 |
|------|--------|----------|
| 买入基金/股票 | AddFundPage/AddStockPage 保存成功后 | 弹轻量BottomSheet，产品类别+金额自动填，用户只填理由+预期 |
| 减持/清仓 | 减持BottomSheet完成后 | 同上，type=卖出，amount=实现金额 |
| 银行产品（定存/大额存单/国债/保险）| 决策日记独立入口 | 最核心的独立价值，目标用户资产大头 |
| 加仓已有持仓 | 加仓完成后 | 同买入，amount=本次加仓金额 |
| 自选股价格预警触发操作 | 操作完成后 | 此时用户理由最鲜活 |
| 查看持仓历史决策 | 持仓卡片操作菜单 | 增加「查看决策记录」选项 |
| 整体调仓（多笔） | 手动录入 | type=调仓，一条记录覆盖整体意图 |

## 代码改动状态（截至2026-03-22）

- [x] AddFundPage + AddStockPage：保存后弹 DecisionPromptSheet（可跳过）
- [x] 基金/股票加仓/减持操作：完成后通过 onSuccess 回调触发
- [x] 持仓卡片操作菜单：已增加「查看决策记录」→ /decisions
- [x] DecisionRecord模型：已增加可选 linkedHoldingId 字段
- [x] 新建共享 widget：lib/features/decisions/presentation/widgets/decision_prompt_sheet.dart
- [x] 复盘判断引擎提取为纯函数：lib/features/decisions/data/decision_judgement.dart（可单元测试）
- [x] 单元测试（80/80通过）：test/models/ + test/logic/
- [x] 集成测试（19/19通过）：test/integration/server_api_test.dart（真实服务器）
