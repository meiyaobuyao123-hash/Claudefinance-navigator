# PRD — 财务工具（Tools Tab）

**文档版本**: V1.0
**最后更新**: 2026-03-23
**状态**: 已实现（基于代码 1:1 还原）
**源文件**: `lib/features/tools/presentation/pages/tools_page.dart`
**路由**: `/tools`（ShellRoute 内，底部导航第 3 个 Tab）

---

## 1. 问题陈述

用户在做理财决策时需要快速完成几类重复性计算（复利、目标拆解、通胀侵蚀、产品横向对比），同时需要一个统一入口快速跳转高频重型功能（持仓监控、决策日记）。现有市场上的计算器要么离散在不同 App，要么与理财场景割裂，用户需要在场景内完成「算完即跳转行动」的闭环。

---

## 2. 目标用户 + 用户故事

**目标用户**: 持有 50万–1000万人民币的中国大陆理财用户，有自主配置需求，能理解年化收益率等基础概念。

| # | 用户故事 |
|---|----------|
| US-1 | 作为用户，我想输入本金、利率、年限，立刻看到复利后的总资产，以便评估一款产品值不值得长持。 |
| US-2 | 作为用户，我想输入目标金额和年限，倒推出现在需要准备多少钱，以便制定储蓄计划。 |
| US-3 | 作为用户，我想知道通胀 10 年会吃掉我多少购买力，以便理解"不投资等于亏损"的紧迫性。 |
| US-4 | 作为用户，我想在同一界面用同一本金对比 10 种产品的到期总额，以便快速选择最优配置。 |
| US-5 | 作为用户，我想在工具页一键进入基金组合监控，不需要找底部导航以外的入口。 |
| US-6 | 作为用户，我想在工具页一键进入决策日记，记录当前投资决策的理由。 |

---

## 3. 功能需求

### 3.1 页面结构（`/tools`）

页面为单列 `ListView`，padding 16px，内容从上到下分三个区域：

#### 区域一：特色功能 Banner（两张渐变大卡，无分组标题）

| 顺序 | 组件类 | 标题 | 副标题 | 图标 | 视觉 | 跳转方式 | 目标路由 |
|------|--------|------|--------|------|------|----------|----------|
| 1 | `_FundTrackerBanner` | 基金组合监控 | 输入基金代码和持仓，实时监控收益 | `Icons.account_balance_outlined` | 蓝色渐变（`AppColors.primary` → `AppColors.primaryLight`），圆角 18 | `context.push('/fund-tracker')` | `/fund-tracker` |
| 2 | `_DecisionJournalBanner` | 决策日记 | 记录每次决策理由，3个月后复盘是否正确 | `Icons.history_edu_outlined` | 紫色渐变（`#7C3AED` → `#9F67FA`），圆角 18 | `context.push('/decisions')` | `/decisions` |

两张 Banner 之间间距 12px，Banner 下方与计算器区域间距 20px。

#### 区域二：分组标题

```
计算器
```

字号 13，fontWeight w600，颜色 `AppColors.textSecondary`，下方 paddingBottom 12px。

#### 区域三：计算器工具列表（4 张 `_ToolCard`）

| 顺序 | 标题 | 副标题 | 图标 | 主题色 | 触发方式 | 展开逻辑 |
|------|------|--------|------|--------|----------|----------|
| 1 | 复利计算器 | 本金 × 利率 × 年限，看看钱能变多少 | `Icons.calculate` | `#6366F1`（靛蓝） | `showModalBottomSheet` | `_CompoundInterestSheet` |
| 2 | 目标倒推计算器 | 想要达成目标，现在需要存多少 | `Icons.flag` | `#10B981`（绿色） | `showModalBottomSheet` | `_GoalPlannerSheet` |
| 3 | 通胀侵蚀测算 | 看看通胀会吃掉你多少购买力 | `Icons.trending_down` | `#EF4444`（红色） | `showModalBottomSheet` | `_InflationSheet` |
| 4 | 产品收益对比 | 同等本金，哪种产品到期最多 | `Icons.compare_arrows` | `#F59E0B`（琥珀） | `showModalBottomSheet` | `_ProductComparisonSheet` |

