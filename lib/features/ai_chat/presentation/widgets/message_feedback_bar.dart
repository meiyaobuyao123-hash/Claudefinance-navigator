/// [M08] 消息反馈 Bar — 每条 AI 回复气泡右下角的 👍/👎 按钮
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/message_feedback.dart';
import '../providers/conversation_state_provider.dart';
import '../providers/feedback_providers.dart';

class MessageFeedbackBar extends ConsumerWidget {
  final String messageId;
  final String userQuestion;
  final String aiResponse;

  const MessageFeedbackBar({
    super.key,
    required this.messageId,
    required this.userQuestion,
    required this.aiResponse,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedback = ref.watch(messageFeedbackProvider(messageId));

    if (feedback != null) {
      // 已反馈 — 只显示已选图标
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              feedback.rating == FeedbackRating.thumbsUp
                  ? Icons.thumb_up
                  : Icons.thumb_down,
              size: 14,
              color: Colors.grey[400],
            ),
          ],
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.thumb_up_outlined, size: 16),
          onPressed: () => _submitFeedback(ref, FeedbackRating.thumbsUp),
          color: Colors.grey[500],
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        IconButton(
          icon: const Icon(Icons.thumb_down_outlined, size: 16),
          onPressed: () => _showReasonSheet(context, ref),
          color: Colors.grey[500],
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    );
  }

  Future<void> _showReasonSheet(BuildContext context, WidgetRef ref) async {
    final reason = await showModalBottomSheet<FeedbackReason>(
      context: context,
      builder: (_) => const _ReasonSheet(),
    );
    if (reason != null) {
      await _submitFeedback(ref, FeedbackRating.thumbsDown, reason: reason);
    }
  }

  Future<void> _submitFeedback(
    WidgetRef ref,
    FeedbackRating rating, {
    FeedbackReason? reason,
  }) async {
    final deviceIdAsync = ref.read(deviceIdProvider);
    final deviceId = deviceIdAsync.valueOrNull ?? 'unknown';

    final feedback = MessageFeedback(
      sessionId: ref.read(currentSessionIdProvider),
      messageId: messageId,
      userQuestion: userQuestion,
      aiResponsePreview:
          aiResponse.length > 50 ? '${aiResponse.substring(0, 50)}...' : aiResponse,
      rating: rating,
      reason: reason,
      conversationStage: ref.read(conversationStateProvider).stage.name,
      timestamp: DateTime.now(),
      deviceId: deviceId,
    );

    ref.read(messageFeedbackProvider(messageId).notifier).set(feedback);
    await ref.read(feedbackServiceProvider).submit(feedback);
  }
}

// ── 原因选择底部弹出框 ───────────────────────────────────────────────────
class _ReasonSheet extends StatelessWidget {
  const _ReasonSheet();

  @override
  Widget build(BuildContext context) {
    final reasons = [
      (FeedbackReason.inaccurate, '回答不准确'),
      (FeedbackReason.notHelpful, '没有解决我的问题'),
      (FeedbackReason.tooGeneric, '建议太泛泛'),
      (FeedbackReason.other, '其他'),
    ];

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '哪里没有帮到你？',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          ...reasons.map(
            (r) => ListTile(
              title: Text(r.$2),
              onTap: () => Navigator.pop(context, r.$1),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
