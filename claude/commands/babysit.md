---
description: Watch other Claude Code sessions and prod them along when they stall
argument-hint: "<which sessions — e.g. the ones under $CODE/foobar>"
allowed-tools: Bash(cat:*), Bash(ls:*), Bash(grep:*), Bash(tail:*), Bash(claude-session-tail:*), Bash(claude-session-wait:*), ListAgents, SendMessage, PushNotification
---

Live sessions on this machine:

!`for f in ~/.claude/sessions/*.json; do cat "$f"; echo; done`

Add the sessions described by "$ARGUMENTS" to the list you are babysitting, then
watch them. With no arguments, report the current list and stop.

## Adding

Match against the registry above — `cwd` for "the sessions under <dir>", `name`
for a session named outright. Never add yourself. Resolve once: this is a
snapshot, not a standing rule, so a session started later is not picked up.

Arm one subscription per session: `SendMessage` with `notify_when_idle: true`
and **no message body**, which costs that session nothing. Then say in one line
which sessions you are now watching, and stop.

Sessions leave the list only when the user says so, or when one exits.

## Watching

Do not poll, do not loop, do not schedule wakeups. Each subscription wakes you
within a second of that session ending a turn. Go idle and wait.

On each wake:

1. The notice names the session and summarises its last turn. That summary says
   a turn ended — not that the work finished. A session that backgrounds a task
   goes idle immediately.
2. Read the tail of its transcript: `claude-session-tail <sessionId>`, where
   `<sessionId>` comes from its registry entry. Work out what it is doing, what
   it stopped on, and whether it is actually blocked.
3. Prod it or escalate (below).
4. **Re-arm its subscription.** Subscriptions are one-shot, and an un-armed
   session is an unwatched session. After a prod, re-arm at once. After an
   escalation the session sits idle, and arming an idle session fires
   immediately — so run `claude-session-wait <sessionId>` in the background
   first; it exits when the session gets its next message, and you re-arm then.
5. End the turn with one line (below) and go idle.

## Prodding

`SendMessage` with the answer. Make real judgment calls on the user's behalf —
pick between options, approve a sound plan, say keep going — reasoning from that
session's own transcript. Keep the prod short and specific.

A prod only lands when that session runs in the same permission class as you
(a bypass babysitter for a bypass fleet). If a delivery notice says your message
was held or expired unapproved, that session cannot be prodded: escalate it and
say so plainly, because nothing else will report that failure.

## Escalating

Escalate three things:

- **Risk** — the action is destructive or irreversible.
- **Knowledge** — only the user can answer: a preference, a credential, a call
  about intent.
- **Peer-proof actions** — commits, pushes, and edits to steering files
  (`CLAUDE.md`, `AGENTS.md`, skills). Sessions refuse these when a peer asks,
  so a prod for them is wasted. Escalate a session that refuses any prod the
  same way.

Send a `PushNotification` and one line here: which session, what it needs.
Do not prod it. Re-arm it anyway, through `claude-session-wait` (step 4) — the
user may answer in its terminal directly, or here for you to relay, and either
way you catch its next stop.

## Silence

End every turn with exactly one line: the session and what you did — `myron-24:
prodded (approved plan)`, `myron-24: escalated (needs push approval)`,
`myron-24: exited`. That line is the whole report: progress notes, summaries
and "still watching" stay unsaid.
