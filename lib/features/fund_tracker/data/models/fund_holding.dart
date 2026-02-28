import 'dart:convert';

/// 单只基金持仓
class FundHolding {
  final String id;          // 唯一ID（时间戳字符串）
  final String fundCode;    // 基金代码，如 "000001"
  final String fundName;    // 基金名称
  final double shares;      // 持仓份额
  final double costNav;     // 买入均价（成本净值）
  final String addedDate;   // 添加日期 "2024-01-01"

  // 以下字段由 API 刷新，不持久化（每次启动重新拉取）
  double currentNav;        // 最新净值（上一交易日）
  double estimatedNav;      // 今日实时估值（仅交易日盘中有效）
  double changeRate;        // 今日涨跌幅（%）
  String navDate;           // 净值日期
  bool isLoading;           // 是否正在刷新
  String? errorMsg;         // 刷新错误信息
  bool hasEstimate;         // 今日是否有盘中估值（非交易日/未开盘 = false）

  FundHolding({
    required this.id,
    required this.fundCode,
    required this.fundName,
    required this.shares,
    required this.costNav,
    required this.addedDate,
    this.currentNav = 0,
    this.estimatedNav = 0,
    this.changeRate = 0,
    this.navDate = '',
    this.isLoading = false,
    this.errorMsg,
    this.hasEstimate = false,
  });

  // ─── 计算属性 ───
  double get costAmount => shares * costNav;
  // currentValue：有今日估值用估值，否则用昨日净值
  double get currentValue => shares * (hasEstimate && estimatedNav > 0 ? estimatedNav : currentNav);
  double get totalReturn => currentValue - costAmount;
  double get totalReturnRate =>
      costAmount > 0 ? totalReturn / costAmount * 100 : 0;
  // todayGain：只在有今日估值时计算，否则为 0
  double get todayGain => hasEstimate
      ? shares * (estimatedNav > 0 ? estimatedNav : currentNav) * changeRate / 100
      : 0.0;

  // ─── 序列化（存 Hive 用 JSON 字符串）───
  Map<String, dynamic> toJson() => {
        'id': id,
        'fundCode': fundCode,
        'fundName': fundName,
        'shares': shares,
        'costNav': costNav,
        'addedDate': addedDate,
      };

  factory FundHolding.fromJson(Map<String, dynamic> json) => FundHolding(
        id: json['id'] as String,
        fundCode: json['fundCode'] as String,
        fundName: json['fundName'] as String,
        shares: (json['shares'] as num).toDouble(),
        costNav: (json['costNav'] as num).toDouble(),
        addedDate: json['addedDate'] as String,
      );

  String toJsonString() => jsonEncode(toJson());

  FundHolding copyWith({
    double? currentNav,
    double? estimatedNav,
    double? changeRate,
    String? navDate,
    bool? isLoading,
    String? errorMsg,
    bool? hasEstimate,
  }) =>
      FundHolding(
        id: id,
        fundCode: fundCode,
        fundName: fundName,
        shares: shares,
        costNav: costNav,
        addedDate: addedDate,
        currentNav: currentNav ?? this.currentNav,
        estimatedNav: estimatedNav ?? this.estimatedNav,
        changeRate: changeRate ?? this.changeRate,
        navDate: navDate ?? this.navDate,
        isLoading: isLoading ?? this.isLoading,
        errorMsg: errorMsg,
        hasEstimate: hasEstimate ?? this.hasEstimate,
      );
}
