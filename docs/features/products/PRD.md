# PRD — 产品库（Products）

> 版本：v1.0
> 日期：2026-03-23
> 状态：已实现（代码 1:1 翻译）
> 覆盖文件：
> - `lib/features/products/presentation/pages/products_page.dart`
> - `lib/features/products/presentation/pages/product_detail_page.dart`
> - `lib/data/models/product_model.dart`
> - `lib/data/datasources/products_data.dart`
> - `lib/data/datasources/platforms_data.dart`
> - `lib/core/providers/market_rate_provider.dart`
> - `lib/core/services/market_rate_service.dart`

---

## 1. 问题陈述

目标用户持有 50 万–1000 万人民币，面对国内外数十种理财品类（货基、定存、ETF、保险、信托、港险、加密等），却缺乏系统性的横向比较工具。他们不知道哪类产品适合自己的风险偏好，不知道在哪里买、怎么买。

本功能提供一个**结构化、可筛选的理财产品导航库**，覆盖大陆 / 香港 / 加密三大市场，帮助用户：

1. 快速了解各类产品的收益率区间、风险等级和流动性；
2. 通过地区 Tab + 风险筛选 + 关键词搜索，精准定位目标产品；
3. 在产品详情页获取操作截图引导，并一键跳转到对应平台 App 完成购买。

**本功能定位为导航而非交易**，App 本身不接触用户资金。

---

## 2. 目标用户与用户故事

### 目标用户

- 中国大陆居民，持有 50 万–1000 万人民币流动资产；
- 对金融产品有基本认知但缺乏系统比较视角；
- 部分用户已持有香港账户或了解加密资产。

### 用户故事

**US-01 浏览与筛选**
作为一名保守型投资者，我想快速看到所有风险等级为"极低"（R1）的产品，以便选择适合我的低风险品类。

**US-02 产品详情了解**
作为一名有意购买增额终身寿险的用户，我想查看该产品的收益率对比、注意事项和适合人群，以便做出知情决策，同时不被不专业的销售误导。

**US-03 跳转购买**
作为已决定购买沪深300 ETF 的用户，我想在 App 内直接跳转到东方财富 / 同花顺进行购买，无需手动查找入口。

---

## 3. 功能需求

### 3.1 数据模型

#### 3.1.1 ProductModel

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `id` | `String` | 是 | 唯一标识，与 LiveRateData 的 key 对应 |
| `name` | `String` | 是 | 产品全名，如"货币基金"、"QDII基金（境外投资）" |
| `shortName` | `String` | 是 | 简称，用于搜索匹配，如"货基"、"ETF" |
| `region` | `String` | 是 | 地区：`mainland` / `hongkong` / `crypto` |
| `category` | `String` | 是 | 产品类别（见 3.2 节） |
| `riskLevel` | `int` | 是 | 风险等级：1–5（整数） |
| `riskDescription` | `String` | 是 | 具体风险说明文字 |
| `returnRates` | `List<ReturnRate>` | 是 | 按期限分级的收益率列表（至少一条） |
| `minInvestment` | `double?` | 否 | 最低投资门槛（元），null 表示无门槛说明 |
| `liquidity` | `String` | 是 | 流动性文字描述 |
| `description` | `String` | 是 | 产品介绍正文 |
| `suitableFor` | `List<String>` | 是 | 适合人群标签数组 |
| `watchOut` | `List<String>` | 是 | 注意事项条目数组 |
| `platformIds` | `List<String>` | 是 | 可购买平台 ID 列表，与 PlatformModel.id 对应 |
| `screenshots` | `List<PlatformScreenshot>` | 否 | 平台操作截图，默认空列表 |

#### 3.1.2 ReturnRate

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `period` | `String` | 是 | 期限描述，如"3个月"、"持有到期（票面利率）" |
| `rate` | `String` | 是 | 收益率字符串，如"1.35%"、"5-8%"、"历史年化8%" |
| `isGuaranteed` | `bool` | 否 | 是否保证收益，默认 `false`；`true` 显示绿色"保证"徽标，`false` 显示橙色"参考"徽标 |

