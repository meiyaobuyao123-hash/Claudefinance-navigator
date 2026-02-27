# 新会话启动指南

> 每次开启新的 Claude 会话时，**将此文件内容复制粘贴给 Claude**。
> 这样 Claude 可以在 30 秒内理解完整项目背景。

---

## 🚀 快速启动模板

```
你好！我在开发一个 Flutter 理财App，请先读取以下文件了解项目背景，然后我们继续开发：

1. .claude/PROJECT.md     —— 项目总纲（产品定位、技术栈、目录结构）
2. .claude/STATUS.md      —— 当前状态（最新进度、待完成任务、已知问题）
3. .claude/DECISIONS.md   —— 历史决策（避免重复讨论已确认的方案）
4. .claude/MODULES.md     —— 模块分工（我今天要做哪个模块）

项目路径：/Users/wenruiwei/Desktop/testclaude/finance_navigator
GitHub：https://github.com/meiyaobuyao123-hash/Claudefinance-navigator.git
当前分支：dev

读完后告诉我你理解的项目状态，然后我告诉你今天要做什么。
```

---

## 🎯 模块专项启动模板

### 开发 AI 诊断模块
```
请读取 .claude/PROJECT.md、.claude/STATUS.md、.claude/MODULES.md

我要继续开发 AI 诊断模块：
- 主文件：lib/features/ai_chat/presentation/pages/ai_chat_page.dart
- 当前状态：基础对话可用，Claude API 已接入（model: claude-sonnet-4-6）
- 今天目标：添加 flutter_markdown 渲染 AI 回复内容
```

### 开发产品导航模块
```
请读取 .claude/PROJECT.md、.claude/MODULES.md

我要从零开发产品导航模块：
- 目标文件：lib/features/navigation/
- 参考数据：.claude/PROJECT.md 中"内容范围"部分
- 今天目标：创建产品数据模型和大陆产品列表页
```

### 开发工具箱模块
```
请读取 .claude/PROJECT.md、.claude/MODULES.md

我要开发工具箱的复利计算器：
- 目标文件：lib/features/tools/presentation/pages/compound_calculator_page.dart
- 输入：本金 + 年利率 + 年限
- 输出：终值 + 利息 + 折线图（使用 fl_chart 库）
```

---

## 📋 会话结束时要做的事

**每次会话结束前，请让 Claude 执行以下操作：**

1. **更新 STATUS.md**
   - 更新"最后更新"日期
   - 更新各模块状态
   - 更新"下一步任务"

2. **提交代码到 Git**
   ```bash
   git add .
   git commit -m "feat/fix/chore: 描述本次会话做了什么"
   git push origin dev
   ```

3. **在 STATUS.md 中记录 Handover**
   - 当前做到哪了
   - 遇到了什么问题
   - 下一步从哪里继续

---

## ⚠️ 会话即将超出限制时

当 Claude 提示上下文快满时，请立即说：

```
"会话快到限制了，请帮我做会话交接：
1. 把当前进度、未完成的代码、遇到的问题写入 .claude/STATUS.md
2. 提交所有改动到 git
3. 给我下一个会话的启动指令"
```

Claude 会生成一个完整的交接文档，确保下一个会话可以无缝继续。

---

## 🔧 常用命令备忘

```bash
# 运行 App
cd /Users/wenruiwei/Desktop/testclaude/finance_navigator
flutter run

# 热重启（在 flutter run 终端中）
R  # 大写 R = Hot Restart（代码完整刷新）
r  # 小写 r = Hot Reload（UI 快速刷新）

# 查看设备
flutter devices

# 启动 iOS 模拟器
xcrun simctl boot "iPhone 17 Pro Max"
open -a Simulator

# Git 操作
git status
git add .
git commit -m "feat: xxx"
git push origin dev

# 安装依赖
flutter pub get
```

---

## 📁 关键文件速查

| 文件 | 作用 |
|------|------|
| `lib/app.dart` | 主题、路由、底部导航配置 |
| `lib/core/theme/app_theme.dart` | 颜色、字体主题 |
| `lib/core/constants/app_constants.dart` | API URL、常量 |
| `lib/core/config/api_keys.dart` | ⚠️ Claude API Key（gitignored） |
| `lib/features/ai_chat/presentation/pages/ai_chat_page.dart` | AI 对话主页面 |
| `pubspec.yaml` | 依赖包管理 |
| `ios/Podfile` | iOS 依赖配置（platform :ios, '13.0' 已启用） |
