/// [M08] 反馈上报服务 — 上报失败静默处理，不影响用户体验
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/message_feedback.dart';

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
