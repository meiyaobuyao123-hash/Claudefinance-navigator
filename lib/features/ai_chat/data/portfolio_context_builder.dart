import '../../../features/fund_tracker/data/models/fund_holding.dart';
import '../../../features/stock_tracker/data/models/stock_holding.dart';

class PortfolioContextBuilder {
  final List<FundHolding> fundHoldings;
  final List<StockHolding> stockHoldings;

  static const _maxHoldings = 8;

  const PortfolioContextBuilder({
    required this.fundHoldings,
    required this.stockHoldings,
  });

  /// 关键词命中时注入完整快照，否则只注入摘要
  bool shouldInjectFull(String userMessage) {
    const keywords = [
      '持仓', '基金', '股票', '配置', '合理', '建议',
      '收益', '亏损', '止盈', '补仓', '加仓', '减持',
      '我的', '帮我看', '现在有',
    ];
    return keywords.any(userMessage.contains);
  }

  /// 完整持仓快照（~100-150 token）
  /// 持仓为空时返回 ''；超过 8 支时截断
  String buildFullSnapshot() {
    if (fundHoldings.isEmpty && stockHoldings.isEmpty) return '';

    final buffer = StringBuffer('【持仓快照 · 实时】\n');

    // 基金
    if (fundHoldings.isNotEmpty) {
      final funds = fundHoldings.length > _maxHoldings
          ? fundHoldings.sublist(0, _maxHoldings)
          : fundHoldings;
      final totalValue = fundHoldings.fold(0.0, (s, h) => s + h.currentValue);
      final totalCost = fundHoldings.fold(0.0, (s, h) => s + h.costAmount);
      final totalReturn = totalCost > 0 ? (totalValue - totalCost) / totalCost * 100 : 0.0;
      buffer.writeln('基金（${fundHoldings.length}支）：总市值 ${_wan(totalValue)}，收益 ${_pct(totalReturn)}');
      for (final h in funds) {
        buffer.writeln('  - ${h.fundName}(${h.fundCode})：${_wan(h.currentValue)}，${_pct(h.totalReturnRate)}');
      }
      if (fundHoldings.length > _maxHoldings) {
        buffer.writeln('  （另有 ${fundHoldings.length - _maxHoldings} 支未展示）');
      }
    }

    // 股票
    if (stockHoldings.isNotEmpty) {
      final stocks = stockHoldings.length > _maxHoldings
          ? stockHoldings.sublist(0, _maxHoldings)
          : stockHoldings;
      final totalValue = stockHoldings.fold(0.0, (s, h) => s + h.currentValue);
      final totalCost = stockHoldings.fold(0.0, (s, h) => s + h.costAmount);
      final totalReturn = totalCost > 0 ? (totalValue - totalCost) / totalCost * 100 : 0.0;
      buffer.writeln('股票（${stockHoldings.length}支）：总市值 ${_wan(totalValue)}，收益 ${_pct(totalReturn)}');
      for (final h in stocks) {
        buffer.writeln('  - ${h.stockName}(${h.symbol}·${_marketLabel(h.market)})：${_wan(h.currentValue)}，${_pct(h.totalReturnRate)}');
      }
      if (stockHoldings.length > _maxHoldings) {
        buffer.writeln('  （另有 ${stockHoldings.length - _maxHoldings} 支未展示）');
      }
    }

    // 合计
    final totalValue = _totalValue;
    final totalCost = _totalCost;
    final totalReturn = totalCost > 0 ? (totalValue - totalCost) / totalCost * 100 : 0.0;
    buffer.write('合计：${_wan(totalValue)}，收益 ${_pct(totalReturn)}');

    return buffer.toString();
  }

  /// 摘要模式（~20 token），用于非持仓相关问题
  String buildSummaryOnly() {
    if (fundHoldings.isEmpty && stockHoldings.isEmpty) return '';
    final totalCost = _totalCost;
    final totalReturn = totalCost > 0 ? (_totalValue - totalCost) / totalCost * 100 : 0.0;
    return '用户总持仓约 ${_wan(_totalValue)}，整体收益 ${_pct(totalReturn)}。';
  }

  double get _totalValue =>
      fundHoldings.fold(0.0, (s, h) => s + h.currentValue) +
      stockHoldings.fold(0.0, (s, h) => s + h.currentValue);

  double get _totalCost =>
      fundHoldings.fold(0.0, (s, h) => s + h.costAmount) +
      stockHoldings.fold(0.0, (s, h) => s + h.costAmount);

  String _wan(double value) {
    if (value >= 10000) return '${(value / 10000).toStringAsFixed(1)}万';
    return value.toStringAsFixed(0);
  }

  String _pct(double rate) {
    final sign = rate >= 0 ? '+' : '';
    return '$sign${rate.toStringAsFixed(1)}%';
  }

  String _marketLabel(String market) => switch (market) {
    'A'  => 'A股',
    'HK' => '港股',
    'US' => '美股',
    _    => market,
  };
}
