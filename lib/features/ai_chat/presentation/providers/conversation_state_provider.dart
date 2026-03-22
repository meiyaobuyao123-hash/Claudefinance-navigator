/// [M04] 对话阶段状态机 Provider
/// 使用 StateNotifier（无 codegen），与项目其他 Provider 保持一致。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/conversation_state.dart';
import '../../data/conversation_stage.dart';

final conversationStateProvider =
    StateNotifierProvider<ConversationStateNotifier, ConversationState>((ref) {
  return ConversationStateNotifier();
});

class ConversationStateNotifier extends StateNotifier<ConversationState> {
  ConversationStateNotifier() : super(const ConversationState());

  /// 每次用户发送消息时调用，更新阶段和消息计数
  void onUserMessage(String message, {bool hasUserProfile = false}) {
    final newCount = state.messageCount + 1;
    final newStage = _computeStage(message, newCount, hasUserProfile);
    state = state.copyWith(stage: newStage, messageCount: newCount);
  }

  /// 累加 token 估算值（用于触发摘要判断）
  void addTokens(int tokens) {
    state = state.copyWith(estimatedTokens: state.estimatedTokens + tokens);
  }

  /// 标记已完成摘要，重置 token 计数到摘要基准值
  void markSummarized() {
    state = state.copyWith(hasSummarized: true, estimatedTokens: 2000);
  }

  /// 重置对话状态（新会话）
  void reset() => state = const ConversationState();

  /// 阶段计算逻辑（纯函数，便于测试）
  ConversationStage _computeStage(
      String message, int count, bool hasProfile) {
    // 复盘关键词优先级最高
    const reviewKeywords = ['当时', '之前', '我买了', '那次', '上次', '已经买'];
    if (reviewKeywords.any(message.contains)) {
      return ConversationStage.reviewing;
    }

    // 行动意图关键词
    const actionKeywords = ['怎么买', '下一步', '我想', '准备', '打算', '操作', '去哪买'];
    if (actionKeywords.any(message.contains)) {
      return ConversationStage.actioning;
    }

    // 当前处于行动阶段：检查是否需要回退到深化，否则保持
    if (state.stage == ConversationStage.actioning) {
      const analyticKeywords = ['为什么', '分析', '比较', '区别', '原理'];
      if (analyticKeywords.any(message.contains)) {
        return ConversationStage.deepening;
      }
      return ConversationStage.actioning;
    }

    // 已有档案或对话数 >= 3 → 深化
    if (hasProfile || count >= 3) {
      return ConversationStage.deepening;
    }

    return ConversationStage.exploring;
  }
}
