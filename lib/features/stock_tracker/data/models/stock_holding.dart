import 'dart:convert';

class StockHolding {
  final String id;
  final String symbol;    // "sh600519" | "hk00700" | "AAPL"
  final String stockName;
  final String market;    // 'A' | 'HK' | 'US'
  final double shares;    // 持仓股数
  final double costPrice; // 每股成本价
  final String addedDate;

  // ── 实时字段（非持久化）──
  final double currentPrice;
  final double changeRate;    // 当日涨跌幅 %
  final double changeAmount;  // 当日涨跌额（每股）
  final bool isLoading;
  final String? errorMsg;

  const StockHolding({
    required this.id,
    required this.symbol,
    required this.stockName,
    required this.market,
    required this.shares,
    required this.costPrice,
    required this.addedDate,
    this.currentPrice = 0,
    this.changeRate = 0,
    this.changeAmount = 0,
    this.isLoading = false,
    this.errorMsg,
  });

  // ── 计算属性 ──
  double get costAmount => shares * costPrice;
  double get currentValue =>
      shares * (currentPrice > 0 ? currentPrice : costPrice);
  double get totalReturn => currentValue - costAmount;
  double get totalReturnRate =>
      costAmount > 0 ? (totalReturn / costAmount * 100) : 0;
  double get todayGain =>
      currentPrice > 0 ? shares * changeAmount : 0;

  // ── 序列化（只持久化核心字段）──
  Map<String, dynamic> toJson() => {
        'id': id,
        'symbol': symbol,
        'stock_name': stockName,
        'market': market,
        'shares': shares,
        'cost_price': costPrice,
        'added_date': addedDate,
      };

  factory StockHolding.fromJson(Map<String, dynamic> json) => StockHolding(
        id: json['id'] as String,
        symbol: json['symbol'] as String,
        stockName: json['stock_name'] as String,
        market: json['market'] as String,
        shares: (json['shares'] as num).toDouble(),
        costPrice: (json['cost_price'] as num).toDouble(),
        addedDate: json['added_date'] as String? ?? '',
      );

  String toJsonString() => jsonEncode(toJson());

  factory StockHolding.fromJsonString(String s) =>
      StockHolding.fromJson(jsonDecode(s) as Map<String, dynamic>);

  StockHolding copyWith({
    double? currentPrice,
    double? changeRate,
    double? changeAmount,
    bool? isLoading,
    String? errorMsg,
    bool clearError = false,
  }) =>
      StockHolding(
        id: id,
        symbol: symbol,
        stockName: stockName,
        market: market,
        shares: shares,
        costPrice: costPrice,
        addedDate: addedDate,
        currentPrice: currentPrice ?? this.currentPrice,
        changeRate: changeRate ?? this.changeRate,
        changeAmount: changeAmount ?? this.changeAmount,
        isLoading: isLoading ?? this.isLoading,
        errorMsg: clearError ? null : (errorMsg ?? this.errorMsg),
      );

  StockHolding copyWithHolding({
    required double shares,
    required double costPrice,
  }) =>
      StockHolding(
        id: id,
        symbol: symbol,
        stockName: stockName,
        market: market,
        shares: shares,
        costPrice: costPrice,
        addedDate: addedDate,
        currentPrice: currentPrice,
        changeRate: changeRate,
        changeAmount: changeAmount,
      );
}
