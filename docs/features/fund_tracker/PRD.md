# 基金持仓追踪器 — 产品需求文档

> 版本：v1.0 | 优先级：P0（最高频功能）| 状态：✅ 已实现 | 最后更新：2026-03-22

---

## 1. 问题陈述

用户持有多只基金，分散在不同平台，缺乏统一视图：
- "我现在所有基金加起来赚了多少？"
- "今天市场大跌，我的持仓今日亏了多少？"
- "我的某只基金涨了20%，我设置的止盈线到了吗？"

**核心矛盾**：基金净值 T+1 更新、各平台数据割裂，用户无法实时感知组合整体收益状况。

---

## 2. 目标用户

- 持有 3–20 只基金，分散在多个平台的用户
- 想随时掌握"我今天赚了多少"的用户
- 有止盈止损纪律意识，需要通知提醒的用户

---

## 3. 用户故事

**US-01**：作为用户，我想把所有基金汇总在一个页面，看到总市值、累计收益、今日盈亏，不用逐个平台查。

**US-02**：作为用户，我在交易时段希望每15分钟自动刷新行情，下班后一打开App就知道今天涨跌。

**US-03**：作为用户，我的某只基金累计涨了20%想止盈，希望自动推送通知提醒我，不用每天盯盘。

**US-04**：作为用户，我买入基金时不记得截图，可以从购买截图里OCR识别份额和净值，减少手动输入。

**US-05**：作为用户，我加仓后想顺手记录决策理由，直接从操作菜单触发，不用重新打开决策日记。

---

## 4. 功能需求

### 4.1 数据模型

#### FundHolding（基金持仓）

| 字段 | 类型 | 持久化 | 说明 |
|------|------|--------|------|
| id | String | ✅ Hive + Supabase | 时间戳字符串（`millisecondsSinceEpoch.toString()`）|
| fundCode | String | ✅ | 基金代码，如 "000001" |
| fundName | String | ✅ | 基金全名 |
| shares | double | ✅ | 持仓份额 |
| costNav | double | ✅ | 买入均价（成本净值）|
| addedDate | String | ✅ | 添加日期 "2024-01-01" |
| alertUp | double? | ✅ Hive | 单仓止盈线（累计浮盈率%）|
| alertDown | double? | ✅ Hive | 单仓止损线（累计亏损率%，负数）|
| alertTriggeredDate | String? | ✅ Hive | 当日已触发日期，防重复推送 |
| currentNav | double | ❌ 运行时 | 上一交易日净值 |
| estimatedNav | double | ❌ 运行时 | 今日盘中估值 |
| changeRate | double | ❌ 运行时 | 今日涨跌幅（%）|
| navDate | String | ❌ 运行时 | 净值日期 |
| hasEstimate | bool | ❌ 运行时 | 今日是否有盘中估值 |
| isLoading | bool | ❌ 运行时 | 是否正在刷新 |
| errorMsg | String? | ❌ 运行时 | 刷新错误信息 |

**注意**：`alertUp/alertDown/alertTriggeredDate` 仅持久化到 Hive，Supabase 同步只含核心字段（持仓基本信息）。

#### 计算属性

| 属性 | 计算逻辑 |
|------|---------|
| costAmount | shares × costNav |
| currentValue | shares × (hasEstimate && estimatedNav > 0 ? estimatedNav : currentNav) |
| totalReturn | currentValue − costAmount |
| totalReturnRate | totalReturn / costAmount × 100 |
| todayGain | hasEstimate ? shares × effectiveNav × changeRate/100 : 0 |

#### AlertSettings（全局组合预警设置）

| 字段 | 类型 | 持久化 | 说明 |
|------|------|--------|------|
| enabled | bool | SharedPreferences | 是否开启预警 |
| targetReturnPct | double | SharedPreferences | 止盈线（%），0=未设置 |
| maxDrawdownPct | double | SharedPreferences | 止损线（%，正数），0=未设置 |

---

### 4.2 核心操作流程

#### 4.2.1 添加基金持仓

**路径**：`/fund-tracker/add`（FundTrackerPage → 基金Tab → FAB「+」）

**两种添加方式**：

**方式A：手动输入**
1. 输入基金代码（6位数字）→ 实时搜索展示建议列表（天天基金搜索接口）
2. 点击建议 或 点击「验证」按钮 → 调用 `fetchFundInfo()` 校验代码合法性，获取基金名称 + 参考净值
3. 填写持仓份额（必填）、买入均价（验证后自动填入最新净值作为参考，可修改）
4. 提交 → 生成 FundHolding，保存到 Hive + Supabase → 立即触发一次行情刷新
5. 弹出 DecisionPromptSheet（可跳过，categoryOptions 仅含基金相关类别）→ 返回列表页

**方式B：截图OCR识别**
1. 点击 AppBar 上的「拍照/相册」图标
2. 调用 `OcrService.recognizeFromImage()` → 两阶段：Claude Vision API 解析截图 → 结构化提取基金代码/份额/净值/金额
3. 识别结果自动填入表单，自动触发代码验证
4. 识别完整时 Snackbar 提示成功，部分识别时提示用户补充