#### 3.1.3 PlatformScreenshot

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `platformId` | `String` | 是 | 所属平台 ID |
| `step` | `String` | 是 | 步骤标识，枚举值：`"入口"` / `"详情页"` / `"购买页"` / `"确认页"` |
| `imageAsset` | `String` | 是 | assets 资源路径，如 `assets/screenshots/alipay_money_fund_1.png` |
| `caption` | `String` | 是 | 截图说明文字（最多显示 2 行） |

**步骤 → 展示标签映射：**

| step 值 | 展示标签 |
|---------|---------|
| `"入口"` | `"① 入口"` |
| `"详情页"` | `"② 详情页"` |
| `"购买页"` | `"③ 购买页"` |
| `"确认页"` | `"④ 确认页"` |
| 其他值 | 原值（不转换） |

#### 3.1.4 PlatformModel

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `id` | `String` | 是 | 平台唯一标识 |
| `name` | `String` | 是 | 平台名称 |
| `logoAsset` | `String` | 是 | Logo 图片资源路径 |
| `description` | `String` | 是 | 平台简介 |
| `deepLinkUrl` | `String?` | 否 | 跳转到平台 App 的 Deep Link URL |
| `webUrl` | `String?` | 否 | 平台网页版 URL |
| `appStoreUrl` | `String` | 是 | App Store 下载链接 |
| `playStoreUrl` | `String` | 是 | Google Play 下载链接 |

**跳转优先级**：`deepLinkUrl` 优先，无 deepLink 时使用 `webUrl`，使用 `url_launcher` 以 `LaunchMode.externalApplication` 模式打开。

#### 3.1.5 LiveRateData（实时行情）

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `displayRate` | `String` | 是 | 展示文字，如 `"7日年化 1.7700%"` / `"沪深300 ¥4.123 (+0.31%)"` |
| `changeRate` | `double?` | 否 | 涨跌幅百分比（可空） |
| `updatedAt` | `DateTime` | 是 | 数据更新时间 |
| `isUp` | `bool` | 否 | 涨跌方向，默认 `true`；`true` 显示绿色，`false` 显示红色 |

---

### 3.2 产品目录（完整列表）

共 **17 个产品**，按地区和类别组织：

#### 大陆（mainland）— 12 个产品

| id | name | shortName | category | riskLevel | minInvestment |
|----|------|-----------|----------|-----------|----------------|
| `cn_money_fund` | 货币基金 | 货基 | 现金管理 | 1 | 1元 |
| `cn_fixed_deposit` | 定期存款 | 定存 | 固定收益 | 1 | 50元 |
| `cn_large_cd` | 大额存单 | 大额存单 | 固定收益 | 1 | 200,000元 |
| `cn_treasury_bond` | 国债 | 国债 | 固定收益 | 1 | 100元 |
| `cn_bank_wealth` | 银行理财产品 | 银行理财 | 固定收益 | 2 | 10,000元 |
| `cn_bond_fund` | 债券基金 | 债基 | 固定收益 | 2 | 1元 |
| `cn_convertible_bond` | 可转债 | 可转债 | 固定收益 | 3 | 1,000元 |
| `cn_trust` | 信托产品 | 信托 | 固定收益 | 3 | 1,000,000元 |
| `cn_a_share` | A股（沪深主板） | A股 | 权益类 | 4 | 100元 |
| `cn_etf` | 指数ETF | ETF | 权益类 | 3 | 100元 |
| `cn_public_fund` | 公募基金（主动型） | 主动基金 | 权益类 | 3 | 1元 |
| `cn_private_fund` | 私募基金 | 私募 | 权益类 | 4 | 1,000,000元 |
| `cn_reits` | 公募REITs | REITs | 权益类 | 3 | 100元 |
| `cn_life_insurance` | 增额终身寿险 | 增额寿 | 保险理财 | 1 | 10,000元 |
| `cn_annuity` | 年金保险 | 年金险 | 保险理财 | 1 | 10,000元 |
| `cn_paper_gold` | 纸黄金/黄金ETF | 黄金 | 黄金 | 3 | 10元 |
| `cn_qdii` | QDII基金（境外投资） | QDII | QDII | 3 | 1元 |