相邻 `_ToolCard` 之间间距 12px，最后一张下方间距 20px。

所有 `showModalBottomSheet` 属性：
- `isScrollControlled: true`（随键盘上推）
- `backgroundColor: AppColors.surface`
- `shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24)))`
- 内部 padding 响应 `MediaQuery.of(context).viewInsets.bottom`（键盘弹起时底部安全区）

---

### 3.2 工具入口详细功能描述

#### 3.2.1 复利计算器（`_CompoundInterestSheet`）

**入参（TextEditingController 默认值）**：

| 字段 | 标签 | 默认值 | 类型 |
|------|------|--------|------|
| 本金 | 本金（元） | 1,000,000 | `double` |
| 年化收益率 | 年化收益率（%） | 3.0 | `double`（内部 /100） |
| 投资年限 | 投资年限（年） | 10 | `int` |

**计算公式**：

```
result = principal × (1 + rate/100) ^ years
```

**输出展示**：

- 标题：「到期总资产」
- 主数字：`¥{formatMoney(result)}`，字号 28，颜色 `AppColors.primary`
- 副文字：「增值 ¥{formatMoney(result - principal)}」，颜色 `AppColors.success`
- 结果框背景：`AppColors.primary.withOpacity(0.08)`

**金额格式化规则（`_formatMoney`）**：

| 数值范围 | 格式 |
|----------|------|
| ≥ 1亿 | `X.XX亿`（保留2位小数） |
| ≥ 1万 | `X.XX万`（保留2位小数） |
| < 1万 | `X.XX`（保留2位小数） |

---

#### 3.2.2 目标倒推计算器（`_GoalPlannerSheet`）

**说明文字**（标题下方）：「想知道要达成目标，现在需要准备多少钱？」

**入参**：

| 字段 | 标签 | 默认值 | 类型 |
|------|------|--------|------|
| 目标金额 | 目标金额（元） | 3,000,000 | `double` |
| 预期年化收益率 | 预期年化收益率（%） | 3.5 | `double`（内部 /100） |
| 投资年限 | 投资年限（年） | 10 | `int` |

**计算公式**（现值公式 Present Value）：

```
result = target / (1 + rate/100) ^ years
```

**输出展示**：

- 标题：「现在需要准备」
- 主数字：`¥{formatMoney(result)}`，字号 28，颜色 `AppColors.success`
- 结果框背景：`AppColors.success.withOpacity(0.08)`
- 无增值副文字（仅显示现值）

---

#### 3.2.3 通胀侵蚀测算（`_InflationSheet`）

**入参**：

| 字段 | 标签 | 默认值 | 类型 |
|------|------|--------|------|
| 当前金额 | 当前金额（元） | 1,000,000 | `double` |
| 年通胀率 | 年通胀率（%，参考3%） | 3.0 | `double`（内部 /100） |
| 年限 | 年限（年） | 10 | `int` |

**计算公式**：

```
realValue = amount / (1 + inflation/100) ^ years
lostValue = amount - realValue
```

**输出展示（双列布局）**：

| 列 | 标题 | 数值颜色 |
|----|------|----------|
| 左 | 实际购买力 | `AppColors.textPrimary` |
| 右 | 被通胀吃掉 | `AppColors.error` |

- 两列主数字字号 20，fontWeight w700
- 结果框背景：`AppColors.error.withOpacity(0.06)`（红色淡背景，视觉警示）

---

#### 3.2.4 产品收益对比（`_ProductComparisonSheet`）

**入参（横排 Row）**：

| 字段 | 标签 | 默认值 | 类型 |
|------|------|--------|------|
| 本金 | 本金（元） | 1,000,000 | `double` |
| 年限 | 年限（年） | 5 | `int` |

**预置产品列表（静态常量，10 种）**：

