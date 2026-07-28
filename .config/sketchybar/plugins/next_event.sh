#!/usr/bin/env bash

# Date and time of the next calendar event, with its title.
#
# The work is done by next_event.py, which reads Google's private ICS URLs over
# the network. That avoids macOS privacy permissions altogether — sketchybar
# cannot obtain Calendar access under launchd, and AeroSpace cannot obtain it at
# all — and it reaches a work Google account that Calendar.app never syncs.
#
# uv fetches the two ICS libraries on demand and caches them, so a fresh machine
# needs no setup step beyond uv itself. The item hides when nothing is upcoming
# or when no calendar URLs have been configured.

set -euo pipefail

PATH="/opt/homebrew/bin:$PATH"
NAME="${NAME:-next_event}"
PLUGIN_DIR="$HOME/.config/sketchybar/plugins"

# Never let a hung network call or a dependency resolution stall the bar.
raw="$(timeout 30 uv run --quiet \
         --with icalendar --with recurring-ical-events \
         python3 "$PLUGIN_DIR/next_event.py" 2>/dev/null | head -1 || true)"

if [ -z "$raw" ]; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

when="${raw%%|*}"
title="${raw#*|}"

# Keep a long meeting title from stretching the bar across the screen.
if [ "${#title}" -gt 24 ]; then
  title="${title:0:23}…"
fi

sketchybar --set "$NAME" drawing=on icon="" label="$when  $title"
