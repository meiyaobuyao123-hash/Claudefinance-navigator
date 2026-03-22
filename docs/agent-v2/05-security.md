# 明理 Agent v2 — 安全设计文档

> 版本：v1.0 | 最后更新：2026-03-22

---

## 1. 威胁模型

| 威胁 | 来源 | 影响 | 已有防护 |
|------|------|------|---------|
| Prompt Injection | 恶意用户输入 | AI 越界行为/泄露 system prompt | M07 InputGuardrail |
| API Key 泄露 | 代码仓库/客户端逆向 | 被盗用产生费用 | gitignore + 客户端存储 |
| 用户数据泄露 | 服务器攻击/传输截获 | 持仓/档案数据暴露 | HTTP（待升级HTTPS） |
| 违规投资建议 | 模型幻觉/越界回复 | 法律合规风险 | M07 OutputGuardrail |
| 设备数据被读取 | 手机丢失/Root | 本地持仓数据暴露 | Hive 无加密（待评估） |

---

## 2. API Key 管理

### 现状

```
lib/core/config/api_keys.dart    ← .gitignore 排除，不上传 GitHub
```

3个 Key：Claude 主 Key、Claude 备用 Key、DeepSeek Key。

### 风险

- 客户端 App 逆向后可提取 Key（无法完全防止）
- 当前策略：gitignore 防止 Key 进入代码仓库

### 加固措施（按优先级）

| 措施 | 优先级 | 说明 |
|------|--------|------|
| 使用 `flutter_secure_storage` 存储 Key（设备 Keychain） | P1 | 比 dart 常量更安全，但仍可被 Root 设备提取 |
| Key 通过服务器中转（不在客户端暴露） | P2 | 最安全，但需要搭建 Proxy 服务，增加延迟 |
| Anthropic API Key 设置 IP/来源限制 | P1 | 在 Anthropic 控制台设置允许调用的 IP 范围 |
| 定期轮换 Key | P1 | 万一泄露，旧 Key 失效 |

### 当前最低要求

- [x] Key 不进入 Git 仓库
- [ ] 设置 Anthropic 控制台的月度消费上限告警
- [ ] Key 泄露应急流程：立即在控制台撤销旧 Key，本地替换新 Key

---

## 3. 用户数据安全

### 数据分类

| 数据 | 存储位置 | 敏感程度 | 当前保护 |
|------|---------|---------|---------|
| 持仓数据（基金/股票代码+金额） | Hive 本地 + 腾讯云 PostgreSQL | 高 | 无加密（传输HTTP，存储明文）|
| 用户档案（资产量级/风险偏好） | SharedPreferences | 中 | 无加密 |
| 对话历史 | 内存（不持久化） | 中 | 会话结束后清除 |
| 决策日记 | Hive 本地 + 腾讯云 | 高 | 无加密 |
| 反馈数据 | 腾讯云 PostgreSQL | 低 | 无加密 |

### 改进措施

**短期（P1）**：
- 服务器启用 HTTPS（腾讯云 Nginx 添加 SSL 证书，免费 Let's Encrypt）
- 腾讯云 PostgreSQL 限制访问来源（只允许 App Server IP + 本机 IP）

**中期（P2）**：
- Hive 本地存储加密（`hive_ce` 支持 AES 加密）
- 用户数据与设备 ID 绑定，不可跨设备访问（已实现）

**长期**：
- 用户账号体系下的数据权限隔离（目前用 device_id 隔离）

---

## 4. Prompt Injection 防护（M07 扩展）

### 当前防护层级

```
Layer 1（客户端，确定性）：InputGuardrail 正则检测
Layer 2（模型层，概率性）：system prompt 中声明角色边界
Layer 3（输出层，确定性）：OutputGuardrail 违规内容检测
```

### 已知绕过风险

| 绕过方式 | 风险程度 | 应对 |
|---------|---------|------|
| 多语言绕过（英文/日文 prompt injection） | 中 | InputGuardrail 已覆盖英文，可扩展其他语言 |
| 编码绕过（Base64/Unicode） | 低 | 实际用户场景极少，暂不处理 |
| 分段输入（多条消息拼接攻击） | 低 | 每条消息独立检测，需多条才能拼成攻击 |

### 不可防的情况

- Claude 模型自身被 Anthropic 更新后行为改变
- 高度定制化的 jailbreak prompt（对抗性的，更新频繁）

**结论**：M07 的目标不是 100% 防御高级攻击，而是**阻止绝大多数普通用户的误操作和简单绕过**。

---

## 5. 合规边界

### 中国大陆合规

| 要求 | 当前状态 |
|------|---------|
| 不提供具体证券推荐（证券法） | ✅ OutputGuardrail 检测股票代码 |
| 不承诺收益（广告法） | ✅ OutputGuardrail 检测承诺语言 |
| 不执行交易操作 | ✅ 架构层面无交易 API |
| 用户数据存储在境内服务器 | ✅ 腾讯云新加坡（待评估是否需迁移境内）|

### App Store 合规

| 要求 | 当前状态 |
|------|---------|
| 删除账户功能 | ✅ 已实现（2026-03-21）|
| 年龄分级（金融App建议 17+） | ⚠️ 待在 App Store Connect 修改 |
| 隐私政策页面 | ⚠️ 待添加（App Store 审核要求）|

---

## 6. 安全检查清单（每次发版前）

- [ ] `git log --all -- lib/core/config/api_keys.dart` 确认无提交记录
- [ ] `flutter analyze` 无安全相关 warning
- [ ] 服务器 Nginx 访问日志无异常大量请求（防 API Key 被滥用）
- [ ] Anthropic 控制台检查本月 API 消费是否在预期范围内
