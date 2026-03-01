import 'dart:convert';

/// 自选股票/基金单条记录
class WatchItem {
  final String id;
  final String symbol;   // 'sh600519' | 'hk00700' | 'AAPL'
  final String name;
  final String market;   // 'A' | 'HK' | 'US'
  final double addedPrice; // 加入自选时的价格（用于计算涨跌幅）
  final String addedDate;

  // ── 预警设置（持久化）──
  final double? alertUp;    // 涨到此价格提醒
  final double? alertDown;  // 跌到此价格提醒
  final String? alertTriggeredDate; // 'yyyy-MM-dd'，当天已触发则跳过

  // ── 实时字段（不持久化）──
  final double currentPrice;
  final double changeRate;    // 今日涨跌幅 %
  final double changeAmount;  // 今日涨跌额
  final bool isLoading;
  final String? errorMsg;

  const WatchItem({
    required this.id,
    required this.symbol,
    required this.name,
    required this.market,
    required this.addedPrice,
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

  /// 自添加以来的累计涨跌幅
  double get sinceAddedRate =>
      addedPrice > 0 ? (currentPrice - addedPrice) / addedPrice * 100 : 0;

  // ── 序列化（只存核心字段 + 预警）──
  Map<String, dynamic> toJson() => {
        'id': id,
        'symbol': symbol,
        'name': name,
        'market': market,
        'added_price': addedPrice,
        'added_date': addedDate,
        if (alertUp != null) 'alert_up': alertUp,
        if (alertDown != null) 'alert_down': alertDown,
        if (alertTriggeredDate != null)
          'alert_triggered_date': alertTriggeredDate,
      };

  factory WatchItem.fromJson(Map<String, dynamic> json) => WatchItem(
        id: json['id'] as String,
        symbol: json['symbol'] as String,
        name: json['name'] as String,
        market: json['market'] as String,
        addedPrice: (json['added_price'] as num).toDouble(),
        addedDate: json['added_date'] as String? ?? '',
        alertUp: (json['alert_up'] as num?)?.toDouble(),
        alertDown: (json['alert_down'] as num?)?.toDouble(),
        alertTriggeredDate: json['alert_triggered_date'] as String?,
      );

  String toJsonString() => jsonEncode(toJson());

  WatchItem copyWith({
    double? currentPrice,
    double? changeRate,
    double? changeAmount,
    bool? isLoading,
    String? errorMsg,
    bool clearError = false,
    double? alertUp,
    double? alertDown,
    bool clearAlertUp = false,
    bool clearAlertDown = false,
    String? alertTriggeredDate,
    bool clearAlertTriggeredDate = false,
  }) =>
      WatchItem(
        id: id,
        symbol: symbol,
        name: name,
        market: market,
        addedPrice: addedPrice,
        addedDate: addedDate,
        currentPrice: currentPrice ?? this.currentPrice,
        changeRate: changeRate ?? this.changeRate,
        changeAmount: changeAmount ?? this.changeAmount,
        isLoading: isLoading ?? this.isLoading,
        errorMsg: clearError ? null : (errorMsg ?? this.errorMsg),
        alertUp: clearAlertUp ? null : (alertUp ?? this.alertUp),
        alertDown: clearAlertDown ? null : (alertDown ?? this.alertDown),
        alertTriggeredDate: clearAlertTriggeredDate
            ? null
            : (alertTriggeredDate ?? this.alertTriggeredDate),
      );
}
