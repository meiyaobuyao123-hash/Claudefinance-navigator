# 理财导航 — Claude 项目记忆

> 此文件由 Claude 自动读取，每次新会话无需任何操作即可加载项目背景。
> 每完成一个任务，Claude 会自动更新此文件并 commit。

---

## 产品定位

Flutter 理财导航 App，目标用户：中国大陆持有 **50万–1000万人民币**的人群。
核心价值：AI 摸清需求 → 匹配产品类型 → 跳转主流平台自主购买。
**不接触资金，不推荐具体代码，合规导航工具。**

---

## 技术栈

- Flutter 3.41.2 + Dart 3.7.2（iOS + Android 双端）
- 状态管理：flutter_riverpod
- HTTP：Dio
- AI 模型：`claude-sonnet-4-6`（Anthropic Claude API）
- 云端数据库：Supabase（PostgreSQL）`https://aboehixfsfclfgblupwu.supabase.co`
- 本地路径：`/Users/wenruiwei/Desktop/testclaude/finance_navigator`
- GitHub：`https://github.com/meiyaobuyao123-hash/Claudefinance-navigator.git`
- 当前分支：`dev`

---

## 运行命令

```bash
cd /Users/wenruiwei/Desktop/testclaude/finance_navigator
flutter run
# 热重启按大写 R，热加载按小写 r
```

---

## ⚡ 当前状态（每次任务后更新）

**最后更新**：2026-03-01（三大留存功能上线：每日通知 + 30日走势图 + 止盈止损预警）

**已完成的功能**：
- ✅ Flutter 项目脚手架（4 Tab 底部导航，微信设计原则）
- ✅ 主题色、字体、AppBar 等基础 UI（Apple HIG 风格）
- ✅ Claude API 接入（claude-sonnet-4-6）
- ✅ AI 对话页面：多轮对话、气泡 UI、打字动画、快捷回复（全屏，无底部导航）
- ✅ AI 角色"明理"：20年私人理财顾问人设，详细系统提示词
- ✅ API Key 安全配置（`lib/core/config/api_keys.dart`，已 gitignore）
- ✅ Git Flow：main（稳定）+ dev（开发）分支
- ✅ 资产配置评估器：5大属性主框架 + 可选子维度细分 + 评分 + 风险提示 + 优化建议
  - L1（始终）：流动/稳健/增值/另类/高弹性 → 宏观配置健康度
  - L2（可选）：稳健→存款/国债/债基；增值→A股/港股/美股；另类→黄金/港险/REITs；高弹性→可转债/BTC+ETH/其他加密
  - 子维度懒初始化（首次展开按父类值等比分配），子类合计须等于父类%
  - L1+L2评估结果分区展示，L2提示标注"基于你的细分数据"
  - 个性化评估标准：_UserProfile（年龄/家庭负担/收入稳定性/资产规模）→ 动态阈值
  - 「个人情况」改为 48px 紧凑条（_buildProfileStrip），点击展开 ModalBottomSheet (_ProfileSheet)
  - 评分结果显示画像标签（稳健保守/均衡平衡/积极进取）+ 当前风险得分
- ✅ 基金组合监控：输入基金代码 + 持仓份额 + 成本净值 → 实时收益监控
  - 天天基金免费 API（无需 token，移动端无 CORS）
  - API 两阶段降级：JSONP 估值接口优先 → 失败时降级历史净值接口 + 搜索接口（兼容货币基金等无估值基金）
  - 本地持久化（Hive）+ 云端同步（Supabase）双写，云端优先加载
  - SupabaseService：设备 UUID（FlutterSecureStorage）隔离数据，CRUD 封装
  - 今日盈亏 / 累计收益 / 持仓市值实时计算（含 gztime 日期校验防止非交易日误显示）
  - 滑动删除 + 下拉刷新 + 300ms 间隔限流
  - 端到端验证通过：App 添加基金 → Supabase fund_holdings 表可见
  - **加仓/减持闭环**：点击卡片 → 操作菜单（加仓/减持/删除）
    - 减持：实时显示卖出金额/已实现盈亏/剩余份额，减持至0份自动清仓
    - 加仓：输入份额+净值，实时计算摊薄后均价，双写持久化
  - **三大留存功能（并行实现）**：
    - 📳 每日收益推送通知：`NotificationService`（flutter_local_notifications），每次刷新后推送今日盈亏+累计收益
    - 📈 30日持仓走势图：Supabase `portfolio_snapshots` 表每日upsert一条快照，`PortfolioChart` sparkline组件展示
    - 🔔 止盈止损预警：`AlertSettingsPage`（AppBar钟形按钮入口），SharedPreferences存储阈值，同一天内最多触发一次
