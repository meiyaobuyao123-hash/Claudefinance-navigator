# PRD — Profile & Onboarding 模块

> 版本：1.0 | 日期：2026-03-23 | 状态：已实现（代码基线 main）

---

## 1. 问题陈述

理财导航 App（明理）需要两类用户身份信息：

1. **账户身份**：用 Supabase Auth 管理邮箱注册/登录，使云端数据可与账号绑定，并支持安全退出和账号销毁。
2. **投资画像**：冷启动时收集用户资产量级、理财目标、风险偏好，注入 AI 对话的 System Prompt（PromptBuilder Layer 3），驱动个性化推荐。

当前架构中，这两类信息**完全解耦**：账户身份通过 Supabase Auth 管理，投资画像通过 `SharedPreferences` 本地持久化，两者互不依赖。

---

## 2. 目标用户 & 用户故事

### 目标用户

中国大陆持有 50 万–1000 万人民币可投资资金的个人用户，使用 iOS/Android 设备。

### 用户故事

| ID | 角色 | 故事 | 优先级 |
|----|------|------|--------|
| US-1 | 新用户 | 首次打开 App，完成三步引导（资产/目标/风险），让 AI 了解我，然后立即开始对话 | P0 |
| US-2 | 新用户 | 不想回答问题，点击"跳过"直接进入对话 | P0 |
| US-3 | 未注册用户 | 在「我的」页看到登录/注册入口，注册后保存风险画像和诊断记录 | P1 |
| US-4 | 已注册用户 | 用邮箱+密码登录，登录后看到昵称/邮箱，知道我已登录 | P1 |
| US-5 | 已登录用户 | 忘记密码时，输入邮箱即可收到重置邮件 | P1 |
| US-6 | 已登录用户 | 退出当前账号（一步确认弹窗） | P1 |
| US-7 | 已登录用户 | 彻底删除账户及所有数据（两步确认弹窗 + 加载态） | P1 |
| US-8 | 老用户（>180天未更新画像） | 再次打开 App 时，系统提示重新填写投资画像（画像已过期） | P2 |

---

## 3. 功能需求

### 3.1 冷启动引导（OnboardingPage）

**文件**：`lib/features/onboarding/pages/onboarding_page.dart`

#### 3.1.1 触发逻辑

由 `UserProfileNotifier.shouldShowOnboarding()` 决定是否展示引导页，规则如下：

| 条件 | 结果 |
|------|------|
| `SharedPreferences['onboarding_skipped'] == true` | 不展示 |
| `UserProfile` 已存在 且 `updatedAt` 距今 ≤ 180 天 | 不展示 |
| `UserProfile` 不存在 | 展示 |
| `UserProfile` 已存在 但 `updatedAt` 距今 > 180 天 | 展示（画像过期） |

#### 3.1.2 页面结构

- 顶部 Header：图标（`Icons.psychology`）+ 标题「让明理了解你」+ 右侧「跳过」按钮
- 进度条：3 段横向进度条，当前步骤及之前的段落高亮（`AppColors.primary`），后续步骤显示为灰色（`AppColors.border`）
- 步骤内容区：可滚动，根据 `_step`（0/1/2）渲染对应子组件
- 底部操作栏：全宽按钮，步骤 0/1 显示「下一步」，步骤 2 显示「开始对话」；未选择时按钮禁用（`AppColors.border` 背景）

#### 3.1.3 三步问卷（step 0 → step 1 → step 2）

**Step 0 — 资产量级（`_AssetRangeStep`）**

- 问题文案：「你目前有多少可以投资的钱？」
- 副文案：「帮我给出合适的产品门槛建议」
- 选项（单选，`AssetRange` 枚举，radio 样式圆形选择器）：

| 枚举值 | 显示标签 |
|--------|----------|
| `AssetRange.below50w` | 50万以下 |
| `AssetRange.w50to200` | 50-200万 |
| `AssetRange.w200to500` | 200-500万 |
| `AssetRange.above500w` | 500万以上 |

- 约束：必选一项，未选时「下一步」禁用

**Step 1 — 理财目标（`_GoalStep`）**

- 问题文案：「你最主要的理财目标是？」
- 副文案：「最多选2个」
- 选项（多选，最多2项，`FinancialGoal` 枚举，checkbox 样式矩形选择器）：

