import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/config/api_keys.dart';
import '../../../../core/providers/market_rate_provider.dart';
import '../../../../features/fund_tracker/presentation/providers/fund_tracker_provider.dart';
import '../../../../features/stock_tracker/presentation/providers/stock_tracker_provider.dart';
import '../../data/guardrails/input_guardrail.dart';
import '../../data/guardrails/output_guardrail.dart';
import '../../data/prompt_builder.dart';
import '../../data/conversation_stage.dart';

// 消息模型
class ChatMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime time;

  ChatMessage({required this.role, required this.content, DateTime? time})
      : time = time ?? DateTime.now();
}

// 聊天状态Provider
final chatMessagesProvider =
    StateNotifierProvider<ChatMessagesNotifier, List<ChatMessage>>((ref) {
  return ChatMessagesNotifier();
});

class ChatMessagesNotifier extends StateNotifier<List<ChatMessage>> {
  ChatMessagesNotifier() : super([]) {
    // 初始欢迎消息
    state = [
      ChatMessage(
        role: 'assistant',
        content: '你好！我是你的AI理财顾问 🤖\n\n'
            '我会帮你根据你的实际情况，找到最适合的理财产品类型。\n\n'
            '请告诉我：\n'
            '• 你目前有多少可投资的资金？（50万-1000万之间）\n'
            '• 你的主要理财目标是什么？（保值/增值/养老/子女教育/财富传承）\n'
            '• 你能接受多大程度的亏损？',
      ),
    ];
  }

  void addMessage(ChatMessage message) {
    state = [...state, message];
  }

  void clear() {
    state = [
      ChatMessage(
        role: 'assistant',
        content: '你好！我是你的AI理财顾问 🤖\n\n请告诉我你的资产情况和理财目标，我来帮你规划适合的投资方向。',
      ),
    ];
  }
}

final isLoadingProvider = StateProvider<bool>((ref) => false);

class AiChatPage extends ConsumerStatefulWidget {
  const AiChatPage({super.key});

  @override
  ConsumerState<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends ConsumerState<AiChatPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _dio = Dio();

