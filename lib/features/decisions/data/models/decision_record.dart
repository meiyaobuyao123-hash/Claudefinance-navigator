import 'dart:convert';

/// 决策类型
class DecisionType {
  static const buy = 'buy';
  static const sell = 'sell';
  static const rebalance = 'rebalance';
  static const renew = 'renew';
  static const pass_ = 'pass';

  static String label(String type) {
    switch (type) {
      case buy: return '买入';
      case sell: return '卖出/赎回';
      case rebalance: return '调仓';
      case renew: return '续期';
      case pass_: return '放弃操作';
      default: return type;
    }
  }
}

/// 决策预期
class DecisionExpectation {
  static const rateDown = 'rate_down';
  static const priceUp = 'price_up';
  static const riskHedge = 'risk_hedge';
  static const other = 'other';

  static String label(String exp) {
    switch (exp) {
      case rateDown: return '预期利率下降';
      case priceUp: return '预期价格上涨';
      case riskHedge: return '规避风险';
      case other: return '其他';
      default: return exp;
    }
  }
}

/// 复盘检查点
class DecisionCheckpoint {
  final String period;       // '3个月' / '6个月' / '1年'
  final DateTime date;       // 复盘时间
  final double? csi300;      // 复盘时沪深300
  final double? moneyYield;  // 复盘时货基7日年化
  final String judgement;    // AI判断文字
  final String verdict;      // 'correct' / 'incorrect' / 'neutral' / 'pending'

  const DecisionCheckpoint({
    required this.period,
    required this.date,
    this.csi300,
    this.moneyYield,
    required this.judgement,
    required this.verdict,
  });

  Map<String, dynamic> toJson() => {
    'period': period,
    'date': date.toIso8601String(),
    'csi300': csi300,
    'moneyYield': moneyYield,
    'judgement': judgement,
    'verdict': verdict,
  };

  factory DecisionCheckpoint.fromJson(Map<String, dynamic> j) =>
      DecisionCheckpoint(
        period: j['period'] as String,
        date: DateTime.parse(j['date'] as String),
        csi300: (j['csi300'] as num?)?.toDouble(),
        moneyYield: (j['moneyYield'] as num?)?.toDouble(),
        judgement: j['judgement'] as String,
        verdict: j['verdict'] as String,
      );
}

/// 单条财务决策记录
class DecisionRecord {
  final String id;
  final String type;            // DecisionType.*
  final String productCategory; // '货币基金', '大额存单', 'A股ETF', ...
  final double amount;          // 涉及金额（元）
  final String rationale;       // 用户填写的理由
  final String expectation;     // DecisionExpectation.*

  // 决策时的市场快照（自动采集）
  final double? csi300AtDecision;
  final double? moneyYieldAtDecision; // 货基7日年化 %

  final DateTime createdAt;
  final List<DecisionCheckpoint> checkpoints;

  const DecisionRecord({
    required this.id,
    required this.type,
    required this.productCategory,
    required this.amount,
    required this.rationale,
    required this.expectation,
    this.csi300AtDecision,
    this.moneyYieldAtDecision,
    required this.createdAt,
    this.checkpoints = const [],
  });

  DecisionRecord copyWith({List<DecisionCheckpoint>? checkpoints}) =>
      DecisionRecord(
        id: id,
        type: type,
        productCategory: productCategory,
        amount: amount,
        rationale: rationale,
        expectation: expectation,
        csi300AtDecision: csi300AtDecision,
        moneyYieldAtDecision: moneyYieldAtDecision,
        createdAt: createdAt,
        checkpoints: checkpoints ?? this.checkpoints,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'productCategory': productCategory,
    'amount': amount,
    'rationale': rationale,
    'expectation': expectation,
    'csi300AtDecision': csi300AtDecision,
    'moneyYieldAtDecision': moneyYieldAtDecision,
    'createdAt': createdAt.toIso8601String(),
    'checkpoints': checkpoints.map((c) => c.toJson()).toList(),
  };

  factory DecisionRecord.fromJson(Map<String, dynamic> j) => DecisionRecord(
    id: j['id'] as String,
    type: j['type'] as String,
    productCategory: j['productCategory'] as String,
    amount: (j['amount'] as num).toDouble(),
    rationale: j['rationale'] as String,
    expectation: j['expectation'] as String,
    csi300AtDecision: (j['csi300AtDecision'] as num?)?.toDouble(),
    moneyYieldAtDecision: (j['moneyYieldAtDecision'] as num?)?.toDouble(),
    createdAt: DateTime.parse(j['createdAt'] as String),
    checkpoints: (j['checkpoints'] as List? ?? [])
        .map((c) => DecisionCheckpoint.fromJson(c as Map<String, dynamic>))
        .toList(),
  );

  String toJsonString() => jsonEncode(toJson());

  factory DecisionRecord.fromJsonString(String s) =>
      DecisionRecord.fromJson(jsonDecode(s) as Map<String, dynamic>);

  // ─── 复盘相关辅助 ───

  /// 下一个待复盘的时间点（null = 已全部复盘）
  DateTime? get nextCheckpointDue {
    final periods = [
      const Duration(days: 90),  // 3个月
      const Duration(days: 180), // 6个月
      const Duration(days: 365), // 1年
    ];
    final done = checkpoints.length;
    if (done >= periods.length) return null;
    return createdAt.add(periods[done]);
  }

  /// 是否有待处理的复盘（到期但未复盘）
  bool get hasPendingReview {
    final due = nextCheckpointDue;
    if (due == null) return false;
    return DateTime.now().isAfter(due);
  }

  /// 最新判决
  String? get latestVerdict =>
      checkpoints.isEmpty ? null : checkpoints.last.verdict;
}

/// 产品类别列表
const decisionProductCategories = [
  '货币基金',
  '定期存款',
  '大额存单',
  '国债',
  '银行理财',
  '债券基金',
  'A股ETF',
  '主动基金',
  '港股',
  '美股ETF',
  '黄金',
  '保险',
  '其他',
];
