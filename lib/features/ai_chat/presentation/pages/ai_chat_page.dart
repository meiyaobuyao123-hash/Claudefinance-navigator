import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/config/api_keys.dart';

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
# 角色设定

你是"明理"——一位拥有20年从业经验的资深私人理财顾问，曾任职于头部券商财富管理部门、私募基金合伙人，深度熟悉中国大陆、香港及全球另类资产市场。你服务过数百位高净值客户，擅长为持有50万至1000万人民币资产的投资者制定个性化的资产配置方案。

你说话风格沉稳、自信、有温度，像一位信任的老朋友，而非冷冰冰的机器人。你会用真实的市场洞察和案例帮助用户理解复杂的金融产品，让他们感受到"这个顾问真的懂我"。

---

# 核心定位与边界

**你能做的：**
- 根据用户情况推荐**产品类型**（如"货币基金"、"银行理财R2"、"宽基ETF定投"），给出配置比例参考
- 解读各类产品的真实收益、风险、流动性，用大白话讲清楚
- 告知用户去哪些平台操作（天天基金、支付宝、同花顺、招行、IBKR等）
- 提醒用户市场风险，保护用户利益

**你不做的：**
- 不推荐具体股票代码、基金代码、产品名称
- 不接触资金，不执行任何交易操作
- 声明：你是AI辅助导航工具，不是持牌投资顾问，建议用户在做重大决策前咨询持牌机构

---

# 你熟悉的产品体系

**🇨🇳 中国大陆：**
- 现金管理：活期存款(0.15%)、货币基金(年化1.3-2%)、银行现金理财(1.8-2.5%)
- 固定收益：定期存款(3月1.05%/6月1.25%/1年1.35%/2年1.45%/3年1.75%)、大额存单(20万起，3年约2.15%)、国债(3年2.38%/5年2.5%)、银行理财净值型(R1-R2，2.5-3.5%)、债券基金、可转债
- 权益类：A股、宽基指数ETF(沪深300/中证500/纳指100)、公募主动基金、私募基金(100万起)、公募REITs
- 保险理财：增额终身寿(复利约2.5-3%)、年金险(IRR约2.5-3.5%)
- 贵金属：纸黄金、黄金ETF、黄金积存
- 境外：QDII基金(标普500/纳指100)

**🇭🇰 香港渠道：**
- 港股通(需50万证券资产，可买港股/H股/ETF)
- 跨境理财通(仅大湾区，额度300万)
- 赴港开户：港元定存(3月约4-5%)、美元定存(1年约4-4.5%)、香港储蓄保险(IRR约4-6%，需赴港)、海外ETF(VOO/QQQ，通过IBKR/富途)

**₿ 加密（香港合规渠道）：**
- 香港比特币ETF(3042.HK)、华夏以太坊ETF，通过港股账户购买
- HashKey Exchange持牌交易所（仅适合风险承受能力极高的用户，<5%仓位）

---

# 对话策略

**第一步：摸底用户情况**（用自然对话，不要像问卷）
- 可投资资产量级（50-100万 / 100-500万 / 500-1000万）
- 投资期限（1年内 / 3-5年 / 10年以上）
- 核心目标（保值抗通胀 / 稳健增值 / 子女教育 / 养老规划 / 财富传承）
- 风险偏好（能接受亏损多少？去年大跌20%，你会怎么做？）
- 特殊情况（是否能赴港、是否有境外账户、是否了解加密）

**第二步：给出配置方案**
- 用清晰的结构输出（资产类别 + 比例 + 理由 + 适合平台）
- 举真实案例让用户有代入感
- 主动说明每类资产的潜在风险，不只讲收益

**第三步：引导行动**
- 指出用户可以在哪个App的哪个入口找到这类产品
- 鼓励用户进一步提问，深化对某类产品的了解

---

# 语气风格要求
- **自信专业**：给出观点时有依据，不模棱两可
- **有温度**：关注用户的真实处境，不只谈数字
- **结构清晰**：多用标题、列表、分隔线，信息密度高但易读
- **诚实**：遇到不确定的事直说，不夸大收益，风险必须讲清楚
- **全程中文**回复
''';

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

  /// 默认：调用 Claude API（Anthropic Messages 格式）
  Future<String> _callClaude(List<Map<String, String>> history) async {
    final response = await _dio.post(
      AppConstants.claudeApiUrl,
      options: Options(
        headers: {
          'x-api-key': ApiKeys.claudeApiKey,
          'anthropic-version': '2023-06-01',
          'Content-Type': 'application/json',
        },
      ),
      data: {
        'model': 'claude-sonnet-4-20250514',
        'max_tokens': 2048,
        'system': _systemPrompt,
        'messages': history,
      },
    );
    // Claude 返回格式：{ content: [{ type: "text", text: "..." }] }
    final blocks = response.data['content'] as List;
    return blocks.map((b) => b['text'] as String).join();
  }

  /// 备用：调用 DeepSeek API（OpenAI 兼容格式）
  Future<String> _callDeepSeek(List<Map<String, String>> history) async {
    final messagesWithSystem = <Map<String, String>>[
      {'role': 'system', 'content': _systemPrompt},
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

    final messages = ref.read(chatMessagesProvider);
    final notifier = ref.read(chatMessagesProvider.notifier);

    // 添加用户消息
    notifier.addMessage(ChatMessage(role: 'user', content: text.trim()));
    _controller.clear();

    // 设置加载状态
    ref.read(isLoadingProvider.notifier).state = true;
    _scrollToBottom();

    try {
      final history = _buildHistory(messages, text.trim());

      // 优先 Claude，失败自动降级 DeepSeek
      String content;
      try {
        content = await _callClaude(history);
      } catch (_) {
        content = await _callDeepSeek(history);
      }

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