| 产品名称 | 年化收益率 | 色标 |
|----------|------------|------|
| 活期存款 | 0.15% | `#94A3B8`（灰） |
| 货币基金 | 1.70% | `#6EE7B7`（浅绿） |
| 1年定存 | 1.35% | `#10B981`（绿） |
| 3年定存 | 1.75% | `#059669`（深绿） |
| 国债(5年) | 2.50% | `#3B82F6`（蓝） |
| 银行理财 | 3.00% | `#6366F1`（靛蓝） |
| 债券基金 | 3.50% | `#8B5CF6`（紫） |
| 增额终身寿 | 2.90% | `#F59E0B`（琥珀） |
| 沪深300 ETF | 6.00% | `#EF4444`（红） |
| 港元存款 | 4.20% | `#EC4899`（粉） |

**计算公式**（对每种产品）：

```
total = principal × (1 + rate/100) ^ years
gain  = total - principal
```

**排序**：按 `total` 降序排列（收益最高排首位）。

**结果展示（条形图列表）**：

每行结构：`[产品名 80px] [进度条] [到期总额 文字]`

- 进度条宽度比例：`item.total / maxTotal`（最高收益产品宽度100%）
- 进度条高度 20px，圆角 10px
- 底层灰色背景（`AppColors.surfaceVariant`）+ 彩色填充（产品色标）
- 到期总额文字：字号 12，fontWeight w600

金额格式化（略有差异）：≥1亿保留1位小数，≥1万保留1位小数，否则取整（`toStringAsFixed(0)`）。

---

### 3.3 共用 UI 组件

#### `_ToolCard`

水平 Row 布局，圆角 16，border 1px（`AppColors.border`）：

```
[图标容器 52×52, 色标 0.1 opacity] [16px] [标题+副标题, Expanded] [chevron_right]
```

- 图标容器圆角 16，图标大小 26
- 标题：字号 16，w600，`AppColors.textPrimary`
- 副标题：字号 13，`AppColors.textSecondary`
- 右侧箭头：`Icons.chevron_right`，颜色 `AppColors.textHint`
- 整体 padding 18px

#### `_InputField`

垂直 Column：标签文字（字号13，textSecondary）+ TextField（数字键盘，filled，`AppColors.surfaceVariant`，圆角10）

---

## 4. 导航逻辑

| 触发位置 | 导航方法 | 目标 | 是否全屏（无底部导航栏） |
|----------|----------|------|--------------------------|
| 底部导航 Tab 3 | `go('/tools')` | `/tools`（ToolsPage） | 否（ShellRoute 内） |
| 基金组合监控 Banner | `context.push('/fund-tracker')` | `/fund-tracker`（FundTrackerPage） | 是（ShellRoute 外） |
| 决策日记 Banner | `context.push('/decisions')` | `/decisions`（DecisionsPage） | 是（ShellRoute 外） |
| 4 张计算器 ToolCard | `showModalBottomSheet(...)` | 同页 Modal | 否（不离开当前页） |

**`push` vs `go` 区分**：

- 两张 Banner 使用 `push`，目标页面在 ShellRoute 外，返回后仍回到 `/tools`
- 计算器均使用 `showModalBottomSheet`，不产生路由跳转，下拉或点击系统返回关闭

---

## 5. 边界条件

| 场景 | 当前行为 | 说明 |
|------|----------|------|
| 输入非数字字符 | `double.tryParse` / `int.tryParse` 返回 null，fallback 为 0 | 不抛异常，但计算结果为 0 |
| 输入负数 | 接受并计算，结果可能为负或异常值 | 未做非负校验 |
| 输入 0 年限 | `pow(1+rate, 0) = 1`，复利结果等于本金 | 逻辑正确 |
| 产品对比：本金输入失败 | fallback `1000000`，年限 fallback `5` | 有兜底默认值 |
| 键盘弹起时 Modal 内容被遮挡 | `viewInsets.bottom` padding 自动上移 | 所有 Sheet 均已处理 |
| 结果为 null 时（未点击计算） | 不显示结果区域（条件渲染 `if (_result != null)`） | 初始状态干净 |

---

## 6. 与其他模块的联动

| 联动模块 | 联动方式 | 方向 |
|----------|----------|------|
| 基金追踪（fund_tracker） | Banner 入口 `push('/fund-tracker')` | 工具页 → 基金追踪页 |
| 决策日记（decisions） | Banner 入口 `push('/decisions')` | 工具页 → 决策日记页 |
| 主题系统（app_theme） | 使用 `AppColors.*` 全部颜色常量 | 工具页依赖 |
| 路由（app_router） | `/tools` 注册在 ShellRoute 下 | 路由系统 → 工具页 |
| AI 对话（ai_chat） | 无直接联动（计算器为纯本地计算） | — |
| 产品导航（products） | 无直接联动 | — |

