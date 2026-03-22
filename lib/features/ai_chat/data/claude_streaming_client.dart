import 'package:anthropic_sdk_dart/anthropic_sdk_dart.dart';
import 'package:dio/dio.dart';
import '../../../core/config/api_keys.dart';
import '../../../core/constants/app_constants.dart';

/// [M06] Claude SSE 流式客户端
/// 返回 Stream<String>，每次 yield 一个文本 chunk
class ClaudeStreamingClient {
  ClaudeStreamingClient._();

  /// 流式调用，自动三级降级：主Key → 备用Key → DeepSeek伪流式
  static Stream<String> streamMessage({
    required String systemPrompt,
    required List<Map<String, String>> history,
    String model = 'claude-sonnet-4-20250514',
    int maxTokens = 1024,
  }) async* {
    // 尝试 Claude 主 Key
    try {
      yield* _claudeStream(
        apiKey: ApiKeys.claudeApiKey,
        systemPrompt: systemPrompt,
        history: history,
        model: model,
        maxTokens: maxTokens,
      );
      return;
    } catch (_) {}

    // 降级：Claude 备用 Key
    try {
      yield* _claudeStream(
        apiKey: ApiKeys.claudeApiKeyBackup,
        systemPrompt: systemPrompt,
        history: history,
        model: model,
        maxTokens: maxTokens,
      );
      return;
    } catch (_) {}

    // 最终降级：DeepSeek 非流式 → 伪流式
    yield* _deepseekFakeStream(
      systemPrompt: systemPrompt,
      history: history,
    );
  }

  /// Claude SSE 流式（单 Key）
  static Stream<String> _claudeStream({
    required String apiKey,
    required String systemPrompt,
    required List<Map<String, String>> history,
    required String model,
    required int maxTokens,
  }) async* {
    final client = AnthropicClient.withApiKey(apiKey);
    try {
      final messages = history
          .map((m) => InputMessage(
                role: m['role'] == 'user'
                    ? MessageRole.user
                    : MessageRole.assistant,
                content: MessageContent.text(m['content']!),
              ))
          .toList();

      // [M09] Prompt Caching：system prompt 标记 cache_control ephemeral
      // 5分钟内同一用户连续对话命中缓存，system prompt 费用降低 90%
      final stream = client.messages.createStream(
        MessageCreateRequest(
          model: model,
          maxTokens: maxTokens,
          system: SystemPrompt.blocks([
            SystemTextBlock(
              text: systemPrompt,
              cacheControl: const CacheControlEphemeral(),
            ),
          ]),
          messages: messages,
        ),
      );

      await for (final event in stream) {
        if (event is ContentBlockDeltaEvent) {
          final delta = event.delta;
          if (delta is TextDelta) {
            yield delta.text;
          }
        }
      }
    } finally {
      client.close();
    }
  }

  /// DeepSeek 非流式 → 每15ms yield一个字符，模拟打字机效果
  static Stream<String> _deepseekFakeStream({
    required String systemPrompt,
    required List<Map<String, String>> history,
  }) async* {
    try {
      final dio = Dio();
      final messages = <Map<String, String>>[
        {'role': 'system', 'content': systemPrompt},
        ...history,
      ];
      final response = await dio.post(
        AppConstants.deepseekApiUrl,
        options: Options(headers: {
          'Authorization': 'Bearer ${ApiKeys.deepseekApiKey}',
          'Content-Type': 'application/json',
        }),
        data: {
          'model': 'deepseek-chat',
          'max_tokens': 1024,
          'messages': messages,
        },
      );
      final text =
          response.data['choices'][0]['message']['content'] as String;
      // 伪流式：逐字符 yield
      for (var i = 0; i < text.length; i++) {
        yield text[i];
        await Future.delayed(const Duration(milliseconds: 15));
      }
    } catch (_) {
      yield '网络异常，请稍后重试。';
    }
  }
}
