// M05 Tool Use — RuleTrigger 单元测试
// 严格对应 PRD/TECH 验收标准：
//   AC-1: "黄金多少钱" → ["get_market_rates"]
//   AC-2: "我的持仓" → ["get_portfolio_summary"]
//   AC-3: 同时含两类关键词 → 两个工具都触发
//   AC-4: 规则触发 < 100ms（本地判断，无网络）
//   AC-5: 无关消息 → 空列表

import 'package:flutter_test/flutter_test.dart';
import 'package:finance_navigator/features/ai_chat/data/tools/rule_trigger.dart';
import 'package:finance_navigator/features/ai_chat/data/tools/tool_definitions.dart';

void main() {
  group('RuleTrigger — 行情关键词', () {
    test('[AC-1] "黄金多少钱" → [get_market_rates]', () {
      final result = RuleTrigger.getTriggeredTools('黄金多少钱');
      expect(result, contains(kToolMarketRates));
      expect(result, isNot(contains(kToolPortfolioSummary)));
    });

    test('"A股今天涨了吗" → [get_market_rates]', () {
      final result = RuleTrigger.getTriggeredTools('A股今天涨了吗');
      expect(result, contains(kToolMarketRates));
    });

    test('"沪深300现在多少点" → [get_market_rates]', () {
      final result = RuleTrigger.getTriggeredTools('沪深300现在多少点');
      expect(result, contains(kToolMarketRates));
    });

    test('"港股最近行情怎么样" → [get_market_rates]', () {
      final result = RuleTrigger.getTriggeredTools('港股最近行情怎么样');
      expect(result, contains(kToolMarketRates));
    });

    test('"美股昨晚怎么了" → [get_market_rates]', () {
      final result = RuleTrigger.getTriggeredTools('美股昨晚怎么了');
      expect(result, contains(kToolMarketRates));
    });

    test('"货基利率是多少" → [get_market_rates]', () {
      final result = RuleTrigger.getTriggeredTools('货基利率是多少');
      expect(result, contains(kToolMarketRates));
    });

    test('"指数今天涨跌情况" → [get_market_rates]', () {
      final result = RuleTrigger.getTriggeredTools('指数今天涨跌情况');
      expect(result, contains(kToolMarketRates));
    });
  });

  group('RuleTrigger — 持仓关键词', () {
    test('[AC-2] "我的持仓怎么样" → [get_portfolio_summary]', () {
      final result = RuleTrigger.getTriggeredTools('我的持仓怎么样');
      expect(result, contains(kToolPortfolioSummary));
      expect(result, isNot(contains(kToolMarketRates)));
    });

    test('"帮我看看我的基金" → [get_portfolio_summary]', () {
      final result = RuleTrigger.getTriggeredTools('帮我看看我的基金');
      expect(result, contains(kToolPortfolioSummary));
    });

    test('"我的股票今天怎么样" → [get_portfolio_summary]', () {
      final result = RuleTrigger.getTriggeredTools('我的股票今天怎么样');
      expect(result, contains(kToolPortfolioSummary));
    });

    test('"我的配置合理吗" → [get_portfolio_summary]', () {
      final result = RuleTrigger.getTriggeredTools('我的配置合理吗');
      expect(result, contains(kToolPortfolioSummary));
    });

    test('"我现在应该怎么操作" → [get_portfolio_summary]', () {
      final result = RuleTrigger.getTriggeredTools('我现在应该怎么操作');
      expect(result, contains(kToolPortfolioSummary));
    });
  });

  group('RuleTrigger — 同时触发两个工具', () {
    test('[AC-3] "帮我看看我的基金，黄金最近行情怎样" → 两个工具', () {
      final result =
          RuleTrigger.getTriggeredTools('帮我看看我的基金，黄金最近行情怎样');
      expect(result, contains(kToolMarketRates));
      expect(result, contains(kToolPortfolioSummary));
      expect(result.length, 2);
    });

    test('"我的持仓里有A股" → 两个工具', () {
      final result = RuleTrigger.getTriggeredTools('我的持仓里有A股');
      expect(result, contains(kToolMarketRates));
      expect(result, contains(kToolPortfolioSummary));
    });
  });

  group('RuleTrigger — 无关消息', () {
    test('[AC-5] 普通问候 → 空列表', () {
      final result = RuleTrigger.getTriggeredTools('你好，明理');
      expect(result, isEmpty);
    });

    test('一般理财问题 → 空列表', () {
      final result = RuleTrigger.getTriggeredTools('货币基金和债券有什么区别');
      expect(result, isEmpty);
    });

    test('空字符串 → 空列表', () {
      final result = RuleTrigger.getTriggeredTools('');
      expect(result, isEmpty);
    });

    test('个人情况描述 → 空列表', () {
      final result = RuleTrigger.getTriggeredTools('我有300万，想稳健配置');
      expect(result, isEmpty);
    });
  });

  group('RuleTrigger — 性能测试', () {
    test('[AC-4] 规则触发耗时 < 100ms（1000次调用）', () {
      final sw = Stopwatch()..start();
      for (var i = 0; i < 1000; i++) {
        RuleTrigger.getTriggeredTools('黄金多少钱，帮我看看我的持仓');
      }
      sw.stop();
      // 1000次总耗时 < 100ms，平均 < 0.1ms/次
      expect(sw.elapsedMilliseconds, lessThan(100));
    });
  });
}
