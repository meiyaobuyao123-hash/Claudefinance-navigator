# M01 冷启动引导 — 技术实现文档

> 版本：v1.0 | 最后更新：2026-03-22

---

## 1. 架构决策

| 决策 | 选择 | 原因 |
|------|------|------|
| 存储方式 | SharedPreferences | 3个字段，无需 Hive 复杂度 |
| 状态管理 | Riverpod StateNotifierProvider | 与项目统一 |
| 规划页数据读取 | 直接读现有 Provider | 不重复存储 |
| 引导触发判断 | 启动时同步检查 | 避免闪烁 |

---

## 2. 数据模型

```dart
// lib/features/onboarding/models/user_profile.dart

enum AssetRange { below50w, w50to200, w200to500, above500w }

enum FinancialGoal { beatInflation, steadyGrowth, aggressiveGrowth, retirement, childEducation, wealthTransfer }

enum RiskReaction { sellImmediately, waitAndSee, holdLongTerm, buyMore }

class UserProfile {
  final AssetRange assetRange;
  final List<FinancialGoal> goals;      // 最多2个
  final RiskReaction riskReaction;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.assetRange,
    required this.goals,
    required this.riskReaction,
    required this.createdAt,
    required this.updatedAt,
  });

  // 转为 system prompt 片段
  String toPromptSnippet() {
    return '''
用户档案：
- 可投资资金：${assetRange.label}
- 理财目标：${goals.map((g) => g.label).join('、')}
- 风险偏好：${riskReaction.label}
''';
  }

  Map<String, dynamic> toJson() => {
    'assetRange': assetRange.index,
    'goals': goals.map((g) => g.index).toList(),
    'riskReaction': riskReaction.index,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    assetRange: AssetRange.values[json['assetRange']],
    goals: (json['goals'] as List).map((i) => FinancialGoal.values[i]).toList(),
    riskReaction: RiskReaction.values[json['riskReaction']],
    createdAt: DateTime.parse(json['createdAt']),
    updatedAt: DateTime.parse(json['updatedAt']),
  );
}
```

---

## 3. Provider 设计

```dart
// lib/features/onboarding/providers/user_profile_provider.dart

@riverpod
class UserProfileNotifier extends _$UserProfileNotifier {
  static const _key = 'user_profile';
  static const _skippedKey = 'onboarding_skipped';
  static const _staleAfterDays = 180;

  @override
  UserProfile? build() {
    _loadFromPrefs();
    return null;
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key);
    if (json != null) {
      state = UserProfile.fromJson(jsonDecode(json));
    }
  }

  Future<void> save(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(profile.toJson()));
    state = profile;
  }

  Future<void> markSkipped() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_skippedKey, true);
  }

  Future<bool> shouldShowOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    // 已跳过，不再显示
    if (prefs.getBool(_skippedKey) == true) return false;
    // 已有档案且未过期
    if (state != null) {
      final daysSinceUpdate = DateTime.now().difference(state!.updatedAt).inDays;
      return daysSinceUpdate > _staleAfterDays; // 超180天提示更新
    }
    return true; // 首次用户
  }

  bool get isStale {
    if (state == null) return false;
    return DateTime.now().difference(state!.updatedAt).inDays > _staleAfterDays;
  }
}
```

---

## 4. UI 组件

```dart
// lib/features/onboarding/pages/onboarding_page.dart

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  int _step = 0;
  AssetRange? _assetRange;
  final Set<FinancialGoal> _goals = {};
  RiskReaction? _riskReaction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildProgress(),
            _buildSkipButton(),
            Expanded(child: _buildStep()),
            _buildNextButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() {
    return switch (_step) {
      0 => _AssetRangeStep(
          selected: _assetRange,
          onChanged: (v) => setState(() => _assetRange = v),
        ),
      1 => _GoalStep(
          selected: _goals,
          onChanged: (v) => setState(() {
            if (_goals.contains(v)) {
              _goals.remove(v);
            } else if (_goals.length < 2) {
              _goals.add(v);
            }
          }),
        ),
      2 => _RiskStep(
          selected: _riskReaction,
          onChanged: (v) => setState(() => _riskReaction = v),
        ),
      _ => const SizedBox(),
    };
  }

  void _onNext() {
    if (_step < 2) {
      setState(() => _step++);
    } else {
      _complete();
    }
  }

  Future<void> _complete() async {
    final profile = UserProfile(
      assetRange: _assetRange!,
      goals: _goals.toList(),
      riskReaction: _riskReaction!,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await ref.read(userProfileNotifierProvider.notifier).save(profile);
    if (mounted) Navigator.of(context).pushReplacementNamed('/chat');
  }

  Future<void> _skip() async {
    await ref.read(userProfileNotifierProvider.notifier).markSkipped();
    if (mounted) Navigator.of(context).pushReplacementNamed('/chat');
  }
}
```

---

## 5. 触发逻辑（App 启动时）

```dart
// lib/app.dart 或 splash_page.dart

Future<Widget> _resolveInitialPage() async {
  final profileNotifier = ref.read(userProfileNotifierProvider.notifier);
  final shouldOnboard = await profileNotifier.shouldShowOnboarding();

  if (shouldOnboard) {
    // 检查是否有规划页数据可以自动注入
    final planningData = ref.read(planningAssessmentProvider);
    if (planningData != null) {
      // 自动注入，跳过引导
      await _injectFromPlanning(planningData);
      return const ChatPage(showBanner: true); // 显示「已读取资产规划数据」banner
    }
    return const OnboardingPage();
  }

  return const ChatPage();
}
```

---

## 6. System Prompt 注入接口

```dart
// UserProfile.toPromptSnippet() 返回值示例：

'''
用户档案：
- 可投资资金：200-500万
- 理财目标：稳健增值（年化3-6%）、养老规划
- 风险偏好：有点担心，但观望不动（稳健型）
'''
```

该片段由 M03 分层 Prompt 架构的「用户档案层」使用，约占 300 token。

---

## 7. 测试计划

| 测试类型 | 用例 | 方式 |
|---------|------|------|
| 单元测试 | `UserProfile.toJson()` / `fromJson()` 往返 | flutter_test |
| 单元测试 | `toPromptSnippet()` 格式正确 | flutter_test |
| 单元测试 | `shouldShowOnboarding()` 各分支逻辑 | flutter_test + mock prefs |
| Widget测试 | 3步流程完整走通 | flutter_test |
| Widget测试 | 跳过后不再显示 | flutter_test |

---

## 8. 文件清单

```
lib/features/onboarding/
├── models/
│   └── user_profile.dart
├── providers/
│   └── user_profile_provider.dart
└── pages/
    ├── onboarding_page.dart
    └── widgets/
        ├── asset_range_step.dart
        ├── goal_step.dart
        └── risk_step.dart
```
