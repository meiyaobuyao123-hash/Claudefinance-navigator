/// [M08] 反馈系统相关 Providers
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/utils/uuid_util.dart';
import '../../data/models/message_feedback.dart';
import '../../data/services/feedback_service.dart';

// ── 会话 ID（每次冷启动生成一个新会话 ID）────────────────────────────────
final currentSessionIdProvider = Provider<String>((ref) => generateUuid());

// ── 设备 ID（持久化到 SharedPreferences）─────────────────────────────────
final deviceIdProvider = FutureProvider<String>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final key = 'device_id';
  String? id = prefs.getString(key);
  if (id == null) {
    id = generateUuid();
    await prefs.setString(key, id);
  }
  return id;
});

// ── 单条消息反馈状态（family，按 messageId 隔离）──────────────────────────
class _FeedbackNotifier extends StateNotifier<MessageFeedback?> {
  _FeedbackNotifier() : super(null);
  void set(MessageFeedback feedback) => state = feedback;
}

final messageFeedbackProvider = StateNotifierProvider.family<_FeedbackNotifier,
    MessageFeedback?, String>(
  (ref, messageId) => _FeedbackNotifier(),
);

// ── FeedbackService 实例────────────────────────────────────────────────
final feedbackServiceProvider = Provider<FeedbackService>((ref) {
  return FeedbackService(Dio());
});
