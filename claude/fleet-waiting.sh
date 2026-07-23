#!/bin/bash
# Claude Code Notification hook: mark THIS session as "waiting on the user" and
# pop a macOS notification. Invoked with one arg: "idle" or "permission".
#
#   idle_prompt       -> $1 = idle        (Claude finished, waiting for next msg)
#   permission_prompt -> $1 = permission  (Claude is blocked needing approval)
#
# Writes a marker file under /tmp/claude-waiting/<session_id> containing the cwd,
# which the overview script (fleet-status.sh) reads to map sessions -> windows.
reason="${1:-idle}"
input=$(cat)

cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
[ -z "$sid" ] && exit 0

dir="/tmp/claude-waiting"
mkdir -p "$dir"
printf '%s\t%s\n' "${cwd:-unknown}" "$reason" > "$dir/$sid"

name=$(basename "${cwd:-unknown}")
if [ "$reason" = "permission" ]; then
  title="🔐 Claude needs permission"
else
  title="💬 Claude is waiting"
fi

# Notify (best-effort; never fail the hook). Prefer terminal-notifier (reliable
# banners under its own app identity); fall back to osascript if it's absent.
if command -v terminal-notifier >/dev/null 2>&1; then
  terminal-notifier -title "$title" -message "$name" -group "claude-$name" >/dev/null 2>&1
else
  osascript -e "display notification \"${name//\"/}\" with title \"$title\"" >/dev/null 2>&1
fi
exit 0
