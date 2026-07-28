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

args=()
for sid in $(aerospace list-workspaces --all); do
  if [ "$sid" = "$focused" ]; then
    args+=(--set space."$sid" drawing=on background.drawing=on)
  elif printf '%s\n' "$occupied" | grep -qx -- "$sid"; then
    args+=(--set space."$sid" drawing=on background.drawing=off)
  else
    args+=(--set space."$sid" drawing=off background.drawing=off)
  fi
done

sketchybar "${args[@]}"
