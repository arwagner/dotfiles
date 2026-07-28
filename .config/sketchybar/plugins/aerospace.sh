#!/usr/bin/env bash

# Redraws every workspace indicator in a single pass.
#
# AeroSpace owns its workspaces, so there is no $SELECTED to read the way the
# mission-control "space" component provides. Instead .aerospace.toml triggers
# aerospace_workspace_change on every switch and passes the new workspace in
# $FOCUSED_WORKSPACE. For the other events we subscribe to — and for the initial
# `sketchybar --update` — nothing sets that variable, so ask AeroSpace directly.
#
# Only workspaces holding windows are drawn, plus the focused one (which may be
# empty). Otherwise all 35 of the workspaces bound in .aerospace.toml would sit
# in the bar permanently.

focused="${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused)}"
occupied="$(aerospace list-workspaces --monitor all --empty no)"

# Display names set by the rename-workspace command, tab separated. Absent
# until something has been renamed, and wiped whenever AeroSpace starts. Read it
# once up front: renaming replaces the file and AeroSpace's startup deletes it,
# so testing and then reading it per workspace races with both.
names="$(cat "$HOME/.cache/sketchybar/workspace-names" 2>/dev/null || true)"

args=()
for sid in $(aerospace list-workspaces --all); do
  name="$(printf '%s\n' "$names" | awk -F'\t' -v s="$sid" '$1 == s { print $2; exit }')"

  if [ -n "$name" ]; then
    label=(label="$name" label.drawing=on)
  else
    label=(label.drawing=off)
  fi

  if [ "$sid" = "$focused" ]; then
    args+=(--set space."$sid" drawing=on background.drawing=on "${label[@]}")
  elif printf '%s\n' "$occupied" | grep -qx -- "$sid"; then
    args+=(--set space."$sid" drawing=on background.drawing=off "${label[@]}")
  else
    args+=(--set space."$sid" drawing=off background.drawing=off "${label[@]}")
  fi
done

sketchybar "${args[@]}"
