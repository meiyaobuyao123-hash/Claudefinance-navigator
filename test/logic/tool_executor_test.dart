// M05 Tool Use — ToolExecutor + ClaudeAgent 单元测试
// 严格对应 PRD/TECH 验收标准：
//   AC-1: get_portfolio_summary 返回非空字符串
//   AC-2: API 超时 → 返回 {error: fetch_timeout, cached: true}
//   AC-3: 未知工具 → 返回 {error: unknown tool: ...}
//   AC-4: ClaudeAgent 最多3轮 tool_use 后强制返回
//   AC-5: get_portfolio_summary 空持仓 → 返回"暂无持仓数据"

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:anthropic_sdk_dart/anthropic_sdk_dart.dart';
import 'package:finance_navigator/features/ai_chat/data/tools/tool_executor.dart';
import 'package:finance_navigator/features/ai_chat/data/tools/tool_definitions.dart';
import 'package:finance_navigator/features/ai_chat/data/claude_agent.dart';
import 'package:finance_navigator/features/ai_chat/data/portfolio_context_builder.dart';
import 'package:finance_navigator/features/fund_tracker/data/models/fund_holding.dart';
import 'package:finance_navigator/features/stock_tracker/data/models/stock_holding.dart';

// ── 辅助：构建 PortfolioContextBuilder ────────────────────────
ToolExecutor _emptyExecutor() {
  return ToolExecutor(
    portfolioBuilder: const PortfolioContextBuilder(
      fundHoldings: [],
      stockHoldings: [],
    ),
  );
}

ToolExecutor _richExecutor() {
  final fund = FundHolding(
    id: 'f1',
    fundCode: '110022',
    fundName: '易方达消费行业',
    shares: 10000,
    costNav: 1.0,
    addedDate: '2025-01-01',
  );
  final stock = StockHolding(
    id: 's1',
    symbol: '600036',
    stockName: '招商银行',
    market: 'A',
    shares: 100,
    costPrice: 45.0,
    addedDate: '2025-01-01',
  );
  return ToolExecutor(
    portfolioBuilder: PortfolioContextBuilder(
      fundHoldings: [fund],
      stockHoldings: [stock],
    ),
  );
}

