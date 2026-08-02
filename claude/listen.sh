#!/bin/bash
# Claude Code Stop hook: render each turn as prose written to be heard.
#
#   Stop -> listen.sh            (fast: stash payload, background a render, exit)
#           listen.sh --render   (slow: rewrite the turn, append to the session file)
#
# Files land in ~/.claude/listen/<date>-<project>-<sid8>.txt as plain prose with
# no markup, because anything that reads them aloud will happily pronounce "##"
# and backticks. Nothing plays on its own. When you want to listen, open the
# file and hand it to Speechify. Multiple sessions each write their own file, so
# they never collide.
#
# Files are pruned after KEEP_DAYS. These are a byproduct of working, not a
# record of it -- nothing here is meant to be durable.
#
# The render is backgrounded because a Stop hook runs on a timeout, and anything
# slow in the hook itself stalls the turn. The hook proper is the last five lines
# of this file.

set -uo pipefail

DIR="$HOME/.claude/listen"
KEEP_DAYS=7
MODEL="haiku"
MIN_CHARS=400          # turns shorter than this, with no tool calls, aren't worth hearing
WAIT_TRIES=20          # transcript lag: 20 x 0.5s = 10s before rendering anyway
CALL_TIMEOUT=180

# Assigned via read, not $(cat <<...): /bin/bash on macOS is 3.2, which cannot
# parse a heredoc inside command substitution. read -d '' returns non-zero at
# EOF, which is fine and deliberate here.
read -r -d '' SYSTEM_PROMPT <<'PROMPT'
You are rewriting one turn of a coding assistant's output so it can be listened to rather than read.

The input is a turn log. Lines beginning "SAID:" are prose the assistant wrote. Lines beginning "DID:" are tool calls it made, given as a tool name and a truncated blob of arguments.

Rewrite the whole turn as flowing spoken prose:

- Never drop anything silently. Where the assistant wrote code, say what that code does and why, in a sentence, and say that you are doing so: "here I dropped in a chunk that adds the retry wrapper around the fetch call". Never read code aloud and never spell out syntax, brackets or punctuation.
- Fold the DID lines into the story rather than listing them: "I read the fleet scripts first, then checked which voices were installed". If a tool call was routine, one clause is enough. What matters is that the listener is never surprised by knowledge that appeared from nowhere.
- Shorten file paths to the last component. Say "the hooks doc", not a full slash-separated path.
- No markup of any kind: no headings, bullets, numbered lists, backticks, or asterisks. Sentences and paragraphs only. Never wrap a flag or filename in backticks; write it as bare words.
- Write in the first person, as the assistant itself. Say "I checked the transcript schema". Never "the assistant checked" and never "they". This is the assistant speaking to the person it was working with.
- Keep its actual conclusions, including any uncertainty or caveats it expressed. Do not add encouragement, and do not open with throat-clearing like "In this turn".
- Be compact. Aim for about a third the length of the input. A trivial turn deserves one sentence.

Output only the spoken prose.
PROMPT

# ---------------------------------------------------------------- render mode

