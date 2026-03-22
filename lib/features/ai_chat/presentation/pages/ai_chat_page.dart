import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/market_rate_provider.dart';
import '../../../../features/fund_tracker/presentation/providers/fund_tracker_provider.dart';
import '../../../../features/stock_tracker/presentation/providers/stock_tracker_provider.dart';
import '../../data/guardrails/input_guardrail.dart';
import '../../data/guardrails/output_guardrail.dart';
import '../../data/prompt_builder.dart';
import '../../data/conversation_stage.dart';
import '../../data/conversation_summarizer.dart';
import '../../data/claude_streaming_client.dart';
import '../../data/portfolio_context_builder.dart';
import '../../data/tools/rule_trigger.dart';
import '../../data/tools/tool_executor.dart';
import '../../presentation/providers/conversation_state_provider.dart';
import '../../../../features/onboarding/providers/user_profile_provider.dart';

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

class AiChatPage extends ConsumerStatefulWidget {
  const AiChatPage({super.key});

  @override
  ConsumerState<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends ConsumerState<AiChatPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  // [M06] 流式状态（本地 setState 管理）
  String _streamingContent = '';
  bool _isStreaming = false;
  bool _streamingError = false;
  String? _lastFailedInput; // 用于重试

  // [M04] 对话摘要后的压缩历史（null 表示使用完整历史）
  List<Map<String, String>>? _summarizedHistory;

