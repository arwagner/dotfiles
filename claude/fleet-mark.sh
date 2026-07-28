#!/bin/bash
# Claude Code hook: record what THIS session is doing, without notifying.
#
#   UserPromptSubmit -> fleet-mark.sh working   (you replied; Claude is busy)
#   Stop             -> fleet-mark.sh idle      (Claude finished; waiting on you)
#
# Writes /tmp/claude-waiting/<session_id> as "<cwd>\t<state>", the same format
# fleet-waiting.sh uses, so fleet-status.sh and the sketchybar workspace
# indicators read one set of markers.
#
# Silent by design: Stop fires on every single turn, so posting a notification
# here would bury the ones that matter. fleet-waiting.sh remains the noisy path,
# for permission prompts and genuine idleness.
state="${1:-working}"
input=$(cat)

cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
[ -z "$sid" ] && exit 0

dir="/tmp/claude-waiting"
mkdir -p "$dir"
printf '%s\t%s\n' "${cwd:-unknown}" "$state" > "$dir/$sid"

# Repaint the workspace indicators. Best effort: a hook must never fail because
# the bar happens not to be running.
/opt/homebrew/bin/sketchybar --trigger aerospace_workspace_change >/dev/null 2>&1
exit 0