| 枚举值 | 显示标签 |
|--------|----------|
| `FinancialGoal.beatInflation` | 跑赢通胀、本金安全 |
| `FinancialGoal.steadyGrowth` | 稳健增值（年化3-6%） |
| `FinancialGoal.aggressiveGrowth` | 积极增值、接受波动 |
| `FinancialGoal.retirement` | 养老规划 |
| `FinancialGoal.childEducation` | 子女教育金 |
| `FinancialGoal.wealthTransfer` | 财富传承 |

- 约束：已选满2项时，未选中的选项变为禁用态（`AppColors.textHint` 字色）；至少选1项才启用「下一步」

**Step 2 — 风险偏好（`_RiskStep`）**

- 问题文案：「去年A股大跌20%，你会怎么做？」
- 副文案：「这个问题帮我判断你的真实风险承受能力」
- 选项（单选，`RiskReaction` 枚举，每项显示 主label（情景描述）+ sublabel（风险类型标签））：

| 枚举值 | 情景描述（主label） | 风险类型（sublabel） |
|--------|---------------------|----------------------|
| `RiskReaction.sellImmediately` | 立刻止损卖出，睡不着觉 | 保守型（大跌会止损） |
| `RiskReaction.waitAndSee` | 有点担心，但观望不动 | 稳健型（观望不动） |
| `RiskReaction.holdLongTerm` | 正常，长期持有不在意 | 平衡型（长期持有） |
| `RiskReaction.buyMore` | 加仓，这是买入机会 | 积极型（加仓买入） |

- 约束：必选一项，未选时「开始对话」禁用

#### 3.1.4 完成流程（`_complete()`）

1. 以当前选择构造 `UserProfile`，`createdAt` 和 `updatedAt` 均设为 `DateTime.now()`
2. 调用 `UserProfileNotifier.save(profile)` → 序列化为 JSON → `SharedPreferences.setString('user_profile', jsonString)`
3. 导航至 `/chat`（`context.go('/chat')`，替换路由栈）

#### 3.1.5 跳过流程（`_skip()`）

1. 调用 `UserProfileNotifier.markSkipped()` → `SharedPreferences.setBool('onboarding_skipped', true)`
2. 导航至 `/chat`（`context.go('/chat')`，替换路由栈）

---

### 3.2 UserProfile 模型

**文件**：`lib/features/onboarding/models/user_profile.dart`

#### 3.2.1 模型字段

| 字段名 | 类型 | 说明 |
|--------|------|------|
| `assetRange` | `AssetRange`（枚举） | 可投资资金量级 |
| `goals` | `List<FinancialGoal>` | 理财目标，1–2 项 |
| `riskReaction` | `RiskReaction`（枚举） | 风险情景反应 |
| `createdAt` | `DateTime` | 首次创建时间 |
| `updatedAt` | `DateTime` | 最后更新时间，用于过期判断 |

#### 3.2.2 持久化方式

- 存储引擎：`SharedPreferences`
- Key：`'user_profile'`（字符串类型，JSON 编码）
- 序列化：枚举以 `index`（int）存储，`DateTime` 以 ISO 8601 字符串存储

#### 3.2.3 JSON 格式（示例）

```json
{
  "assetRange": 1,
  "goals": [1, 3],
  "riskReaction": 2,
  "createdAt": "2026-01-10T09:00:00.000",
  "updatedAt": "2026-01-10T09:00:00.000"
}
```

#### 3.2.4 过期逻辑

- 阈值：`_staleAfterDays = 180`（约6个月）
- 判断：`DateTime.now().difference(state!.updatedAt).inDays > 180`
- `isStale` getter：返回 `bool`，供上层判断是否显示"更新画像"提示（当前 `shouldShowOnboarding()` 已使用此逻辑）

#### 3.2.5 AI 注入格式（`toPromptSnippet()`）

`UserProfile.toPromptSnippet()` 输出约50 token 的文本片段，由 `PromptBuilder` Layer 3 注入至 AI System Prompt：

```
用户档案：
- 可投资资金：{assetRange.label}
- 理财目标：{goals[0].label}、{goals[1].label}
- 风险偏好：{riskReaction.label}
```

---

### 3.3 UserProfileNotifier

**文件**：`lib/features/onboarding/providers/user_profile_provider.dart`