#### 香港（hongkong）— 4 个产品

| id | name | shortName | category | riskLevel | minInvestment |
|----|------|-----------|----------|-----------|----------------|
| `hk_stock_connect` | 港股通（H股/蓝筹） | 港股通 | 港股 | 4 | 100元 |
| `hk_deposit` | 香港银行定期存款 | 港元定存 | 现金管理 | 1 | 5,000元 |
| `hk_savings_insurance` | 香港储蓄分红保险 | 港险 | 保险理财 | 2 | 10,000元 |
| `hk_overseas_etf` | 海外ETF（美股指数） | 海外ETF | 权益类 | 3 | 100元 |

#### 加密（crypto）— 2 个产品

| id | name | shortName | category | riskLevel | minInvestment |
|----|------|-----------|----------|-----------|----------------|
| `crypto_btc_etf` | 比特币ETF（香港） | BTC ETF | 加密货币 | 5 | 100元 |
| `crypto_hashkey` | 加密货币（HashKey合规交易所） | 合规加密 | 加密货币 | 5 | 100元 |

**注：** 代码中大陆区共 17 个产品（含保险 2、黄金 1、QDII 1），合计全库 23 个产品。

**风险等级标签映射：**

| riskLevel | 列表筛选 Chip | 详情页标签 |
|-----------|-------------|-----------|
| 1 | R1 极低 | 极低风险 |
| 2 | R2 低 | 低风险 |
| 3 | R3 中 | 中等风险 |
| 4 | R4 高 | 高风险 |
| 5 | R5 极高 | 极高风险 |

---

### 3.3 实时行情（Market Rate）

**4 个产品接入实时行情**，其余产品展示静态"参考收益"：

| productId | 行情内容 | 数据源 | API |
|-----------|---------|--------|-----|
| `cn_money_fund` | 7日年化利率（余额宝 000198） | 东方财富 | `https://api.fund.eastmoney.com/f10/lsjz` |
| `cn_etf` | 沪深300 ETF 价格与涨跌（sz510300） | 东方财富 push2 | `https://push2.eastmoney.com/api/qt/stock/get` |
| `cn_paper_gold` | 华安黄金ETF 价格与涨跌（sh518880） | 东方财富 push2 | `https://push2.eastmoney.com/api/qt/stock/get` |
| `hk_overseas_etf` | VOO 价格与涨跌（标普500 ETF） | Yahoo Finance | `https://query1.finance.yahoo.com/v8/finance/chart/VOO` |

**行情计算逻辑：**

- **货币基金7日年化**：取最近 7 个交易日万份收益（`DWJZ`），计算公式：`avg(DWJZ) / 10000 * 365 * 100`；请求窗口为前 14 天、pageSize=7。
- **A股/港股ETF**：取东方财富 `f43`（现价）和 `f60`（前收），按新浪格式（sh/sz/hk）转换为 secid（sh→`1.xxx`，sz→`0.xxx`，hk→`116.xxx`），scale：A股=100，港股=1000；涨跌幅 = `(current - prevClose) / prevClose * 100`。
- **美股ETF（Yahoo Finance）**：取 `meta.regularMarketPrice` 和 `meta.regularMarketChangePercent`。
- **Provider**：`marketRatesProvider`（`AsyncNotifierProvider<MarketRatesNotifier, Map<String, LiveRateData>>`），key = productId；支持手动 `refresh()`；所有请求并发发起，单个失败不影响其他。

**展示规则（产品列表卡片中）：**

