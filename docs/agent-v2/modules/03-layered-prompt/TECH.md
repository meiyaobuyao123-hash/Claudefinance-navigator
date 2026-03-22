# M03 分层 Prompt 架构 — 技术实现文档

> 版本：v1.0 | 最后更新：2026-03-22

---

## 1. 核心类设计

```dart
// lib/features/ai_chat/data/prompt_builder.dart

class PromptBuilder {
  static const int _maxTotalTokens = 1200;

  final UserProfile? userProfile;
  final Map<String, double>? marketRates;
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

  String build(String userMessage) {
    final layers = [
      _layer1Persona(),
      _layer2MarketData(),
      _layer3UserProfile(),
      _layer4Portfolio(userMessage),
      _layer5ConversationStage(),
    ].where((l) => l.isNotEmpty).toList();

    return layers.join('\n\n');
  }

  // Layer 1: 人格层（~500 token，固定不裁剪）
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
- 提供法律/税务专业建议''';

  // Layer 2: 市场数据层（~200 token，15min TTL）
  String _layer2MarketData() {
    if (marketRates == null || marketRates!.isEmpty) return '';
    final buffer = StringBuffer('【今日市场参考】\n');
    if (marketRates!['moneyFund7d'] != null) {
      buffer.writeln('货币基金7日年化：${marketRates!['moneyFund7d']!.toStringAsFixed(2)}%');
    }
    if (marketRates!['csi300'] != null) {
      buffer.writeln('沪深300：${marketRates!['csi300']!.toStringAsFixed(2)}');
    }
    if (marketRates!['gold'] != null) {
      buffer.writeln('黄金Au9999：¥${marketRates!['gold']!.toStringAsFixed(2)}/g');
    }
    return buffer.toString().trim();
  }

  // Layer 3: 用户档案层（~300 token）
  String _layer3UserProfile() {
    if (userProfile == null) return '';
    return userProfile!.toPromptSnippet();
  }

  // Layer 4: 持仓快照层（~100-150 token，按需注入）
  String _layer4Portfolio(String userMessage) {
    final builder = PortfolioContextBuilder(
      fundHoldings: fundHoldings,
      stockHoldings: stockHoldings,
    );
    return builder.shouldInjectFull(userMessage)
        ? builder.buildFullSnapshot()
        : builder.buildSummaryOnly();
  }

  // Layer 5: 对话阶段层（~100 token）
  String _layer5ConversationStage() => stage.promptHint;
}
```

---

## 2. ConversationStage 对话阶段（M04 预留接口）

```dart
enum ConversationStage {
  exploring,  // 探索阶段：收集用户情况
  deepening,  // 深化阶段：深入分析某个主题
  actioning,  // 行动阶段：给出具体建议步骤
  reviewing,  // 复盘阶段：回顾决策结果
}

extension ConversationStageExtension on ConversationStage {
  String get promptHint => switch (this) {
    ConversationStage.exploring  => '当前阶段：了解用户情况。优先提问，每次最多问1-2个问题，不要急于给建议。',
    ConversationStage.deepening  => '当前阶段：深入分析。用户已提供足够信息，开始给出有深度的分析。',
    ConversationStage.actioning  => '当前阶段：行动建议。给出清晰的行动步骤，以"你可以..."为句式开头。',
    ConversationStage.reviewing  => '当前阶段：复盘总结。帮助用户回顾之前的决策，客观评估结果。',
  };
}
```

---

## 3. 接入 ai_chat_page.dart

```dart
// 在 _sendMessage() 中替换原有 systemPrompt 字符串

final promptBuilder = PromptBuilder(
  userProfile: ref.read(userProfileNotifierProvider),
  marketRates: ref.read(marketRatesProvider).valueOrNull,
  fundHoldings: ref.read(fundHoldingsProvider),
  stockHoldings: ref.read(stockHoldingsProvider),
  stage: ref.read(conversationStageProvider),
);

final systemPrompt = promptBuilder.build(userInput);

// 替换原有 history 中的 system 消息
final messages = [
  {'role': 'user', 'content': '<system>$systemPrompt</system>\n$userInput'},
  ...previousMessages,
];
```

> **注意**：Anthropic Messages API 的 `system` 字段是独立参数，不在 messages 数组中。

```dart
final response = await http.post(
  Uri.parse('https://api.anthropic.com/v1/messages'),
  headers: {
    'x-api-key': apiKey,
    'anthropic-version': '2023-06-01',
    'content-type': 'application/json',
  },
  body: jsonEncode({
    'model': 'claude-sonnet-4-20250514',
    'max_tokens': 1024,
    'system': systemPrompt,   // ← 独立参数
    'messages': history,
  }),
);
```

---

## 4. Token 预算监控（开发阶段）

```dart
// 仅在 debug 模式下打印 token 分布
void _debugTokenUsage(PromptBuilder builder, String userMessage) {
  if (!kDebugMode) return;
  // 粗略估算：1 token ≈ 4 英文字符 ≈ 1.5 中文字符
  int estimateTokens(String text) => (text.length / 1.5).round();

  debugPrint('=== Prompt Token 分布 ===');
  debugPrint('人格层: ${estimateTokens(builder._layer1Persona())} token');
  debugPrint('市场层: ${estimateTokens(builder._layer2MarketData())} token');
  debugPrint('用户档案: ${estimateTokens(builder._layer3UserProfile())} token');
  debugPrint('持仓快照: ${estimateTokens(builder._layer4Portfolio(userMessage))} token');
  debugPrint('对话阶段: ${estimateTokens(builder._layer5ConversationStage())} token');
}
```

---

## 5. 测试计划

| 用例 | 预期结果 |
|------|---------|
| 无持仓、无用户档案 | 只有Layer1 + 可能Layer2，< 700 token |
| 有用户档案，无持仓关键词 | Layer1+2+3，摘要持仓，< 1000 token |
| 有持仓关键词 | Layer1+2+3+4（完整），< 1200 token |
| market rates 为 null | Layer2 返回空字符串，不报错 |

---

## 6. 文件清单

```
lib/features/ai_chat/data/
├── prompt_builder.dart           # 分层构建器（本模块核心）
└── portfolio_context_builder.dart  # M02 持仓快照（已有）

test/logic/
└── prompt_builder_test.dart
```