| 方法/属性 | 说明 |
|-----------|------|
| `userProfileNotifierProvider` | Riverpod `StateNotifierProvider<UserProfileNotifier, UserProfile?>` |
| 构造时 `_loadFromPrefs()` | 异步加载 `SharedPreferences['user_profile']`，反序列化后设置为初始 state |
| `save(UserProfile profile)` | 序列化并写入 `SharedPreferences['user_profile']`，更新 state |
| `markSkipped()` | 写入 `SharedPreferences['onboarding_skipped'] = true` |
| `shouldShowOnboarding()` | 异步判断是否需要显示引导页（见 3.1.1） |
| `isStale` | 同步 getter，判断画像是否已超过180天 |

#### SharedPreferences Keys（完整列表）

| Key | 类型 | 含义 |
|-----|------|------|
| `'user_profile'` | String（JSON） | 序列化的 UserProfile |
| `'onboarding_skipped'` | bool | 用户是否曾点击「跳过」 |

---

### 3.4 用户认证（Auth）

#### 3.4.1 注册页（RegisterPage）

**文件**：`lib/features/profile/presentation/pages/register_page.dart`

**路由**：`/register`（`context.push('/register')`）

**表单字段**：

| 字段 | 输入类型 | 校验规则 |
|------|----------|----------|
| 邮箱 | `emailAddress` | 非空；必须包含 `@` |
| 密码 | 密码（可切换显隐） | 非空；长度 ≥ 6 |
| 确认密码 | 密码（固定遮蔽） | 非空；必须与密码字段完全一致 |

**注册流程**：

1. 表单本地校验通过后，调用 `Supabase.instance.client.auth.signUp(email, password)`
2. **分支 A — 无邮箱验证**（`res.session != null`）：显示 SnackBar「注册成功，已自动登录」，`context.pop()` 返回
3. **分支 B — 需邮箱验证**（`res.session == null`）：显示 SnackBar「注册成功！验证邮件已发送至 {email}，请查收后登录」（持续5秒），`context.pop()`，再 `context.push('/login')` 跳转到登录页
4. **错误处理**：`AuthException` → `localizeAuthError()` 中文化 → 红色 SnackBar；其他异常 → 「网络异常，请稍后重试」

**页脚文案**：「注册即表示你同意我们的服务条款和隐私政策」

**跳转至登录**：「已有账号？去登录」→ `context.pop(); context.push('/login')`

---

#### 3.4.2 登录页（LoginPage）

**文件**：`lib/features/profile/presentation/pages/login_page.dart`

**路由**：`/login`（`context.push('/login')`）

**表单字段**：

| 字段 | 输入类型 | 校验规则 |
|------|----------|----------|
| 邮箱 | `emailAddress` | 非空；必须包含 `@` |
| 密码 | 密码（可切换显隐） | 非空（无最小长度校验） |

**登录流程**：

1. 调用 `Supabase.instance.client.auth.signInWithPassword(email, password)`
2. 成功 → SnackBar「登录成功」，`context.pop()` 返回
3. **错误处理**：`AuthException` → `localizeAuthError()` → 红色 SnackBar；其他异常 → 「网络异常，请稍后重试」

**忘记密码流程**（`_sendPasswordReset()`）：

1. 前置校验：邮箱输入框非空且包含 `@`；否则提示「请先在上方填写邮箱地址」
2. 调用 `Supabase.instance.client.auth.resetPasswordForEmail(email)`
3. 成功 → SnackBar「重置密码邮件已发送至 {email}」
4. 失败 → SnackBar「发送失败，请稍后重试」

**跳转至注册**：「还没有账号？立即注册」→ `context.pop(); context.push('/register')`

---

#### 3.4.3 Auth 错误本地化（`localizeAuthError()`）

**文件**：`lib/core/providers/auth_provider.dart`

| Supabase 英文关键词 | 中文提示 |
|--------------------|----------|
| `invalid login credentials` / `invalid email or password` | 邮箱或密码不正确 |
| `user already registered` / `already been registered` | 该邮箱已被注册，请直接登录 |
| `password should be at least` | 密码至少需要6位 |
| `unable to validate email` / `invalid format` | 邮箱格式不正确 |
| `email not confirmed` | 请先验证邮箱后再登录 |
| `network` / `connection` | 网络异常，请检查网络后重试 |
| 其他 | 操作失败：{原始message} |

---

#### 3.4.4 Auth 状态 Provider

**文件**：`lib/core/providers/auth_provider.dart`