- 若 `marketRatesProvider` 中该产品有 `LiveRateData`：显示绿色"实时"徽标 + `displayRate`，颜色根据 `isUp` 显示绿（AppColors.success）或红（AppColors.error）。
- 否则：显示"参考收益" + `returnRates.first.rate`（绿色）；若 `returnRates.length > 1`，追加灰色 `+N种期限` 提示。

---

### 3.4 页面结构与导航逻辑

#### 3.4.1 ProductsPage（产品列表页）

路由：`/products`，作为 Shell 路由的第二 Tab（底部导航栏）。

**页面层级结构（从上到下）：**

1. **AppBar**：标题"产品库"；底部嵌 `TabBar`（4 个 Tab）。
2. **TabBar（地区筛选）**：
   - `全部`（key: `all`）
   - `🇨🇳 大陆`（key: `mainland`）
   - `🇭🇰 香港`（key: `hongkong`）
   - `₿ 加密`（key: `crypto`）
   - 切换 Tab 时重置风险筛选为"全部"（`_selectedRisk = null`）。
3. **搜索框**：hint"搜索产品名称或类别…"，前缀搜索图标，有输入时显示清除按钮；实时过滤（`onChanged`）。
4. **风险筛选条（横向滚动 Chip 列表，高度 44）**：
   - "全部"（始终显示，点击重置）
   - R1 极低 / R2 低 / R3 中 / R4 高 / R5 极高（5 个 Chip）
   - 点击已选中的 Chip 再次点击取消选中（toggle 逻辑）。
   - Chip 选中时：背景色 = 对应风险色，文字白色，粗体；未选中：白背景，灰边框，灰文字。
   - 动画：`AnimatedContainer`，时长 180ms。
5. **产品数量提示**：`共 N 种产品`（灰色小字）。
6. **产品卡片列表**（`ListView.builder`，padding: 16,0,16,16，卡片间距 12）。

**过滤逻辑（三重叠加，顺序执行）：**

1. 地区过滤：`ProductsData.all`（all tab）或 `ProductsData.byRegion(region)`；
2. 风险过滤：`_selectedRisk != null` 时按 `riskLevel` 精确匹配；
3. 关键词过滤：对 `product.name`、`product.shortName`、`product.category` 三个字段做 `toLowerCase().contains(query)` 匹配。

**产品卡片（_ProductCard）内容：**

- 行1：产品全名（粗体） + 地区标签（背景色带透明度）
- 行2：风险等级条（5格横条，`_RiskIndicator`）+ 文字标签
- 行3（条件）：实时行情或参考收益区域（`AppColors.surfaceVariant` 背景色块）
- 行4：起投金额（格式化）+ 产品类别 + 右箭头图标

**最低投资金额格式化规则（`_formatAmount`）：**

| 范围 | 格式 | 示例 |
|------|------|------|
| ≥ 10,000,000 | `N千万` | `1千万` |
| ≥ 1,000,000 | `N万` | `100万` |
| ≥ 10,000 | `N万` | `20万` |
| < 10,000 | `N元` | `100元` |

**空状态**：搜索/筛选无结果时，居中显示 `Icons.search_off`（48pt，灰色）+ "没有找到匹配的产品"。

**点击跳转**：`context.go('/products/${product.id}')`。

#### 3.4.2 ProductDetailPage（产品详情页）

路由：`/products/:id`，`id` 为 `ProductModel.id`，通过 `ProductsData.findById(productId)` 查找。

**找不到产品时**：返回带 AppBar（标题"产品详情"）的空白页，body 居中显示"产品不存在"。

**找到产品时**，页面为带 AppBar（标题为 `product.name`）的单列滚动视图，内容区域 padding=16，各卡片间距 16：

