# 股票持仓追踪器 — 产品需求文档

> 版本：v1.0 | 优先级：P0（最高频功能）| 状态：✅ 已实现 | 最后更新：2026-03-22

---

## 1. 问题陈述

用户持有 A股/港股/美股，行情分散在三个市场，时区不同、货币不同、交易规则各异：
- "我持有的茅台今天涨了多少钱？"
- "港股和美股合计算，我的股票仓位今天赚了多少？"
- "腾讯涨了20%，我设的止盈线到了吗？"

**核心矛盾**：三市场数据来源不同，用户在单一界面无法横向对比多市场持仓盈亏。

---

## 2. 目标用户

- 同时持有 A股/港股/美股的用户
- 关注持仓实时涨跌，需要轻量盯盘工具的用户
- 有止盈止损纪律，需要通知提醒的用户

---

## 3. 用户故事

**US-01**：作为用户，我想在同一个界面按市场 Tab 查看 A股/港股/美股的持仓，不用在三个 App 之间切换。

**US-02**：作为用户，我的持仓同时包含 A 股和港股，我想在汇总卡片里看到换算后的总市值（含今日盈亏）。

**US-03**：作为用户，我持有的美股 ETF 涨了 15%，希望触发止盈通知，不用每天开 App 查。

**US-04**：作为用户，添加股票时，我搜索"茅台"就能找到 sh600519，不用记忆完整代码。

---

## 4. 功能需求

### 4.1 数据模型

#### StockHolding（股票持仓）

| 字段 | 类型 | 持久化 | 说明 |
|------|------|--------|------|
| id | String | ✅ Hive + Supabase | 时间戳字符串（`millisecondsSinceEpoch.toString()`）|
| symbol | String | ✅ | 内部标准代码（新浪格式前缀，见下表）|
| stockName | String | ✅ | 股票名称 |
| market | String | ✅ | 市场标识：`'A'` / `'HK'` / `'US'` |
| shares | double | ✅ | 持仓股数（A股整数，美股可含小数）|
| costPrice | double | ✅ | 每股买入成本价 |
| addedDate | String | ✅ | 添加日期 "2024-01-01" |
| alertUp | double? | ✅ Hive | 单仓止盈线（累计浮盈率%）|
| alertDown | double? | ✅ Hive | 单仓止损线（累计亏损率%，负数）|
| alertTriggeredDate | String? | ✅ Hive | 当日已触发日期，防重复推送 |
| currentPrice | double | ❌ 运行时 | 当前股价（非持久化）|
| changeRate | double | ❌ 运行时 | 当日涨跌幅（%）|
| changeAmount | double | ❌ 运行时 | 当日涨跌额（每股，原始货币单位）|
| isLoading | bool | ❌ 运行时 | 是否正在刷新 |
| errorMsg | String? | ❌ 运行时 | 刷新错误信息 |

**注意**：`alertUp/alertDown/alertTriggeredDate` 仅持久化到 Hive，Supabase 同步只含核心字段。

#### symbol 格式规范

| 市场 | 格式 | 示例 |
|------|------|------|
| A股（沪市，代码6开头）| `sh{code}` | `sh600519` |
| A股（深市，代码0/3/2/8开头）| `sz{code}` | `sz000001` |
| 港股 | `hk{code}` | `hk00700` |
| 美股 | 原始 ticker（大写）| `AAPL` |

#### 计算属性

| 属性 | 计算逻辑 |
|------|---------|
| costAmount | shares × costPrice |
| currentValue | shares × (currentPrice > 0 ? currentPrice : costPrice) |
| totalReturn | currentValue − costAmount |
| totalReturnRate | totalReturn / costAmount × 100 |
| todayGain | currentPrice > 0 ? shares × changeAmount : 0（changeAmount 为每股涨跌额）|

**注意**：`todayGain` 基于每股涨跌额计算（非涨跌幅%），可正确反映持股数量对应的实际盈亏。

#### 价格精度规范

| 市场 | 小数位 | 货币符号 |
|------|--------|---------|
| A股 | 2位 | ¥ |
| 港股 | 3位 | HK$ |
| 美股 | 2位 | $ |

---

### 4.2 核心操作流程

#### 4.2.1 添加股票持仓

**路径**：`/fund-tracker/add-stock`（FundTrackerPage → A股/港股/美股 Tab → FAB「+」）

