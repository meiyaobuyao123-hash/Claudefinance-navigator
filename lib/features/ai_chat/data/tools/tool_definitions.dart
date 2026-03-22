/// [M05] Tool Use — 工具定义（Anthropic SDK 格式）
import 'package:anthropic_sdk_dart/anthropic_sdk_dart.dart';

/// MVP 工具列表：`get_market_rates` + `get_portfolio_summary`
/// V1.1 追加：`get_fund_detail`
final List<ToolDefinition> kToolDefinitions = [
  ToolDefinition.custom(
    Tool(
      name: 'get_market_rates',
      description: '获取实时市场行情，包括A股指数、黄金价格、货币基金7日年化利率等',
      inputSchema: InputSchema(
        properties: {
          'symbols': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': '需要查询的标的，如 ["CSI300", "GOLD", "MONEY_FUND"]',
          },
        },
        required: ['symbols'],
      ),
    ),
  ),
  ToolDefinition.custom(
    Tool(
      name: 'get_portfolio_summary',
      description: '获取用户当前持仓摘要，包括基金和股票的持仓情况和收益',
      inputSchema: const InputSchema(
        properties: {},
        required: [],
      ),
    ),
  ),
  ToolDefinition.custom(
    Tool(
      name: 'get_fund_detail',
      description: '获取某支基金的详细信息',
      inputSchema: InputSchema(
        properties: {
          'fund_code': {
            'type': 'string',
            'description': '基金代码，如 005827',
          },
        },
        required: ['fund_code'],
      ),
    ),
  ),
];

/// 工具名称常量
const kToolMarketRates = 'get_market_rates';
const kToolPortfolioSummary = 'get_portfolio_summary';
const kToolFundDetail = 'get_fund_detail';
