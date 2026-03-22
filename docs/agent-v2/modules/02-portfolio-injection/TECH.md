# M02 持仓上下文注入 — 技术实现文档

> 版本：v1.0 | 最后更新：2026-03-22

---

## 1. 架构决策

| 决策 | 选择 | 原因 |
|------|------|------|
| 注入位置 | system prompt 末尾独立块 | 与人格层分离，便于更新 |
| 触发方式 | 关键词规则 + AI 标志位 | 可预测 + 覆盖边界情况 |
| 快照生成 | 客户端实时计算 | 数据已在 Riverpod，无需额外请求 |
| token 控制 | 摘要格式，每条持仓 ≤ 25 token | 控制总 prompt < 1200 token |

---

## 2. 核心接口

```dart
// lib/features/ai_chat/data/portfolio_context_builder.dart

class PortfolioContextBuilder {
  final List<FundHolding> fundHoldings;
  final List<StockHolding> stockHoldings;

  const PortfolioContextBuilder({
    required this.fundHoldings,
    required this.stockHoldings,
  });

  /// 判断是否应注入完整持仓
  bool shouldInjectFull(String userMessage) {
    const keywords = ['持仓', '基金', '股票', '配置', '合理', '建议', '收益', '亏损', '止盈', '补仓', '加仓', '减持'];
    return keywords.any((k) => userMessage.contains(k));
  }

  /// 生成完整持仓快照（约 100-150 token）
  String buildFullSnapshot() {
    if (fundHoldings.isEmpty && stockHoldings.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln('【持仓快照 · 实时】');

    if (fundHoldings.isNotEmpty) {
      final fundValue = fundHoldings.fold(0.0, (sum, h) => sum + h.currentValue);
      final fundCost = fundHoldings.fold(0.0, (sum, h) => sum + h.totalCost);
      final fundReturn = fundCost > 0 ? (fundValue - fundCost) / fundCost * 100 : 0.0;
      buffer.writeln('基金（${fundHoldings.length}支）：总市值 ${_formatWan(fundValue)}，收益 ${_formatReturn(fundReturn)}');
      for (final h in fundHoldings) {
        buffer.writeln('  - ${h.fundName}(${h.fundCode})：${_formatWan(h.currentValue)}，${_formatReturn(h.returnRate)}');
      }
    }

    if (stockHoldings.isNotEmpty) {
      final stockValue = stockHoldings.fold(0.0, (sum, h) => sum + h.currentValue);
      final stockCost = stockHoldings.fold(0.0, (sum, h) => sum + h.totalCost);
      final stockReturn = stockCost > 0 ? (stockValue - stockCost) / stockCost * 100 : 0.0;
      buffer.writeln('股票（${stockHoldings.length}支）：总市值 ${_formatWan(stockValue)}，收益 ${_formatReturn(stockReturn)}');
      for (final h in stockHoldings) {
        buffer.writeln('  - ${h.stockName}(${h.symbol}·${h.market.label})：${_formatWan(h.currentValue)}，${_formatReturn(h.returnRate)}');
      }
    }

    final totalValue = _totalValue;
    final totalReturn = _totalReturnRate;
    buffer.writeln('合计：${_formatWan(totalValue)}，收益 ${_formatReturn(totalReturn)}');

    return buffer.toString();
  }

  /// 生成摘要（约 20 token，用于通用问题）
  String buildSummaryOnly() {
    if (fundHoldings.isEmpty && stockHoldings.isEmpty) return '';
    return '用户总持仓约 ${_formatWan(_totalValue)}，整体收益 ${_formatReturn(_totalReturnRate)}。';
  }

  double get _totalValue =>
      fundHoldings.fold(0.0, (s, h) => s + h.currentValue) +
      stockHoldings.fold(0.0, (s, h) => s + h.currentValue);

  double get _totalReturnRate {
    final totalCost =
        fundHoldings.fold(0.0, (s, h) => s + h.totalCost) +
        stockHoldings.fold(0.0, (s, h) => s + h.totalCost);
    return totalCost > 0 ? (_totalValue - totalCost) / totalCost * 100 : 0.0;
  }

  String _formatWan(double value) {
    if (value >= 10000) return '${(value / 10000).toStringAsFixed(1)}万';
    return value.toStringAsFixed(0);
  }

  String _formatReturn(double rate) {
    final sign = rate >= 0 ? '+' : '';
    return '$sign${rate.toStringAsFixed(1)}%';
  }
}
```

---

## 3. 与 Prompt 构建层集成

```dart
// lib/features/ai_chat/data/prompt_builder.dart（M03 分层架构）

String buildSystemPrompt({
  required String userMessage,
  required UserProfile? userProfile,
  required List<FundHolding> fundHoldings,
  required List<StockHolding> stockHoldings,
}) {
  final portfolioBuilder = PortfolioContextBuilder(
    fundHoldings: fundHoldings,
    stockHoldings: stockHoldings,
  );

  final portfolioBlock = portfolioBuilder.shouldInjectFull(userMessage)
      ? portfolioBuilder.buildFullSnapshot()
      : portfolioBuilder.buildSummaryOnly();

  return '''
${_personaLayer}

${userProfile != null ? userProfile.toPromptSnippet() : ''}

${portfolioBlock}
'''.trim();
}
```

---

## 4. Provider 接入

```dart
// ai_chat_page.dart 中调用

final fundHoldings = ref.read(fundHoldingsProvider);
final stockHoldings = ref.read(stockHoldingsProvider);

final systemPrompt = buildSystemPrompt(
  userMessage: userInput,
  userProfile: ref.read(userProfileNotifierProvider),
  fundHoldings: fundHoldings,
  stockHoldings: stockHoldings,
);
```

---

## 5. Token 估算

| 场景 | 持仓块大小 | 说明 |
|------|-----------|------|
| 5支基金 + 3支股票 | ~120 token | 每条约 15 token |
| 10支基金 + 5支股票 | ~230 token | 超出时截断，只保留持仓最大的前8支 |
| 通用问题（摘要模式） | ~20 token | 不列明细 |

**截断策略**：超过 8 支持仓时，按持仓市值降序取前 8 支，末尾追加「（另有 N 支未展示）」。

---

## 6. 测试计划

| 测试类型 | 用例 |
|---------|------|
| 单元测试 | `buildFullSnapshot()` 格式正确 |
| 单元测试 | `shouldInjectFull()` 关键词命中率 |
| 单元测试 | 持仓为空时返回空字符串 |
| 单元测试 | 超过8支时截断逻辑正确 |
| 单元测试 | token 估算 < 150（字符数代估） |

---

## 7. 文件清单

```
lib/features/ai_chat/data/
└── portfolio_context_builder.dart     # 核心快照构建器

test/logic/
└── portfolio_context_builder_test.dart
```