**流程**：
1. 选择市场（A股 / 港股 / 美股，三段式 Segmented Control）
2. 输入代码或名称 → 实时搜索建议（东方财富搜索接口 for A/HK，Yahoo Finance for US）
   - 搜索建议最多展示 6 条
   - 搜索结果按市场筛选（切换市场时清空建议）
3. 点击建议 或 点击「验证」按钮 → 调用 `fetchStockInfo()` 校验代码，获取股票名称 + 当前价格
   - 成功后回填规范化代码（如用户输入 "600519" → 自动回填 "sh600519"）
   - 自动填入当前股价作为默认成本价（可修改）
4. 填写持仓股数（必填，A股建议整数，美股支持小数）
5. 填写买入成本价（已预填，可修改）
6. 底部实时展示总成本预览（股数 × 成本价，含货币单位）
7. 点击「确认添加」→ 保存到 Hive + Supabase → 立即刷新行情
8. 弹出 DecisionPromptSheet（可跳过，productCategory 按市场映射，categoryOptions 仅含股票相关类别）→ 返回列表

**市场 → 决策类别映射**：
| 市场 | productCategory | categoryOptions |
|------|----------------|-----------------|
| A股 | A股ETF | A股ETF / 港股 / 美股ETF / 主动基金 / 其他 |
| 港股 | 港股 | A股ETF / 港股 / 美股ETF / 主动基金 / 其他 |
| 美股 | 美股ETF | A股ETF / 港股 / 美股ETF / 主动基金 / 其他 |

#### 4.2.2 增持

**路径**：StockCard → 点击 → 操作 Sheet → 「增持」

1. 弹出 `_AddStockSheet`：输入本次买入股数 + 成本价
2. 计算新均价：`newCostPrice = (oldShares × oldCostPrice + newShares × newPrice) / (oldShares + newShares)`
3. 调用 `updateHolding(id, newShares, newCostPrice)`：更新 Hive + Supabase
4. 弹出 DecisionPromptSheet（预填：buy / 按市场映射类别 / 金额 = 增持股数 × 价格）

#### 4.2.3 减持（卖出）

**路径**：StockCard → 点击 → 操作 Sheet → 「减持（卖出）」

1. 弹出 `_ReduceStockSheet`：输入卖出股数 + 卖出价格
2. 展示已实现盈亏：`soldShares × (sellPrice - costPrice)`
3. 若 `newShares ≤ 0`：自动删除持仓
4. 弹出 DecisionPromptSheet（预填：sell / 按市场映射类别 / 金额 = 卖出股数 × 价格）

#### 4.2.4 删除持仓

**两种入口**：
- **右滑删除**：StockCard 右滑出现红色删除区 → 确认弹窗
- **操作 Sheet 删除**：点击 → 操作 Sheet → 「删除持仓」→ 确认弹窗

确认后：Hive 删除 + Supabase 删除，不可恢复。

#### 4.2.5 设置单仓止盈止损

**路径**：StockCard → 点击 → 操作 Sheet → 「设置止盈止损」

- 弹出 `_HoldingAlertSheet`（与基金持仓共用同一 Widget）：输入止盈率（如 +20%）和止损率（如 -10%）
- 仅存 Hive，触发检查在每次 `_refreshOne()` 成功后执行
- 每个持仓每日最多触发一次

---

### 4.3 行情刷新机制

#### 数据来源

| 市场 | 数据源 | 接口 |
|------|--------|------|
| A股 | 东方财富 | `push2.eastmoney.com/api/qt/stock/get` |
| 港股 | 东方财富 | 同上，secid 前缀 `116.` |
| 美股 | Yahoo Finance | `query1.finance.yahoo.com/v8/finance/chart/{symbol}` |

**价格缩放（东方财富接口特殊处理）**：
- A股：API 返回 f43 字段以"分"存储 → ÷100 得 CNY（如 f43=145502 → 1455.02 元）
- 港股：API 返回 f43 字段以"厘"存储 → ÷1000 得 HKD（如 f43=518000 → 518.000 港元）
- 无效值处理：非交易时段 f43 可能返回 `-2147483648`（INT_MIN），此时忽略数据

**secid 映射规则**（新浪格式 → 东方财富 secid）：
- `sh{code}` → `1.{code}`
- `sz{code}` → `0.{code}`
- `hk{code}` → `116.{code}`

#### 自动刷新

- 由 `FundHoldingsNotifier.refreshAll()` 统一触发，会同时调用股票持仓的 `refreshAll()`
- 触发时机：交易时段内每 15 分钟（见基金持仓交易时段定义）
- 每只股票刷新间隔 300ms

---

### 4.4 持仓卡片展示

