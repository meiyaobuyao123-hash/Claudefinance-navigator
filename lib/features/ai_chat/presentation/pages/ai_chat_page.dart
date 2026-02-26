import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';

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

  // 系统提示词 - 定义AI角色和行为边界
  static const String _systemPrompt = '''
你是一位专业的中国理财规划顾问AI助手。你的职责是帮助持有50万-1000万人民币的中国投资者了解适合他们的理财产品类型，并引导他们去合适的平台自主投资。

【重要边界】
- 你只推荐产品类型（如"货币基金"、"银行理财"、"宽基ETF"），不推荐具体产品代码或基金名称
- 你不接触任何资金，不提供具体交易操作
- 你是教育和导航工具，不是持牌投资顾问
- 对于股票选股、具体基金选择，告知用户需要自己判断或咨询持牌机构

【你了解的投资产品范围】
大陆：活期存款、货币基金、定期存款（3月/6月/1/2/3/5年不同利率）、大额存单（20万起）、国债、银行理财、债券基金、可转债、A股、指数ETF、公募基金、私募基金（100万起）、公募REITs、增额终身寿险、年金险、纸黄金/黄金ETF、QDII基金

香港：港股通（需50万证券资产）、跨境理财通（大湾区专属）、香港定期存款（港元3月约4-5%）、香港储蓄分红保险（IRR约4-6%，需赴港）、海外ETF（通过IBKR/富途）

加密：香港比特币ETF（3042.HK）、HashKey Exchange合规渠道

【对话策略】
1. 先了解用户资产量（50-100万/100-500万/500-1000万）
2. 了解风险承受能力（保守/稳健/平衡/积极/激进）
3. 了解投资目标和期限
4. 了解是否能赴港、是否了解加密
5. 基于以上信息，推荐产品类型组合和参考配比（如"50%固收+30%权益+10%保险+10%黄金"）
6. 解释每类产品的收益和风险
7. 告知可以去哪些平台（天天基金、支付宝、同花顺等）自主操作

【语气风格】
- 专业但亲切，像一位有经验的朋友
- 回答简洁清晰，多用列表和结构化输出
- 遇到高风险产品要主动提示风险
- 用中文回复
''';

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final messages = ref.read(chatMessagesProvider);
    final notifier = ref.read(chatMessagesProvider.notifier);

    // 添加用户消息
    notifier.addMessage(ChatMessage(role: 'user', content: text.trim()));
    _controller.clear();

    // 设置加载状态
    ref.read(isLoadingProvider.notifier).state = true;
    _scrollToBottom();

    try {
      // 构建发送给Claude的消息历史
      final history = messages
          .where((m) => m.role != 'assistant' || messages.indexOf(m) > 0)
          .map((m) => {'role': m.role, 'content': m.content})
          .toList();
      history.add({'role': 'user', 'content': text.trim()});

      final response = await _dio.post(
        AppConstants.claudeApiUrl,
        options: Options(
          headers: {
            'x-api-key': 'YOUR_CLAUDE_API_KEY', // TODO: 替换为实际API Key
            'anthropic-version': '2023-06-01',
            'content-type': 'application/json',
          },
        ),
        data: {
          'model': 'claude-3-5-sonnet-20241022',
          'max_tokens': 1024,
          'system': _systemPrompt,
          'messages': history,
        },
      );

      final content = response.data['content'][0]['text'] as String;
      notifier.addMessage(ChatMessage(role: 'assistant', content: content));
    } catch (e) {
      notifier.addMessage(ChatMessage(
        role: 'assistant',
        content: '抱歉，连接出现问题。请检查网络连接或稍后重试。\n\n错误信息：$e',
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
        title: const Column(
          children: [
            Text('AI理财诊断'),
            Text(
              '由 Claude AI 驱动',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
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
