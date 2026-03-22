---
name: finance_navigator_project
description: Flutter理财导航App项目上下文——技术栈、路径、当前状态
type: project
---

主项目路径：`/Users/wenruiwei/Desktop/testclaude/finance_navigator`

**Why:** 用户正在开发一个面向50万-1000万人民币用户群的Flutter理财导航App，核心价值是AI诊断需求→匹配产品类型→跳转平台购买，不接触资金。

**How to apply:** 每次涉及该项目的代码修改，直接去该目录读取代码，不要问用户路径。CLAUDE.md在项目根目录，有完整的功能清单和技术决策记录。

技术栈：Flutter 3.41.2 + Riverpod + Hive + Supabase + Claude API + DeepSeek备用

已完成核心功能（截至2026-03-22）：
- 持仓监控（基金+A股+港股+美股+自选股）
- 资产配置评估 + R1-R5风险测评
- 产品导航库（15+产品，实时行情已接入）
- AI明理对话（claude-sonnet-4-6）
- 决策日记 + 3/6/12月自动复盘系统（最新功能）
- Supabase云同步，Hive本地持久化

⚠️ Supabase decision_records表需手动建表（SQL在CLAUDE.md中）
