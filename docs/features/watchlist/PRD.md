# PRD · 自选股（Watchlist）

> 版本：v1.0
> 日期：2026-03-23
> 状态：已实现（代码逆向）
> 对应代码路径：`lib/features/watchlist/`

---

## 1. 问题陈述

用户持有的基金/股票已由"持仓追踪"模块覆盖，但他们还需要**无需持仓**地跟踪感兴趣的股票或指数，并在价格达到目标时获得主动提醒。现有持仓模块不支持"仅观察、不持有"的场景，需要独立的自选股模块来满足这一需求。

---

## 2. 目标用户 + 用户故事

**目标用户**：持有 50万–1000万人民币、主动关注 A/港/美股行情的中国投资者。

| ID | 用户故事 |
|----|---------|
| US-01 | 作为投资者，我希望将感兴趣的股票加入自选列表，以便随时查看其最新价格和涨跌幅，而无需实际持有仓位。 |
| US-02 | 作为投资者，我希望设置价格提醒（涨到 X 元或跌到 Y 元），当行情触及我的目标价时收到通知，以便及时决策。 |
| US-03 | 作为投资者，我希望追踪股票自我加入自选以来的累计涨跌幅，以便评估我的判断是否正确。 |

---

## 3. 功能需求

### 3.1 数据模型（WatchItem）

文件：`lib/features/watchlist/data/models/watch_item.dart`

#### 3.1.1 全字段清单

| 字段名 | Dart 类型 | JSON Key | 是否持久化 | 说明 |
|--------|-----------|----------|-----------|------|
| `id` | `String` | `id` | ✅ | `DateTime.now().millisecondsSinceEpoch.toString()` 生成 |
| `symbol` | `String` | `symbol` | ✅ | 股票代码，如 `sh600519` / `hk00700` / `AAPL` |
| `name` | `String` | `name` | ✅ | 股票名称，如"贵州茅台" |
| `market` | `String` | `market` | ✅ | 市场标识：`'A'` / `'HK'` / `'US'` |
| `addedPrice` | `double` | `added_price` | ✅ | 加入自选时的价格（用于计算累计涨跌幅） |
| `addedDate` | `String` | `added_date` | ✅ | 格式 `yyyy-MM-dd`，为空时默认 `''` |
| `alertUp` | `double?` | `alert_up` | ✅（可选） | 上涨提醒价；`null` 表示未设置 |
| `alertDown` | `double?` | `alert_down` | ✅（可选） | 下跌提醒价；`null` 表示未设置 |
| `alertTriggeredDate` | `String?` | `alert_triggered_date` | ✅（可选） | 当天已触发提醒的日期（`yyyy-MM-dd`），用于防止重复推送 |
| `currentPrice` | `double` | — | ❌（运行时） | 当前实时价格，默认 `0` |
| `changeRate` | `double` | — | ❌（运行时） | 今日涨跌幅（%），默认 `0` |
| `changeAmount` | `double` | — | ❌（运行时） | 今日涨跌额（绝对值），默认 `0` |
| `isLoading` | `bool` | — | ❌（运行时） | 行情拉取中状态，默认 `false` |
| `errorMsg` | `String?` | — | ❌（运行时） | 行情拉取失败的错误文案，默认 `null` |

#### 3.1.2 计算字段

- `sinceAddedRate`（computed getter）：
  ```
  addedPrice > 0 ? (currentPrice - addedPrice) / addedPrice * 100 : 0
  ```
  即：以加入自选时价格为基准，计算累计涨跌幅（%）。

#### 3.1.3 持久化方式

- **本地**：Hive，box 名 `'watchlist'`，key `'items'`，值为整个列表序列化后的 JSON 字符串（`List<WatchItem.toJson()>`）。
  - 持久化字段：`id`、`symbol`、`name`、`market`、`added_price`、`added_date`、`alert_up`（可选）、`alert_down`（可选）、`alert_triggered_date`（可选）。
  - 实时字段（`currentPrice`、`changeRate`、`changeAmount`、`isLoading`、`errorMsg`）**不持久化**。