| 序号 | 卡片标题 | 组件 | 内容 |
|------|---------|------|------|
| 1 | 无（渐变头图卡） | `_buildIntroCard` | 产品名、类别、描述；渐变背景（primary 0.9 → primaryLight） |
| 2 | 📈 收益率详情 | `_buildReturnRates` | `returnRates` 列表，每条：彩色圆点 + 期限 + 收益率 + 保证/参考徽标 |
| 3 | ⚠️ 风险详解 | `_buildRiskDetail` | 风险等级 5 格色条 + 等级标签 + `riskDescription` 文字 |
| 4 | 💧 流动性 | `_buildLiquidity` | `liquidity` 文字 |
| 5 | 📱 平台操作预览 | `_buildPlatformScreenshots` | 仅当 `screenshots` 非空时显示；横向滚动，截图尺寸 90×195（9:19.5 竖屏比例），步骤 pill 标签 + 截图 + 说明文字 |
| 6 | 👤 适合人群 | `_buildSuitableFor` | `suitableFor` 标签数组，Wrap 排列 |
| 7 | 🚨 注意事项 | `_buildWatchOut` | `watchOut` 数组，带序号圆圈（橙色背景） |
| 8 | 🔗 去哪里买 | `_buildPlatforms` | `PlatformModel` 列表（通过 `platformIds` 查找）；每条：Logo + 名称/描述 + "去购买"按钮 |

**截图区域尺寸常量：**

- imgWidth: 90，imgHeight: 195，listHeight: 261
- 图片加载失败时显示 `Icons.smartphone_outlined` 占位符 + step 文字

**"去购买"按钮逻辑：**

- 优先使用 `platform.deepLinkUrl`，无则使用 `platform.webUrl`；
- `url_launcher.canLaunchUrl()` 检查可用性；
- `launchUrl(uri, mode: LaunchMode.externalApplication)` 外部应用模式打开。

**_SectionCard** 通用卡片样式：白色背景（`AppColors.surface`），圆角 16，border `AppColors.border`，内边距 16，title 字号 15/粗体，title 与 child 间距 12。

---

### 3.5 导航平台目录（完整列表）

共 **30 个平台**：

#### 大陆平台（21 个）

| id | name | deepLinkUrl | webUrl |
|----|------|-------------|--------|
| `alipay` | 支付宝 | `alipays://platformapi/startapp?appId=20000003` | https://www.alipay.com |
| `wechat` | 微信零钱通 | `weixin://` | https://weixin.qq.com |
| `tiantian` | 天天基金 | `amkt://` | https://fund.eastmoney.com |
| `eastmoney` | 东方财富 | `eastmoney://` | https://www.eastmoney.com |
| `tonghuashun` | 同花顺 | `ths://` | https://www.10jqka.com.cn |
| `cmb` | 招商银行 | `cmbmobilebank://` | https://www.cmbchina.com |
| `icbc` | 工商银行 | `icbc://` | https://www.icbc.com.cn |
| `pingan` | 平安保险 | `pingan://` | https://www.pingan.com |
| `futu` | 富途牛牛 | `futu://` | https://www.futunn.com |
| `ccb` | 建设银行 | `ccbmobile://` | https://www.ccb.com |
| `boc` | 中国银行 | `bocmobilebank://` | https://www.boc.cn |
| `abc` | 农业银行 | `abcmobile://` | https://www.abchina.com |
| `huatai` | 华泰证券 | `htsc://` | https://www.htsc.com.cn |
| `citic_sec` | 中信证券 | `citics://` | https://www.citics.com |
| `cmb_private` | 招行私行/招银理财 | `cmbmobilebank://` | https://www.cmbchina.com/privatebank/ |
| `yingmi` | 盈米基金 | `yingmi://` | https://www.yingmi.cn |
| `citic_trust` | 中信信托 | null（无 deepLink） | https://www.citic-trust.com |
| `ping_an_trust` | 平安信托 | null（无 deepLink） | https://trust.pingan.com |
| `cpic` | 太平洋保险 | null（无 deepLink） | https://www.cpic.com.cn |
| `china_life` | 中国人寿 | null（无 deepLink） | https://www.e-chinalife.com |
| `alipay_insurance` | 支付宝保险 | `alipays://platformapi/startapp?appId=2021002161608880` | https://www.alipay.com |

