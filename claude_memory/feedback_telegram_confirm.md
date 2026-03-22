---
name: telegram_confirm_before_action
description: When receiving instructions via Telegram, always confirm the planned action on Telegram before executing
type: feedback
---

Always confirm on Telegram before executing any instruction received through Telegram.

**Why:** User explicitly requested this workflow — they want to review and approve what Claude is about to do before it happens, to avoid unintended actions.

**How to apply:** When a Telegram message contains an instruction or task, reply on Telegram describing what you plan to do, wait for the user's confirmation ("确认" or equivalent), then proceed. Do not execute immediately.