  @override
  void initState() {
    super.initState();
    // [M01] 首次进入聊天页时检查是否需要冷启动引导
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final shouldOnboard = await ref
          .read(userProfileNotifierProvider.notifier)
          .shouldShowOnboarding();
      if (shouldOnboard && mounted) {
        context.go('/onboarding');
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// [M03+M04] 用 PromptBuilder 动态构建分层 system prompt（接入真实对话阶段）
  String _buildSystemPrompt(String userInput) {
    final builder = PromptBuilder(
      userProfile: ref.read(userProfileNotifierProvider),
      marketRates: ref.read(marketRatesProvider).valueOrNull,
      fundHoldings: ref.read(fundHoldingsProvider),
      stockHoldings: ref.read(stockHoldingsProvider),
      stage: ref.read(conversationStateProvider).stage, // [M04] 真实阶段
    );
    return builder.build(userInput);
  }

  /// 构建对话历史（跳过初始欢迎消息，不含当前用户输入）
  List<Map<String, String>> _buildHistory(List<ChatMessage> messages) {
    final history = <Map<String, String>>[];
    for (var i = 0; i < messages.length; i++) {
      if (i == 0 && messages[i].role == 'assistant') continue;
      history.add({'role': messages[i].role, 'content': messages[i].content});
    }
    return history;
  }

  /// [M06] 流式发送消息
  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isStreaming) return;

    final userInput = text.trim();
    final notifier = ref.read(chatMessagesProvider.notifier);
    final messages = ref.read(chatMessagesProvider);

    // 添加用户消息
    notifier.addMessage(ChatMessage(role: 'user', content: userInput));
    _controller.clear();

    // [M07] 输入护栏
    final blocked = InputGuardrail.check(userInput);
    if (blocked != null) {
      notifier.addMessage(ChatMessage(role: 'assistant', content: blocked));
      return;
    }

    // [M04] 更新对话阶段状态机
    final hasProfile = ref.read(userProfileNotifierProvider) != null;
    ref.read(conversationStateProvider.notifier).onUserMessage(
          userInput,
          hasUserProfile: hasProfile,
        );

    // [M04] 检查是否需要对话摘要
    final convState = ref.read(conversationStateProvider);
    if (convState.shouldSummarize && !convState.hasSummarized) {
      final baseHistory = _summarizedHistory ?? _buildHistory(ref.read(chatMessagesProvider));
      _summarizedHistory = await ConversationSummarizer.summarize(
        history: baseHistory,
        callAI: (prompt) async {
          var result = '';
          await for (final chunk in ClaudeStreamingClient.streamMessage(
            systemPrompt: '',
            history: [
              {'role': 'user', 'content': prompt}
            ],
          )) {
            result += chunk;
          }
          return result;
        },
      );
      ref.read(conversationStateProvider.notifier).markSummarized();
    }

    // [M05] 规则触发层：关键词命中则预先执行工具，结果注入 system prompt
    final triggeredTools = RuleTrigger.getTriggeredTools(userInput);
    String toolContext = '';
    if (triggeredTools.isNotEmpty) {
      final executor = ToolExecutor(
        portfolioBuilder: PortfolioContextBuilder(
          fundHoldings: ref.read(fundHoldingsProvider),
          stockHoldings: ref.read(stockHoldingsProvider),
        ),
      );
      final results = <String>[];
      for (final tool in triggeredTools) {
        final result = await executor.execute(tool, {});
        results.add('[$tool] $result');
      }
      toolContext = '\n\n【实时工具数据】\n${results.join('\n')}';
    }

    // 构建 system prompt 和历史（摘要后使用压缩历史）
    final systemPrompt = _buildSystemPrompt(userInput) + toolContext;
    final history = (_summarizedHistory ?? _buildHistory(messages))
      ..add({'role': 'user', 'content': userInput});

    setState(() {
      _isStreaming = true;
      _streamingContent = '';
      _streamingError = false;
      _lastFailedInput = userInput;
    });
    _scrollToBottom();

    try {
      await for (final chunk in ClaudeStreamingClient.streamMessage(
        systemPrompt: systemPrompt,
        history: history,
      )) {
        if (!mounted) return;
        setState(() => _streamingContent += chunk);
        _scrollToBottom();
      }

      // 流式完成 → 应用输出护栏 → 加入消息列表
      if (mounted) {
        final finalContent = OutputGuardrail.process(_streamingContent);
        notifier.addMessage(
            ChatMessage(role: 'assistant', content: finalContent));
        setState(() {
          _isStreaming = false;
          _streamingContent = '';
          _lastFailedInput = null;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isStreaming = false;
        _streamingError = true;
        // 保留已有内容（截断提示）
        final truncated = _streamingContent.isNotEmpty
            ? '$_streamingContent\n\n_（消息已截断，网络异常）_'
            : null;
        if (truncated != null) {
          notifier.addMessage(
              ChatMessage(role: 'assistant', content: truncated));
        }
        _streamingContent = '';
      });
    }

    _scrollToBottom();
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
            onPressed: _isStreaming
                ? null
                : () {
                    ref.read(chatMessagesProvider.notifier).clear();
                    ref.read(conversationStateProvider.notifier).reset();
                    setState(() => _summarizedHistory = null);
                  },
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
              itemCount: messages.length +
                  (_isStreaming || _streamingError ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == messages.length) {
                  // 流式区域：等待首字符 or 实时内容 or 错误+重试
                  if (_streamingError) {
                    return _RetryBubble(
                      onRetry: _lastFailedInput != null
                          ? () => _sendMessage(_lastFailedInput!)
                          : null,
                    );
                  }
                  if (_streamingContent.isEmpty) {
                    return const _TypingIndicator();
                  }
                  return _StreamingBubble(content: _streamingContent);
                }
                return _MessageBubble(message: messages[index]);
              },
            ),
          ),
          // 快捷回复（仅初始状态）
          if (messages.length == 1 && !_isStreaming) _buildQuickReplies(),
          // 输入框
          _buildInputBar(),
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
        children: suggestions
            .map((text) => GestureDetector(
                  onTap: () => _sendMessage(text),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      text,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildInputBar() {
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
                enabled: !_isStreaming,
                onSubmitted: (v) => _sendMessage(v),
                decoration: InputDecoration(
                  hintText: _isStreaming ? '明理正在回复...' : '输入你的问题...',
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
              onTap: _isStreaming
                  ? null
                  : () => _sendMessage(_controller.text),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _isStreaming
                      ? AppColors.textHint
                      : AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isStreaming ? Icons.hourglass_empty : Icons.send,
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

// ── 已完成的消息气泡（assistant 使用 Markdown）────────────────────
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
            _AiAvatar(),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isUser ? 18 : 4),
                  topRight: Radius.circular(isUser ? 4 : 18),
                  bottomLeft: const Radius.circular(18),
                  bottomRight: const Radius.circular(18),
                ),
                border: isUser ? null : Border.all(color: AppColors.border),
              ),
              child: isUser
                  ? Text(
                      message.content,
                      style: const TextStyle(
                          fontSize: 14, color: Colors.white, height: 1.5),
                    )
                  : MarkdownBody(
                      data: message.content,
                      styleSheet: _mdStyle(),
                    ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// ── 流式实时气泡（逐字渲染）────────────────────────────────────────
class _StreamingBubble extends StatelessWidget {
  final String content;
  const _StreamingBubble({required this.content});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AiAvatar(),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                border: Border.all(color: AppColors.border),
              ),
              child: MarkdownBody(
                data: content,
                styleSheet: _mdStyle(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 错误 + 重试气泡 ────────────────────────────────────────────────
class _RetryBubble extends StatelessWidget {
  final VoidCallback? onRetry;
  const _RetryBubble({this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AiAvatar(),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('网络异常',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
                if (onRetry != null) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onRetry,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('重试',
                          style: TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── AI 头像 ─────────────────────────────────────────────────────
class _AiAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.psychology, color: Colors.white, size: 18),
    );
  }
}

// ── 等待首字符动画（TTFT 前）────────────────────────────────────
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
          _AiAvatar(),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('明理正在思考',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(width: 4),
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Row(
                      children: List.generate(3, (i) {
                        final delay = i * 0.3;
                        final value =
                            (_controller.value - delay).clamp(0.0, 0.5);
                        final opacity =
                            value < 0.25 ? value * 4 : (0.5 - value) * 4;
                        return Container(
                          width: 5,
                          height: 5,
                          margin:
                              const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary
                                .withValues(alpha: opacity.clamp(0.3, 1.0)),
                            shape: BoxShape.circle,
                          ),
                        );
                      }),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Markdown 样式 ────────────────────────────────────────────────
MarkdownStyleSheet _mdStyle() {
  return MarkdownStyleSheet(
    p: const TextStyle(
        fontSize: 14, color: AppColors.textPrimary, height: 1.6),
    strong: const TextStyle(
        fontSize: 14,
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600),
    code: TextStyle(
      fontSize: 13,
      backgroundColor: Colors.grey[100],
      fontFamily: 'monospace',
      color: AppColors.textPrimary,
    ),
    codeblockDecoration: BoxDecoration(
      color: Colors.grey[100],
      borderRadius: BorderRadius.circular(6),
    ),
    listBullet:
        const TextStyle(fontSize: 14, color: AppColors.textPrimary),
  );
}