#### 香港平台（9 个）

| id | name | deepLinkUrl | webUrl |
|----|------|-------------|--------|
| `hsbc_hk` | 汇丰香港 | null | https://www.hsbc.com.hk |
| `aia` | 友邦保险（AIA） | null | https://www.aia.com.hk |
| `ibkr` | 盈透证券（IBKR） | `ibkr://` | https://www.interactivebrokers.com.hk |
| `hang_seng` | 恒生银行 | null | https://www.hangseng.com |
| `bochk` | 中银香港 | null | https://www.bochk.com |
| `sc_hk` | 渣打香港 | null | https://www.sc.com/hk |
| `futu_hk` | 富途（香港版） | `futu://` | https://www.futunn.com/hk |
| `manulife` | 宏利保险 | null | https://www.manulife.com.hk |
| `prudential` | 保诚保险 | null | https://www.prudential.com.hk |

#### 加密货币平台（2 个）

| id | name | deepLinkUrl | webUrl |
|----|------|-------------|--------|
| `hashkey` | HashKey Exchange | null | https://www.hashkey.com |
| `osl` | OSL Exchange | null | https://osl.com |

---

## 4. 边界条件

### 4.1 空状态

| 场景 | 展示行为 |
|------|---------|
| 搜索 + 筛选无结果 | 居中显示 `Icons.search_off`（48，灰色）+ "没有找到匹配的产品" |
| `productId` 不存在 | ProductDetailPage 显示 AppBar("产品详情") + 正文"产品不存在" |
| `platformIds` 为空或所有 id 不存在 | `_buildPlatforms` 返回 `SizedBox()`（不显示该 section） |
| `screenshots` 为空列表 | 不渲染"📱 平台操作预览"卡片（条件渲染） |

### 4.2 网络失败 / 加载状态

| 场景 | 展示行为 |
|------|---------|
| `marketRatesProvider` 加载中（AsyncLoading） | `ref.watch(...).valueOrNull` 返回 null，产品卡片展示静态"参考收益"，不显示实时行情区域 |
| 单个行情接口失败（catch）| 对应 productId 不写入 result map，该产品卡片显示参考收益，其他产品不受影响 |
| 所有行情接口失败 | 所有产品均显示静态参考收益，无 loading 态占位 |
| 截图 asset 加载失败 | `errorBuilder` 显示 `Icons.smartphone_outlined`（28，灰色）+ step 文字 |
| 平台 Logo 加载失败 | `errorBuilder` 显示 `Icons.open_in_new`（22，primary 色） |
| `canLaunchUrl` 返回 false / URL 为 null | 点击"去购买"按钮无响应（静默处理） |

### 4.3 格式规则

- `marketRatesProvider` 中货基年化展示格式：`"7日年化 X.XXXXˈ%"`（4 位小数）
- 沪深300展示格式：`"沪深300 ¥X.XXX (+X.XX%)"`（价格 3 位小数，涨跌幅 2 位小数）
- 黄金ETF展示格式：`"黄金ETF ¥X.XXX (+X.XX%)"`
- VOO展示格式：`"VOO $X.XX (+X.XX%)"`（价格 2 位小数）
- 涨跌幅正数时显示"+"前缀，负数自然负号

---

## 5. 与其他模块的联动

| 模块 | 联动方式 | 说明 |
|------|---------|------|
| AI 导航（AiChatPage） | 无直接代码联动，逻辑上互补 | AI 根据用户需求推荐产品类型后，用户可进入产品库对照筛选 |
| 基金/股票追踪（FundTrackerPage） | 无直接跳转 | 产品库是"了解"，追踪页是"记录"，目前两者独立 |
| `marketRatesProvider` | 共享 | 产品列表卡片通过 `ref.watch(marketRatesProvider)` 读取实时行情；Provider 为全局单例，首次构建时自动 fetch，可手动调用 `refresh()` |
| `ProductsData` / `PlatformsData` | 静态数据源 | 产品库和详情页均依赖这两个 class 的静态数据，无网络请求（行情除外） |
| 路由（GoRouter） | `/products` 为 Shell 路由子路由 | 产品库置于底部导航栏，详情页 `/products/:id` 为其子路由，保留底部导航栏 |

