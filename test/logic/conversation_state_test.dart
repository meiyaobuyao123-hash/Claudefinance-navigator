// M04 对话阶段状态机 — 单元测试
// 严格对应 PRD/TECH 验收标准：
//   AC-1: 新会话默认 exploring 阶段
//   AC-2: 消息数 >= 3 → deepening
//   AC-3: 行动关键词 → actioning
//   AC-4: 复盘关键词 → reviewing（最高优先级）
//   AC-5: messageCount >= 20 → shouldSummarize = true
//   AC-6: estimatedTokens >= 8000 → shouldSummarize = true
//   AC-7: 行动阶段中出现分析性问题 → 回退 deepening
//   AC-8: 已有 userProfile → 直接进入 deepening
//   AC-9: ConversationSummarizer 保留最近5条 + 摘要
//   AC-10: history <= 5 时不触发摘要

import 'package:flutter_test/flutter_test.dart';
import 'package:finance_navigator/features/ai_chat/data/conversation_state.dart';
import 'package:finance_navigator/features/ai_chat/data/conversation_stage.dart';
import 'package:finance_navigator/features/ai_chat/data/conversation_summarizer.dart';
import 'package:finance_navigator/features/ai_chat/presentation/providers/conversation_state_provider.dart';

void main() {
  // ── ConversationState 模型测试 ─────────────────────────────
  group('ConversationState 模型', () {
    test('默认值：exploring 阶段，messageCount=0，token=0', () {
      const s = ConversationState();
      expect(s.stage, ConversationStage.exploring);
      expect(s.messageCount, 0);
      expect(s.estimatedTokens, 0);
      expect(s.hasSummarized, false);
    });

    test('copyWith 只修改指定字段', () {
      const s = ConversationState(messageCount: 5);
      final s2 = s.copyWith(stage: ConversationStage.deepening);
      expect(s2.stage, ConversationStage.deepening);
      expect(s2.messageCount, 5); // 未变
    });

    test('[AC-5] messageCount >= 20 → shouldSummarize = true', () {
      const s = ConversationState(messageCount: 20);
      expect(s.shouldSummarize, isTrue);
    });

    test('messageCount = 19 → shouldSummarize = false', () {
      const s = ConversationState(messageCount: 19);
      expect(s.shouldSummarize, isFalse);
    });

    test('[AC-6] estimatedTokens >= 8000 → shouldSummarize = true', () {
      const s = ConversationState(estimatedTokens: 8000);
      expect(s.shouldSummarize, isTrue);
    });

    test('estimatedTokens = 7999 → shouldSummarize = false', () {
      const s = ConversationState(estimatedTokens: 7999);
      expect(s.shouldSummarize, isFalse);
    });

    test('两个条件均不满足 → shouldSummarize = false', () {
      const s = ConversationState(messageCount: 5, estimatedTokens: 500);
      expect(s.shouldSummarize, isFalse);
    });
  });

  // ── ConversationStateNotifier 状态机逻辑 ──────────────────
  group('ConversationStateNotifier 阶段转换', () {
    late ConversationStateNotifier notifier;

    setUp(() {
      notifier = ConversationStateNotifier();
    });

    test('[AC-1] 新会话默认 exploring 阶段', () {
      expect(notifier.state.stage, ConversationStage.exploring);
      expect(notifier.state.messageCount, 0);
    });

    test('[AC-1] 第1条普通消息 → 仍在 exploring', () {
      notifier.onUserMessage('你好');
      expect(notifier.state.stage, ConversationStage.exploring);
      expect(notifier.state.messageCount, 1);
    });

    test('[AC-1] 第2条普通消息 → 仍在 exploring', () {
      notifier.onUserMessage('你好');
      notifier.onUserMessage('目前有300万存款');
      expect(notifier.state.stage, ConversationStage.exploring);
      expect(notifier.state.messageCount, 2);
    });

    test('[AC-2] 第3条普通消息 → deepening', () {
      notifier.onUserMessage('你好');
      notifier.onUserMessage('我有200万');
      notifier.onUserMessage('主要是稳健投资');
      expect(notifier.state.stage, ConversationStage.deepening);
      expect(notifier.state.messageCount, 3);
    });

    test('[AC-3] 含"怎么买" → actioning', () {
      notifier.onUserMessage('货币基金怎么买？');
      expect(notifier.state.stage, ConversationStage.actioning);
    });

    test('[AC-3] 含"下一步" → actioning', () {
      notifier.onUserMessage('我应该下一步怎么做');
      expect(notifier.state.stage, ConversationStage.actioning);
    });

    test('[AC-3] 含"我想" → actioning', () {
      notifier.onUserMessage('我想配置一些债券');
      expect(notifier.state.stage, ConversationStage.actioning);
    });

    test('[AC-3] 含"准备" → actioning', () {
      notifier.onUserMessage('我准备买点货币基金');
      expect(notifier.state.stage, ConversationStage.actioning);
    });

    test('[AC-3] 含"去哪买" → actioning', () {
      notifier.onUserMessage('这个产品去哪买');
      expect(notifier.state.stage, ConversationStage.actioning);
    });

    test('[AC-4] 含"当时" → reviewing（最高优先级）', () {
      notifier.onUserMessage('我当时买的那支基金');
      expect(notifier.state.stage, ConversationStage.reviewing);
    });

    test('[AC-4] 含"我买了" → reviewing', () {
      notifier.onUserMessage('我买了一些沪深300，现在亏了');
      expect(notifier.state.stage, ConversationStage.reviewing);
    });

    test('[AC-4] 含"之前" → reviewing', () {
      notifier.onUserMessage('之前你建议我买货币基金');
      expect(notifier.state.stage, ConversationStage.reviewing);
    });

    test('[AC-4] 复盘关键词优先于行动关键词', () {
      // 同时含"我想"（行动）和"当时"（复盘），复盘优先
      notifier.onUserMessage('我想回顾当时的决策');
      expect(notifier.state.stage, ConversationStage.reviewing);
    });

    test('[AC-8] hasUserProfile=true → 第1条消息就进入 deepening', () {
      notifier.onUserMessage('你好', hasUserProfile: true);
      expect(notifier.state.stage, ConversationStage.deepening);
    });

    test('[AC-7] 行动阶段中含"为什么" → 回退 deepening', () {
      // 先进入行动阶段
      notifier.onUserMessage('我想买货币基金');
      expect(notifier.state.stage, ConversationStage.actioning);
      // 再问分析性问题
      notifier.onUserMessage('为什么货币基金比较安全');
      expect(notifier.state.stage, ConversationStage.deepening);
    });

    test('[AC-7] 行动阶段中含"分析" → 回退 deepening', () {
      notifier.onUserMessage('我想做配置');
      notifier.onUserMessage('帮我分析一下利弊');
      expect(notifier.state.stage, ConversationStage.deepening);
    });

    test('[AC-7] 行动阶段中含"比较" → 回退 deepening', () {
      notifier.onUserMessage('准备买');
      notifier.onUserMessage('帮我比较下两个产品');
      expect(notifier.state.stage, ConversationStage.deepening);
    });

    test('行动阶段中普通消息 → 保持 actioning', () {
      notifier.onUserMessage('我想买');
      notifier.onUserMessage('好的谢谢');
      expect(notifier.state.stage, ConversationStage.actioning);
    });

    test('addTokens 累加 estimatedTokens', () {
      notifier.addTokens(3000);
      notifier.addTokens(2000);
      expect(notifier.state.estimatedTokens, 5000);
    });

    test('markSummarized 设置 hasSummarized=true，重置 token 到2000', () {
      notifier.addTokens(9000);
      notifier.markSummarized();
      expect(notifier.state.hasSummarized, isTrue);
      expect(notifier.state.estimatedTokens, 2000);
    });

    test('reset 恢复初始状态', () {
      notifier.onUserMessage('我想买货币基金');
      notifier.addTokens(5000);
      notifier.reset();
      expect(notifier.state.stage, ConversationStage.exploring);
      expect(notifier.state.messageCount, 0);
      expect(notifier.state.estimatedTokens, 0);
    });

    test('messageCount 每次 onUserMessage 递增1', () {
      for (var i = 0; i < 5; i++) {
        notifier.onUserMessage('消息$i');
      }
      expect(notifier.state.messageCount, 5);
    });
  });

  // ── ConversationSummarizer 摘要逻辑 ───────────────────────
  group('ConversationSummarizer', () {
    Future<String> mockAI(String prompt) async =>
        '用户有300万，目标稳健增值，风险偏好中等。已讨论货币基金和债券配置。';

    List<Map<String, String>> buildHistory(int count) {
      return List.generate(count, (i) {
        return {
          'role': i.isEven ? 'user' : 'assistant',
          'content': '消息内容$i',
        };
      });
    }

    test('[AC-10] history <= 5 → 直接返回原列表，不调用 AI', () async {
      var aiCalled = false;
      final history = buildHistory(5);
      final result = await ConversationSummarizer.summarize(
        history: history,
        callAI: (p) async {
          aiCalled = true;
          return '摘要';
        },
      );
      expect(aiCalled, isFalse);
      expect(result, history);
    });

    test('[AC-9] history > 5 → 返回 [摘要 + 最近5条]，共6条', () async {
      final history = buildHistory(10);
      final result = await ConversationSummarizer.summarize(
        history: history,
        callAI: mockAI,
      );
      expect(result.length, 6); // 1 摘要 + 5 最近
      expect(result[0]['content'], contains('[对话摘要]'));
    });

    test('[AC-9] 摘要消息 role 为 assistant', () async {
      final history = buildHistory(8);
      final result = await ConversationSummarizer.summarize(
        history: history,
        callAI: mockAI,
      );
      expect(result[0]['role'], 'assistant');
    });

    test('[AC-9] 最近5条内容与原始历史末尾5条一致', () async {
      final history = buildHistory(8);
      final result = await ConversationSummarizer.summarize(
        history: history,
        callAI: mockAI,
      );
      final last5 = history.sublist(3); // 8-5=3
      for (var i = 0; i < 5; i++) {
        expect(result[i + 1], last5[i]);
      }
    });

    test('history = 6 → 摘要前1条，保留后5条', () async {
      final history = buildHistory(6);
      final result = await ConversationSummarizer.summarize(
        history: history,
        callAI: mockAI,
      );
      expect(result.length, 6);
      expect(result[0]['content'], contains('[对话摘要]'));
    });

    test('摘要文本由 callAI 返回内容决定', () async {
      final history = buildHistory(7);
      final result = await ConversationSummarizer.summarize(
        history: history,
        callAI: (p) async => '自定义摘要内容',
      );
      expect(result[0]['content'], contains('自定义摘要内容'));
    });
  });
}
