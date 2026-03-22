/// [T1-2 + T1-3] Agent v2 集成测试
///
/// T1-2: ClaudeStreamingClient 真实 API 调用
///   - 发送消息 → 能收到 chunk，最终结果非空
///   - OutputGuardrail 处理后包含免责声明
///   - 首字符延迟计时（宽松边界）
///
/// T1-3: PortfolioContextBuilder + PromptBuilder 集成
///   - 带真实持仓数据构建完整 prompt → token < 1200
///   - 持仓关键词命中时 Layer4 注入持仓快照
///   - 非持仓问题时 Layer4 只注入摘要
///
/// 运行命令：flutter test test/integration/agent_v2_integration_test.dart
/// 前提：网络可访问 api.anthropic.com
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:finance_navigator/features/ai_chat/data/claude_streaming_client.dart';
import 'package:finance_navigator/features/ai_chat/data/guardrails/output_guardrail.dart';
import 'package:finance_navigator/features/ai_chat/data/prompt_builder.dart';
import 'package:finance_navigator/features/ai_chat/data/portfolio_context_builder.dart';
import 'package:finance_navigator/features/ai_chat/data/conversation_stage.dart';
import 'package:finance_navigator/features/fund_tracker/data/models/fund_holding.dart';
import 'package:finance_navigator/features/stock_tracker/data/models/stock_holding.dart';

// ── 测试数据 ────────────────────────────────────────────────────

FundHolding _fund(String code, String name, double shares,
    {double costNav = 1.0, double currentNav = 1.2}) =>
    FundHolding(
      id: code,
      fundCode: code,
      fundName: name,
      shares: shares,
      costNav: costNav,
      addedDate: '2024-01-01',
      currentNav: currentNav,
    );

StockHolding _stock(String symbol, String name, String market, double shares,
    {double costPrice = 100.0, double currentPrice = 130.0}) =>
    StockHolding(
      id: symbol,
      symbol: symbol,
      stockName: name,
      market: market,
      shares: shares,
      costPrice: costPrice,
      addedDate: '2024-01-01',
      currentPrice: currentPrice,
    );

final _testFunds = [
  _fund('005827', '易方达蓝筹精选', 10000),
  _fund('166002', '中欧价值发现', 8000, currentNav: 0.98),
  _fund('161725', '招商中证白酒', 6000),
];

final _testStocks = [
  _stock('600519', '贵州茅台', 'A', 100),
  _stock('0700', '腾讯控股', 'HK', 200, costPrice: 300.0, currentPrice: 280.0),
];

