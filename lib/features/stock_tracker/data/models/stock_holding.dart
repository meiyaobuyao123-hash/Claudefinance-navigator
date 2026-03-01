import 'dart:convert';

class StockHolding {
  final String id;
  final String symbol;    // "sh600519" | "hk00700" | "AAPL"
  final String stockName;
  final String market;    // 'A' | 'HK' | 'US'
  final double shares;    // 持仓股数
  final double costPrice; // 每股成本价
  final String addedDate;

  // ── 单仓预警（持久化）──
  final double? alertUp;            // 止盈线（累计浮盈率%，如 20.0 表示 +20%）
  final double? alertDown;          // 止损线（累计亏损率%，如 -10.0 表示 -10%）
  final String? alertTriggeredDate; // 当日已触发日期，防重复推送

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
    this.alertUp,
    this.alertDown,
    this.alertTriggeredDate,
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

  // ── 序列化（含预警字段，存 Hive；Supabase 侧 upsertStockHolding 只取核心字段）──
  Map<String, dynamic> toJson() => {
        'id': id,
        'symbol': symbol,
        'stock_name': stockName,
        'market': market,
        'shares': shares,
        'cost_price': costPrice,
        'added_date': addedDate,
        'alert_up': alertUp,
        'alert_down': alertDown,
        'alert_triggered_date': alertTriggeredDate,
      };

  factory StockHolding.fromJson(Map<String, dynamic> json) => StockHolding(
        id: json['id'] as String,
        symbol: json['symbol'] as String,
        stockName: json['stock_name'] as String,
        market: json['market'] as String,
        shares: (json['shares'] as num).toDouble(),
        costPrice: (json['cost_price'] as num).toDouble(),
        addedDate: json['added_date'] as String? ?? '',
        alertUp: (json['alert_up'] as num?)?.toDouble(),
        alertDown: (json['alert_down'] as num?)?.toDouble(),
        alertTriggeredDate: json['alert_triggered_date'] as String?,
      );

  String toJsonString() => jsonEncode(toJson());

  factory StockHolding.fromJsonString(String s) =>
      StockHolding.fromJson(jsonDecode(s) as Map<String, dynamic>);

  /// 更新行情（保留预警字段）
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
        alertUp: alertUp,
        alertDown: alertDown,
        alertTriggeredDate: alertTriggeredDate,
        currentPrice: currentPrice ?? this.currentPrice,
        changeRate: changeRate ?? this.changeRate,
        changeAmount: changeAmount ?? this.changeAmount,
        isLoading: isLoading ?? this.isLoading,
        errorMsg: clearError ? null : (errorMsg ?? this.errorMsg),
      );

  /// 更新持仓成本（增持/减持后调用，保留预警字段）
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
        alertUp: alertUp,
        alertDown: alertDown,
        alertTriggeredDate: alertTriggeredDate,
        currentPrice: currentPrice,
        changeRate: changeRate,
        changeAmount: changeAmount,
      );

  /// 更新预警设置（null = 清除对应预警）
  StockHolding copyWithAlert({
    double? alertUp,
    double? alertDown,
    String? alertTriggeredDate,
    bool clearAlertUp = false,
    bool clearAlertDown = false,
    bool clearTriggeredDate = false,
  }) =>
      StockHolding(
        id: id,
        symbol: symbol,
        stockName: stockName,
        market: market,
        shares: shares,
        costPrice: costPrice,
        addedDate: addedDate,
        alertUp: clearAlertUp ? null : (alertUp ?? this.alertUp),
        alertDown: clearAlertDown ? null : (alertDown ?? this.alertDown),
        alertTriggeredDate: clearTriggeredDate
            ? null
            : (alertTriggeredDate ?? this.alertTriggeredDate),
        currentPrice: currentPrice,
        changeRate: changeRate,
        changeAmount: changeAmount,
        isLoading: isLoading,
        errorMsg: errorMsg,
      );
}