- **云端**：腾讯云 FastAPI + PostgreSQL，通过 `SupabaseService` 操作：
  - 读取：`GET /watchlist/{device_id}` → `loadWatchlist()`
  - 写入/更新：`POST /watchlist` → `upsertWatchItem(item.toJson())`，包含 `device_id` 字段
  - 删除：`DELETE /watchlist/{device_id}/{item_id}` → `deleteWatchItem(id)`

---

### 3.2 添加自选股流程

文件：`lib/features/watchlist/presentation/pages/add_watch_page.dart`

路由：`/fund-tracker/add-watch`（从 FundTrackerPage Tab index=4 的 FAB 触发）

#### 3.2.1 市场选择

- 提供三个市场选项：A股（`'A'`）、港股（`'HK'`）、美股（`'US'`）。
- 默认选中 `'A'`。
- 切换市场时，同时清空：已验证结果 `_verified`、搜索建议 `_suggestions`、错误信息 `_error`、代码输入框 `_symbolCtrl`。

#### 3.2.2 代码输入与搜索联想

- 输入框限制：
  - A股：`FilteringTextInputFormatter.digitsOnly`（仅允许数字）。
  - 港股/美股：无格式限制，自动大写（`TextCapitalization.characters`）。
- 占位文案：
  - A股：`如 600519（上海）或 000001（深圳）`
  - 港股：`如 00700 或 02800`
  - 美股：`如 AAPL 或 SPY`
- 输入框变化时自动触发 `_onSearchChanged`：
  - 空字符串 → 清空建议列表。
  - 非空 → 调用 `StockApiService.searchStock(keyword, market)`：
    - A股/港股：东方财富搜索 API。
    - 美股：Yahoo Finance 搜索 API。
  - 搜索结果以下拉列表展示，每条显示名称（`name`）和代码（`symbol`）。
  - 点击建议项：将 symbol 填入输入框，并自动触发验证。

#### 3.2.3 验证（Verify）

- 点击"验证"按钮或选择建议项时触发 `_verify(symbol)`。
- 调用 `StockApiService.fetchStockInfo(symbol, market)` 获取 `StockHolding` 对象：
  - 美股：Yahoo Finance API。
  - A股/港股：新浪财经 API（symbol 先经过 `_toSinaSymbol` 转换）。
- 成功：渲染验证卡片，显示：股票名称、代码、当前价格（港股保留 3 位小数，其余 2 位）、今日涨跌幅徽章（涨显示红色，跌显示绿色）。
- 失败（`fetchStockInfo` 返回 `null`）：显示错误文案 `'找不到该股票，请确认代码和市场'`。

#### 3.2.4 去重校验

- 提交前在客户端检查 `watchlistProvider` 现有列表，若 `symbol` 已存在则弹出 SnackBar：`'该股票已在自选列表中'`，不继续提交。
- Provider 层亦有二次去重：`addItem` 中检查 `state.any((w) => w.symbol == item.symbol)`，若重复则直接返回。

#### 3.2.5 保存逻辑

- 仅在通过验证（`_verified != null`）且未提交中（`!_isSubmitting`）时，"添加到自选"按钮可点击。
- 构造 `WatchItem`：
  - `id`：`DateTime.now().millisecondsSinceEpoch.toString()`
  - `symbol`：来自 `_verified!.symbol`
  - `name`：来自 `_verified!.stockName`
  - `market`：当前选择的市场
  - `addedPrice`：来自 `_verified!.currentPrice`（验证时的快照价）
  - `addedDate`：`DateTime.now().toIso8601String().substring(0, 10)`（`yyyy-MM-dd`）
  - 预警字段默认 `null`
- 调用 `watchlistProvider.notifier.addItem(item)` 完成持久化和云同步。
- 成功后：导航返回（`context.pop()`），展示 SnackBar：`'已添加 {name} 到自选'`。

---

### 3.3 自选股列表展示

文件：`lib/features/fund_tracker/presentation/pages/fund_tracker_page.dart`（`_WatchlistTab`、`_WatchCard`）

#### 3.3.1 空状态

- 条件：`watchlistProvider` 列表为空。
- 展示：星形图标 + `'还没有自选股票'` + `'点击右下角 + 添加，长按卡片可设置价格提醒'`。

#### 3.3.2 下拉刷新

- 列表支持下拉刷新（`RefreshIndicator`）。
- 触发 `watchlistProvider.notifier.refreshAll()`，逐一刷新所有自选项行情，相邻两次刷新之间固定延迟 300ms。

