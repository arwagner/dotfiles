---
name: babysit
description: Monitor Codex subagents in the current shared thread and nudge them when they are genuinely blocked or stalled.
---

Monitor only the current thread's child agents using the collaboration tools. With no arguments, list their current status and stop. If the user names agents, watch those agents only; never watch yourself.

Do not poll or schedule wakeups. Use the agent wait mechanism. When an agent stops, inspect its latest result, then either send a short, concrete nudge based on its work or escalate only when the next action is destructive or requires the user's unique decision. Re-arm the watch after each response. Report nothing unless the user is needed or a watched agent exits.

Codex cannot observe arbitrary external CLI sessions, so state that boundary briefly if the user asks to monitor sessions outside this thread.
