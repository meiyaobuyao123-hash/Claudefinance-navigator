// M03 分层 Prompt 架构 — 单元测试
// 严格对应 PRD 验收标准：
//   AC-1: 每次对话 system prompt token 数 < 1200
//   AC-2: 修改人格层不影响其他层（各层独立）
//   AC-3: 持仓快照层可独立启用/禁用
//   AC-4: 市场数据层缓存为 null 时不报错

import 'package:flutter_test/flutter_test.dart';
import 'package:finance_navigator/features/ai_chat/data/prompt_builder.dart';
import 'package:finance_navigator/features/ai_chat/data/conversation_stage.dart';
import 'package:finance_navigator/features/onboarding/models/user_profile.dart';
import 'package:finance_navigator/features/fund_tracker/data/models/fund_holding.dart';
import 'package:finance_navigator/features/stock_tracker/data/models/stock_holding.dart';
import 'package:finance_navigator/core/providers/market_rate_provider.dart';

// token 估算（与 PromptBuilder 内部一致）
int _est(String text) => (text.length / 1.5).round();

// ── 测试用夹具 ──────────────────────────────────────────────────

UserProfile _makeProfile() => UserProfile(
  assetRange: AssetRange.w200to500,
  goals: [FinancialGoal.steadyGrowth, FinancialGoal.retirement],
  riskReaction: RiskReaction.waitAndSee,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

Map<String, LiveRateData> _makeRates() => {
  'cn_money_fund': LiveRateData(
    displayRate: '1.77%', changeRate: null, isUp: false,
    updatedAt: DateTime.now(),
  ),
  'cn_etf': LiveRateData(
    displayRate: '3850.12 (+0.5%)', changeRate: 0.5, isUp: true,
    updatedAt: DateTime.now(),
  ),
  'cn_paper_gold': LiveRateData(
    displayRate: '¥628.50/g (+0.3%)', changeRate: 0.3, isUp: true,
    updatedAt: DateTime.now(),
  ),
};

FundHolding _makeFund(String code, String name, double shares, double costNav, double currentNav) =>
  FundHolding(
    id: code,
    fundCode: code,
    fundName: name,
    shares: shares,
    costNav: costNav,
    currentNav: currentNav,
    addedDate: '2025-01-01',
  );

StockHolding _makeStock(String symbol, String name, String market, double shares, double costPrice, double currentPrice) =>
  StockHolding(
    id: symbol,
    symbol: symbol,
    stockName: name,
    market: market,
    shares: shares,
    costPrice: costPrice,
    currentPrice: currentPrice,
    addedDate: '2025-01-01',
  );

void main() {
  // ── PromptBuilder 基础行为 ────────────────────────────────────
  group('PromptBuilder 基础行为', () {
    test('最简配置（无档案无持仓无行情）- 只有 L1+L5，不报错', () {
      final builder = PromptBuilder(
        fundHoldings: const [],
        stockHoldings: const [],
        stage: ConversationStage.exploring,
      );
      final result = builder.build('你好');
      expect(result, isNotEmpty);
      expect(result, contains('明理'));
    });

    test('build() 是确定性函数，相同输入相同输出', () {
      final builder = PromptBuilder(
        fundHoldings: const [],
        stockHoldings: const [],
        stage: ConversationStage.exploring,
      );
      final r1 = builder.build('黄金多少钱');
      final r2 = builder.build('黄金多少钱');
      expect(r1, equals(r2));
    });

    test('build() 永不抛异常（各层均可空）', () {
      final builder = PromptBuilder(
        userProfile: null,
        marketRates: null,
        fundHoldings: const [],
        stockHoldings: const [],
        stage: ConversationStage.exploring,
      );
      expect(() => builder.build('任意消息'), returnsNormally);
    });
  });

  // ── [AC-1] Token 预算 < 1200 ──────────────────────────────────
  group('[AC-1] system prompt token 数 < 1200', () {
    test('无持仓无档案：只有L1+L5，远低于预算', () {
      final builder = PromptBuilder(
        fundHoldings: const [],
        stockHoldings: const [],
        stage: ConversationStage.exploring,
      );
      final prompt = builder.build('普通问题');
      expect(_est(prompt), lessThan(1200));
    });

    test('有用户档案+行情，无持仓关键词：L1+L2+L3，应 < 1200', () {
      final builder = PromptBuilder(
        userProfile: _makeProfile(),
        marketRates: _makeRates(),
        fundHoldings: const [],
        stockHoldings: const [],
        stage: ConversationStage.deepening,
      );
      final prompt = builder.build('我应该怎么做养老规划');
      expect(_est(prompt), lessThan(1200));
    });

    test('有用户档案+行情+持仓关键词：L1+L2+L3+L4，应 < 1200', () {
      final funds = List.generate(5, (i) =>
          _makeFund('00$i', '基金$i', 10000, 1.0, 1.1));
      final stocks = List.generate(3, (i) =>
          _makeStock('sh60000$i', '股票$i', 'A', 100, 10.0, 12.0));

      final builder = PromptBuilder(
        userProfile: _makeProfile(),
        marketRates: _makeRates(),
        fundHoldings: funds,
        stockHoldings: stocks,
        stage: ConversationStage.actioning,
      );
      final prompt = builder.build('我的持仓配置合理吗');
      expect(_est(prompt), lessThan(1200));
    });

    test('超大持仓（20支基金+10支股票）：截断后仍 < 1200', () {
      final funds = List.generate(20, (i) =>
          _makeFund('0000$i', '大型基金$i', 50000, 1.5, 1.8));
      final stocks = List.generate(10, (i) =>
          _makeStock('sh60000$i', '大型股票$i', 'A', 500, 20.0, 25.0));

      final builder = PromptBuilder(
        userProfile: _makeProfile(),
        marketRates: _makeRates(),
        fundHoldings: funds,
        stockHoldings: stocks,
        stage: ConversationStage.actioning,
      );
      final prompt = builder.build('帮我看看我的持仓');
      expect(_est(prompt), lessThan(1200));
    });
  });

  // ── [AC-2] 各层独立，互不影响 ────────────────────────────────
  group('[AC-2] 各层独立，互不影响', () {
    test('L3 用户档案 null vs 有值：只影响 L3，其他层内容不变', () {
      final withoutProfile = PromptBuilder(
        userProfile: null,
        fundHoldings: const [],
        stockHoldings: const [],
        stage: ConversationStage.exploring,
      ).build('问题');

      final withProfile = PromptBuilder(
        userProfile: _makeProfile(),
        fundHoldings: const [],
        stockHoldings: const [],
        stage: ConversationStage.exploring,
      ).build('问题');

      // L1 人格层内容在两者中应相同
      expect(withoutProfile, contains('明理'));
      expect(withProfile, contains('明理'));
      // 有档案时应包含档案信息
      expect(withProfile, contains('用户档案'));
      expect(withoutProfile, isNot(contains('用户档案')));
    });

    test('L2 行情 null vs 有值：只影响 L2', () {
      final withoutRates = PromptBuilder(
        marketRates: null,
        fundHoldings: const [],
        stockHoldings: const [],
        stage: ConversationStage.exploring,
      ).build('问题');

      final withRates = PromptBuilder(
        marketRates: _makeRates(),
        fundHoldings: const [],
        stockHoldings: const [],
        stage: ConversationStage.exploring,
      ).build('问题');

      expect(withRates, contains('今日市场参考'));
      expect(withoutRates, isNot(contains('今日市场参考')));
      // L1 人格层在两者中均存在
      expect(withoutRates, contains('明理'));
      expect(withRates, contains('明理'));
    });

    test('L5 对话阶段：不同阶段有不同提示，不影响 L1', () {
      String build(ConversationStage s) => PromptBuilder(
        fundHoldings: const [],
        stockHoldings: const [],
        stage: s,
      ).build('问题');

      final exploring = build(ConversationStage.exploring);
      final actioning = build(ConversationStage.actioning);

      expect(exploring, contains('优先提问'));
      expect(actioning, contains('行动建议'));
      // 两者都有 L1
      expect(exploring, contains('明理'));
      expect(actioning, contains('明理'));
    });
  });

  // ── [AC-3] 持仓快照层可独立启用/禁用 ────────────────────────
  group('[AC-3] 持仓快照层按关键词触发', () {
    final funds = [_makeFund('005827', '易方达蓝筹', 10000, 1.0, 1.2)];

    test('无关键词 → 不注入完整快照', () {
      final prompt = PromptBuilder(
        fundHoldings: funds,
        stockHoldings: const [],
        stage: ConversationStage.exploring,
      ).build('养老规划怎么做');
      expect(prompt, isNot(contains('【持仓快照')));
    });

    test('含"持仓"关键词 → 注入完整快照', () {
      final prompt = PromptBuilder(
        fundHoldings: funds,
        stockHoldings: const [],
        stage: ConversationStage.exploring,
      ).build('我的持仓配置合理吗');
      expect(prompt, contains('【持仓快照'));
      expect(prompt, contains('易方达蓝筹'));
    });

    test('含"基金"关键词 → 注入完整快照', () {
      final prompt = PromptBuilder(
        fundHoldings: funds,
        stockHoldings: const [],
        stage: ConversationStage.exploring,
      ).build('我的基金亏了怎么办');
      expect(prompt, contains('【持仓快照'));
    });

    test('持仓为空 → 任何情况下都不注入', () {
      final prompt = PromptBuilder(
        fundHoldings: const [],
        stockHoldings: const [],
        stage: ConversationStage.exploring,
      ).build('我的持仓');
      expect(prompt, isNot(contains('【持仓快照')));
    });
  });

  // ── [AC-4] market rates 为 null 不报错 ───────────────────────
  group('[AC-4] market rates 为 null 时不报错', () {
    test('marketRates null → Layer2 返回空字符串', () {
      expect(
        () => PromptBuilder(
          marketRates: null,
          fundHoldings: const [],
          stockHoldings: const [],
          stage: ConversationStage.exploring,
        ).build('黄金多少钱'),
        returnsNormally,
      );
    });

    test('marketRates 空 Map → Layer2 返回空字符串', () {
      expect(
        () => PromptBuilder(
          marketRates: const {},
          fundHoldings: const [],
          stockHoldings: const [],
          stage: ConversationStage.exploring,
        ).build('黄金多少钱'),
        returnsNormally,
      );
    });
  });

  // ── UserProfile 模型测试 ──────────────────────────────────────
  group('UserProfile 模型', () {
    test('toJson / fromJson 往返一致', () {
      final profile = _makeProfile();
      final json = profile.toJson();
      final restored = UserProfile.fromJson(json);

      expect(restored.assetRange, equals(profile.assetRange));
      expect(restored.goals, equals(profile.goals));
      expect(restored.riskReaction, equals(profile.riskReaction));
    });

    test('toPromptSnippet 包含所有档案字段', () {
      final snippet = _makeProfile().toPromptSnippet();
      expect(snippet, contains('200-500万'));
      expect(snippet, contains('稳健增值'));
      expect(snippet, contains('养老规划'));
      expect(snippet, contains('稳健型'));
    });

    test('toPromptSnippet token 估算 < 100', () {
      final snippet = _makeProfile().toPromptSnippet();
      expect(_est(snippet), lessThan(100));
    });
  });

  // ── ConversationStage 枚举测试 ────────────────────────────────
  group('ConversationStage', () {
    test('4个阶段均有非空 promptHint', () {
      for (final stage in ConversationStage.values) {
        expect(stage.promptHint, isNotEmpty);
      }
    });

    test('不同阶段的 promptHint 各不相同', () {
      final hints = ConversationStage.values.map((s) => s.promptHint).toList();
      expect(hints.toSet().length, equals(ConversationStage.values.length));
    });
  });
}
