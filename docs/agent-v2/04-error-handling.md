# 明理 Agent v2 — 统一错误处理与降级策略

> 版本：v1.0 | 最后更新：2026-03-22

---

## 1. 设计原则

1. **对用户透明**：每种失败都有明确的用户可见提示，不静默失败
2. **不中断对话**：任何单点失败不应导致整个对话不可用
3. **降级而非报错**：优先用更低级但可用的功能替代，而非抛出错误弹窗
4. **异步失败隔离**：上报/统计等非核心操作失败不影响主流程

---

## 2. 错误分类与处理矩阵

### 2.1 AI API 层

| 错误场景 | 检测方式 | 降级策略 | 用户提示 |
|---------|---------|---------|---------|
| Claude 主 Key 超时/5xx | `catch` HTTP 异常 | 切换备用 Key | 无感知（透明切换）|
| Claude 备用 Key 失败 | `catch` HTTP 异常 | 切换 DeepSeek | 无感知 |
| DeepSeek 也失败 | `catch` HTTP 异常 | 终止，提示用户 | "网络繁忙，请稍后重试" + 重试按钮 |
| API 返回 429（限流） | HTTP status 429 | 等待 2s 后重试一次，仍失败切换下级 | 无感知 |
| 流式中途断开 | Stream `addError` | 显示已接收内容 + 截断提示 | "消息已截断，点击重新发送" |
| tool_use 循环超过3轮 | 计数器 | 强制返回降级文本 | "暂时无法获取实时数据，以下基于已知信息回答" |

```dart
// ai_chat_page.dart 三级降级实现
Future<String> _callWithFallback(List<Map<String,dynamic>> history, String systemPrompt) async {
  // 级别1：Claude 主 Key
  try {
    return await _agent.run(systemPrompt: systemPrompt, history: history, apiKey: ApiKeys.claudeApiKey);
  } catch (e) {
    debugPrint('Claude primary failed: $e');
  }
  // 级别2：Claude 备用 Key
  try {
    return await _agent.run(systemPrompt: systemPrompt, history: history, apiKey: ApiKeys.claudeApiKeyBackup);
  } catch (e) {
    debugPrint('Claude backup failed: $e');
  }
  // 级别3：DeepSeek
  try {
    return await _callDeepSeek(history);
  } catch (e) {
    debugPrint('DeepSeek failed: $e');
    throw const AIUnavailableException();
  }
}
```

### 2.2 Tool Use 层

| 错误场景 | 处理 |
|---------|------|
| `get_market_rates` 超时 | 返回 `{"error":"timeout","cached":true}`，明理用缓存数据 + 声明时效 |
| `get_portfolio_summary` 持仓为空 | 返回 `{"holdings":[]}`，明理引导用户添加持仓 |
| 未知工具名 | 返回 `{"error":"unknown_tool"}`，跳过该工具继续 |
| 工具结果 JSON 解析失败 | 返回原始字符串，明理自行处理 |

### 2.3 持仓数据层

| 错误场景 | 处理 |
|---------|------|
| 天天基金 API 不可用 | Hive 本地缓存数据 + UI 显示"数据来自昨日" |
| 新浪/Yahoo 股票 API 不可用 | 同上 |
| Hive 读取失败 | 返回空列表，UI 显示"持仓数据暂时不可用" |
| 服务器同步失败 | 本地数据照常使用，后台重试，不弹框 |

### 2.4 用户档案层

| 错误场景 | 处理 |
|---------|------|
| SharedPreferences 读取失败 | `UserProfile` 返回 null，进入通用模式 |
| 档案 JSON 解析失败（版本迁移） | 删除旧档案，重新触发引导 |

### 2.5 流式输出层

| 错误场景 | 处理 |
|---------|------|
| 网络断开（中途） | 显示已收到内容 + "消息已截断" badge + 重试按钮 |
| 网络断开（发送前） | 不发送，提示"请检查网络连接" |
| `anthropic_sdk_dart` 包异常 | 降级为 `http.post` 非流式请求 |

### 2.6 反馈上报层

| 错误场景 | 处理 |
|---------|------|
| 服务器不可达 | 静默失败，本地 log，**不影响对话** |
| 超时 | 5秒超时后放弃，不重试 |

---

## 3. 全局错误边界

```dart
// lib/app.dart — 全局未捕获异常处理

FlutterError.onError = (FlutterErrorDetails details) {
  // 生产环境：记录日志，不崩溃
  debugPrint('Flutter error: ${details.exception}');
  // 不调用 FlutterError.presentError（避免红屏）
};

PlatformDispatcher.instance.onError = (error, stack) {
  debugPrint('Platform error: $error');
  return true; // 表示已处理，不崩溃
};
```

---

## 4. 用户可见的错误 UI 规范

| 级别 | 场景 | UI 形式 | 示例文案 |
|------|------|---------|---------|
| Info | 数据来自缓存 | 气泡内小字 | "数据来自15分钟前" |
| Warning | 消息截断 | 气泡底部 badge | "消息已截断 · 重新发送" |
| Error | AI 完全不可用 | 气泡内 + 重试按钮 | "网络繁忙，请稍后重试" |
| Fatal | App 级别崩溃 | 系统处理（极少发生） | — |

**原则**：不用 AlertDialog（打断感太强），优先内嵌在气泡或 SnackBar。

---

## 5. 自定义异常类

```dart
// lib/core/errors/app_exceptions.dart

class AIUnavailableException implements Exception {
  const AIUnavailableException();
  @override
  String toString() => '所有 AI 服务暂时不可用';
}

class ToolExecutionException implements Exception {
  final String toolName;
  final String reason;
  const ToolExecutionException(this.toolName, this.reason);
}

class StreamInterruptedException implements Exception {
  final String partialContent;
  const StreamInterruptedException(this.partialContent);
}
```
