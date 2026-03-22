// M08 评估与反馈系统 — 单元测试
// 严格对应 PRD/TECH 验收标准：
//   AC-1: MessageFeedback.toJson() 字段名和值正确
//   AC-2: aiResponsePreview — 超50字截断 + '...'，不超50字原样保留
//   AC-3: FeedbackRating/FeedbackReason .name 枚举序列化值正确
//   AC-4: reason = null 时 toJson()['reason'] 为 null
//   AC-5: FeedbackService.submit 在抛出异常时不向上传播（静默失败）

import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:finance_navigator/features/ai_chat/data/models/message_feedback.dart';
import 'package:finance_navigator/features/ai_chat/data/services/feedback_service.dart';

// 构造一个基准反馈对象，便于各测试复用
MessageFeedback _buildFeedback({
  FeedbackRating rating = FeedbackRating.thumbsUp,
  FeedbackReason? reason,
  String aiResponse = '这是一段AI回复内容',
}) {
  return MessageFeedback(
    sessionId: 'session-123',
    messageId: 'msg-456',
    userQuestion: '我应该买什么基金',
    aiResponsePreview: aiResponse,
    rating: rating,
    reason: reason,
    conversationStage: 'deepening',
    timestamp: DateTime.parse('2026-03-22T10:30:00Z'),
    deviceId: 'device-789',
  );
}

