# 决策日志（Architecture Decision Records）

> 记录所有**重要的技术和产品决策**，包括原因和被否决的方案。
> 格式：ADR（Architecture Decision Record）

---

## ADR-001：前端框架选择 Flutter

- **日期**：2026-02-26
- **状态**：✅ 已采纳
- **决策**：使用 Flutter 3.x 开发 iOS + Android 双端
- **原因**：
  - 一套代码覆盖双端，减少维护成本
  - 用户（产品经理）无移动端开发经验，Flutter 文档和 AI 支持好
  - UI 一致性好，金融类 App 视觉要求较高
- **被否决的方案**：
  - React Native：JS 生态复杂，原生模块桥接问题多
  - 原生 Swift + Kotlin：开发成本翻倍

---

## ADR-002：AI 模型选择 Claude API

- **日期**：2026-02-26
- **状态**：✅ 已采纳
- **决策**：使用 Anthropic Claude API（claude-sonnet-4-6）
- **原因**：
  - 中文理解和长上下文能力强
  - System prompt 遵循度高，适合角色扮演场景
  - 项目本身就是用 Claude 开发的，API 已有
- **注意**：
  - 模型 `claude-3-5-sonnet-20241022` 已废弃（2026-02 遇到404错误）
  - 当前使用：`claude-sonnet-4-6`

---

## ADR-003：MVP 阶段无后端

- **日期**：2026-02-26
- **状态**：✅ 已采纳
- **决策**：MVP 阶段不搭建后端，所有数据本地存储
- **原因**：
  - 快速验证产品价值，减少早期成本
  - 用户系统可以等到需要时再接入
- **后续计划**：
  - 后端技术选型：Node.js / Python FastAPI
  - 数据库：PostgreSQL
  - 认证：JWT

---

## ADR-004：状态管理选择 Riverpod

- **日期**：2026-02-26
- **状态**：✅ 已采纳（但简化使用）
- **决策**：使用 flutter_riverpod（不使用代码生成版本）
- **原因**：
  - 比 Provider 更灵活，适合复杂状态
  - 不使用 riverpod_generator 避免代码生成复杂度
- **注意**：
  - 已移除 hive_generator、riverpod_generator 等代码生成包（依赖冲突）

---

## ADR-005：API Key 安全存储方案

- **日期**：2026-02-27
- **状态**：✅ 已采纳
- **决策**：API Key 存储在 `lib/core/config/api_keys.dart`，加入 `.gitignore`
- **背景**：用户曾在聊天中暴露 API Key（需吊销旧 Key）
- **方案**：
  - `api_keys.dart`（真实 Key，gitignore，不提交）
  - `api_keys.dart.example`（占位符模板，提交到 GitHub）
- **被否决方案**：
  - 硬编码在源文件：绝对不可，会提交到 GitHub
  - 环境变量：Flutter 客户端无法安全使用环境变量

---

## ADR-006：AI 顾问人设"明理"

- **日期**：2026-02-27
- **状态**：✅ 已采纳
- **决策**：给 AI 设定具体人设而非通用助手
- **人设**：
  - 名字：明理
  - 背景：20年私人理财顾问，前头部券商 + 私募基金合伙人
  - 风格：沉稳自信有温度，像信任的老朋友
- **原因**：
  - 有具体人设的 AI 回复更有代入感
  - 明确的边界（不推荐代码、不接触资金）更合规
  - 三步策略（摸底→方案→引导）提升对话质量

---

## ADR-007：Git 分支策略

- **日期**：2026-02-27
- **状态**：✅ 已采纳
- **决策**：简化 Git Flow
  - `main`：稳定版本，里程碑完成后合并
  - `dev`：日常开发主干
  - `feature/xxx`：单个功能分支
- **Commit 规范**：`feat/fix/refactor/docs/chore: 描述`