void main() {
  // ── ToolExecutor 测试 ─────────────────────────────────────
  group('ToolExecutor — get_portfolio_summary', () {
    test('[AC-5] 空持仓 → JSON 含"暂无持仓数据"', () async {
      final executor = _emptyExecutor();
      final result = await executor.execute(kToolPortfolioSummary, {});
      final json = jsonDecode(result) as Map<String, dynamic>;
      expect(json['summary'], contains('暂无持仓数据'));
    });

    test('[AC-1] 有持仓 → 返回非空字符串，含持仓快照内容', () async {
      final executor = _richExecutor();
      final result = await executor.execute(kToolPortfolioSummary, {});
      expect(result, isNotEmpty);
      final json = jsonDecode(result) as Map<String, dynamic>;
      expect(json['summary'], isNotEmpty);
      expect(json['summary'], contains('持仓快照'));
    });

    test('返回值是合法 JSON 字符串', () async {
      final executor = _richExecutor();
      final result = await executor.execute(kToolPortfolioSummary, {});
      expect(() => jsonDecode(result), returnsNormally);
    });
  });

  group('ToolExecutor — 未知工具', () {
    test('[AC-3] unknown_tool → JSON 含"unknown tool"', () async {
      final executor = _emptyExecutor();
      final result = await executor.execute('unknown_tool', {});
      final json = jsonDecode(result) as Map<String, dynamic>;
      expect(json['error'], contains('unknown tool'));
      expect(json['error'], contains('unknown_tool'));
    });
  });

  group('ToolExecutor — get_market_rates 超时降级', () {
    test('[AC-2] 超时 → 返回 {error: fetch_timeout, cached: true}', () async {
      // 注入一个模拟超时的 fetcher（直接抛出 TimeoutException）
      final executor = ToolExecutor(
        portfolioBuilder: const PortfolioContextBuilder(
          fundHoldings: [],
          stockHoldings: [],
        ),
        marketRatesFetcher: () async {
          throw Exception('timeout');
        },
      );
      final result = await executor.execute(kToolMarketRates, {
        'symbols': ['GOLD'],
      });
      final json = jsonDecode(result) as Map<String, dynamic>;
      expect(json['error'], equals('fetch_timeout'));
      expect(json['cached'], isTrue);
    });

    test('正常返回 → JSON 含 timestamp 和 data 字段', () async {
      final executor = ToolExecutor(
        portfolioBuilder: const PortfolioContextBuilder(
          fundHoldings: [],
          stockHoldings: [],
        ),
        marketRatesFetcher: () async => {
          'gold': {'current': 628.5, 'changeRate': 0.3},
          'csi300': {'current': 3.95, 'changeRate': -0.1},
          'money_fund_7d_yield': 1.75,
        },
      );
      final result = await executor.execute(kToolMarketRates, {
        'symbols': ['GOLD', 'CSI300'],
      });
      final json = jsonDecode(result) as Map<String, dynamic>;
      expect(json['timestamp'], isNotNull);
      expect(json['data'], isNotNull);
      expect((json['data'] as Map)['gold'], isNotNull);
    });
  });

  group('ToolExecutor — get_fund_detail（V1.1 占位）', () {
    test('返回 V1.1 占位错误提示', () async {
      final executor = _emptyExecutor();
      final result = await executor.execute(kToolFundDetail, {
        'fund_code': '110022',
      });
      final json = jsonDecode(result) as Map<String, dynamic>;
      expect(json['fund_code'], equals('110022'));
      expect(json['error'], isNotEmpty);
    });
  });

  // ── ClaudeAgent 测试 ─────────────────────────────────────
  group('ClaudeAgent — 3轮上限', () {
    test('[AC-4] tool_use 循环超过3轮后强制返回兜底文本', () async {
      var callCount = 0;

      // 模拟 API 永远返回 tool_use（不收敛）
      final agent = ClaudeAgent(
        toolExecutor: ToolExecutor(
          portfolioBuilder: const PortfolioContextBuilder(
            fundHoldings: [],
            stockHoldings: [],
          ),
          marketRatesFetcher: () async => {},
        ),
        apiCaller: ({
          required apiKey,
          required systemPrompt,
          required messages,
          required tools,
        }) async {
          callCount++;
          return Message(
            id: 'msg_$callCount',
            type: 'message',
            role: MessageRole.assistant,
            model: 'claude-sonnet-4-20250514',
            content: [
              ToolUseBlock(
                id: 'tu_$callCount',
                name: kToolPortfolioSummary,
                input: {},
              ),
            ],
            stopReason: StopReason.toolUse,
            usage: const Usage(inputTokens: 10, outputTokens: 10),
          );
        },
      );

      final result = await agent.run(
        systemPrompt: '测试',
        history: [
          {'role': 'user', 'content': '测试'}
        ],
        apiKey: 'test-key',
      );

      // 最多调用3次，然后返回兜底文本
      expect(callCount, equals(3));
      expect(result, contains('抱歉'));
    });

    test('首次返回 end_turn → 直接返回文本，只调用1次', () async {
      var callCount = 0;

      final agent = ClaudeAgent(
        toolExecutor: _emptyExecutor(),
        apiCaller: ({
          required apiKey,
          required systemPrompt,
          required messages,
          required tools,
        }) async {
          callCount++;
          return Message(
            id: 'msg_1',
            type: 'message',
            role: MessageRole.assistant,
            model: 'claude-sonnet-4-20250514',
            content: [TextBlock(text: '这是最终回复')],
            stopReason: StopReason.endTurn,
            usage: const Usage(inputTokens: 10, outputTokens: 10),
          );
        },
      );

      final result = await agent.run(
        systemPrompt: '测试',
        history: [
          {'role': 'user', 'content': '你好'}
        ],
        apiKey: 'test-key',
      );

      expect(callCount, 1);
      expect(result, equals('这是最终回复'));
    });

    test('第2轮 end_turn → 调用2次，返回正确文本', () async {
      var callCount = 0;

      final agent = ClaudeAgent(
        toolExecutor: ToolExecutor(
          portfolioBuilder: const PortfolioContextBuilder(
            fundHoldings: [],
            stockHoldings: [],
          ),
          marketRatesFetcher: () async => {'data': 'mock'},
        ),
        apiCaller: ({
          required apiKey,
          required systemPrompt,
          required messages,
          required tools,
        }) async {
          callCount++;
          if (callCount == 1) {
            return Message(
              id: 'msg_1',
              type: 'message',
              role: MessageRole.assistant,
              model: 'claude-sonnet-4-20250514',
              content: [
                ToolUseBlock(
                  id: 'tu_1',
                  name: kToolMarketRates,
                  input: {'symbols': ['GOLD']},
                ),
              ],
              stopReason: StopReason.toolUse,
              usage: const Usage(inputTokens: 10, outputTokens: 10),
            );
          }
          return Message(
            id: 'msg_2',
            type: 'message',
            role: MessageRole.assistant,
            model: 'claude-sonnet-4-20250514',
            content: [TextBlock(text: '黄金当前价格为628元/克')],
            stopReason: StopReason.endTurn,
            usage: const Usage(inputTokens: 20, outputTokens: 15),
          );
        },
      );

      final result = await agent.run(
        systemPrompt: '你是理财顾问',
        history: [
          {'role': 'user', 'content': '黄金多少钱'}
        ],
        apiKey: 'test-key',
      );

      expect(callCount, 2);
      expect(result, contains('黄金'));
    });
  });
}