---

## 7. 验收标准

| ID | 验收项 | 预期结果 |
|----|--------|----------|
| AC-1 | 进入 `/tools`，页面正常渲染 | 显示 2 张 Banner + 「计算器」分组标题 + 4 张 ToolCard |
| AC-2 | 点击「基金组合监控」Banner | 全屏跳转 `/fund-tracker`，底部导航隐藏 |
| AC-3 | 点击「决策日记」Banner | 全屏跳转 `/decisions`，底部导航隐藏 |
| AC-4 | 点击「复利计算器」→ 点击「计算」 | Modal 展示「到期总资产」和「增值」两行数值 |
| AC-5 | 复利计算：本金100万，年化3%，10年 | 到期总资产 ≈ ¥134.39万（1,343,916.38） |
| AC-6 | 点击「目标倒推计算器」→ 输入目标300万，年化3.5%，10年 → 计算 | 显示「现在需要准备 ≈ ¥212.62万」 |
| AC-7 | 通胀测算：100万，通胀3%，10年 | 实际购买力 ≈ ¥74.41万，被通胀吃掉 ≈ ¥25.59万 |
| AC-8 | 产品对比：本金100万，5年 → 点击「对比」 | 10 行按收益降序排列，沪深300 ETF 排首位 |
| AC-9 | 产品对比进度条 | 第1名（最高收益）进度条宽度为 100%，其余按比例缩短 |
| AC-10 | 弹起键盘时，Modal 内容随键盘上移，输入框不被遮挡 | 所有 4 个 Sheet 均响应 `viewInsets.bottom` |
| AC-11 | 输入空字符串或非数字 | 计算不崩溃，结果显示 ¥0 |
| AC-12 | 从 `/fund-tracker` 或 `/decisions` 返回 | 回到 `/tools` 页，底部导航恢复显示 |

---

## 8. 不做的范围（V1.0 明确排除）

- 计算器结果**不可保存**，关闭 Modal 后数据不持久化
- 计算器结果**不可分享**（无截图、无导出功能）
- 产品收益对比的**利率为静态硬编码**，不接入实时利率接口
- 通胀率**不自动拉取 CPI 数据**，需用户手动输入
- 工具页**无搜索功能**，无工具分类折叠
- 计算器**无历史记录**
- Banner 入口**无未读角标/数量提示**（如持仓亏损提醒）
- **无新手引导/Tooltip**

---

## 9. V1.1 可扩展工具（推断自现有路由和代码）

基于当前路由表和代码架构，以下工具在 V1.1 中可自然扩展：

| 候选工具 | 依据 | 优先级 |
|----------|------|--------|
| **AI 顾问入口 Banner**（跳 `/chat`） | 路由 `/chat` 已注册，`AiChatPage` 已实现；工具页是自然入口 | P0 |
| **定投计算器**（DCA，每月定投 + 年化收益 + 年限 → 总资产） | 计算器区已有基础组件，逻辑类似复利 | P1 |
| **持仓风险诊断**（联动 fund_tracker 持仓数据） | `PortfolioContextBuilder` 已实现，M02 持仓注入已完成 | P1 |
| **产品对比利率实时化** | `MarketRateService` 已存在，可替换静态利率 | P1 |
| **股票追踪入口**（跳 `/fund-tracker/add-stock`）| 路由 `fund-tracker-add-stock` 已注册 | P2 |
| **自选股入口**（跳 `/fund-tracker/add-watch`） | 路由 `fund-tracker-add-watch` 已注册 | P2 |
| **告警设置入口**（跳 `/fund-tracker/alert-settings`） | 路由 `fund-tracker-alert-settings` 已注册 | P2 |
| **税后收益计算器**（理财产品利息所得税测算） | 无现有代码，属新功能 | P3 |
| **产品推荐跳转**（对比结果页直接跳 `/products`） | `/products` 路由已注册 | P2 |
