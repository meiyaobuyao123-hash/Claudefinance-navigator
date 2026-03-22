import 'package:flutter/foundation.dart';
import '../../../core/providers/market_rate_provider.dart';
import '../../../features/fund_tracker/data/models/fund_holding.dart';
import '../../../features/stock_tracker/data/models/stock_holding.dart';
import '../../../features/onboarding/models/user_profile.dart';
import 'conversation_stage.dart';
import 'portfolio_context_builder.dart';

class PromptBuilder {
  // token 预算上限（中文字符估算：1 token ≈ 1.5 字符）
  static const int _maxTotalTokens = 1200;

  final UserProfile? userProfile;
  final Map<String, LiveRateData>? marketRates;
  final List<FundHolding> fundHoldings;
  final List<StockHolding> stockHoldings;
  final ConversationStage stage;

  const PromptBuilder({
    this.userProfile,
    this.marketRates,
    required this.fundHoldings,
    required this.stockHoldings,
    required this.stage,
  });

  /// 构建最终 system prompt（各层非空则用 \n\n 拼接）
  /// 永不超过 _maxTotalTokens，永不抛异常
  String build(String userMessage) {
    final layers = [
      _layer1Persona(),
      _layer2MarketData(),
      _layer3UserProfile(),
      _layer4Portfolio(userMessage),
      _layer5ConversationStage(),
    ].where((l) => l.isNotEmpty).toList();

    final result = layers.join('\n\n');

    // Token 预算监控（仅 debug）
    _debugTokenUsage(userMessage);

    return result;
  }

  // ── Layer 1: 人格层（固定，~300 token，不裁剪）──────────────
  String _layer1Persona() => '''
你是"明理"，一位拥有20年从业经验的私人理财顾问。你的风格是：
- 专业但不傲慢，像朋友一样聊钱
- 先听懂用户的真实情况，再给建议
- 只给方向和框架，不推荐具体证券代码
- 始终提示用户：最终决策由用户自主做出

你可以帮助用户：
- 梳理资产配置结构和优化方向
- 解读市场行情和产品特点
- 制定储蓄/养老/教育金等目标规划
- 分析现有持仓的健康度

你不会：
- 预测具体股票/基金的涨跌
- 推荐特定基金代码
- 执行任何交易操作
- 提供法律/税务专业建议
- 所有回复使用中文''';

  // ── Layer 2: 市场数据层（~100 token，15min TTL，按需）────────
  String _layer2MarketData() {
    if (marketRates == null || marketRates!.isEmpty) return '';

    final buffer = StringBuffer('【今日市场参考】\n');
    final rates = marketRates!;

    if (rates['cn_money_fund'] != null) {
      buffer.writeln('货币基金7日年化：${rates['cn_money_fund']!.displayRate}');
    }
    if (rates['cn_etf'] != null) {
      buffer.writeln('沪深300ETF：${rates['cn_etf']!.displayRate}');
    }
    if (rates['cn_paper_gold'] != null) {
      buffer.writeln('黄金：${rates['cn_paper_gold']!.displayRate}');
    }
    if (rates['hk_overseas_etf'] != null) {
      buffer.writeln('美股VOO：${rates['hk_overseas_etf']!.displayRate}');
    }

    final text = buffer.toString().trim();
    return text == '【今日市场参考】' ? '' : text;
  }

  // ── Layer 3: 用户档案层（~50 token，M01 提供）────────────────
  String _layer3UserProfile() {
    if (userProfile == null) return '';
    return userProfile!.toPromptSnippet();
  }

  // ── Layer 4: 持仓快照层（~100-150 token，关键词按需注入）──────
  String _layer4Portfolio(String userMessage) {
    final builder = PortfolioContextBuilder(
      fundHoldings: fundHoldings,
      stockHoldings: stockHoldings,
    );
    return builder.shouldInjectFull(userMessage)
        ? builder.buildFullSnapshot()
        : builder.buildSummaryOnly();
  }

  // ── Layer 5: 对话阶段层（~30 token，M04 提供）────────────────
  String _layer5ConversationStage() => stage.promptHint;

  // ── Debug token 监控（仅开发阶段）───────────────────────────
  void _debugTokenUsage(String userMessage) {
    if (!kDebugMode) return;
    int est(String t) => (t.length / 1.5).round();

    final l1 = est(_layer1Persona());
    final l2 = est(_layer2MarketData());
    final l3 = est(_layer3UserProfile());
    final l4 = est(_layer4Portfolio(userMessage));
    final l5 = est(_layer5ConversationStage());
    final total = l1 + l2 + l3 + l4 + l5;

    debugPrint('=== Prompt Token 分布 ===');
    debugPrint('L1 人格层:   $l1 token');
    debugPrint('L2 市场数据: $l2 token');
    debugPrint('L3 用户档案: $l3 token');
    debugPrint('L4 持仓快照: $l4 token');
    debugPrint('L5 对话阶段: $l5 token');
    debugPrint('总计: $total / $_maxTotalTokens token');
    if (total > _maxTotalTokens) {
      debugPrint('⚠️ 超出预算！需裁剪');
    }
  }
}