**表单验证**：
- 基金代码：必须先通过 `fetchFundInfo()` 验证（`_isVerified = true`）
- 份额：必填，> 0
- 买入均价：必填，> 0

#### 4.2.2 加仓

**路径**：FundCard → 点击卡片 → 操作 Sheet → 「加仓」

1. 弹出 `_AddPositionSheet`：输入本次加仓份额 + 加仓净值
2. 计算新的持仓均价：`newCostNav = (oldShares × oldCostNav + newShares × newNav) / (oldShares + newShares)`
3. 调用 `updateHolding(id, newShares, newCostNav)`：更新 Hive + Supabase
4. 弹出 DecisionPromptSheet（预填：buy/主动基金/金额=加仓份额×净值，可跳过）

#### 4.2.3 减持（卖出）

**路径**：FundCard → 点击卡片 → 操作 Sheet → 「减持（卖出）」

1. 弹出 `_ReduceSheet`：输入卖出份额 + 卖出净值
2. 更新持仓：`newShares = oldShares - soldShares`（份额减少，成本净值不变）
3. 若 newShares ≤ 0：自动删除该持仓
4. 弹出 DecisionPromptSheet（预填：sell/主动基金/金额=卖出份额×净值，可跳过）

#### 4.2.4 删除持仓

**两种删除入口**：
- **右滑删除**：FundCard 右滑出现红色删除区域 → 确认弹窗
- **操作 Sheet 删除**：点击 → 操作 Sheet → 「删除持仓」→ 确认弹窗

确认后：Hive 删除 + Supabase 删除，不可恢复。

#### 4.2.5 设置单仓止盈止损

**路径**：FundCard → 点击 → 操作 Sheet → 「设置止盈止损」

- 弹出 `_HoldingAlertSheet`：输入止盈率（如 +20%）和止损率（如 -10%）
- 支持清空（输入框留空 = 清除该预警）
- 仅存 Hive，触发检查在每次 `_refreshOne()` 成功后执行
- 每个持仓每日最多触发一次（由 `alertTriggeredDate` 防重复）
- 触发时调用 `NotificationService.showPriceAlert()`

---

### 4.3 行情刷新机制

#### 数据来源：天天基金（东方财富）非官方接口

| 接口 | 用途 | 说明 |
|------|------|------|
| `fundgz.1234567.com.cn/js/{code}.js` | JSONP 盘中估值 | 优先，含今日估值（gsz）+ 净值（dwjz）|
| `api.fund.eastmoney.com/f10/lsjz` | 历史净值 | 降级用，货币基金等无估值基金 |
| `fund.eastmoney.com/api/fundSearch` | 基金搜索 | 获取基金名称（降级拼合用）|

**刷新策略**：
- `hasEstimate`：仅当 `gztime` 前缀匹配今天日期时为 true（即盘中有实时估值）
- 非交易日/未开盘：`hasEstimate = false`，今日盈亏显示「--」
- 每只基金刷新间隔 300ms（避免接口限频）

#### 自动刷新

- 交易时段内（北京时间）每 15 分钟自动刷新一次
- App 进入前台（`didChangeAppLifecycleState = resumed`）重启定时器
- App 进入后台（`paused`）停止定时器
- 手动刷新：AppBar「刷新」图标 + 下拉刷新

**交易时段判定（北京时间，工作日）**：
- A股：9:30–11:30 / 13:00–15:00
- 港股：9:30–16:00
- 美股（约）：21:30– 次日 04:00

---

### 4.4 持仓总览页面结构

#### 顶部汇总卡片

| 项目 | 说明 |
|------|------|
| 总市值 | 所有基金 + 股票持仓当前市值之和 |
| 累计收益 | totalReturn + 收益率% |
| 今日盈亏 | 仅当至少一只持仓 `hasEstimate=true` 时展示，否则显示「暂无估值」|

数据来源：`portfolioSummaryProvider`（基金 + 股票合并计算）

#### 近30日走势图

- 数据：`portfolioSnapshotsProvider` 从 Supabase 加载近30天快照
- 最少需要 2 个数据点才展示图表，否则隐藏
- 每次 `refreshAll()` 完成后自动保存当日快照 → 刷新走势图

#### Tab 结构（5个Tab，固定吸顶）

| Tab | 内容 |
|-----|------|
| 基金 | FundHolding 列表 |
| A股 | StockHolding（market='A'）|
| 港股 | StockHolding（market='HK'）|
| 美股 | StockHolding（market='US'）|
| 自选 | WatchItem 列表 |

FAB「+」根据当前 Tab 跳转不同添加页面（基金/股票/自选）。

#### 基金持仓卡片展示

有行情数据时展示（currentNav > 0 或 estimatedNav > 0）：
- 基金名称 + 代码 + 预警图标（有预警时显示橙色铃铛）
- 今日涨跌幅徽章（`hasEstimate=true` 显示 %，否则显示「未开盘」）
- 昨日净值
- 数据行：持仓市值 / 累计收益 / 收益率 / 今日盈亏

---

### 4.5 刷新后留存功能（refreshAll 完成后触发）

每次完整刷新成功（totalCost > 0）后，自动执行：

