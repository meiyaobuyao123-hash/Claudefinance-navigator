/// M03/M04 共用：对话阶段枚举
/// M03 使用其 promptHint 注入 Layer 5
/// M04 实现完整状态机逻辑
enum ConversationStage {
  exploring, // 探索阶段：收集用户情况
  deepening, // 深化阶段：深入分析某个主题
  actioning, // 行动阶段：给出具体建议步骤
  reviewing, // 复盘阶段：回顾决策结果
}

extension ConversationStageExtension on ConversationStage {
  String get promptHint => switch (this) {
    ConversationStage.exploring =>
      '当前阶段：了解用户情况。优先提问，每次最多问1-2个问题，不要急于给建议。',
    ConversationStage.deepening =>
      '当前阶段：深入分析。用户已提供足够信息，开始给出有深度的分析。',
    ConversationStage.actioning =>
      '当前阶段：行动建议。用户已明确要求给建议，必须直接给出具体配置方向和比例，不要再追问。格式参考："建议配置：40%债基 + 30%宽基ETF + ..."，并说明理由。',
    ConversationStage.reviewing =>
      '当前阶段：复盘总结。帮助用户回顾之前的决策，客观评估结果。',
  };
}