#### 3.3.3 卡片字段

每张 `_WatchCard` 展示以下内容：

**左侧区域：**
- 股票名称（`name`），最多 1 行，超长省略。
- 市场标签徽章（`market`）：
  - A股：红色背景，文字 `'A股'`
  - 港股：蓝色（`#007AFF`）背景，文字 `'港股'`
  - 美股：绿色（`#34C759`）背景，文字 `'美股'`
- 若已设置任一价格提醒（`alertUp != null || alertDown != null`），显示铃铛图标（`notifications_active`，主色）。
- 股票代码（`symbol`），灰色小字。

**右侧区域（行情数据）：**
- 加载中：小圆形进度指示器。
- 有数据（`currentPrice > 0`）：
  - 当前价格：货币符号 + 价格数值（港股 3 位小数，A股/美股 2 位小数）。
    - A股：`¥`，港股：`HK$`，美股：`$`
  - 今日涨跌幅徽章：`+XX.XX%` 或 `-XX.XX%`，涨红跌绿。
- 无数据且有错误（`errorMsg != null`）：展示错误文案（灰色小字）。

**底部区域（仅当 `currentPrice > 0 && addedPrice > 0` 时展示）：**
- 分隔线。
- 左：`加入价 {currency}{addedPrice}`（保留与价格相同的小数位数）。
- 右：`自添加以来` + `sinceAddedRate` 百分比（涨红跌绿）。

---

### 3.4 价格预警逻辑

文件：`lib/features/watchlist/presentation/providers/watchlist_provider.dart`

#### 3.4.1 设置预警

- 入口：长按自选卡片 → 弹出 `AlertDialog`（`_showAlertDialog`）。
- 对话框包含两个数字输入框：
  - `涨到此价格提醒`（`alertUp`），留空则不设置。
  - `跌到此价格提醒`（`alertDown`），留空则不设置。
- 点击"保存"时调用 `watchlistProvider.notifier.setAlert(id, alertUp: up, alertDown: down)`。
- `setAlert` 逻辑：
  - 更新内存状态：`copyWith(alertUp: alertUp, alertDown: alertDown, clearAlertTriggeredDate: true)`。
  - **修改预警时，同时清除 `alertTriggeredDate`**（重置"今日已触发"标记，确保新阈值立即生效）。
  - 持久化到 Hive + 云端 upsert。
- 保存成功后展示 SnackBar：`'价格提醒已保存'`。

#### 3.4.2 预警触发条件

每次 `_refreshOne` 拉取到新行情后，若 `alertTriggeredDate != today`，调用 `_checkPriceAlert`：

| 条件 | 通知标题 | 通知正文 |
|------|---------|---------|
| `alertUp != null && currentPrice >= alertUp` | `涨价提醒 · {name}` | `当前 {price}，已触达上涨提醒价 {alertUp}` |
| `alertDown != null && currentPrice <= alertDown` | `跌价提醒 · {name}` | `当前 {price}，已触达下跌提醒价 {alertDown}` |

- 优先级：`alertUp` 优先于 `alertDown`（if/else if 顺序）。
- 同一天内每只股票最多触发一次提醒（通过 `alertTriggeredDate == today` 跳过）。
- 触发后：
  1. 更新内存中 `alertTriggeredDate = today`。
  2. 写入 Hive（本地持久化）。
  3. 尝试 upsert 到云端（静默忽略云端失败，用于防止多设备重复推送）。

#### 3.4.3 通知发送方式

- 调用 `NotificationService.instance.showPriceAlert(title, body)`。
- 通知 Channel ID：`'price_alert'`，Channel 名称：`'自选提醒'`。
- Android 重要性级别：`Importance.defaultImportance`。
- 通知 ID 计算规则：`2000 + (title + body).hashCode.abs() % 1000`（范围 2000–2999，相同内容不重复弹出）。
- `NotificationService` 未初始化时（`!_initialized`）静默跳过，不抛出异常。

---

### 3.5 删除逻辑

- 手势：从右向左滑动卡片（`DismissDirection.endToStart`）。
- 滑出后展示红色背景 + 垃圾桶图标 + `'删除'` 文字。
- 触发 `confirmDismiss` 弹出确认对话框：
  - 标题：`'从自选删除'`
  - 内容：`'确定删除 {name}？'`
  - 取消：返回 `false`，卡片回弹，不删除。
  - 确认：返回 `true`，执行删除。