| Provider | 类型 | 说明 |
|----------|------|------|
| `authStateProvider` | `StreamProvider<AuthState>` | 监听 `Supabase.instance.client.auth.onAuthStateChange` 实时流 |
| `currentUserProvider` | `Provider<User?>` | 从 `authStateProvider` 派生，`null` 表示未登录；加载中时回退到 `Supabase.instance.client.auth.currentUser`；出错时返回 `null` |

---

### 3.5 个人中心（ProfilePage）

**文件**：`lib/features/profile/presentation/pages/profile_page.dart`

**路由**：Tab 底部导航「我的」（第4个 Tab）

#### 3.5.1 页面布局（从上至下）

1. **用户信息卡片**（条件渲染）
   - 未登录：渐变色（`primary → primaryLight`）引导卡，显示登录/注册按钮
   - 已登录：白色卡片，显示头像（邮箱首字母大写）、昵称（邮箱 `@` 前缀）、完整邮箱、「已登录」徽标（绿色）

2. **我的风险画像**（始终显示）
   - 占位文案：「完成AI诊断后，你的风险画像将显示在这里」
   - 展示5个风险等级标签（静态展示，非交互）：

   | 标签 | 颜色 |
   |------|------|
   | 保守 | `AppColors.riskLevel1` |
   | 稳健 | `AppColors.riskLevel2` |
   | 平衡 | `AppColors.riskLevel3` |
   | 积极 | `AppColors.riskLevel4` |
   | 激进 | `AppColors.riskLevel5` |

3. **我的数据**（菜单组，`onTap` 均为空回调，即功能待实现）
   - 诊断记录（`Icons.history`）
   - 收藏产品（`Icons.bookmark_outline`）

4. **设置**（菜单组，`onTap` 均为空回调，即功能待实现）
   - 消息通知（`Icons.notifications_outlined`）
   - 隐私政策（`Icons.security`）
   - 关于我们（`Icons.info_outline`）

5. **退出登录**（仅已登录时显示，红色文字）

6. **删除账户**（仅已登录时显示，红色文字，副文案：「永久删除账户及所有数据」）

7. **免责声明**（始终显示）
   > 本APP为理财产品类型导航工具，仅提供教育性信息，不构成投资建议。理财有风险，投资需谨慎。所有投资决策由您自行负责。

#### 3.5.2 退出登录流程

1. 点击「退出登录」→ 弹出 `AlertDialog`
2. 弹窗标题：「退出登录」，内容：「确定要退出当前账号吗？」
3. 操作：「取消」（关闭弹窗）/ 「退出」（红色文字，调用 `Supabase.instance.client.auth.signOut()`）
4. 登出后 `authStateProvider` 自动更新，`currentUserProvider` 变为 `null`，页面自动切换为未登录态

---

#### 3.5.3 删除账户流程（两步确认）

**步骤1 — 第一次确认弹窗**

- 标题：「删除账户」（带警告图标 `Icons.warning_amber_rounded`）
- 内容说明将删除的数据范围：
  - 基金持仓记录
  - 股票持仓记录
  - 自选股列表
  - 持仓走势快照
  - 本地缓存数据
- 操作：「取消」/ 「继续删除」（红色）→ 进入步骤2

**步骤2 — 第二次确认弹窗**（`barrierDismissible: false`，点弹窗外不可关闭）

- 标题：「最终确认」
- 内容：「请再次确认：删除后所有数据将无法找回。」
- 操作：「我再想想」（关闭）/ 「确认删除」（红底白字 `ElevatedButton`）→ 执行删除

**步骤3 — 执行删除（`_executeDeleteAccount()`）**

1. 显示全屏加载指示器（`CircularProgressIndicator`，`barrierDismissible: false`）
2. 调用 `SupabaseService.instance.deleteAllUserData()` → `DELETE /api/finance/all-data/{device_id}`（删除云端全部数据）
3. 清除本地 Hive 数据（各自 `try/catch` 独立处理，互不影响）：
   - `Hive.box('fund_holdings').clear()`
   - `Hive.box('stock_holdings').clear()`
   - `Hive.box('watchlist').clear()`
4. 调用 `Supabase.instance.client.auth.signOut()`（登出）
5. 关闭加载指示器
6. 显示 SnackBar「账户已删除，所有数据已清除」（`AppColors.success` 背景）
7. **失败处理**：关闭加载指示器，显示错误 SnackBar「删除失败，请稍后重试：{e}」

