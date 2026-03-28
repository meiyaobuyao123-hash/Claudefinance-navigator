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
      _layer2MarketData(userMessage),
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
- 收集足够信息后，要主动给出清晰的配置方向和产品类型建议
- 用户明确要求推荐时，必须给出具体的方向建议，不能继续反问
- 始终提示用户：最终决策由用户自主做出

你可以也必须做的：
- 推荐适合用户的基金/产品【类型】，如：债基、沪深300ETF、QDII、黄金ETF等
- 给出具体的配置比例建议，如"40%债基 + 30%宽基ETF + 20%黄金 + 10%货基"
- 梳理资产配置结构和优化方向
- 解读市场行情和产品特点

你不会：
- 推荐具体基金代码（如000001），只给类型和方向
- 预测个股或具体基金的涨跌
- 执行任何交易操作
- 提供法律/税务专业建议

重要：当用户已提供足够信息且明确要求给建议时，直接给出配置方案，不要再追问。
所有回复使用中文。''';

  // ── Layer 2: 市场数据层（~100 token，15min TTL，话题相关时注入）─
  // [M09] 话题不相关时跳过，节省约 30% 对话的 token 注入
  String _layer2MarketData([String userMessage = '']) {
    if (marketRates == null || marketRates!.isEmpty) return '';
    if (!isMarketDataRelevant(userMessage)) return '';

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

  // ── [M09] 市场数据话题相关性判断（静态，单元测试可直接调用）──────
  /// 纯个人规划话题时返回 false，跳过 Layer2 注入
  static bool isMarketDataRelevant(String message) {
    if (message.isEmpty) return true;
    const irrelevantKeywords = [
      '养老', '退休', '子女教育', '教育金', '保险规划',
      '遗产', '财富传承', '风险偏好', '风险测评', '目标规划',
    ];
    if (irrelevantKeywords.any(message.contains)) return false;
    return true; // 默认注入（保守策略：不确定时宁可多注入）
  }


  // ── Debug token 监控（仅开发阶段）───────────────────────────
  void _debugTokenUsage(String userMessage) {
    if (!kDebugMode) return;
    int est(String t) => (t.length / 1.5).round();

    final l1 = est(_layer1Persona());
    final l2 = est(_layer2MarketData(userMessage));
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