- 确认后：
  1. `watchlistProvider.notifier.removeItem(id)` → 更新内存状态 → 写入 Hive → 云端 DELETE。
  2. 展示 SnackBar：`'已从自选删除 {name}'`。

---

## 4. 边界条件

| 编号 | 场景 | 处理方式 |
|------|------|---------|
| BC-01 | 添加重复 symbol | 客户端提前检查 + Provider 二次防御，均不执行添加，仅 SnackBar 提示 |
| BC-02 | 行情数据 `current` 字段缺失或为 0 | 抛出 `Exception('行情数据无效')`，`errorMsg` 设为 `'行情获取失败'` |
| BC-03 | 行情 API 返回 `null` | 抛出 `Exception('无数据')`，同上 |
| BC-04 | 云端加载失败 | 降级使用本地 Hive 数据，`loadWatchlist()` 返回 `null` 时不更新 state |
| BC-05 | 云端写入失败（upsert/delete） | 所有云端操作包裹在 `try/catch`，静默忽略，不影响本地操作 |
| BC-06 | `addedPrice = 0` | `sinceAddedRate` 返回 `0`，底部累计涨跌区域**不显示** |
| BC-07 | `NotificationService` 未初始化 | 提醒静默跳过，不抛出异常 |
| BC-08 | 同一天已触发预警 | `alertTriggeredDate == today` 时跳过检查，每天至多推送一次 |
| BC-09 | alertUp 和 alertDown 同时满足 | 仅触发 `alertUp`（if/else if，上涨提醒优先） |
| BC-10 | 修改预警阈值 | `alertTriggeredDate` 强制清除，新阈值在下次行情刷新时立即生效 |
| BC-11 | 验证阶段 symbol 为空字符串 | `_verify` 提前返回，不发起网络请求 |
| BC-12 | 刷新全部时逐一串行刷新 | `refreshAll()` 顺序执行，相邻 300ms 延迟，避免并发过高触发 API 限流 |
| BC-13 | A股输入框强制纯数字 | `FilteringTextInputFormatter.digitsOnly` 限制，防止非法代码 |

---

## 5. 与其他模块的联动

### 5.1 在 FundTrackerPage 中的 Tab 位置

- `FundTrackerPage` 使用 5 个 Tab：`基金`（0）/ `A股`（1）/ `港股`（2）/ `美股`（3）/ `自选`（4）。
- 自选 Tab 为**第 5 个 Tab（index = 4）**，由 `_WatchlistTab()` 渲染。
- FAB 按钮根据 `_tab.index` 动态切换行为：
  - index = 0 → 跳转 `/fund-tracker/add`（添加基金）
  - index = 4 → 跳转 `/fund-tracker/add-watch`（添加自选）
  - 其他 → 跳转 `/fund-tracker/add-stock`（添加股票）

### 5.2 自动刷新（与 FundTrackerPage 共享定时器）

- `FundTrackerPage` 启动一个 15 分钟周期的定时器（`Timer.periodic`）。
- 仅在交易时段（`_isInTradingHours()`）触发刷新，避免非交易时间无意义轮询。
- 交易时段判断（北京时间，UTC+8）：
  - A股：工作日 09:30–11:30、13:00–15:00
  - 港股：工作日 09:30–16:00
  - 美股：夏令时约 21:30 起 / 冬令时约 22:30 起（近似 `minutes >= 1290 || minutes < 240`）
- `_refreshAll()` 同时调用 `fundHoldingsProvider`、`stockHoldingsProvider`、`watchlistProvider` 三者的 `refreshAll()`。
- App 进入后台（`AppLifecycleState.paused`）时停止定时器，恢复前台（`resumed`）时重新启动。

### 5.3 StockApiService 共享

- 自选股复用 `stock_tracker` 模块的 `StockApiService`（通过 `stockApiServiceProvider`）：
  - `searchStock(keyword, market)` — 搜索联想
  - `fetchStockInfo(symbol, market)` — 验证并获取完整信息（返回 `StockHolding`）
  - `refreshQuote(symbol, market)` — 拉取实时行情（返回 `Map<String, dynamic>?`）

