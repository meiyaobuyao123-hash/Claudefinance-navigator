# M08 评估与反馈系统 — 技术实现文档

> 版本：v1.0 | 最后更新：2026-03-22

---

## 1. 数据模型

```dart
// lib/features/ai_chat/data/models/message_feedback.dart

enum FeedbackRating { thumbsUp, thumbsDown }
enum FeedbackReason { inaccurate, notHelpful, tooGeneric, other }

class MessageFeedback {
  final String sessionId;
  final String messageId;
  final String userQuestion;
  final String aiResponsePreview; // 前50字
  final FeedbackRating rating;
  final FeedbackReason? reason;   // 仅 thumbsDown 时填写
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
```

---

## 2. 反馈 Widget

```dart
// lib/features/ai_chat/presentation/widgets/message_feedback_bar.dart

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
      // 已反馈，只显示结果
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
          onPressed: () => _submitFeedback(context, ref, FeedbackRating.thumbsUp),
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
      await _submitFeedback(context, ref, FeedbackRating.thumbsDown, reason: reason);
    }
  }

  Future<void> _submitFeedback(
    BuildContext context,
    WidgetRef ref,
    FeedbackRating rating, {
    FeedbackReason? reason,
  }) async {
    final feedback = MessageFeedback(
      sessionId: ref.read(currentSessionIdProvider),
      messageId: messageId,
      userQuestion: userQuestion,
      aiResponsePreview: aiResponse.length > 50
          ? '${aiResponse.substring(0, 50)}...'
          : aiResponse,
      rating: rating,
      reason: reason,
      conversationStage: ref.read(conversationStateNotifierProvider).stage.name,
      timestamp: DateTime.now(),
      deviceId: ref.read(deviceIdProvider),
    );

    ref.read(messageFeedbackProvider(messageId).notifier).set(feedback);
    await ref.read(feedbackServiceProvider).submit(feedback);
  }
}
```

---

## 3. 上报服务

```dart
// lib/features/ai_chat/data/services/feedback_service.dart

class FeedbackService {
  final Dio _dio;
  static const _endpoint = 'http://43.156.207.26/api/finance/feedback';

  const FeedbackService(this._dio);

  Future<void> submit(MessageFeedback feedback) async {
    try {
      await _dio.post(
        _endpoint,
        data: feedback.toJson(),
        options: Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      // 上报失败静默处理，不影响用户体验
      debugPrint('Feedback submit failed: $e');
    }
  }
}
```

---

## 4. 服务端接口（腾讯云 FastAPI）

在 `/opt/finance-nav-api/main.py` 新增：

```python
# 建表 SQL
"""
CREATE TABLE ai_feedback (
    id SERIAL PRIMARY KEY,
    session_id TEXT NOT NULL,
    message_id TEXT NOT NULL,
    user_question TEXT,
    ai_response_preview TEXT,
    rating TEXT NOT NULL,
    reason TEXT,
    conversation_stage TEXT,
    device_id TEXT,
    timestamp TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
"""

@app.post("/feedback")
async def submit_feedback(payload: dict):
    conn = get_db()
    try:
        conn.execute("""
            INSERT INTO ai_feedback
            (session_id, message_id, user_question, ai_response_preview,
             rating, reason, conversation_stage, device_id, timestamp)
            VALUES (%(session_id)s, %(message_id)s, %(user_question)s,
                    %(ai_response_preview)s, %(rating)s, %(reason)s,
                    %(conversation_stage)s, %(device_id)s, %(timestamp)s)
        """, payload)
        conn.commit()
        return {"status": "ok"}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()
```

---

## 5. 测试计划

| 用例 | 方式 |
|------|------|
| 点赞后按钮变为实心 | Widget 测试 |
| 点踩弹出原因选择框 | Widget 测试 |
| 服务端上报成功 | 集成测试 |
| 断网时上报失败但对话不中断 | 断网测试 |

---

## 6. 文件清单

```
lib/features/ai_chat/data/models/
└── message_feedback.dart

lib/features/ai_chat/data/services/
└── feedback_service.dart

lib/features/ai_chat/presentation/widgets/
└── message_feedback_bar.dart

lib/features/ai_chat/presentation/providers/
└── message_feedback_provider.dart
```
