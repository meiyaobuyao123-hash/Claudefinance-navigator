# 明理 Agent v2 — 可观测性方案

> 版本：v1.0 | 最后更新：2026-03-22

---

## 1. 目标

在没有专职运维的情况下，能够在**5分钟内**定位以下问题：
- 明理突然不回复了（API 故障）
- 用户反映建议质量变差（prompt 问题 or 模型降级）
- API 费用异常飙升（token 泄漏）
- 某个功能崩溃（Flutter 异常）

---

## 2. 观测层级

```
Level 1: 客户端 Debug 日志     ← 开发阶段用，生产不上报
Level 2: 服务端 API 日志        ← 腾讯云服务器已有 Nginx 日志
Level 3: AI 使用量监控          ← Anthropic 控制台
Level 4: 用户反馈数据           ← M08 评估反馈系统
```

---

## 3. 客户端日志（Level 1）

### 关键埋点

```dart
// lib/core/utils/app_logger.dart

class AppLogger {
  static void aiRequest({
    required String model,
    required int estimatedInputTokens,
    required ConversationStage stage,
  }) {
    if (!kDebugMode) return;
    debugPrint('[AI] model=$model input_tokens≈$estimatedInputTokens stage=${stage.name}');
  }

  static void aiResponse({
    required int inputTokens,
    required int outputTokens,
    required int cacheReadTokens,
    required int ttftMs,       // 首字符延迟
    required String stopReason,
  }) {
    if (!kDebugMode) return;
    debugPrint('[AI] input=$inputTokens output=$outputTokens '
        'cache_hit=$cacheReadTokens ttft=${ttftMs}ms stop=$stopReason');
  }

  static void toolExecution({
    required String toolName,
    required bool success,
    required int durationMs,
  }) {
    if (!kDebugMode) return;
    debugPrint('[TOOL] $toolName success=$success duration=${durationMs}ms');
  }

  static void guardrailTriggered({
    required String type,    // 'input' or 'output'
    required String pattern,
  }) {
    debugPrint('[GUARDRAIL] type=$type pattern=$pattern');
    // 生产环境也记录（安全审计）
  }

  static void error({
    required String module,
    required dynamic error,
    StackTrace? stackTrace,
  }) {
    debugPrint('[ERROR][$module] $error');
    if (stackTrace != null) debugPrint(stackTrace.toString());
  }
}
```

---

## 4. 服务端监控（Level 2）

### 腾讯云服务器现有日志

```bash
# Nginx 访问日志
/var/log/nginx/access.log

# FastAPI 服务日志
journalctl -u finance-nav-api -f

# PostgreSQL 慢查询日志（需配置）
/etc/postgresql/14/main/postgresql.conf
# log_min_duration_statement = 1000  # 1秒以上的查询记录
```

### 新增：AI 使用量上报接口

在腾讯云 `main.py` 新增接口，客户端在每次 AI 对话完成后上报：

```python
@app.post("/ai-usage")
async def record_ai_usage(payload: dict):
    """
    payload: {
      device_id, model, input_tokens, output_tokens,
      cache_read_tokens, ttft_ms, stop_reason,
      conversation_stage, timestamp
    }
    """
    conn = get_db()
    conn.execute("""
        INSERT INTO ai_usage_log
        (device_id, model, input_tokens, output_tokens, cache_read_tokens,
         ttft_ms, stop_reason, conversation_stage, timestamp)
        VALUES (%(device_id)s, %(model)s, %(input_tokens)s, %(output_tokens)s,
                %(cache_read_tokens)s, %(ttft_ms)s, %(stop_reason)s,
                %(conversation_stage)s, %(timestamp)s)
    """, payload)
    conn.commit()
    conn.close()
    return {"status": "ok"}
```

### 关键监控 SQL

```sql
-- 今日 API 消费（token 数）
SELECT
  DATE(timestamp) as date,
  SUM(input_tokens) as total_input,
  SUM(output_tokens) as total_output,
  SUM(cache_read_tokens) as total_cache_hit,
  COUNT(*) as call_count
FROM ai_usage_log
WHERE timestamp > NOW() - INTERVAL '7 days'
GROUP BY DATE(timestamp)
ORDER BY date DESC;

-- 平均首字符延迟（按模型）
SELECT model, AVG(ttft_ms) as avg_ttft, COUNT(*) as calls
FROM ai_usage_log
WHERE timestamp > NOW() - INTERVAL '1 day'
GROUP BY model;

-- 护栏触发次数（从 feedback 表关联）
SELECT reason, COUNT(*) FROM ai_feedback GROUP BY reason ORDER BY 2 DESC;
```

---

## 5. Anthropic 控制台监控（Level 3）

### 每周检查清单

- [ ] 检查 `https://console.anthropic.com/usage` 本周 token 消费趋势
- [ ] 设置消费告警（建议：日消费超过 $5 时发邮件告警）
- [ ] 检查是否有 `cache_read_input_tokens`（确认 Prompt Caching 生效）
- [ ] 检查 `stop_reason` 分布（`max_tokens` 比例高说明回复被截断）

---

## 6. 用户反馈监控（Level 4）

来自 M08 评估反馈系统，每周查询：

```sql
-- 本周差评率
SELECT
  COUNT(CASE WHEN rating = 'thumbs_down' THEN 1 END)::float /
  COUNT(*) as thumbs_down_rate,
  COUNT(*) as total_feedback
FROM ai_feedback
WHERE created_at > NOW() - INTERVAL '7 days';

-- 差评原因分布
SELECT reason, COUNT(*) as count
FROM ai_feedback
WHERE rating = 'thumbs_down'
  AND created_at > NOW() - INTERVAL '30 days'
GROUP BY reason
ORDER BY count DESC;

-- 差评最多的问题（定性分析）
SELECT user_question, reason, ai_response_preview
FROM ai_feedback
WHERE rating = 'thumbs_down'
ORDER BY created_at DESC
LIMIT 20;
```

---

## 7. 告警阈值（生产标准）

| 指标 | 告警阈值 | 处理方式 |
|------|---------|---------|
| 连续 3 次 AI 请求失败 | 立即 | 检查 API Key 是否有效 |
| 日 token 消费 > 预期 3 倍 | 24小时内 | 检查是否有异常调用 |
| TTFT 平均 > 2000ms | 1天内 | 检查网络 / 考虑切换模型 |
| 周差评率 > 20% | 1周内 | 分析差评原因，调整 prompt |
| 护栏触发 > 50次/天 | 1天内 | 检查是否有攻击行为 |

---

## 8. 生产问题排查手册

### Case 1：明理不回复

```
1. 检查手机网络
2. 检查 Anthropic 控制台是否有服务中断
3. ssh ubuntu@43.156.207.26，检查 finance-nav-api 服务状态
   → sudo systemctl status finance-nav-api
4. 检查 API Key 是否过期
   → curl -H "x-api-key: $KEY" https://api.anthropic.com/v1/messages
```

### Case 2：回复质量变差

```
1. 检查 Anthropic 是否有模型更新公告
2. 检查 prompt_builder.dart 最近是否有改动
   → git log -5 -- lib/features/ai_chat/data/prompt_builder.dart
3. 在 Debug 模式查看实际发送的 system prompt 内容
4. 对比近期 ai_feedback 差评原因分布
```

### Case 3：API 费用异常

```
1. 登录 Anthropic 控制台查看使用量曲线
2. 查询服务器 ai_usage_log 找异常时间段
3. 检查是否有 token 无限循环（tool_use 超过 3 轮）
4. 检查 Prompt Caching 是否还在生效
```
