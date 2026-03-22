/// [M05] Tool 执行器
/// MVP：get_market_rates + get_portfolio_summary
/// V1.1：get_fund_detail
import 'dart:convert';
import '../../../../core/services/market_rate_service.dart';
import '../portfolio_context_builder.dart';
import 'tool_definitions.dart';

class ToolExecutor {
  final PortfolioContextBuilder portfolioBuilder;

  /// 可注入自定义行情获取函数（用于单元测试时 mock，生产默认调用 MarketRateService）
  final Future<Map<String, dynamic>> Function()? _marketRatesFetcher;

  const ToolExecutor({
    required this.portfolioBuilder,
    Future<Map<String, dynamic>> Function()? marketRatesFetcher,
  }) : _marketRatesFetcher = marketRatesFetcher;

  /// 执行指定工具，返回 JSON 字符串结果
  Future<String> execute(String toolName, Map<String, dynamic> input) {
    return switch (toolName) {
      kToolMarketRates => _getMarketRates(),
      kToolPortfolioSummary => Future.value(_getPortfolioSummary()),
      kToolFundDetail => _getFundDetail(input),
      _ => Future.value(jsonEncode({'error': 'unknown tool: $toolName'})),
    };
  }

  Future<String> _getMarketRates() async {
    try {
      final fetcher = _marketRatesFetcher ?? _defaultMarketFetch;
      final data = await fetcher().timeout(const Duration(seconds: 5));
      return jsonEncode({
        'timestamp': DateTime.now().toIso8601String(),
        'data': data,
      });
    } catch (e) {
      return jsonEncode({'error': 'fetch_timeout', 'cached': true});
    }
  }

  /// 默认行情获取：调用 MarketRateService 获取黄金/沪深300/货基利率
  static Future<Map<String, dynamic>> _defaultMarketFetch() async {
    final svc = MarketRateService();
    final results = await Future.wait([
      svc.fetchGoldPrice(),
      svc.fetchETFQuote('sz510300'),
      svc.fetchMoneyFundYield('000198'),
    ]);
    return {
      'gold': results[0] ?? {'error': 'unavailable'},
      'csi300': results[1] ?? {'error': 'unavailable'},
      'money_fund_7d_yield': results[2],
    };
  }

  String _getPortfolioSummary() {
    final snapshot = portfolioBuilder.buildFullSnapshot();
    if (snapshot.isEmpty) return jsonEncode({'summary': '暂无持仓数据'});
    return jsonEncode({'summary': snapshot});
  }

  Future<String> _getFundDetail(Map<String, dynamic> input) async {
    // V1.1 功能，当前返回占位符
    final code = input['fund_code'] as String? ?? '';
    return jsonEncode({
      'fund_code': code,
      'error': 'get_fund_detail 功能将在 V1.1 版本中实现',
    });
  }
}