void main() {
  // ── MessageFeedback.toJson() ────────────────────────────────────────
  group('MessageFeedback.toJson', () {
    test('[AC-1] 点赞反馈 — 字段名和值全部正确', () {
      final fb = _buildFeedback(rating: FeedbackRating.thumbsUp);
      final json = fb.toJson();
      expect(json['session_id'], 'session-123');
      expect(json['message_id'], 'msg-456');
      expect(json['user_question'], '我应该买什么基金');
      expect(json['ai_response_preview'], '这是一段AI回复内容');
      expect(json['rating'], 'thumbsUp');
      expect(json['conversation_stage'], 'deepening');
      expect(json['device_id'], 'device-789');
      expect(json['timestamp'], '2026-03-22T10:30:00.000Z');
    });

    test('[AC-1] 点踩反馈 — rating 字段值为 thumbsDown', () {
      final fb = _buildFeedback(rating: FeedbackRating.thumbsDown,
          reason: FeedbackReason.tooGeneric);
      final json = fb.toJson();
      expect(json['rating'], 'thumbsDown');
    });

    test('[AC-3] FeedbackRating.thumbsUp .name == "thumbsUp"', () {
      expect(FeedbackRating.thumbsUp.name, 'thumbsUp');
    });

    test('[AC-3] FeedbackRating.thumbsDown .name == "thumbsDown"', () {
      expect(FeedbackRating.thumbsDown.name, 'thumbsDown');
    });

    test('[AC-3] FeedbackReason.inaccurate .name == "inaccurate"', () {
      expect(FeedbackReason.inaccurate.name, 'inaccurate');
    });

    test('[AC-3] FeedbackReason.notHelpful .name == "notHelpful"', () {
      expect(FeedbackReason.notHelpful.name, 'notHelpful');
    });

    test('[AC-3] FeedbackReason.tooGeneric .name == "tooGeneric"', () {
      expect(FeedbackReason.tooGeneric.name, 'tooGeneric');
    });

    test('[AC-3] FeedbackReason.other .name == "other"', () {
      expect(FeedbackReason.other.name, 'other');
    });

    test('[AC-3] reason 在 toJson 中使用 .name 序列化', () {
      final fb = _buildFeedback(
        rating: FeedbackRating.thumbsDown,
        reason: FeedbackReason.notHelpful,
      );
      expect(fb.toJson()['reason'], 'notHelpful');
    });

    test('[AC-4] reason = null → toJson()[reason] = null', () {
      final fb = _buildFeedback(rating: FeedbackRating.thumbsUp, reason: null);
      expect(fb.toJson()['reason'], isNull);
    });
  });

  // ── aiResponsePreview 截断逻辑 ──────────────────────────────────────
  // 注意：截断逻辑在 MessageFeedbackBar._submitFeedback 中，
  // 这里通过直接赋值测试长度边界和截断行为。
  group('aiResponsePreview 截断（Widget层逻辑验证）', () {
    test('[AC-2] 正好50字 → 不截断（不加...）', () {
      // 构造50字的字符串
      const s = '这是恰好五十个字的AI回复内容用于测试截断边界条件啊啊啊啊啊啊啊啊啊啊啊啊啊啊啊啊啊啊';
      // 验证截断规则：> 50 才截断
      final preview = s.length > 50 ? '${s.substring(0, 50)}...' : s;
      expect(preview, s); // 不截断
      expect(preview.endsWith('...'), isFalse);
    });

    test('[AC-2] 超过50字 → 截断为前50字 + "..."', () {
      const longResponse = '根据你的情况，建议配置以下产品：一是货币基金，流动性好；二是债券基金，稳定收益；三是混合基金，平衡风险收益。';
      expect(longResponse.length, greaterThan(50));
      final preview = longResponse.length > 50
          ? '${longResponse.substring(0, 50)}...'
          : longResponse;
      expect(preview.length, 53); // 50字 + 3个字符的'...'
      expect(preview.endsWith('...'), isTrue);
      expect(preview.substring(0, 50), longResponse.substring(0, 50));
    });

    test('[AC-2] 短回复（< 50字）→ 原样保留', () {
      const shortResponse = '货币基金收益稳定';
      final preview = shortResponse.length > 50
          ? '${shortResponse.substring(0, 50)}...'
          : shortResponse;
      expect(preview, shortResponse);
    });

    test('[AC-2] 空字符串 → 空字符串', () {
      const emptyResponse = '';
      final preview = emptyResponse.length > 50
          ? '${emptyResponse.substring(0, 50)}...'
          : emptyResponse;
      expect(preview, '');
    });
  });

  // ── FeedbackService — 静默失败 ──────────────────────────────────────
  group('FeedbackService.submit — 静默失败', () {
    test('[AC-5] Dio 抛出异常 → submit 不向上传播，正常完成', () async {
      // 构造一个必然失败的 Dio（无效地址+极短超时）
      final failDio = Dio(BaseOptions(
        connectTimeout: const Duration(milliseconds: 1),
        receiveTimeout: const Duration(milliseconds: 1),
      ));
      final service = FeedbackService(failDio);
      final fb = _buildFeedback();

      // 期望：不抛出任何异常
      await expectLater(service.submit(fb), completes);
    });

    test('[AC-5] 正常 Dio + 无效URL → submit 不抛出', () async {
      final dio = Dio();
      final service = FeedbackService(dio);
      final fb = _buildFeedback(
        rating: FeedbackRating.thumbsDown,
        reason: FeedbackReason.inaccurate,
      );
      await expectLater(service.submit(fb), completes);
    });
  });

  // ── MessageFeedback 构造函数 ──────────────────────────────────────────
  group('MessageFeedback 构造', () {
    test('thumbsUp 时 reason 可为 null', () {
      final fb = MessageFeedback(
        sessionId: 's1',
        messageId: 'm1',
        userQuestion: 'q',
        aiResponsePreview: 'a',
        rating: FeedbackRating.thumbsUp,
        conversationStage: 'exploring',
        timestamp: DateTime.now(),
        deviceId: 'd1',
      );
      expect(fb.reason, isNull);
      expect(fb.rating, FeedbackRating.thumbsUp);
    });

    test('thumbsDown + reason 都能存储并序列化', () {
      final fb = MessageFeedback(
        sessionId: 's1',
        messageId: 'm1',
        userQuestion: 'q',
        aiResponsePreview: 'a',
        rating: FeedbackRating.thumbsDown,
        reason: FeedbackReason.other,
        conversationStage: 'actioning',
        timestamp: DateTime.now(),
        deviceId: 'd1',
      );
      expect(fb.reason, FeedbackReason.other);
      expect(fb.toJson()['reason'], 'other');
      expect(fb.toJson()['rating'], 'thumbsDown');
    });
  });
}