---

### 3.6 云端服务（SupabaseService）

**文件**：`lib/core/services/supabase_service.dart`

> 注：尽管类名为 `SupabaseService`，实际上已迁移至腾讯云自托管服务器，不再直接调用 Supabase 数据库。Supabase 仅保留 Auth（登录/注册/登出）功能。

#### 3.6.1 身份标识机制

| 属性 | 说明 |
|------|------|
| 标识方式 | `device_id`（UUID v4，首次生成后持久化于 `FlutterSecureStorage`） |
| SecureStorage Key | `'finance_nav_device_id'` |
| `currentOwnerId` | 等同于 `deviceId`（向后兼容旧调用方） |

设备 ID 与 Supabase Auth 账户**完全解耦**：即使未登录，云端数据同步也可正常运作，以 `device_id` 作为数据主键。

#### 3.6.2 API Base URL

`http://43.156.207.26/api/finance`（HTTP，非HTTPS）

超时设置：连接超时 8 秒，接收超时 8 秒

#### 3.6.3 删除账户相关 API

| 方法 | HTTP | 路径 | 说明 |
|------|------|------|------|
| `deleteAllUserData()` | DELETE | `/all-data/{device_id}` | 删除该设备的所有云端数据；成功返回 `true`，失败（任何异常）返回 `false` |

#### 3.6.4 涉及删除账户的 Hive Box 名称

| Hive Box 名称 | 数据类型 |
|---------------|----------|
| `'fund_holdings'` | 基金持仓记录 |
| `'stock_holdings'` | 股票持仓记录 |
| `'watchlist'` | 自选股列表 |

---

## 4. 边界条件

| 编号 | 场景 | 处理方式 |
|------|------|----------|
| BC-1 | 注册时 Supabase 开启邮箱验证 | `res.session == null`，提示发送验证邮件，跳转登录页 |
| BC-2 | 注册时 Supabase 关闭邮箱验证 | `res.session != null`，自动登录，直接返回 |
| BC-3 | 注册重复邮箱 | `AuthException` → `localizeAuthError()` → 「该邮箱已被注册，请直接登录」 |
| BC-4 | 登录密码错误 | `AuthException` → 「邮箱或密码不正确」 |
| BC-5 | 登录但邮箱未验证 | `AuthException` → 「请先验证邮箱后再登录」 |
| BC-6 | 忘记密码：邮箱框为空 | 本地前置校验失败 → 「请先在上方填写邮箱地址」，不调用 API |
| BC-7 | 网络断开（Auth 操作） | `catch` 捕获非 `AuthException` → 「网络异常，请稍后重试」 |
| BC-8 | 删除账户云端 API 失败 | `deleteAllUserData()` 返回 `false`，抛出异常，`_executeDeleteAccount` catch 层显示错误 SnackBar |
| BC-9 | 删除账户时某个 Hive Box 未开启 | 每个 `box.clear()` 独立 `try/catch`，失败静默忽略，不影响后续步骤 |
| BC-10 | 删除账户第二步弹窗点击外部 | `barrierDismissible: false`，不可关闭 |
| BC-11 | Onboarding 画像已过期（>180天） | `shouldShowOnboarding()` 返回 `true`，重新展示引导 |
| BC-12 | 用户跳过 Onboarding 后再次打开 App | `onboarding_skipped == true` → 不再展示引导页 |
| BC-13 | `goals` 选满2项后尝试继续选择 | 超出2项的选项变为禁用态，点击无响应 |
| BC-14 | `authStateProvider` 错误状态 | `currentUserProvider` 返回 `null`，页面渲染为未登录态 |
| BC-15 | `authStateProvider` 加载中 | `currentUserProvider` 回退到 `Supabase.instance.client.auth.currentUser`（同步值），避免闪白 |

---

## 5. 与其他模块的联动

