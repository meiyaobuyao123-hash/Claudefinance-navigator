// M09 Token 优化 — HistoryManager 单元测试
// 严格对应 PRD/TECH 验收标准：
//   AC-1: 历史超8条 + token超4000 → messages.length <= 9（摘要+8条）
//   AC-2: 历史 <= 8条 → 直接返回，不调用 AI
//   AC-3: 历史 > 8条但 token <= 4000 → 不压缩，直接返回
//   AC-4: 摘要消息 role=assistant，content 含 [历史摘要]
//   AC-5: 最近8条内容与原始末尾8条一致
//   AC-6: estimateTokens 估算逻辑正确（字符数/1.5）

import 'package:flutter_test/flutter_test.dart';
import 'package:finance_navigator/features/ai_chat/data/history_manager.dart';

List<Map<String, String>> _buildHistory(int count,
    {int contentLength = 10}) {
  return List.generate(count, (i) => {
    'role': i.isEven ? 'user' : 'assistant',
    'content': '消' * contentLength + i.toString(), // 固定长度内容
  });
}

// 生成超过 token 阈值的历史（每条约700字符 ≈ 467 token，10条超过4000）
List<Map<String, String>> _buildLongHistory(int count) {
  return List.generate(count, (i) => {
    'role': i.isEven ? 'user' : 'assistant',
    // 每条约700字符，10条 = 7000字符 / 1.5 ≈ 4667 token > 4000 阈值
    'content': 'a' * 700 + i.toString(),
  });
}

Future<String> _mockAI(String prompt) async =>
    '用户有300万，目标稳健增值，风险中等，已讨论货币基金配置。';

void main() {
  group('HistoryManager.estimateTokens', () {
    test('[AC-6] 空历史 → 0 token', () {
      expect(HistoryManager.estimateTokens([]), 0);
    });

    test('[AC-6] 单条30字符 → 约20 token', () {
      final h = [{'role': 'user', 'content': '这是三十个字符的消息内容测试一下'}];
      final tokens = HistoryManager.estimateTokens(h);
      expect(tokens, closeTo(h[0]['content']!.length ~/ 1.5, 2));
    });

    test('[AC-6] 多条消息累加字符数后除以1.5', () {
      final h = [
        {'role': 'user', 'content': 'aaa'}, // 3字符
        {'role': 'assistant', 'content': 'bbbbbb'}, // 6字符
      ];
      // 总9字符 / 1.5 = 6
      expect(HistoryManager.estimateTokens(h), 6);
    });
  });

  group('HistoryManager.trim — 不触发压缩的情况', () {
    test('[AC-2] 历史 <= 8条 → 原样返回，不调用 AI', () async {
      var aiCalled = false;
      final history = _buildHistory(8);
      final result = await HistoryManager.trim(
        fullHistory: history,
        callAI: (p) async {
          aiCalled = true;
          return '摘要';
        },
      );
      expect(aiCalled, isFalse);
      expect(result, history);
    });

    test('[AC-2] 历史 = 1条 → 原样返回', () async {
      final history = _buildHistory(1);
      final result = await HistoryManager.trim(
        fullHistory: history,
        callAI: _mockAI,
      );
      expect(result, history);
    });

    test('[AC-3] 历史 > 8条但 token <= 4000 → 不压缩', () async {
      // 每条内容短，token 不超阈值
      var aiCalled = false;
      final history = _buildHistory(10, contentLength: 5); // 很短的内容
      final result = await HistoryManager.trim(
        fullHistory: history,
        callAI: (p) async {
          aiCalled = true;
          return '摘要';
        },
      );
      expect(aiCalled, isFalse);
      expect(result, history);
    });
  });

  group('HistoryManager.trim — 触发压缩的情况', () {
    test('[AC-1] 超8条+超token → 返回 [摘要 + 最近8条]，共9条', () async {
      final history = _buildLongHistory(12); // 12条，每条长内容
      final result = await HistoryManager.trim(
        fullHistory: history,
        callAI: _mockAI,
      );
      expect(result.length, 9); // 1摘要 + 8最近
    });

    test('[AC-4] 摘要消息 role=assistant，content 含 [历史摘要]', () async {
      final history = _buildLongHistory(12);
      final result = await HistoryManager.trim(
        fullHistory: history,
        callAI: _mockAI,
      );
      expect(result[0]['role'], 'assistant');
      expect(result[0]['content'], contains('[历史摘要]'));
    });

    test('[AC-5] 最近8条内容与原始末尾8条一致', () async {
      final history = _buildLongHistory(12);
      final result = await HistoryManager.trim(
        fullHistory: history,
        callAI: _mockAI,
      );
      final last8 = history.sublist(12 - 8);
      for (var i = 0; i < 8; i++) {
        expect(result[i + 1], last8[i]);
      }
    });

    test('摘要内容由 callAI 返回值决定', () async {
      final history = _buildLongHistory(10);
      final result = await HistoryManager.trim(
        fullHistory: history,
        callAI: (p) async => '自定义摘要内容XYZ',
      );
      expect(result[0]['content'], contains('自定义摘要内容XYZ'));
    });

    test('超大历史（20条）→ 仍只保留 [摘要 + 最近8条]', () async {
      final history = _buildLongHistory(20);
      final result = await HistoryManager.trim(
        fullHistory: history,
        callAI: _mockAI,
      );
      expect(result.length, 9);
      // 最近8条与原始末尾8条一致
      final last8 = history.sublist(20 - 8);
      for (var i = 0; i < 8; i++) {
        expect(result[i + 1], last8[i]);
      }
    });
  });
}