- ✅ 产品导航页（导航 Tab）：15+ 产品，大陆/香港/加密分区，搜索 + R1-R5风险筛选，详情页 + 去购买跳转

**各 Tab 状态**：
| Tab | 功能 | 状态 |
|-----|------|------|
| 📊 规划 | 资产配置评估器（3维度）+ 问明理入口 | 🟢 可用 |
| 🗺️ 导航 | 大陆/香港/加密产品卡片列表 + 详情页 + 去购买 | 🟢 可用 |
| 🔧 工具 | 复利/目标/通胀/对比计算器 + 基金组合监控 | 🟢 可用 |
| 👤 我的 | 邮箱注册/登录/退出 + 用户信息展示 | 🟢 Supabase Auth 已接入 |

**⚠️ 待处理问题**：
- 旧 Claude API Key 已在聊天暴露，需去 console.anthropic.com 吊销并换新 Key
- AI 回复无 Markdown 渲染（加粗/列表显示为原始符号）
- Android 工具链未配置（只能 iOS Simulator 运行）

**记忆机制说明**：
- CLAUDE.md 已 commit 进 git 仓库，任何 Claude Code 实例打开项目目录即自动加载
- 换账户 / 新窗口 / 换电脑 clone 仓库后，无需额外说明，自动恢复完整上下文
- Auto Memory（`~/.claude/`）绑定本地账户，换账户后失效，以 CLAUDE.md 为准

**⚠️ Supabase 建表 SQL（需手动在 Supabase SQL Editor 执行一次）**：
```sql
CREATE TABLE portfolio_snapshots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id text NOT NULL,
  total_value decimal(15,4) NOT NULL,
  total_cost decimal(15,4) NOT NULL,
  recorded_date date NOT NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE(device_id, recorded_date)
);
```

**下一步推荐任务**（按优先级）：
1. 给 AI 回复加 Markdown 渲染（`flutter_markdown` 包）
2. 将 _UserProfile 本地持久化（SharedPreferences）避免每次重新设置
3. 基金调仓记录流水（每次加减仓写入 trade_log 表）
4. 在 Supabase SQL Editor 执行上方建表 SQL，激活走势图功能

---

## 关键文件索引

| 文件 | 说明 |
|------|------|
| `lib/app.dart` | 主题、路由、底部导航配置 |
| `lib/core/theme/app_theme.dart` | 颜色/字体 |
| `lib/core/constants/app_constants.dart` | API URL、常量 |
| `lib/core/config/api_keys.dart` | ⚠️ Claude Key（gitignored，本地才有） |
| `lib/core/router/app_router.dart` | 路由配置（ShellRoute + 全屏页面） |
| `lib/features/ai_chat/presentation/pages/ai_chat_page.dart` | AI 对话核心文件（全屏，无底部导航） |
| `lib/features/planning/presentation/pages/planning_page.dart` | 资产配置评估器（规划 Tab 主页） |
| `lib/features/tools/presentation/pages/tools_page.dart` | 工具 Tab（含基金组合监控入口 Banner） |
| `lib/features/fund_tracker/data/models/fund_holding.dart` | 基金持仓数据模型 |
| `lib/features/fund_tracker/data/services/fund_api_service.dart` | 天天基金 API 封装（实时估值/历史净值/搜索） |
| `lib/features/fund_tracker/presentation/providers/fund_tracker_provider.dart` | Riverpod StateNotifier + Hive 持久化 |
| `lib/features/fund_tracker/presentation/pages/fund_tracker_page.dart` | 基金组合主页（汇总卡片 + 30日走势图 + 持仓列表） |
| `lib/features/fund_tracker/presentation/pages/add_fund_page.dart` | 添加基金页（代码验证 + 份额输入） |
| `lib/features/fund_tracker/presentation/pages/alert_settings_page.dart` | 止盈止损预警设置页 + AlertSettingsNotifier |
| `lib/features/fund_tracker/presentation/widgets/portfolio_chart.dart` | 30日持仓走势 Sparkline（fl_chart） |
| `lib/core/services/notification_service.dart` | 本地推送通知单例（daily P&L + alert） |
| `pubspec.yaml` | 依赖管理 |
| `ios/Podfile` | iOS 依赖（platform :ios, '13.0' 已启用） |

