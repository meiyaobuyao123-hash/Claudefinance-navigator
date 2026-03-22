// M09 Token 优化 — TokenMonitor + PromptBuilder市场数据过滤 单元测试
// 严格对应 PRD/TECH 验收标准：
//   AC-1: 问"养老规划"，Layer2 market data 为空（不注入）
//   AC-2: 问"黄金涨了吗"，Layer2 market data 非空
//   AC-3: TokenMonitor.savingPercent 正确计算节省百分比
//   AC-4: TokenMonitor.hasCacheHit 正确判断缓存命中
//   AC-5: 无关键词时默认注入（保守策略）

import 'package:flutter_test/flutter_test.dart';
import 'package:finance_navigator/features/ai_chat/data/token_monitor.dart';
import 'package:finance_navigator/features/ai_chat/data/prompt_builder.dart';
import 'package:finance_navigator/features/ai_chat/data/conversation_stage.dart';
import 'package:finance_navigator/core/providers/market_rate_provider.dart';

// 构建带市场数据的 PromptBuilder
PromptBuilder _builderWithMarket(String userMessage) {
  return PromptBuilder(
    userProfile: null,
    marketRates: {
      'cn_money_fund': LiveRateData(
        displayRate: '7日年化 1.75%',
        updatedAt: DateTime.now(),
      ),
    },
    fundHoldings: const [],
    stockHoldings: const [],
    stage: ConversationStage.exploring,
  );
}

void main() {
  // ── PromptBuilder 市场数据话题过滤（M09 AC-1/AC-2/AC-5）──────
  group('PromptBuilder.isMarketDataRelevant', () {
    test('[AC-1] "养老规划" → false（不注入）', () {
      expect(PromptBuilder.isMarketDataRelevant('我想做养老规划'), isFalse);
    });

    test('[AC-1] "退休" → false', () {
      expect(PromptBuilder.isMarketDataRelevant('我快退休了怎么配置'), isFalse);
    });

    test('[AC-1] "子女教育" → false', () {
      expect(PromptBuilder.isMarketDataRelevant('子女教育金怎么规划'), isFalse);
    });

    test('[AC-1] "教育金" → false', () {
      expect(PromptBuilder.isMarketDataRelevant('帮我规划教育金'), isFalse);
    });

    test('[AC-1] "风险偏好" → false', () {
      expect(PromptBuilder.isMarketDataRelevant('我想了解我的风险偏好'), isFalse);
    });

    test('[AC-1] "遗产" → false', () {
      expect(PromptBuilder.isMarketDataRelevant('遗产规划怎么做'), isFalse);
    });

    test('[AC-1] "财富传承" → false', () {
      expect(PromptBuilder.isMarketDataRelevant('财富传承有哪些工具'), isFalse);
    });

    test('[AC-2] "黄金涨了吗" → true（注入）', () {
      expect(PromptBuilder.isMarketDataRelevant('黄金最近涨了吗'), isTrue);
    });

    test('[AC-2] "沪深300" → true', () {
      expect(PromptBuilder.isMarketDataRelevant('沪深300今天多少'), isTrue);
    });

    test('[AC-5] 空字符串 → true（默认注入）', () {
      expect(PromptBuilder.isMarketDataRelevant(''), isTrue);
    });

    test('[AC-5] 无关键词普通消息 → true（默认注入）', () {
      expect(PromptBuilder.isMarketDataRelevant('我有300万怎么配置'), isTrue);
    });

    test('[AC-5] 一般理财问题 → true', () {
      expect(PromptBuilder.isMarketDataRelevant('货币基金和债券有什么区别'), isTrue);
    });
  });

  group('PromptBuilder.build — 市场数据按需注入', () {
    test('[AC-1] "养老规划"消息 → build 结果不含市场数据', () {
      final builder = _builderWithMarket('我想做养老规划');
      final prompt = builder.build('我想做养老规划');
      expect(prompt, isNot(contains('今日市场参考')));
    });

    test('[AC-2] "黄金多少钱"消息 → build 结果含市场数据', () {
      final builder = _builderWithMarket('黄金最近多少钱');
      final prompt = builder.build('黄金最近多少钱');
      expect(prompt, contains('今日市场参考'));
    });
  });

  // ── TokenMonitor 工具函数测试 ─────────────────────────────────
  group('TokenMonitor.savingPercent', () {
    test('[AC-3] 无缓存命中 → 节省0%', () {
      final usage = {
        'input_tokens': 1000,
        'output_tokens': 200,
        'cache_read_input_tokens': 0,
        'cache_creation_input_tokens': 0,
      };
      expect(TokenMonitor.savingPercent(usage), closeTo(0.0, 0.01));
    });

    test('[AC-3] 全部缓存命中 → 节省90%', () {
      final usage = {
        'input_tokens': 0,
        'output_tokens': 200,
        'cache_read_input_tokens': 1000,
        'cache_creation_input_tokens': 0,
      };
      // 节省 = 1000 * 0.9 / (0 + 1000) * 100 = 90%
      expect(TokenMonitor.savingPercent(usage), closeTo(90.0, 0.1));
    });

    test('[AC-3] 混合场景（500 input + 500 cache_read）→ 节省约45%', () {
      final usage = {
        'input_tokens': 500,
        'output_tokens': 100,
        'cache_read_input_tokens': 500,
        'cache_creation_input_tokens': 800,
      };
      // 节省 = 500 * 0.9 / (500 + 500) * 100 = 45%
      expect(TokenMonitor.savingPercent(usage), closeTo(45.0, 0.1));
    });

    test('空 usage → 节省0%', () {
      expect(TokenMonitor.savingPercent({'input_tokens': 0}), 0.0);
    });
  });

  group('TokenMonitor.hasCacheHit', () {
    test('[AC-4] cache_read > 0 → true', () {
      expect(TokenMonitor.hasCacheHit({'cache_read_input_tokens': 500}), isTrue);
    });

    test('[AC-4] cache_read = 0 → false', () {
      expect(TokenMonitor.hasCacheHit({'cache_read_input_tokens': 0}), isFalse);
    });

    test('[AC-4] 缺失字段 → false', () {
      expect(TokenMonitor.hasCacheHit({}), isFalse);
    });
  });

  group('TokenMonitor.logUsage — 不崩溃', () {
    test('null usage → 不崩溃', () {
      expect(() => TokenMonitor.logUsage(null), returnsNormally);
    });

    test('完整 usage map → 不崩溃', () {
      expect(
        () => TokenMonitor.logUsage({
          'input_tokens': 800,
          'output_tokens': 150,
          'cache_read_input_tokens': 600,
          'cache_creation_input_tokens': 200,
        }),
        returnsNormally,
      );
    });

    test('空 map → 不崩溃', () {
      expect(() => TokenMonitor.logUsage({}), returnsNormally);
    });
  });
}
