# 理财导航 - Finance Navigator

面向持有 **50万–1000万人民币**存款的中国人，提供AI驱动的理财产品类型导航APP。

> **定位**：导航工具，不接触资金，不向平台收费，不推荐具体产品代码

---

## 功能模块

| 模块 | 说明 |
|------|------|
| 🤖 AI理财诊断 | Claude API驱动，多轮对话收集用户画像，输出产品类型配比建议 |
| 📚 产品知识库 | 大陆+香港+加密全覆盖，收益按期限细分，风险详细说明 |
| 📱 平台预览 | 展示在支付宝/天天基金/同花顺等平台的操作截图 |
| 🔗 平台导航 | 一键跳转到对应平台APP |
| 🧮 财务工具 | 复利计算器、目标倒推、通胀测算、产品收益对比 |
| 👤 用户系统 | 注册/登录，云端同步风险画像和诊断记录 |

---

## 快速开始

### 环境要求
- Flutter SDK 3.x（[下载](https://flutter.dev/docs/get-started/install)）
- Dart SDK 3.0+
- Android Studio 或 Xcode（iOS）

### 安装运行

```bash
# 1. 克隆项目
git clone <your-repo-url>
cd finance_navigator

# 2. 安装依赖
flutter pub get

# 3. 配置Claude API Key
# 打开 lib/features/ai_chat/presentation/pages/ai_chat_page.dart
# 找到第 136 行，替换 'YOUR_CLAUDE_API_KEY'
'x-api-key': 'YOUR_CLAUDE_API_KEY',

# 4. 运行
flutter run
```

### 添加平台截图
将各平台操作截图放入 `assets/screenshots/` 目录：
- `alipay_yuebao_entry.png` - 支付宝余额宝入口
- `alipay_yuebao_detail.png` - 余额宝详情页
- 其他截图按命名规则添加

---

## 项目结构

```
lib/
├── main.dart                    # 入口
├── app.dart                     # 应用配置
├── core/
│   ├── theme/app_theme.dart     # 主题/颜色
│   ├── router/app_router.dart   # 路由配置
│   └── constants/               # 常量
├── data/
│   ├── models/product_model.dart    # 产品数据模型
│   ├── datasources/
│   │   ├── products_data.dart       # 所有产品静态数据
│   │   └── platforms_data.dart      # 所有平台数据
├── features/
│   ├── home/                    # 首页
│   ├── ai_chat/                 # AI诊断对话
│   ├── products/                # 产品库+详情
│   ├── tools/                   # 财务计算工具
│   └── profile/                 # 用户中心+登录注册
└── shared/
    └── widgets/main_scaffold.dart  # 底部导航栏
```

---

## Claude API 配置

1. 前往 [console.anthropic.com](https://console.anthropic.com) 获取API Key
2. 替换 `lib/features/ai_chat/presentation/pages/ai_chat_page.dart` 中的 API Key

> **安全提示**：正式上线前，API Key应放在后端服务器，不应硬编码在APP中

---

## 打包上架

### Android
```bash
# 生成签名密钥（首次）
keytool -genkey -v -keystore ~/my-release-key.jks -keyAlias my-key-alias -keyalg RSA -keysize 2048 -validity 10000

# 配置签名（android/app/build.gradle）
# 见 Flutter 官方文档

# 打包 AAB（Google Play）
flutter build appbundle --release

# 打包 APK
flutter build apk --release
```

### iOS
```bash
# 需要 Mac + Xcode + Apple Developer 账号
flutter build ios --release

# 在 Xcode 中 Archive → Distribute App
```

### 上架流程
- **Google Play**：[developer.android.com](https://developer.android.com)，注册费 $25（一次性）
- **App Store**：[appstoreconnect.apple.com](https://appstoreconnect.apple.com)，年费 $99

---

## 合规说明

- ✅ 仅展示产品类型教育信息
- ✅ 导流至持牌平台（不介入交易）
- ✅ 不接触用户资金
- ✅ 不向合作平台收取费用
- ❌ 不推荐具体股票/基金代码
- ❌ 不提供具体仓位操作建议

> 上线前建议咨询金融科技律师，确认合规边界

---

## 技术栈

- **Flutter 3.x** - 跨平台 Android + iOS
- **Riverpod** - 状态管理
- **GoRouter** - 路由
- **Claude API** - AI对话（claude-3-5-sonnet）
- **Dio** - 网络请求
- **Hive** - 本地存储
