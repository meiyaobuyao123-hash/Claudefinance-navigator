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

**最后更新**：2026-02-27

**已完成的功能**：
- ✅ Flutter 项目脚手架（5 Tab 底部导航）
- ✅ 主题色、字体、AppBar 等基础 UI
- ✅ Claude API 接入（claude-sonnet-4-6）
- ✅ AI 对话页面：多轮对话、气泡 UI、打字动画、快捷回复
- ✅ AI 角色"明理"：20年私人理财顾问人设，详细系统提示词
- ✅ API Key 安全配置（`lib/core/config/api_keys.dart`，已 gitignore）
- ✅ Git Flow：main（稳定）+ dev（开发）分支

**各 Tab 状态**：
| Tab | 功能 | 状态 |
|-----|------|------|
| 🤖 AI诊断 | Claude 对话诊断 | 🟡 基础可用，待增强 |
| 🗺️ 产品导航 | 大陆/香港/加密产品 | 🔴 占位符，待开发 |
| 📚 知识库 | 产品百科 | 🔴 占位符，待开发 |
| 🔧 工具箱 | 计算器 | 🔴 占位符，待开发 |
| 👤 我的 | 登录注册 | 🔴 占位符，需后端 |

**⚠️ 待处理问题**：
- 旧 Claude API Key 已在聊天暴露，需去 console.anthropic.com 吊销并换新 Key
- AI 回复无 Markdown 渲染（加粗/列表显示为原始符号）
- Android 工具链未配置（只能 iOS Simulator 运行）

**下一步推荐任务**（按优先级）：
1. 给 AI 回复加 Markdown 渲染（`flutter_markdown` 包）
2. 开发产品导航页（大陆产品卡片列表）
3. 复利计算器

---

## 关键文件索引

| 文件 | 说明 |
|------|------|
| `lib/app.dart` | 主题、路由、底部导航配置 |
| `lib/core/theme/app_theme.dart` | 颜色/字体 |
| `lib/core/constants/app_constants.dart` | API URL、常量 |
| `lib/core/config/api_keys.dart` | ⚠️ Claude Key（gitignored，本地才有） |
| `lib/features/ai_chat/presentation/pages/ai_chat_page.dart` | AI 对话核心文件 |
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
