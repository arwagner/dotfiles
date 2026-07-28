#!/usr/bin/env bash

# Redraws every workspace indicator in a single pass.
#
# AeroSpace owns its workspaces, so there is no $SELECTED to read the way the
# mission-control "space" component provides. Instead .aerospace.toml triggers
# aerospace_workspace_change on every switch and passes the new workspace in
# $FOCUSED_WORKSPACE. For the other events we subscribe to — and for the initial
# `sketchybar --update` — nothing sets that variable, so ask AeroSpace directly.
#
# Each indicator shows the workspace key (plus its rename-workspace name, and a
# Claude Code status glyph when a session there wants attention) as the icon,
# and the apps living there as the label. The two are split that way because a
# sketchybar label has a single font, and the app glyphs need
# sketchybar-app-font while the key needs a readable text font.
#
# Only workspaces holding windows are drawn, plus the focused one (which may be
# empty). Otherwise all 30 of the workspaces bound in .aerospace.toml would sit
# in the bar permanently.

source "$HOME/.config/sketchybar/plugins/icon_map.sh"

# Nerd Font glyphs, drawn in the icon's font: gear for a session that is busy,
# hourglass for one waiting on a reply, padlock for one blocked on permission.
# Written as UTF-8 byte escapes rather than literal characters: these live in
# the Private Use Area, where they are invisible in most editors and easily
# lost. bash 3.2, which is what /bin/bash is here, has no \u escape.
GLYPH_WORKING="$(printf '\357\200\223')"     # U+F013 nf-fa-gear
GLYPH_IDLE="$(printf '\357\211\222')"        # U+F252 nf-fa-hourglass_half
GLYPH_PERMISSION="$(printf '\357\200\243')"  # U+F023 nf-fa-lock

COLOR_DEFAULT=0xffffffff
COLOR_WORKING=0xff7aa2f7
COLOR_IDLE=0xffe6b450
COLOR_PERMISSION=0xffff5f5f

focused="${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused)}"
occupied="$(aerospace list-workspaces --monitor all --empty no)"

# One query for every window on every workspace, rather than one per workspace.
windows="$(aerospace list-windows --all --format '%{workspace}|%{app-name}|%{window-title}' 2>/dev/null || true)"

# Display names set by the rename-workspace command, tab separated. Absent
# until something has been renamed, and wiped whenever AeroSpace starts. Read it
# once up front: renaming replaces the file and AeroSpace's startup deletes it,
# so testing and then reading it per workspace races with both.
names="$(cat "$HOME/.cache/sketchybar/workspace-names" 2>/dev/null || true)"

# Claude Code sessions and what they are doing, located the same way
# claude/fleet-status.sh does it: each marker under /tmp/claude-waiting holds a
# cwd and a state (working, idle or permission — see claude/fleet-mark.sh), and
# the cwd's basename is matched against Terminal window titles, which Apple
# Terminal begins with the tab's directory. Distinct project directories map
# cleanly; two sessions in one directory are ambiguous.
#
# A title may itself contain "|", so only the workspace and app fields are
# split on it — the prefix match never reaches that far anyway.
terminals="$(printf '%s\n' "$windows" | awk -F'|' '$2 == "Terminal" { print $1 "\t" tolower($3) }')"

# Apple Music reports whether it is importing (converting) a track. Ask only if
# it is already running: `tell application "Music"` would launch it otherwise,
# and a status bar must never start applications on its own.
music_importing=""
if pgrep -xq Music; then
  music_importing="$(timeout 5 osascript -e 'tell application "Music" to return converting' 2>/dev/null || true)"
fi

claude=""
shopt -s nullglob
for marker in /tmp/claude-waiting/*; do
  [ -f "$marker" ] || continue
  project="$(basename "$(cut -f1 "$marker")" | tr '[:upper:]' '[:lower:]')"
  state="$(cut -f2 "$marker")"
  [ -n "$project" ] || continue
  while IFS=$'\t' read -r window_workspace title; do
    [ -n "$window_workspace" ] || continue
    case "$title" in
      "$project"*) claude="$claude$window_workspace	${state:-idle}"$'\n' ;;
    esac
  done <<< "$terminals"
done
shopt -u nullglob

args=()
for sid in $(aerospace list-workspaces --all); do
  name="$(printf '%s\n' "$names" | awk -F'\t' -v s="$sid" '$1 == s { print $2; exit }')"

  if [ -n "$name" ]; then
    icon="$sid $name"
  else
    icon="$sid"
  fi

  # Collect one glyph per distinct app, in the order AeroSpace lists them. Two
  # Chrome windows are still one Chrome icon; a workspace is about what is in
  # it, not how many copies.
  glyphs=""
  while IFS='|' read -r window_workspace app title; do
    [ "$window_workspace" = "$sid" ] || continue
    __icon_map "$app"
    case " $glyphs " in
      *" $icon_result "*) continue ;;
    esac
    glyphs="$glyphs$icon_result "
  done <<< "$windows"
  glyphs="${glyphs% }"

  # Ranked by how much they want you: blocked on permission beats waiting for a
  # reply, which beats merely busy. A workspace running several sessions shows
  # the most demanding one.
  status="$(printf '%s\n' "$claude" | awk -F'\t' -v s="$sid" '
    $1 == s {
      if ($2 == "permission") { print "permission"; exit }
      if ($2 == "idle") { found = "idle" }
      else if (found != "idle") { found = "working" }
    }
    END { if (found) print found }')"

  case "$status" in
    permission) icon="$icon $GLYPH_PERMISSION"; status_color="$COLOR_PERMISSION" ;;
    idle)       icon="$icon $GLYPH_IDLE";       status_color="$COLOR_IDLE" ;;
    working)    icon="$icon $GLYPH_WORKING";    status_color="$COLOR_WORKING" ;;
    *)          status_color="$COLOR_DEFAULT" ;;
  esac

  # An importing Music library reads as busy too — same blue, no glyph, since
  # the Music app icon is already sitting in the label saying which app it is.
  # A Claude session in the same workspace outranks it: that one may want you.
  if [ -z "$status" ] && [ "$music_importing" = "true" ]; then
    case "$glyphs" in
      *":music:"*) status_color="$COLOR_WORKING" ;;
    esac
  fi

  if [ -n "$glyphs" ]; then
    label=(label="$glyphs" label.drawing=on)
  else
    label=(label.drawing=off)
  fi

  # Colour the app glyphs too, so the whole indicator reads as one status.
  common=(icon="$icon" icon.color="$status_color" label.color="$status_color" "${label[@]}")

  if [ "$sid" = "$focused" ]; then
    args+=(--set space."$sid" drawing=on background.drawing=on "${common[@]}")
  elif printf '%s\n' "$occupied" | grep -qx -- "$sid"; then
    args+=(--set space."$sid" drawing=on background.drawing=off "${common[@]}")
  else
    args+=(--set space."$sid" drawing=off background.drawing=off "${common[@]}")
  fi
done

sketchybar "${args[@]}"