if [ "${1:-}" = "--render" ]; then
  payload_file="${2:-}"
  [ -f "$payload_file" ] || exit 0
  input=$(cat "$payload_file")
  rm -f "$payload_file"

  sid=$(printf '%s' "$input"  | jq -r '.session_id // empty' 2>/dev/null)
  tp=$(printf '%s' "$input"   | jq -r '.transcript_path // empty' 2>/dev/null)
  cwd=$(printf '%s' "$input"  | jq -r '.cwd // empty' 2>/dev/null)
  last=$(printf '%s' "$input" | jq -r '.last_assistant_message // empty' 2>/dev/null)
  [ -n "$sid" ] && [ -f "$tp" ] || exit 0

  # Everything the assistant said and did since the last real user prompt.
  # Real prompts carry .promptSource; tool results arrive as user rows too and
  # carry .toolUseResult instead. Sidechain rows are subagents -- those get their
  # own SubagentStop and don't belong in this turn.
  extract() {
    jq -s -r '
      . as $all
      | ([range(0; length)
          | select($all[.].type == "user"
                   and ($all[.] | has("promptSource"))
                   and ($all[.].isSidechain != true))] | last) as $s
      | $all[(($s // -1) + 1):]
      | map(select(.isSidechain != true and .type == "assistant"))
      | map(.message.content[]? |
          if   .type == "text"     then "SAID: " + .text
          elif .type == "tool_use" then "DID: " + .name + " -- " + ((.input | tostring)[:200])
          else empty end)
      | join("\n\n")' "$tp" 2>/dev/null
  }

  # The payload warns that the transcript file may lag behind the turn it is
  # telling us about, so wait until the turn's final text actually shows up.
  digest=""
  tail_frag="${last: -80}"
  for _ in $(seq "$WAIT_TRIES"); do
    digest=$(extract)
    if [ -z "$tail_frag" ] || [[ "$digest" == *"$tail_frag"* ]]; then break; fi
    sleep 0.5
  done
  [ -n "$digest" ] || exit 0

  # Stop fires on every turn, including "done, tests pass". Those aren't worth a
  # model call or a paragraph in your ears.
  if ! printf '%s' "$digest" | grep -q '^DID: ' && [ "${#digest}" -lt "$MIN_CHARS" ]; then
    exit 0
  fi

  # --setting-sources '' makes the inner call load no settings, so it cannot fire
  # hooks: no recursion into this script, and no stray fleet markers. (--bare
  # would also skip hooks but never reads the keychain, so it cannot log in.)
  spoken=$(printf '%s' "$digest" | timeout "$CALL_TIMEOUT" \
    claude -p --model "$MODEL" --setting-sources '' --system-prompt "$SYSTEM_PROMPT")
  [ -n "$spoken" ] || exit 0

  # Belt and braces: the model mostly honours "no markup", but a stray backtick
  # gets pronounced, so strip the characters that have no spoken form.
  # \140 is a backtick -- written as octal because a literal one inside $( )
  # breaks bash's parser no matter how it is quoted.
  spoken=$(printf '%s' "$spoken" | tr -d '\140*' | tr '_' ' ' | sed -e 's/^#\{1,\} *//' -e 's/^- //')

  mkdir -p "$DIR"
  project=$(basename "${cwd:-unknown}")
  file="$DIR/$(date +%Y-%m-%d)-${project}-${sid:0:8}.txt"

  # Serialise appends per session. Renders are queued in the order they finish
  # polling, which for human-paced turns is the order they happened; a very slow
  # render followed immediately by a fast one could in principle land inverted.
  lock="$file.lock"
  held=""
  for _ in $(seq 120); do
    if mkdir "$lock" 2>/dev/null; then held=1; break; fi
    sleep 0.5
  done
  # Only release a lock we actually took; after a 60s wait we append anyway
  # rather than lose the turn, but we must not free someone else's lock.
  trap '[ -n "$held" ] && rmdir "$lock" 2>/dev/null' EXIT

  if [ ! -f "$file" ]; then
    printf 'Claude session in %s, starting %s.\n\n' "$project" "$(date '+%-I:%M %p')" > "$file"
  fi
  printf 'Turn at %s.\n\n%s\n\n' "$(date '+%-I:%M %p')" "$spoken" >> "$file"

  # These are scratch. Reap anything that has aged out.
  find "$DIR" -maxdepth 1 -type f -name '*.txt' -mtime "+$KEEP_DAYS" -delete 2>/dev/null
  find "$DIR" -maxdepth 1 -type d -name '*.lock' -mmin +30 -exec rmdir {} \; 2>/dev/null

  exit 0
fi

# ------------------------------------------------------------------ hook mode
# Must be fast and must never block: no output on stdout, always exit 0.

input=$(cat)
payload=$(mktemp "${TMPDIR:-/tmp}/claude-listen.XXXXXX") || exit 0
printf '%s' "$input" > "$payload"
nohup "$0" --render "$payload" >/dev/null 2>&1 &
exit 0
