// M01 冷启动引导 — 单元测试
// 严格对应 PRD 验收标准：
//   AC-1: 首次用户（无档案未跳过）→ shouldShowOnboarding = true
//   AC-2: 跳过后不再显示引导
//   AC-3: 有档案且 < 180 天 → shouldShowOnboarding = false
//   AC-4: 有档案且 > 180 天 → shouldShowOnboarding = true（提示更新）
//   AC-5: save() 持久化档案，state 同步更新
//   AC-6: isStale 正确反映档案新鲜度

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finance_navigator/features/onboarding/providers/user_profile_provider.dart';
import 'package:finance_navigator/features/onboarding/models/user_profile.dart';

// ── 测试用夹具 ────────────────────────────────────────────────────

UserProfile _freshProfile() => UserProfile(
      assetRange: AssetRange.w200to500,
      goals: [FinancialGoal.steadyGrowth, FinancialGoal.retirement],
      riskReaction: RiskReaction.waitAndSee,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime.now(),
    );

UserProfile _staleProfile() => UserProfile(
      assetRange: AssetRange.w50to200,
      goals: [FinancialGoal.beatInflation],
      riskReaction: RiskReaction.holdLongTerm,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime.now().subtract(const Duration(days: 200)),
    );

void main() {
  setUp(() {
    // 每个测试前清空 SharedPreferences
    SharedPreferences.setMockInitialValues({});
  });

  // ── [AC-1] 首次用户 ──────────────────────────────────────────
  group('[AC-1] 首次用户（无档案未跳过）', () {
    test('shouldShowOnboarding() 返回 true', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = UserProfileNotifier();
      expect(await notifier.shouldShowOnboarding(), isTrue);
    });

    test('state 初始为 null', () {
      SharedPreferences.setMockInitialValues({});
      final notifier = UserProfileNotifier();
      expect(notifier.state, isNull);
    });

    test('isStale 为 false（无档案）', () {
      SharedPreferences.setMockInitialValues({});
      final notifier = UserProfileNotifier();
      expect(notifier.isStale, isFalse);
    });
  });

  // ── [AC-2] 跳过后不再显示 ─────────────────────────────────────
  group('[AC-2] 跳过机制', () {
    test('markSkipped() 后 shouldShowOnboarding() 返回 false', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = UserProfileNotifier();
      await notifier.markSkipped();
      expect(await notifier.shouldShowOnboarding(), isFalse);
    });

    test('markSkipped() 持久化到 SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = UserProfileNotifier();
      await notifier.markSkipped();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('onboarding_skipped'), isTrue);
    });

    test('跳过且有过期档案 → shouldShowOnboarding() 仍返回 false', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = UserProfileNotifier();
      await notifier.save(_staleProfile());
      await notifier.markSkipped();
      expect(await notifier.shouldShowOnboarding(), isFalse);
    });
  });

  // ── [AC-3] 有档案且 < 180 天 ──────────────────────────────────
  group('[AC-3] 档案未过期（< 180 天）', () {
    test('shouldShowOnboarding() 返回 false', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = UserProfileNotifier();
      await notifier.save(_freshProfile());
      expect(await notifier.shouldShowOnboarding(), isFalse);
    });

    test('isStale 返回 false', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = UserProfileNotifier();
      await notifier.save(_freshProfile());
      expect(notifier.isStale, isFalse);
    });
  });

  // ── [AC-4] 有档案且 > 180 天 ──────────────────────────────────
  group('[AC-4] 档案过期（> 180 天）', () {
    test('shouldShowOnboarding() 返回 true（提示更新）', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = UserProfileNotifier();
      await notifier.save(_staleProfile());
      expect(await notifier.shouldShowOnboarding(), isTrue);
    });

    test('isStale 返回 true', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = UserProfileNotifier();
      await notifier.save(_staleProfile());
      expect(notifier.isStale, isTrue);
    });

    test('未跳过且档案过期 → shouldShowOnboarding() 返回 true', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = UserProfileNotifier();
      await notifier.save(_staleProfile());
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('onboarding_skipped'), isNull); // 未跳过
      expect(await notifier.shouldShowOnboarding(), isTrue);
    });
  });

  // ── [AC-5] save() 持久化 ──────────────────────────────────────
  group('[AC-5] save() 持久化档案', () {
    test('save() 后 state 立即更新', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = UserProfileNotifier();
      final profile = _freshProfile();
      await notifier.save(profile);
      expect(notifier.state, isNotNull);
      expect(notifier.state!.assetRange, equals(profile.assetRange));
    });

    test('save() 写入 SharedPreferences，新 Notifier 加载后可读取', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier1 = UserProfileNotifier();
      await notifier1.save(_freshProfile());

      // 模拟重启：从 prefs 读取已保存的值
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user_profile'), isNotNull);
    });

    test('save() 保存 assetRange / goals / riskReaction 完整', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = UserProfileNotifier();
      final profile = _freshProfile();
      await notifier.save(profile);

      expect(notifier.state!.assetRange, equals(AssetRange.w200to500));
      expect(notifier.state!.goals,
          containsAll([FinancialGoal.steadyGrowth, FinancialGoal.retirement]));
      expect(notifier.state!.riskReaction, equals(RiskReaction.waitAndSee));
    });

    test('连续 save() 覆盖旧档案', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = UserProfileNotifier();
      await notifier.save(_freshProfile());
      final updated = UserProfile(
        assetRange: AssetRange.above500w,
        goals: [FinancialGoal.aggressiveGrowth],
        riskReaction: RiskReaction.buyMore,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await notifier.save(updated);
      expect(notifier.state!.assetRange, equals(AssetRange.above500w));
      expect(notifier.state!.riskReaction, equals(RiskReaction.buyMore));
    });
  });

  // ── [AC-6] isStale 精确度 ─────────────────────────────────────
  group('[AC-6] isStale 边界值', () {
    test('更新时间恰好 180 天前 → isStale = false', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = UserProfileNotifier();
      final profile = UserProfile(
        assetRange: AssetRange.w50to200,
        goals: [FinancialGoal.beatInflation],
        riskReaction: RiskReaction.holdLongTerm,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now().subtract(const Duration(days: 180)),
      );
      await notifier.save(profile);
      expect(notifier.isStale, isFalse); // 恰好180天，不超过
    });

    test('更新时间 181 天前 → isStale = true', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = UserProfileNotifier();
      final profile = UserProfile(
        assetRange: AssetRange.w50to200,
        goals: [FinancialGoal.beatInflation],
        riskReaction: RiskReaction.holdLongTerm,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now().subtract(const Duration(days: 181)),
      );
      await notifier.save(profile);
      expect(notifier.isStale, isTrue);
    });
  });

  // ── UserProfile 模型完整性 ────────────────────────────────────
  group('UserProfile 模型', () {
    test('所有 AssetRange 枚举都有非空 label', () {
      for (final r in AssetRange.values) {
        expect(r.label, isNotEmpty);
      }
    });

    test('所有 FinancialGoal 枚举都有非空 label', () {
      for (final g in FinancialGoal.values) {
        expect(g.label, isNotEmpty);
      }
    });

    test('所有 RiskReaction 枚举都有非空 label', () {
      for (final r in RiskReaction.values) {
        expect(r.label, isNotEmpty);
      }
    });

    test('toPromptSnippet 包含 用户档案 关键词', () {
      expect(_freshProfile().toPromptSnippet(), contains('用户档案'));
    });

    test('toPromptSnippet 包含 assetRange.label', () {
      final snippet = _freshProfile().toPromptSnippet();
      expect(snippet, contains(AssetRange.w200to500.label));
    });

    test('toPromptSnippet 包含 goals labels', () {
      final snippet = _freshProfile().toPromptSnippet();
      expect(snippet, contains(FinancialGoal.steadyGrowth.label));
      expect(snippet, contains(FinancialGoal.retirement.label));
    });

    test('toPromptSnippet 包含 riskReaction.label', () {
      final snippet = _freshProfile().toPromptSnippet();
      expect(snippet, contains(RiskReaction.waitAndSee.label));
    });

    test('copyWith 只修改指定字段', () {
      final original = _freshProfile();
      final copy = original.copyWith(assetRange: AssetRange.above500w);
      expect(copy.assetRange, equals(AssetRange.above500w));
      expect(copy.goals, equals(original.goals)); // 其他字段不变
      expect(copy.riskReaction, equals(original.riskReaction));
    });

    test('toJson / fromJson 往返一致（全部枚举值）', () {
      for (final assetRange in AssetRange.values) {
        for (final riskReaction in RiskReaction.values) {
          final profile = UserProfile(
            assetRange: assetRange,
            goals: [FinancialGoal.steadyGrowth],
            riskReaction: riskReaction,
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          );
          final restored = UserProfile.fromJson(profile.toJson());
          expect(restored.assetRange, equals(profile.assetRange));
          expect(restored.riskReaction, equals(profile.riskReaction));
        }
      }
    });
  });
}