| 联动模块 | 联动方式 | 说明 |
|---------|---------|------|
| **AI 对话（M03 PromptBuilder）** | `UserProfile.toPromptSnippet()` 注入 Layer 3 | 投资画像作为 System Prompt 的用户档案层 |
| **AI 对话（M01 冷启动）** | `UserProfileNotifier.shouldShowOnboarding()` 控制路由跳转 | App 启动时决定是进 Onboarding 还是直接进 Chat |
| **基金持仓（FundTracker）** | `SupabaseService.instance.deleteAllUserData()` | 删除账户时清除基金云端数据 |
| **股票持仓（StockTracker）** | `Hive.box('stock_holdings').clear()` | 删除账户时清除股票本地数据 |
| **自选股（Watchlist）** | `Hive.box('watchlist').clear()` | 删除账户时清除自选股本地数据 |
| **路由（app_router.dart）** | `/login`、`/register`、`/chat` 路由 | 登录/注册页通过 `go_router` 的 `push`/`pop`/`go` 导航 |
| **Riverpod（currentUserProvider）** | `ProfilePage` 通过 `ref.watch(currentUserProvider)` 响应登录状态 | Auth 状态变化自动触发 UI 重建 |

---

## 6. 验收标准

| ID | 标准描述 |
|----|---------|
| AC-1 | 首次安装 App，Onboarding 页自动展示，进度条初始高亮第1段 |
| AC-2 | Step 0 未选资产量级时，「下一步」按钮不可点击（背景为 `AppColors.border`） |
| AC-3 | Step 1 选满2个目标后，其余选项变灰且不可点击 |
| AC-4 | Step 2 点击「开始对话」后，`SharedPreferences['user_profile']` 存在有效 JSON |
| AC-5 | 点击「跳过」后，`SharedPreferences['onboarding_skipped'] == true`，并跳转至 Chat 页 |
| AC-6 | 注册页：密码 < 6 位时显示内联校验错误「密码至少需要6位」 |
| AC-7 | 注册页：确认密码与密码不一致时显示内联错误「两次密码不一致」 |
| AC-8 | 注册成功（无邮箱验证）后，SnackBar 显示「注册成功，已自动登录」，并自动关闭注册页 |
| AC-9 | 登录成功后，ProfilePage 显示已登录用户卡，昵称为邮箱 `@` 前缀，头像为首字母大写 |
| AC-10 | 忘记密码：邮箱框为空时点击「忘记密码？」，显示「请先在上方填写邮箱地址」而非调用 API |
| AC-11 | 退出登录：弹窗点击「退出」后，ProfilePage 切换为未登录引导卡 |
| AC-12 | 删除账户：必须经过两次确认弹窗才能执行删除；第二步弹窗点击外部区域不关闭 |
| AC-13 | 删除账户执行期间显示全屏加载指示器，用户无法关闭 |
| AC-14 | 删除账户成功后：云端数据已删除，三个 Hive Box 已清空，Supabase Auth 已登出，SnackBar 显示成功提示 |
| AC-15 | 画像创建超过180天后，`shouldShowOnboarding()` 返回 `true`，重新引导用户填写 |
| AC-16 | `UserProfile.toPromptSnippet()` 输出格式包含「用户档案：」标头及三行字段信息 |

---

## 7. 不做的范围（Out of Scope）

| 编号 | 描述 |
|------|------|
| OOS-1 | **第三方登录**（微信、Apple、Google 等）：当前仅支持邮箱+密码 |
| OOS-2 | **手机号注册/登录**：不支持 |
| OOS-3 | **用户头像上传**：头像固定为邮箱首字母，不支持自定义图片 |
| OOS-4 | **昵称修改**：昵称固定为邮箱前缀，无编辑入口 |
| OOS-5 | **邮箱修改**：无变更邮箱功能 |
| OOS-6 | **密码修改（App内）**：仅支持通过邮件重置密码，无In-App修改密码页面 |
| OOS-7 | **诊断记录页**：「诊断记录」菜单项 `onTap` 为空，功能待实现 |
| OOS-8 | **收藏产品页**：「收藏产品」菜单项 `onTap` 为空，功能待实现 |
| OOS-9 | **消息通知设置**：「消息通知」菜单项 `onTap` 为空，功能待实现 |
| OOS-10 | **隐私政策/关于我们页面**：菜单项 `onTap` 为空，功能待实现 |
| OOS-11 | **风险画像可视化**：当前风险画像区块为占位状态，不读取 `UserProfile.riskReaction` |
| OOS-12 | **画像更新流程**：无「重新填写画像」入口，过期画像只在 App 冷启动时触发重新引导 |
| OOS-13 | **UserProfile 云端同步**：仅本地 `SharedPreferences` 存储，不上传至任何云端 |
| OOS-14 | **多设备同步**：`device_id` 机制使数据绑定设备，切换设备后数据不互通 |