---

## 重要决策（已定，无需重新讨论）

| 决策 | 结论 |
|------|------|
| 前端框架 | Flutter（非 RN，非原生） |
| AI 模型 | claude-sonnet-4-6（旧模型已废弃） |
| 状态管理 | flutter_riverpod（无代码生成版，无 build_runner） |
| MVP 后端 | 暂无，纯本地 |
| API Key 存储 | gitignore 的独立 dart 文件 |
| AI 人设 | "明理"，资深私人理财顾问 |
| Git 分支 | main + dev + feature/xxx |
| 内容范围 | 大陆 + 香港 + 加密（香港合规渠道） |
| Tab 数量 | 4个（微信原则：规划/导航/工具/我的） |
| IA 原则 | 微信式简洁（功能藏在场景里，底部只放最高频场景） |
| UI 原则 | Apple HIG + 科技简约（克制用色、卡片轻阴影、呼吸感间距） |
| AI对话入口 | 从规划Tab进入，全屏体验，无底部导航 |

---

## 用户画像（来源：Manus PRD 分析）

### 画像一：张建国 — 稳健保守的退休规划者
| 维度 | 内容 |
|------|------|
| 年龄/职业 | 58岁，退休国企干部 |
| 资产规模 | ~300万，主为银行存款+少量国债 |
| 核心诉求 | 本金安全 > 跑赢通胀 > 稳定利息收入 |
| 痛点 | 信息焦虑、技术障碍、不信任销售、需求模糊 |
| **对 AI 明理的要求** | 语言通俗、问题实在、结论简单有理据、操作截图引导 |
| 典型路径 | AI诊断 → "稳健型" → 大额存单/国债/银行R1理财 → 跳转招行App |

### 画像二：王丽 — 高净值忙碌的家庭支柱
| 维度 | 内容 |
|------|------|
| 年龄/职业 | 42岁，互联网公司总监 |
| 资产规模 | ~800万，股票+基金+公司期权+银行理财 |
| 核心诉求 | 资产配置顶层设计 + 探索香港/海外机会 |
| 痛点 | 时间稀缺、信息过载、配置碎片化、渠道局限 |
| **对 AI 明理的要求** | 给"道"不给"术"，给配置框架（如40%固收/40%权益/10%保险），效率优先 |
| 典型路径 | AI诊断 → 配置框架建议 → 香港板块对比 → 收藏/分享待办 |

### 画像三：李明 — 积极进取的科技新贵
| 维度 | 内容 |
|------|------|
| 年龄/职业 | 35岁，软件工程师 |
| 资产规模 | ~150万，快速积累期 |
| 核心诉求 | 高速增值 + 探索新兴资产（可转债/加密/海外ETF） |
| 痛点 | 信息零散不结构化、厌恶冗长流程、合规边界不清 |
| **对 AI 明理的要求** | 可跳过诊断直达产品，深度专业内容，横向对比工具，数据驱动 |
| 典型路径 | 直接进产品导航 → 搜索"比特币" → 港股ETF详情 → HashKey渠道 |

### 设计原则（来自旅程地图提炼）
- **对张建国**：字体大、操作截图、零专业术语、强调"极低风险"标签
- **对王丽**：允许快速跳过、产品对比、收藏功能、香港/大陆分区筛选
- **对李明**：允许绕过AI直达产品、搜索直达、专业深度内容、多维对比图表
- **共同**：产品卡片显示"起投门槛"+"风险等级"，跳转前明确提示将打开第三方

---

## 可投资产品范围（数据来源）

**大陆**：活期/定期存款、货币基金、大额存单（20万起）、国债、银行理财（净值型）、债券基金、可转债、信托（100万起）、A股、宽基ETF、公募基金、私募（100万起）、REITs、增额寿/年金/万能险、纸黄金/黄金ETF、QDII基金

**香港**：港股通（50万证券资产）、跨境理财通（大湾区）、港元/美元定存、香港储蓄保险（IRR 4-6%）、海外ETF（VOO/QQQ via IBKR/富途）

**加密**：香港比特币ETF（3042.HK）、HashKey Exchange（持牌）

---

## 环境信息

- 系统：macOS 26.2，Apple Silicon (arm64)
- 模拟器：iPhone 17 Pro Max（iOS 26.2）
- CocoaPods：✅ 已安装
- Android Studio：❌ 未安装
