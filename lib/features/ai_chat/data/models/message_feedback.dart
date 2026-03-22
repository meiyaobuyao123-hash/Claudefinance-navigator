/// [M08] 反馈数据模型
library;

enum FeedbackRating { thumbsUp, thumbsDown }

enum FeedbackReason { inaccurate, notHelpful, tooGeneric, other }

class MessageFeedback {
  final String sessionId;
  final String messageId;
  final String userQuestion;
  final String aiResponsePreview; // 前50字
  final FeedbackRating rating;
  final FeedbackReason? reason; // 仅 thumbsDown 时填写
  final String conversationStage;
  final DateTime timestamp;
  final String deviceId;

  const MessageFeedback({
    required this.sessionId,
    required this.messageId,
    required this.userQuestion,
    required this.aiResponsePreview,
    required this.rating,
    this.reason,
    required this.conversationStage,
    required this.timestamp,
    required this.deviceId,
  });

  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'message_id': messageId,
        'user_question': userQuestion,
        'ai_response_preview': aiResponsePreview,
        'rating': rating.name,
        'reason': reason?.name,
        'conversation_stage': conversationStage,
        'timestamp': timestamp.toIso8601String(),
        'device_id': deviceId,
      };
}