### 5.4 投资组合总览联动

- `FundTrackerPage` 的"空状态"判断包含 `watchlist.isNotEmpty`：
  ```dart
  final hasAny = funds.isNotEmpty || stocks.isNotEmpty || watchlist.isNotEmpty;
  ```
  即：只要自选列表非空，就不展示整体空状态界面，而是展示持仓总览页面。

### 5.5 PortfolioContextBuilder（AI 对话模块）

- `watchlistProvider` 的数据可被 AI 对话模块的 `PortfolioContextBuilder` 读取，注入进 AI System Prompt，供明理顾问参考用户的关注股票列表。

---

## 6. 验收标准

| AC | 场景 | 预期结果 |
|----|------|---------|
| AC-1 | 用户在"自选"Tab 点击 FAB → 跳转 AddWatchPage → 选择"A股" → 输入 `600519` → 点击"验证" | 显示"贵州茅台"验证卡片，含当前价格和今日涨跌幅 |
| AC-2 | 验证成功后点击"添加到自选" | 返回列表页，SnackBar 显示"已添加 贵州茅台 到自选"；列表中出现该卡片 |
| AC-3 | 再次添加已存在的 `600519` | SnackBar 显示"该股票已在自选列表中"，列表不重复添加 |
| AC-4 | 自选列表展示卡片时，currentPrice > 0 且 addedPrice > 0 | 卡片底部显示"加入价"和"自添加以来"累计涨跌幅 |
| AC-5 | 长按自选卡片 → 设置 alertUp = 1800 → 保存 | SnackBar"价格提醒已保存"；卡片名称旁显示铃铛图标 |
| AC-6 | 行情刷新后 currentPrice >= alertUp | 设备收到推送通知"涨价提醒 · 贵州茅台 · 当前 1800.00，已触达上涨提醒价 1800.00"；当天不再重复推送 |
| AC-7 | 第二天再次刷新行情，价格仍 >= alertUp | 重新触发提醒（alertTriggeredDate 为昨日，today 不同，重新检查） |
| AC-8 | 修改 alertUp 为新值后当天立即刷新行情触达 | alertTriggeredDate 已清除，新阈值立即参与判断，可正常触发 |
| AC-9 | 从右向左滑动卡片 → 点击确认删除 | 卡片消失，SnackBar"已从自选删除 {name}"；Hive 和云端同步删除 |
| AC-10 | 取消删除确认对话框 | 卡片回弹，数据不变 |
| AC-11 | 行情 API 返回异常（无数据或 price <= 0） | 卡片右侧显示"行情获取失败" |
| AC-12 | 应用冷启动时（有历史自选） | 优先加载云端数据；云端失败则降级 Hive；完成后立即执行 refreshAll |
| AC-13 | 下拉刷新"自选"Tab | 触发 watchlistProvider.refreshAll()，行情卡片更新 |
| AC-14 | 非交易时段（如凌晨 3 点，非美股时段） | 15 分钟定时器不触发刷新 |
| AC-15 | 选择"港股"市场 → 输入 `00700` | 验证成功后，价格显示 `HK$`，保留 3 位小数 |

---

## 7. 不做的范围（Out of Scope）

| 项目 | 说明 |
|------|------|
| 自选股排序/分组 | 当前按添加顺序展示，无手动排序或分类功能 |
| 涨跌幅阈值预警 | 仅支持绝对价格预警（alertUp/alertDown），不支持"涨幅超过 X%"的百分比触发预警 |
| 多设备多用户隔离 | 当前以 `device_id` 区分，不支持同一账号多设备合并 |
| 批量添加 | 每次只能添加一只股票 |
| 历史价格走势图 | 自选卡片不展示 K 线或迷你图，仅显示今日涨跌幅和自添加以来涨跌幅 |
| 编辑 addedPrice | 加入价在添加时锁定，不支持后续修改 |
| 自选股与持仓联动操作 | 自选股不能直接转为持仓记录，需在对应持仓 Tab 单独添加 |
| 推送通知历史记录 | 不维护已发送提醒的日志或历史列表 |
| 指数/ETF 专属展示 | 与普通股票共用同一卡片结构，无差异化展示 |
| 基金加入自选 | 当前自选仅支持股票（A/港/美），不支持基金代码 |
