#!/bin/bash
# Claude Code UserPromptSubmit / SessionEnd hook: this session is no longer
# waiting on the user (they just replied, or the session ended). Remove its
# waiting-marker so it drops out of the fleet overview.
input=$(cat)
sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
[ -n "$sid" ] && rm -f "/tmp/claude-waiting/$sid"

# Drop this session's glyph from the workspace indicators. Best effort: the
# hook must never fail because the bar happens not to be running.
/opt/homebrew/bin/sketchybar --trigger aerospace_workspace_change >/dev/null 2>&1
exit 0