---

## 6. 验收标准

**AC-1 地区 Tab 筛选**
切换"大陆"Tab 后，列表仅显示 `region == 'mainland'` 的产品，且风险筛选自动重置为"全部"。

**AC-2 风险筛选 Chip**
选中"R1 极低"后，只显示 riskLevel=1 的产品；再次点击同一 Chip，恢复显示当前地区全部产品。

**AC-3 关键词搜索**
输入"ETF"，应匹配 name/shortName/category 含"ETF"的所有产品（含"指数ETF"、"黄金ETF"等）；清除输入后恢复完整列表。

**AC-4 空状态**
在大陆 Tab 下搜索一个不存在的字符串，显示搜索空态图标和"没有找到匹配的产品"。

**AC-5 实时行情展示**
网络正常时，`cn_money_fund`、`cn_etf`、`cn_paper_gold`、`hk_overseas_etf` 的卡片显示绿色"实时"徽标和 displayRate；其他产品显示"参考收益"。

**AC-6 产品详情完整性**
点击任意产品，详情页依次显示：渐变头图卡、收益率详情、风险详解、流动性、适合人群、注意事项、去哪里买（共 7 节，截图区仅在有截图数据时出现）。

**AC-7 收益率徽标颜色**
`isGuaranteed=true` 的 ReturnRate 行显示绿色圆点和"保证"绿色徽标；`isGuaranteed=false` 显示橙色圆点和"参考"橙色徽标。

**AC-8 风险等级 5 格色条**
详情页风险色条：前 `riskLevel` 格填充对应色，后 `5-riskLevel` 格填充对应色的 0.2 透明度。

**AC-9 平台跳转**
"去购买"按钮：优先调用 deepLinkUrl 打开对应 App；若 deepLinkUrl 为 null 则使用 webUrl 在外部浏览器打开；URL 和 deepLink 均为 null 时按钮无响应。

**AC-10 截图区横向滚动**
有截图数据的产品（如货币基金、定期存款、债券基金）详情页中，"平台操作预览"卡片可横向滑动查看各步骤截图（① 入口 → ② 详情页 → ③ 购买页）；图片资源缺失时显示手机图标占位。

**AC-11 最低投资金额格式**
`minInvestment=200000` 显示为"起投 20万"；`minInvestment=1000000` 显示为"起投 100万"；`minInvestment=null` 不显示该区域。

**AC-12 无效产品路由**
访问 `/products/nonexistent_id` 时，ProductDetailPage 显示"产品不存在"，不 crash。

---

## 7. 不做的范围（Out of Scope）

以下内容当前版本明确不实现：

1. **产品购买**：App 不处理任何资金或订单，只做跳转导航。
2. **产品比较**：当前无多选对比功能。
3. **产品搜索排序**：过滤后的列表顺序固定（`ProductsData.all` 定义顺序），无排序控件。
4. **收藏/自选产品**：无收藏功能，无用户侧产品列表管理。
5. **实时行情 auto-refresh**：Provider 仅初始化时 fetch 一次，不自动轮询；手动 `refresh()` 未从 UI 层暴露（无下拉刷新按钮）。
6. **价格历史图表**：详情页无 K 线或历史收益曲线。
7. **AI 推荐排序**：产品库与 AI 模块无自动联动，不根据用户画像动态排序产品。
8. **用户评价/评论**：无 UGC 内容。
9. **产品代码推荐**：定位为"类型导航"，不推荐具体基金/股票代码。
10. **港股和加密实时行情**：`hk_stock_connect`、`crypto_btc_etf`、`crypto_hashkey` 无实时行情接入，仅显示静态参考收益。
