enum AssetRange {
  below50w,   // 50万以下
  w50to200,   // 50-200万
  w200to500,  // 200-500万
  above500w,  // 500万以上
}

extension AssetRangeExtension on AssetRange {
  String get label => switch (this) {
    AssetRange.below50w  => '50万以下',
    AssetRange.w50to200  => '50-200万',
    AssetRange.w200to500 => '200-500万',
    AssetRange.above500w => '500万以上',
  };
}

enum FinancialGoal {
  beatInflation,    // 跑赢通胀，本金安全
  steadyGrowth,     // 稳健增值（年化3-6%）
  aggressiveGrowth, // 积极增值，接受波动
  retirement,       // 养老规划（10年以上）
  childEducation,   // 子女教育金
  wealthTransfer,   // 财富传承
}

extension FinancialGoalExtension on FinancialGoal {
  String get label => switch (this) {
    FinancialGoal.beatInflation    => '跑赢通胀、本金安全',
    FinancialGoal.steadyGrowth     => '稳健增值（年化3-6%）',
    FinancialGoal.aggressiveGrowth => '积极增值、接受波动',
    FinancialGoal.retirement       => '养老规划',
    FinancialGoal.childEducation   => '子女教育金',
    FinancialGoal.wealthTransfer   => '财富传承',
  };
}

enum RiskReaction {
  sellImmediately, // 立刻止损卖出，睡不着觉
  waitAndSee,      // 有点担心，但观望不动
  holdLongTerm,    // 正常，长期持有不在意
  buyMore,         // 加仓，这是买入机会
}

extension RiskReactionExtension on RiskReaction {
  String get label => switch (this) {
    RiskReaction.sellImmediately => '保守型（大跌会止损）',
    RiskReaction.waitAndSee      => '稳健型（观望不动）',
    RiskReaction.holdLongTerm    => '平衡型（长期持有）',
    RiskReaction.buyMore         => '积极型（加仓买入）',
  };
}

class UserProfile {
  final AssetRange assetRange;
  final List<FinancialGoal> goals; // 最多2个
  final RiskReaction riskReaction;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.assetRange,
    required this.goals,
    required this.riskReaction,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 输出给 M03 PromptBuilder Layer 3（~50 token）
  String toPromptSnippet() => '''
用户档案：
- 可投资资金：${assetRange.label}
- 理财目标：${goals.map((g) => g.label).join('、')}
- 风险偏好：${riskReaction.label}''';

  Map<String, dynamic> toJson() => {
    'assetRange': assetRange.index,
    'goals': goals.map((g) => g.index).toList(),
    'riskReaction': riskReaction.index,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    assetRange: AssetRange.values[json['assetRange'] as int],
    goals: (json['goals'] as List)
        .map((i) => FinancialGoal.values[i as int])
        .toList(),
    riskReaction: RiskReaction.values[json['riskReaction'] as int],
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  UserProfile copyWith({
    AssetRange? assetRange,
    List<FinancialGoal>? goals,
    RiskReaction? riskReaction,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => UserProfile(
    assetRange: assetRange ?? this.assetRange,
    goals: goals ?? this.goals,
    riskReaction: riskReaction ?? this.riskReaction,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