有行情数据时展示（currentPrice > 0）：
- 股票名称 + 市场标签（A股=红, 港股=蓝, 美股=绿）+ 预警铃铛图标（有预警时显示橙色）
- 代码（symbol）
- 当前股价（含货币符号，HK股3位小数）
- 今日涨跌幅徽章（%）
- 数据行：持仓市值 / 累计收益（含货币符号）/ 收益率% / 今日盈亏（含货币符号）

**注意**：A股今日盈亏显示人民币金额（¥），港股显示港元（HK$），美股显示美元（$），不做货币换算。

---

### 4.5 数据存储与同步

**StockHolding 持久化**：
- 本地：Hive box `stock_holdings`，key = `holdings`，value = JSON 列表字符串
- 云端：Supabase `stock_holdings` 表（upsert by id），不含预警字段

**加载策略**：
1. 启动时先加载 Hive（快速展示）
2. 异步拉取 Supabase 云端数据，若非空则替换本地（云端为准）
3. 重新保存到 Hive
4. 有数据后立即触发全量行情刷新

---

### 4.6 与其他模块的联动

| 联动方向 | 触发时机 | 行为 |
|---------|---------|------|
| 股票持仓 → 决策日记 | 添加/增持/减持成功后 | 弹出 DecisionPromptSheet，按市场映射 productCategory |
| 股票持仓 → 决策日记 | 操作 Sheet | 「查看决策记录」跳转 /decisions |
| 基金持仓 → 股票持仓 | refreshAll | 基金刷新时同步触发股票刷新 + 自选股刷新 |
| 股票持仓 → portfolioSummaryProvider | 每次刷新 | 贡献 totalCost / totalValue / todayGain 到全局汇总 |
| 股票持仓 → AI 对话 | PortfolioContextBuilder | 持仓快照注入 AI 上下文（M02）|

---

## 5. 边界条件

| 场景 | 处理方式 |
|------|---------|
| 东方财富接口非交易时段返回 INT_MIN | 判断 `f43 <= 0 \|\| f43 > 2000000000`，数据无效，显示错误 |
| 美股 Yahoo Finance 返回空 | `data == null`，显示「行情获取失败」|
| 美股股数为小数（如 10.5 股）| 支持，表单 hint「可输入小数」|
| 港股代码输入不带前缀（如 00700）| 自动补全 `hk00700` |
| 减持后股数 ≤ 0 | 自动删除持仓 |
| 添加同一 symbol 重复持仓 | 允许（不去重，id 不同，代表不同批次）|
| 货币换算 | 不做换算，各市场金额用原始货币展示 |
| 无持仓的市场 Tab | 展示「还没有股票持仓」空状态 + 「添加股票」按钮 |
| Supabase 不可用 | 降级 Hive，刷新正常进行 |

---

## 6. 验收标准

| AC | 验收方式 |
|----|---------|
| AC-1：A股搜索「茅台」能显示 sh600519 | 手动测试 |
| AC-2：港股价格小数3位，A股/美股2位 | 手动测试 |
| AC-3：A股 f43 值正确 ÷100 转元 | 对比东方财富 App 价格 |
| AC-4：港股 f43 值正确 ÷1000 转港元 | 对比港股实际价格 |
| AC-5：增持后持仓均价重新计算正确 | 单元测试 stock_holding_test.dart |
| AC-6：减持后份额正确，0股自动删除 | 单元测试 |
| AC-7：止盈止损通知触发（同日不重复）| 模拟设置低阈值，刷新后检查通知 |
| AC-8：美股 Yahoo Finance 数据正常 | 手动测试（需联网）|
| AC-9：从增持操作触发决策日记，类别按市场正确映射 | 手动测试 |
| AC-10：portfolioSummaryProvider 正确汇总基金+股票 | 对比手动计算 |

---

## 7. 不做的范围

- **不做**：货币换算（港元/美元不换算为人民币，直接展示原始货币）
- **不做**：股票历史 K 线图（只看当前持仓盈亏，不提供 K 线）
- **不做**：股票分红、拆股等公司行为处理
- **不做**：多账户/多组合管理
- **不做**：历史交易记录
- **不做**：A 股实时撮合价格（东方财富接口返回当日行情，非 Level2 实时价）

---

## 8. V1.1 可延后

- 货币换算（按实时汇率统一换算为人民币展示总市值）
- 持仓成本分摊记录（每次增持/减持的历史）
- 美股盘后交易价格支持
- A股/港股涨跌停幅度提醒