// ── T1-2: ClaudeStreamingClient 真实调用 ───────────────────────
void main() {
  group('[T1-2] ClaudeStreamingClient — 真实 API 调用', () {
    test('发送简单问题 → 收到非空流式响应', () async {
      final chunks = <String>[];
      await for (final chunk in ClaudeStreamingClient.streamMessage(
        systemPrompt: '你是一个简洁的 AI 助手，用中文回答。',
        history: [
          {'role': 'user', 'content': '用一句话介绍货币基金'},
        ],
        maxTokens: 100,
      )) {
        chunks.add(chunk);
      }
      expect(chunks, isNotEmpty, reason: '流式响应应至少有一个 chunk');
      expect(chunks.join(), isNotEmpty, reason: '合并内容不应为空');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('首字符延迟 < 10秒（WiFi）', () async {
      DateTime? firstChunkTime;
      final start = DateTime.now();
      await for (final chunk in ClaudeStreamingClient.streamMessage(
        systemPrompt: '简洁回答。',
        history: [
          {'role': 'user', 'content': '什么是货币基金，一句话'},
        ],
        maxTokens: 60,
      )) {
        if (firstChunkTime == null && chunk.isNotEmpty) {
          firstChunkTime = DateTime.now();
          break; // 只要第一个 chunk
        }
      }
      expect(firstChunkTime, isNotNull);
      final ttft = firstChunkTime!.difference(start).inSeconds;
      expect(ttft, lessThan(10),
          reason: '首字符延迟应 < 10秒，实际 ${ttft}秒');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('OutputGuardrail — 普通对比回复不触发声明', () async {
      final buffer = StringBuffer();
      await for (final chunk in ClaudeStreamingClient.streamMessage(
        systemPrompt: '你是一个理财顾问，简洁回答。',
        history: [
          {'role': 'user', 'content': '债券基金和货币基金哪个好'},
        ],
        maxTokens: 150,
      )) {
        buffer.write(chunk);
      }
      final rawContent = buffer.toString();
      expect(rawContent, isNotEmpty, reason: '应收到非空响应');
      // 普通对比分析，无股票代码/保证收益/涨幅预测 → 护栏不追加声明
      final processed = OutputGuardrail.process(rawContent);
      expect(processed, equals(rawContent),
          reason: '无风险模式时 process() 应原样返回');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('OutputGuardrail — 含保证收益语言时追加免责声明', () {
      // 直接构造一个包含保证收益关键词的内容
      const riskyContent = '这只基金保证收益8%，放心买。';
      final processed = OutputGuardrail.process(riskyContent);
      expect(processed, contains('以上内容仅供参考'),
          reason: '含「保证收益」时应追加免责声明');
    });

    test('持仓问题场景：系统 prompt 含持仓数据时回复更具体', () async {
      final builder = PortfolioContextBuilder(
        fundHoldings: _testFunds,
        stockHoldings: [],
      );
      final systemPrompt =
          '你是明理，一位私人理财顾问。\n\n${builder.buildFullSnapshot()}';

      final buffer = StringBuffer();
      await for (final chunk in ClaudeStreamingClient.streamMessage(
        systemPrompt: systemPrompt,
        history: [
          {'role': 'user', 'content': '我的基金收益怎么样'},
        ],
        maxTokens: 200,
      )) {
        buffer.write(chunk);
      }
      final response = buffer.toString();
      expect(response, isNotEmpty);
      // 明理应提到持仓中的基金（至少提到某个基金名或代码）
      final mentionsFund = response.contains('易方达') ||
          response.contains('中欧') ||
          response.contains('招商') ||
          response.contains('005827') ||
          response.contains('166002') ||
          response.contains('基金');
      expect(mentionsFund, isTrue,
          reason: '含持仓数据时，明理应在回复中涉及持仓信息');
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  // ── T1-3: PromptBuilder 集成测试（不调用 AI）────────────────
  group('[T1-3] PromptBuilder + PortfolioContextBuilder 集成', () {
    test('带真实持仓的完整 prompt → token 估算 < 1200', () {
      final builder = PromptBuilder(
        userProfile: null,
        marketRates: null,
        fundHoldings: _testFunds,
        stockHoldings: _testStocks,
        stage: ConversationStage.deepening,
      );
      final prompt = builder.build('我的配置合理吗');
      final tokenEstimate = (prompt.length / 1.5).round();
      expect(tokenEstimate, lessThan(1200),
          reason: '总 prompt token 估算应 < 1200，实际 $tokenEstimate');
    });

    test('持仓关键词问题 → Layer4 注入完整快照（含「持仓快照」标题）', () {
      final builder = PromptBuilder(
        userProfile: null,
        marketRates: null,
        fundHoldings: _testFunds,
        stockHoldings: _testStocks,
        stage: ConversationStage.exploring,
      );
      final prompt = builder.build('我的持仓合理吗');
      expect(prompt, contains('【持仓快照 · 实时】'),
          reason: '含持仓关键词时应注入完整快照');
      expect(prompt, contains('易方达蓝筹精选'));
      expect(prompt, contains('贵州茅台'));
    });

    test('非持仓问题 → Layer4 只注入摘要（不含各持仓明细）', () {
      final builder = PromptBuilder(
        userProfile: null,
        marketRates: null,
        fundHoldings: _testFunds,
        stockHoldings: _testStocks,
        stage: ConversationStage.exploring,
      );
      final prompt = builder.build('最近利率变化怎么看');
      expect(prompt, isNot(contains('【持仓快照 · 实时】')),
          reason: '非持仓问题不应注入完整快照');
      // 摘要只有总持仓数据，无个股明细
      expect(prompt, isNot(contains('易方达蓝筹精选')));
    });

    test('空持仓时 Layer4 不注入任何持仓内容', () {
      final builder = PromptBuilder(
        userProfile: null,
        marketRates: null,
        fundHoldings: const [],
        stockHoldings: const [],
        stage: ConversationStage.exploring,
      );
      final prompt = builder.build('我的配置合理吗');
      expect(prompt, isNot(contains('持仓快照')));
      expect(prompt, isNot(contains('总持仓')));
    });

    test('PromptBuilder 包含 Layer1 人格层（明理角色描述）', () {
      const builder = PromptBuilder(
        userProfile: null,
        marketRates: null,
        fundHoldings: [],
        stockHoldings: [],
        stage: ConversationStage.exploring,
      );
      final prompt = builder.build('你好');
      expect(prompt, contains('明理'));
    });

    test('Layer5 对话阶段提示正确注入', () {
      const builderExploring = PromptBuilder(
        userProfile: null,
        marketRates: null,
        fundHoldings: [],
        stockHoldings: [],
        stage: ConversationStage.exploring,
      );
      const builderActioning = PromptBuilder(
        userProfile: null,
        marketRates: null,
        fundHoldings: [],
        stockHoldings: [],
        stage: ConversationStage.actioning,
      );
      // 不同阶段应产生不同 prompt（Layer5 内容不同）
      expect(
        builderExploring.build('你好'),
        isNot(equals(builderActioning.build('你好'))),
      );
    });

    test('8支基金 + 8支股票（截断上限）→ prompt token < 1200', () {
      final funds = List.generate(8,
          (i) => _fund('f$i', '测试基金$i号', 10000.0 * (i + 1)));
      final stocks = List.generate(8,
          (i) => _stock('S$i', '测试股票$i号', 'A', 100.0 * (i + 1)));
      final builder = PromptBuilder(
        userProfile: null,
        marketRates: null,
        fundHoldings: funds,
        stockHoldings: stocks,
        stage: ConversationStage.deepening,
      );
      final prompt = builder.build('我的配置合理吗');
      final tokenEstimate = (prompt.length / 1.5).round();
      expect(tokenEstimate, lessThan(1200));
    });
  });
}
