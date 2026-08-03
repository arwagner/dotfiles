#!/bin/bash
# Fleet overview of Claude Code sessions currently waiting on the user, mapped to
# their AeroSpace window/workspace via the terminal window title.
#
#   fleet-status.sh list   -> notification summary of who's waiting + where
#   fleet-status.sh jump   -> focus the next waiting session's window (round-robin)
#
# Correlation heuristic: a waiting session's cwd basename (e.g. "skylight") is
# matched against Terminal windows whose title starts with that name (Apple
# Terminal shows the tab's dir first, e.g. "skylight — claude ..."). Distinct
# project dirs map cleanly; two sessions in the same dir are ambiguous.
set -o pipefail

# AeroSpace and Hammerspoon both start us with a bare PATH that has no Homebrew
# in it, and both `aerospace` and `jq` live there. Their failures below are sent
# to /dev/null, so without this the script reports "no matching Terminal
# windows" instead of reporting an error, which is the worst way to be wrong.
PATH="/opt/homebrew/bin:$PATH"

dir="/tmp/claude-waiting"
mode="${1:-list}"

# Post a notification: prefer terminal-notifier, fall back to osascript.
notify() { # $1 = title, $2 = message
  if command -v terminal-notifier >/dev/null 2>&1; then
    terminal-notifier -title "$1" -message "$2" -group "claude-fleet" >/dev/null 2>&1
  else
    osascript -e "display notification \"${2//\"/}\" with title \"${1//\"/}\"" >/dev/null 2>&1
  fi
}

shopt -s nullglob
# Markers also record sessions that are merely busy (see fleet-mark.sh). This
# overview is about who needs you, so keep only the ones that do — and count
# those, or a fleet of busy sessions would report as "no matching windows"
# rather than as clear.
markers=()
for m in "$dir"/*; do
  [ -f "$m" ] || continue
  [ "$(cut -f2 "$m")" = "working" ] && continue
  markers+=("$m")
done
if [ ${#markers[@]} -eq 0 ]; then
  [ "$mode" = "list" ] && notify "🟢 Fleet clear" "No sessions waiting"
  exit 0
fi

wins=$(aerospace list-windows --all --format '%{workspace}%{window-id}%{app-name}%{window-title}' --json 2>/dev/null)

# Build tab-separated rows: workspace<TAB>window-id<TAB>projectname
matches=""
for m in "${markers[@]}"; do
  cwd=$(cut -f1 "$m")
  name=$(basename "$cwd")
  [ -z "$name" ] && continue
  row=$(printf '%s' "$wins" | jq -r --arg n "$name" '
    .[]
    | select(.["app-name"] == "Terminal")
    | select((.["window-title"] | ascii_downcase) | startswith($n | ascii_downcase))
    | "\(.workspace)\t\(.["window-id"])\t\($n)"' 2>/dev/null | head -1)
  [ -n "$row" ] && matches+="$row"$'\n'
done

matches=$(printf '%s' "$matches" | grep -v '^[[:space:]]*$' | sort -u)
if [ -z "$matches" ]; then
  [ "$mode" = "list" ] && notify "⚠️ Fleet" "Waiting sessions found, but no matching Terminal windows"
  exit 0
fi

if [ "$mode" = "jump" ]; then
  ids=()
  while IFS=$'\t' read -r ws id nm; do ids+=("$id"); done <<< "$matches"
  focused=$(aerospace list-windows --focused --format '%{window-id}' 2>/dev/null | tr -dc '0-9')
  target="${ids[0]}"
  found=""
  for id in "${ids[@]}"; do
    if [ -n "$found" ]; then target="$id"; break; fi
    [ "$id" = "$focused" ] && found=1
  done
  # if focused was the last (or only) waiting window, wrap to the first
  [ -n "$found" ] && [ "$target" = "$focused" ] && target="${ids[0]}"
  aerospace focus --window-id "$target"
  exit 0
fi

# mode = list
count=$(printf '%s\n' "$matches" | grep -c .)
summary=$(printf '%s\n' "$matches" | awk -F'\t' '{printf "%s (WS %s)  ", $3, $1}')
notify "⏳ $count Claude waiting" "$summary"
exit 0