| 功能 | 实现 | 触发条件 |
|------|------|---------|
| 保存今日快照 | `SupabaseService.saveSnapshot()` | 每次刷新（覆盖当日）|
| 每日收益播报 | `NotificationService.showPnlSummary()` | 每次刷新 |
| 全局止盈止损预警 | `alertSettingsProvider.checkAndAlert()` | 每次刷新，同日仅一次 |
| 单仓止盈止损预警 | `_checkHoldingAlert()` | 每只基金刷新成功后，同日仅一次 |

---

### 4.6 全局预警设置

**路径**：FundTrackerPage AppBar → 铃铛图标 → `/fund-tracker/alert-settings`

- 开关：开启后需要系统通知权限（`NotificationService.requestPermission()`）
- 止盈线：累计收益率达到 X% 时触发（整个组合）
- 止损线：累计亏损超过 X% 时触发（整个组合）
- 同日只触发一次（`alert_last_date` in SharedPreferences）
- 启用但没设置任何阈值时，保存时拦截

---

### 4.7 数据存储与同步

**FundHolding 持久化**：
- 本地：Hive box `fund_holdings`，key = `holdings`，value = JSON 列表字符串
- 云端：Supabase `holdings` 表（upsert by id），仅含核心字段（不含预警字段）

**加载策略**：
1. 启动时先加载 Hive（快速展示）
2. 异步拉取 Supabase 云端数据，若非空则替换本地（云端为准）
3. 重新保存到 Hive
4. 有数据后立即触发全量行情刷新

**快照持久化**：Supabase `portfolio_snapshots` 表（每天一条，覆盖写）

---

### 4.8 与其他模块的联动

| 联动方向 | 触发时机 | 行为 |
|---------|---------|------|
| 基金持仓 → 决策日记 | 添加/加仓/减持成功后 | 弹出 DecisionPromptSheet，传入 categoryOptions 过滤基金类别 |
| 基金持仓 → 决策日记 | 操作 Sheet | 「查看决策记录」跳转 /decisions |
| 基金持仓 → 股票持仓 | refreshAll | 同时触发股票持仓刷新 + 自选股刷新 |
| 基金持仓 → 自选股 | refreshAll | 同时刷新自选股行情 |
| 基金持仓 → AI 对话 | PortfolioContextBuilder | 持仓快照注入 AI 上下文（M02）|

---

## 5. 边界条件

| 场景 | 处理方式 |
|------|---------|
| 行情接口返回空（货币基金等）| 降级历史净值接口，`hasEstimate=false` |
| 行情接口全部失败 | `errorMsg='行情获取失败'`，保留上次数据 |
| Supabase 不可用 | 降级 Hive，刷新正常进行 |
| 非交易日/未开盘 | `hasEstimate=false`，今日涨跌显示「未开盘」，今日盈亏显示「--」|
| 减持后份额 ≤ 0 | 自动删除持仓 |
| 添加与已有基金相同的代码 | 不去重（允许同代码多条持仓，id 不同）|
| OCR 识别失败 | Snackbar 提示，用户手动填写 |
| OCR 部分识别（仅识别代码）| 自动触发代码验证，其余字段用户补充 |
| 无持仓时打开页面 | 展示空状态引导页，两个按钮「添加基金」「添加股票」|
| 走势图数据不足2个点 | 隐藏走势图卡片 |

---

## 6. 验收标准

| AC | 验收方式 |
|----|---------|
| AC-1：添加基金 → 卡片立即展示 + 行情刷新 | 手动测试 |
| AC-2：有估值时今日涨跌幅% 正确 | 对比天天基金App |
| AC-3：无估值时显示「未开盘」，今日盈亏「--」| 非交易时段手动测试 |
| AC-4：加仓后持仓均价重新计算正确 | 单元测试 fund_holding_test.dart |
| AC-5：减持后份额正确，0份额自动删除 | 单元测试 |
| AC-6：止盈止损通知触发（同日不重复）| 模拟设置低阈值，刷新后检查通知 |
| AC-7：断网时可查看 Hive 历史数据 | 断网测试 |
| AC-8：走势图在有 ≥ 2 天快照时显示 | 累积2天数据后检查 |
| AC-9：OCR 识别完整截图自动填表 | 上传测试截图 |
| AC-10：从加仓操作触发决策日记，金额正确预填 | 手动加仓后检查 Sheet |

---

## 7. 不做的范围

- **不做**：基金历史净值图表（只有走势图，不展示单只基金净值曲线）
- **不做**：基金排行/筛选（不是导航工具，只管持仓）
- **不做**：T+1 净值自动更新提醒（推送通知仅用于预警，不做收盘播报）
- **不做**：多账户/多组合管理（device_id 单用户视图）
- **不做**：历史交易记录（只记录当前持仓状态）
- **不做**：基金分红、拆分等公司行为处理

---

## 8. V1.1 可延后

- 单只基金历史净值走势图（点击卡片展开）
- 基金持仓分类汇总（按类型：权益/固收/货币）
- 加仓/减持操作历史记录
- 截图 OCR 支持更多平台格式（目前主要支持天天基金）