  /// [M03] 用 PromptBuilder 动态构建分层 system prompt
  String _buildSystemPrompt(String userInput) {
    final builder = PromptBuilder(
      userProfile: null, // M01 完成后接入 ref.read(userProfileNotifierProvider)
      marketRates: ref.read(marketRatesProvider).valueOrNull,
      fundHoldings: ref.read(fundHoldingsProvider),
      stockHoldings: ref.read(stockHoldingsProvider),
      stage: ConversationStage.exploring, // M04 完成后接入 conversationStageProvider
    );
    return builder.build(userInput);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 构建对话历史（跳过初始欢迎消息）
  List<Map<String, String>> _buildHistory(List<ChatMessage> messages, String userText) {
    final history = <Map<String, String>>[];
    for (final m in messages) {
      if (messages.indexOf(m) == 0 && m.role == 'assistant') continue;
      history.add({'role': m.role, 'content': m.content});
    }
    history.add({'role': 'user', 'content': userText});
    return history;
  }

  /// [M03] Claude API 通用调用（接受外部构建的 systemPrompt）
  Future<String> _callClaudeWithPrompt(
    String apiKey,
    List<Map<String, String>> history,
    String systemPrompt,
  ) async {
    final response = await _dio.post(
      AppConstants.claudeApiUrl,
      options: Options(
        headers: {
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
          'Content-Type': 'application/json',
        },
      ),
      data: {
        'model': 'claude-sonnet-4-20250514',
        'max_tokens': 2048,
        'system': systemPrompt,
        'messages': history,
      },
    );
    final blocks = response.data['content'] as List;
    return blocks.map((b) => b['text'] as String).join();
  }

  /// 兜底：DeepSeek API（OpenAI 兼容格式）
  Future<String> _callDeepSeek(
    List<Map<String, String>> history, {
    required String systemPrompt,
  }) async {
    final messagesWithSystem = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
      ...history,
    ];
    final response = await _dio.post(
      AppConstants.deepseekApiUrl,
      options: Options(
        headers: {
          'Authorization': 'Bearer ${ApiKeys.deepseekApiKey}',
          'Content-Type': 'application/json',
        },
      ),
      data: {
        'model': 'deepseek-chat',
        'max_tokens': 2048,
        'messages': messagesWithSystem,
      },
    );
    return response.data['choices'][0]['message']['content'] as String;
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final userInput = text.trim();
    final messages = ref.read(chatMessagesProvider);
    final notifier = ref.read(chatMessagesProvider.notifier);

    // 添加用户消息
    notifier.addMessage(ChatMessage(role: 'user', content: userInput));
    _controller.clear();

    // [M07] 输入护栏：检测 prompt injection
    final blocked = InputGuardrail.check(userInput);
    if (blocked != null) {
      notifier.addMessage(ChatMessage(role: 'assistant', content: blocked));
      return;
    }

    // 设置加载状态
    ref.read(isLoadingProvider.notifier).state = true;
    _scrollToBottom();

    try {
      // [M03] 每次发送前动态构建分层 system prompt
      final systemPrompt = _buildSystemPrompt(userInput);
      final history = _buildHistory(messages, userInput);

      // 三级降级：Claude主 → Claude备 → DeepSeek
      String content;
      try {
        content = await _callClaudeWithPrompt(ApiKeys.claudeApiKey, history, systemPrompt);
      } catch (_) {
        try {
          content = await _callClaudeWithPrompt(ApiKeys.claudeApiKeyBackup, history, systemPrompt);
        } catch (_) {
          content = await _callDeepSeek(history, systemPrompt: systemPrompt);
        }
      }

      // [M07] 输出护栏：检测合规风险，必要时追加免责声明
      content = OutputGuardrail.process(content);

      notifier.addMessage(ChatMessage(role: 'assistant', content: content));
    } catch (e) {
      String errorDetail = e.toString();
      if (e is DioException && e.response != null) {
        errorDetail = '状态码：${e.response!.statusCode}\n返回内容：${e.response!.data}';
      }
      notifier.addMessage(ChatMessage(
        role: 'assistant',
        content: '❌ 请求失败\n\n$errorDetail',
      ));
    } finally {
      ref.read(isLoadingProvider.notifier).state = false;
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatMessagesProvider);
    final isLoading = ref.watch(isLoadingProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.go('/'),
          tooltip: '返回',
        ),
        title: const Column(
          children: [
            Text('明理 · AI顾问'),
            Text(
              '由 Claude AI 驱动',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined, size: 22),
            onPressed: () => ref.read(chatMessagesProvider.notifier).clear(),
            tooltip: '重新开始',
          ),
        ],
      ),
      body: Column(
        children: [
          // 消息列表
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: messages.length + (isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == messages.length) {
                  return const _TypingIndicator();
                }
                final message = messages[index];
                return _MessageBubble(message: message);
              },
            ),
          ),
          // 快捷回复建议
          if (messages.length == 1)
            _buildQuickReplies(),
          // 输入框
          _buildInputBar(isLoading),
        ],
      ),
    );
  }

  Widget _buildQuickReplies() {
    final suggestions = [
      '我有100万，想稳健增值',
      '我想为养老做规划',
      '我想了解香港理财产品',
      '我有500万，想多元配置',
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: suggestions.map((text) => GestureDetector(
          onTap: () => _sendMessage(text),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.primary,
              ),
            ),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildInputBar(bool isLoading) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (v) => _sendMessage(v),
                decoration: InputDecoration(
                  hintText: '输入你的问题...',
                  hintStyle: const TextStyle(color: AppColors.textHint),
                  filled: true,
                  fillColor: AppColors.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: isLoading ? null : () => _sendMessage(_controller.text),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isLoading ? AppColors.textHint : AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isLoading ? Icons.hourglass_empty : Icons.send,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.psychology, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isUser ? 18 : 4),
                  topRight: Radius.circular(isUser ? 4 : 18),
                  bottomLeft: const Radius.circular(18),
                  bottomRight: const Radius.circular(18),
                ),
                border: isUser
                    ? null
                    : Border.all(color: AppColors.border),
              ),
              child: Text(
                message.content,
                style: TextStyle(
                  fontSize: 14,
                  color: isUser ? Colors.white : AppColors.textPrimary,
                  height: 1.5,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.psychology, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Row(
                  children: List.generate(3, (i) {
                    final delay = i * 0.3;
                    final value = (_controller.value - delay).clamp(0.0, 0.5);
                    final opacity = value < 0.25 ? value * 4 : (0.5 - value) * 4;
                    return Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(opacity.clamp(0.3, 1.0)),
                        shape: BoxShape.circle,
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
