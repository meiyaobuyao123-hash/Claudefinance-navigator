/// [M04] 对话阶段状态机 — 状态数据模型
/// ConversationStage 枚举复用自 conversation_stage.dart
import 'conversation_stage.dart';

class ConversationState {
  final ConversationStage stage;
  final int messageCount;
  final int estimatedTokens;
  final bool hasSummarized;

  const ConversationState({
    this.stage = ConversationStage.exploring,
    this.messageCount = 0,
    this.estimatedTokens = 0,
    this.hasSummarized = false,
  });

  ConversationState copyWith({
    ConversationStage? stage,
    int? messageCount,
    int? estimatedTokens,
    bool? hasSummarized,
  }) =>
      ConversationState(
        stage: stage ?? this.stage,
        messageCount: messageCount ?? this.messageCount,
        estimatedTokens: estimatedTokens ?? this.estimatedTokens,
        hasSummarized: hasSummarized ?? this.hasSummarized,
      );

  /// 超过20轮或 token 超过8000时，需要触发对话摘要
  bool get shouldSummarize => messageCount >= 20 || estimatedTokens >= 8000;
}
