/// [M05] Claude Agentic Loop — AI 自主 Tool Use 循环
/// 使用非流式 messages.create()，最多3轮 tool_use，防止无限循环
import 'package:anthropic_sdk_dart/anthropic_sdk_dart.dart';
import 'tools/tool_definitions.dart';
import 'tools/tool_executor.dart';

class ClaudeAgent {
  final ToolExecutor toolExecutor;

  /// 可注入 API 调用函数（用于测试时 mock）
  final Future<Message> Function({
    required String apiKey,
    required String systemPrompt,
    required List<InputMessage> messages,
    required List<ToolDefinition> tools,
  })? _apiCaller;

  ClaudeAgent({
    required this.toolExecutor,
    Future<Message> Function({
      required String apiKey,
      required String systemPrompt,
      required List<InputMessage> messages,
      required List<ToolDefinition> tools,
    })? apiCaller,
  }) : _apiCaller = apiCaller;

  /// 运行 agentic loop，返回最终文本回复
  Future<String> run({
    required String systemPrompt,
    required List<Map<String, String>> history,
    required String apiKey,
  }) async {
    var messages = _buildInputMessages(history);

    // 最多3轮 tool 调用，防止无限循环
    for (int i = 0; i < 3; i++) {
      final response = await _callAPI(
        apiKey: apiKey,
        systemPrompt: systemPrompt,
        messages: messages,
        tools: kToolDefinitions,
      );

      if (response.stopReason == StopReason.toolUse) {
        // 提取所有 ToolUseBlock
        final toolUseBlocks =
            response.content.whereType<ToolUseBlock>().toList();

        // 将 assistant 回复（含 tool_use blocks）追加到 messages
        messages = [
          ...messages,
          InputMessage(
            role: MessageRole.assistant,
            content: MessageContent.blocks(
              response.content
                  .map((block) => _toInputBlock(block))
                  .whereType<InputContentBlock>()
                  .toList(),
            ),
          ),
        ];

        // 执行所有 tool，收集结果
        final toolResults = <InputContentBlock>[];
        for (final block in toolUseBlocks) {
          final result = await toolExecutor.execute(block.name, block.input);
          toolResults.add(
            InputContentBlock.toolResultText(
              toolUseId: block.id,
              text: result,
            ),
          );
        }

        // 追加 tool_result 用户消息
        messages = [
          ...messages,
          InputMessage(
            role: MessageRole.user,
            content: MessageContent.blocks(toolResults),
          ),
        ];
        continue;
      }

      // stop_reason == end_turn → 返回最终文本
      final textBlocks = response.content.whereType<TextBlock>().toList();
      return textBlocks.map((b) => b.text).join();
    }

    return '抱歉，处理过程中遇到了问题，请稍后重试。';
  }

  Future<Message> _callAPI({
    required String apiKey,
    required String systemPrompt,
    required List<InputMessage> messages,
    required List<ToolDefinition> tools,
  }) async {
    if (_apiCaller != null) {
      return _apiCaller!(
        apiKey: apiKey,
        systemPrompt: systemPrompt,
        messages: messages,
        tools: tools,
      );
    }
    final client = AnthropicClient.withApiKey(apiKey);
    try {
      return await client.messages.create(
        MessageCreateRequest(
          model: 'claude-sonnet-4-20250514',
          maxTokens: 1024,
          system: SystemPrompt.text(systemPrompt),
          messages: messages,
          tools: tools,
        ),
      );
    } finally {
      client.close();
    }
  }

  List<InputMessage> _buildInputMessages(List<Map<String, String>> history) {
    return history.map((m) {
      return InputMessage(
        role: m['role'] == 'user' ? MessageRole.user : MessageRole.assistant,
        content: MessageContent.text(m['content']!),
      );
    }).toList();
  }

  /// 将 ContentBlock 转换为 InputContentBlock（只处理 text 和 tool_use）
  InputContentBlock? _toInputBlock(ContentBlock block) {
    if (block is TextBlock) {
      return InputContentBlock.text(block.text);
    }
    if (block is ToolUseBlock) {
      return InputContentBlock.toolUse(
        id: block.id,
        name: block.name,
        input: block.input,
      );
    }
    return null;
  }
}
