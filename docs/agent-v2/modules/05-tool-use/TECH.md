# M05 Tool Use 混合触发架构 — 技术实现文档

> 版本：v1.0 | 最后更新：2026-03-22

---

## 1. 工具定义（Anthropic Tool Use 格式）

```dart
// lib/features/ai_chat/data/tools/tool_definitions.dart

const List<Map<String, dynamic>> kToolDefinitions = [
  {
    'name': 'get_market_rates',
    'description': '获取实时市场行情，包括A股指数、黄金价格、货币基金7日年化利率等',
    'input_schema': {
      'type': 'object',
      'properties': {
        'symbols': {
          'type': 'array',
          'items': {'type': 'string'},
          'description': '需要查询的标的，如 ["CSI300", "GOLD", "MONEY_FUND"]',
        },
      },
      'required': ['symbols'],
    },
  },
  {
    'name': 'get_portfolio_summary',
    'description': '获取用户当前持仓摘要，包括基金和股票的持仓情况和收益',
    'input_schema': {
      'type': 'object',
      'properties': {},
      'required': [],
    },
  },
  {
    'name': 'get_fund_detail',
    'description': '获取某支基金的详细信息',
    'input_schema': {
      'type': 'object',
      'properties': {
        'fund_code': {
          'type': 'string',
          'description': '基金代码，如 005827',
        },
      },
      'required': ['fund_code'],
    },
  },
];
```

---

## 2. 工具执行器

```dart
// lib/features/ai_chat/data/tools/tool_executor.dart

class ToolExecutor {
  final MarketRateService marketRateService;
  final PortfolioContextBuilder portfolioBuilder;
  final FundApiService fundApiService;

  const ToolExecutor({
    required this.marketRateService,
    required this.portfolioBuilder,
    required this.fundApiService,
  });

  Future<String> execute(String toolName, Map<String, dynamic> input) async {
    return switch (toolName) {
      'get_market_rates'     => await _getMarketRates(input),
      'get_portfolio_summary' => _getPortfolioSummary(),
      'get_fund_detail'      => await _getFundDetail(input),
      _                      => '{"error": "unknown tool: $toolName"}',
    };
  }

  Future<String> _getMarketRates(Map<String, dynamic> input) async {
    try {
      final rates = await marketRateService.fetchAll()
          .timeout(const Duration(seconds: 5));
      return jsonEncode({
        'timestamp': DateTime.now().toIso8601String(),
        'data': rates,
      });
    } catch (e) {
      return jsonEncode({'error': 'fetch_timeout', 'cached': true});
    }
  }

  String _getPortfolioSummary() {
    return portfolioBuilder.buildFullSnapshot();
  }

  Future<String> _getFundDetail(Map<String, dynamic> input) async {
    final code = input['fund_code'] as String;
    final detail = await fundApiService.fetchFundInfo(code);
    return jsonEncode(detail?.toJson() ?? {'error': 'fund_not_found'});
  }
}
```

---

## 3. 规则触发层（Rule-Based Pre-trigger）

```dart
// lib/features/ai_chat/data/tools/rule_trigger.dart

class RuleTrigger {
  /// 根据用户消息判断应预先执行哪些工具
  static List<String> getTriggeredTools(String message) {
    final triggered = <String>[];

    const marketKeywords = ['黄金', 'A股', '沪深', '港股', '美股', '行情', '涨跌', '指数', '货基', '利率'];
    if (marketKeywords.any(message.contains)) {
      triggered.add('get_market_rates');
    }

    const portfolioKeywords = ['我的持仓', '我的基金', '我的股票', '我的配置', '帮我看看', '我现在'];
    if (portfolioKeywords.any(message.contains)) {
      triggered.add('get_portfolio_summary');
    }

    return triggered;
  }
}
```

---

## 4. AI Tool Use 循环（Agentic Loop）

```dart
// lib/features/ai_chat/data/claude_agent.dart

class ClaudeAgent {
  final ToolExecutor toolExecutor;

  Future<String> run({
    required String systemPrompt,
    required List<Map<String, String>> history,
    required String apiKey,
  }) async {
    var messages = List<Map<String, dynamic>>.from(history);

    // 最多3轮 tool 调用，防止无限循环
    for (int i = 0; i < 3; i++) {
      final response = await _callAPI(
        systemPrompt: systemPrompt,
        messages: messages,
        apiKey: apiKey,
        tools: kToolDefinitions,
      );

      if (response.stopReason == 'tool_use') {
        // 执行所有 tool_use block
        final toolResults = <Map<String, dynamic>>[];
        for (final block in response.toolUseBlocks) {
          final result = await toolExecutor.execute(block.name, block.input);
          toolResults.add({
            'type': 'tool_result',
            'tool_use_id': block.id,
            'content': result,
          });
        }

        // 将 tool 结果追加到 messages
        messages.add({'role': 'assistant', 'content': response.content});
        messages.add({'role': 'user', 'content': toolResults});
        continue;
      }

      // stop_reason == 'end_turn' → 最终回复
      return response.textContent;
    }

    return '抱歉，我遇到了一些问题，请稍后再试。';
  }
}
```

---

## 5. 与流式输出的兼容性（M06 预留）

Tool Use 和 Streaming 在 Anthropic API 中可以同时使用：
- 流式响应中，`tool_use` block 会以 delta 形式流出
- 但 Tool 执行本身必须等待完整 `tool_use` block 收集完才能开始
- **实现策略**：接收到 `stop_reason: tool_use` 时暂停流式，执行工具，再继续流式

---

## 6. 测试计划

| 用例 | 预期 |
|------|------|
| `RuleTrigger.getTriggeredTools("黄金多少钱")` | `["get_market_rates"]` |
| `ToolExecutor.execute("get_portfolio_summary", {})` | 返回非空字符串 |
| API 超时 → 降级返回 cached: true | 故障注入验证 |
| 3轮 tool_use 循环后强制返回 | 边界测试 |

---

## 7. 文件清单

```
lib/features/ai_chat/data/tools/
├── tool_definitions.dart
├── tool_executor.dart
└── rule_trigger.dart

lib/features/ai_chat/data/
└── claude_agent.dart

test/logic/
├── rule_trigger_test.dart
└── tool_executor_test.dart
```
