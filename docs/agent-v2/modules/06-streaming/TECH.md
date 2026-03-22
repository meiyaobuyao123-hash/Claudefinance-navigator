# M06 流式输出 — 技术实现文档

> 版本：v1.0 | 最后更新：2026-03-22

---

## 1. 依赖

```yaml
# pubspec.yaml
dependencies:
  anthropic_sdk_dart: ^0.9.0   # 官方 Dart SDK，支持 SSE 流式
  flutter_markdown: ^0.7.4     # Markdown 渲染
```

> **为什么不用 Dio**：Dio 不原生支持 SSE 流式；`anthropic_sdk_dart` 封装了完整的 SSE 处理逻辑。

---

## 2. 流式调用核心代码

```dart
// lib/features/ai_chat/data/claude_streaming_client.dart

import 'package:anthropic_sdk_dart/anthropic_sdk_dart.dart';

class ClaudeStreamingClient {
  final AnthropicClient _client;

  ClaudeStreamingClient(String apiKey)
      : _client = AnthropicClient(apiKey: apiKey);

  /// 返回 Stream<String>，每次 yield 一个 chunk
  Stream<String> streamMessage({
    required String systemPrompt,
    required List<Map<String, dynamic>> messages,
    String model = 'claude-sonnet-4-20250514',
    int maxTokens = 1024,
  }) async* {
    final stream = _client.messages.stream(
      request: CreateMessageRequest(
        model: Model.modelId(model),
        maxTokens: maxTokens,
        system: systemPrompt,
        messages: messages.map((m) => Message(
          role: MessageRole.fromJson(m['role']!),
          content: MessageContent.text(m['content']!),
        )).toList(),
      ),
    );

    await for (final event in stream) {
      if (event is MessageStreamEventContentBlockDelta) {
        final delta = event.delta;
        if (delta is TextDelta) {
          yield delta.text;
        }
      }
    }
  }
}
```

---

## 3. UI 集成（ai_chat_page.dart 修改）

```dart
// 状态变量
String _streamingContent = '';
bool _isStreaming = false;

Future<void> _sendMessageStreaming(String userInput) async {
  setState(() {
    _isStreaming = true;
    _streamingContent = '';
    _messages.add(ChatMessage(role: 'user', content: userInput));
    _messages.add(ChatMessage(role: 'assistant', content: '')); // 占位
  });

  final systemPrompt = _buildSystemPrompt(userInput);
  final history = _buildHistory(); // 不含最后占位的 assistant 消息

  try {
    await for (final chunk in _streamingClient.streamMessage(
      systemPrompt: systemPrompt,
      messages: history,
    )) {
      setState(() {
        _streamingContent += chunk;
        // 更新最后一条占位消息
        _messages.last = ChatMessage(role: 'assistant', content: _streamingContent);
      });
    }
  } catch (e) {
    setState(() {
      _messages.last = ChatMessage(
        role: 'assistant',
        content: _streamingContent.isEmpty
            ? '网络异常，请重试。'
            : '$_streamingContent\n\n_（消息已截断，网络异常）_',
      );
    });
  } finally {
    setState(() => _isStreaming = false);
  }
}
```

---

## 4. Markdown 渲染 Widget

```dart
// 在消息气泡中替换 Text 为 MarkdownBody

Widget _buildAssistantBubble(String content) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.grey[100],
      borderRadius: BorderRadius.circular(12),
    ),
    child: MarkdownBody(
      data: content,
      styleSheet: MarkdownStyleSheet(
        p: const TextStyle(fontSize: 15, height: 1.6),
        strong: const TextStyle(fontWeight: FontWeight.w600),
        code: TextStyle(
          backgroundColor: Colors.grey[200],
          fontFamily: 'monospace',
        ),
      ),
    ),
  );
}
```

---

## 5. 等待状态（TTFT 前）

```dart
// 当 _isStreaming && _streamingContent.isEmpty 时显示

Widget _buildThinkingIndicator() {
  return Row(
    children: [
      const Text('明理正在思考', style: TextStyle(color: Colors.grey)),
      const SizedBox(width: 4),
      _ThreeDotsAnimation(), // 自定义三点跳动动画
    ],
  );
}
```

---

## 6. 降级策略

```dart
// 如果 anthropic_sdk_dart 初始化失败（如包版本冲突），降级回 http.post 非流式

Stream<String> streamMessage(...) async* {
  try {
    // 尝试流式
    await for (final chunk in _client.messages.stream(...)) { ... yield ...; }
  } catch (e) {
    // 降级：一次性请求，伪流式（100ms 间隔 yield 字符）
    final fullResponse = await _fallbackHttpCall(...);
    for (final char in fullResponse.characters) {
      yield char;
      await Future.delayed(const Duration(milliseconds: 15));
    }
  }
}
```

---

## 7. 测试计划

| 用例 | 方式 |
|------|------|
| TTFT 计时 | `Stopwatch` 从发送到第一次 setState |
| Markdown 渲染正确性 | Widget 测试 |
| 断网中途截断 | 模拟网络中断 |
| 重试按钮功能 | 集成测试 |

---

## 8. 文件清单

```
lib/features/ai_chat/data/
└── claude_streaming_client.dart

lib/features/ai_chat/presentation/pages/
└── ai_chat_page.dart       # 修改：添加流式逻辑 + Markdown 渲染
```
