# 理财导航 — 项目总纲

> 此文件是项目的**静态背景文档**，内容稳定，不频繁修改。
> 每个新 Claude 会话都应该首先阅读此文件。

---

## 产品定位

- **名称**：理财导航（Finance Navigator）
- **目标用户**：中国大陆持有 **50万–1000万人民币存款**的人群
- **核心价值**：用AI摸清用户需求 → 匹配适合的**产品类型** → 跳转至主流平台自主购买
- **商业模式**：不接触资金、不推荐具体产品代码、不向平台收费（合规导航工具）

---

## 技术栈

| 层级 | 技术选型 | 说明 |
|------|---------|------|
| 前端框架 | Flutter 3.41.2 | Android + iOS 双端 |
| 状态管理 | flutter_riverpod | Provider 模式 |
| 路由 | GoRouter（待引入）| 当前用 IndexedStack |
| HTTP 客户端 | Dio | Claude API 请求 |
| 本地存储 | flutter_secure_storage + Hive | Token + 缓存 |
| AI 模型 | claude-sonnet-4-6 | Anthropic Claude API |
| 后端 | 暂无（MVP 纯本地） | 后期接 Node.js / FastAPI |
| 数据库 | 暂无（后期 PostgreSQL） | 用户数据云端同步 |

---

## 代码仓库

- **GitHub**: https://github.com/meiyaobuyao123-hash/Claudefinance-navigator.git
- **本地路径**: `/Users/wenruiwei/Desktop/testclaude/finance_navigator`
- **主分支**: `main`（稳定版本）
- **开发分支**: `dev`（日常开发）
- **功能分支命名**: `feature/xxx`

---

## 目录结构

```
lib/
├── main.dart                    # 入口
├── app.dart                     # MaterialApp + 主题配置
├── core/
│   ├── constants/app_constants.dart  # API URL、常量
│   ├── config/api_keys.dart          # ⚠️ 已 gitignore，存 Claude API Key
│   ├── theme/app_theme.dart          # 主题色、字体
│   └── widgets/                      # 公共组件
├── features/
│   ├── ai_chat/                 # AI 诊断模块（Claude API）
│   ├── navigation/              # 产品导航模块（大陆/香港/加密）
│   ├── learn/                   # 产品知识库
│   ├── tools/                   # 财富计算工具箱
│   └── profile/                 # 用户画像 / 登录
└── shared/                      # 共享组件
```

---

## 5大功能模块

| 模块 | Tab | 当前状态 | 说明 |
|------|-----|---------|------|
| AI 诊断 | 🤖 | ✅ 基础可用 | Claude API 已接入，角色"明理" |
| 产品导航 | 🗺️ | 🚧 占位符 | 需开发大陆/香港/加密三板块 |
| 知识库 | 📚 | 🚧 占位符 | 产品百科，需填充内容 |
| 工具箱 | 🔧 | 🚧 占位符 | 复利/目标倒推/通胀测算 |
| 我的 | 👤 | 🚧 占位符 | 登录注册，无后端 |

---

## 内容范围（可投资标的）

### 🇨🇳 中国大陆
- 现金管理：活期存款、货币基金、银行现金理财
- 固定收益：定期存款、大额存单（20万起）、国债、银行理财净值型、债券基金、可转债、信托（100万起）
- 权益类：A股、指数ETF、公募基金、私募基金（100万起）、公募REITs
- 保险理财：增额终身寿、年金险、万能险
- 贵金属：纸黄金、黄金ETF、黄金积存
- 境外：QDII 基金（标普500/纳指100）

### 🇭🇰 香港
- 港股通（需50万证券资产）
- 跨境理财通（仅大湾区，额度300万）
- 赴港开户：港元/美元定存、香港储蓄保险（IRR 4-6%）、海外ETF（VOO/QQQ via IBKR）

### 🔐 加密（香港合规）
- 香港比特币/以太坊 ETF（联交所上市）
- HashKey Exchange（持牌，VASP 牌照）

---

## 合规边界

- ✅ 展示产品类型信息（教育性质）
- ✅ 跳转至持牌平台（导流）
- ❌ 不推荐具体股票/基金代码
- ❌ 不接触资金
- ❌ 不向合作平台收费

---

## API Key 安全配置

```dart
// lib/core/config/api_keys.dart（已加入 .gitignore）
class ApiKeys {
  static const String claudeApiKey = 'sk-ant-...';
}
```

**⚠️ 注意**：api_keys.dart 不提交到 GitHub，只有 api_keys.dart.example 作为模板。
