#!/bin/sh

# The name of the app that currently has focus.
#
# sketchybar puts the app name in $INFO when it sends front_app_switched, so the
# common case costs nothing. $INFO is empty on the forced first run at the end of
# sketchybarrc, and AeroSpace already knows what is focused, so ask it then.

name="$INFO"

if [ -z "$name" ]; then
  name="$(aerospace list-windows --focused --format '%{app-name}' 2>/dev/null | head -1)"
fi

sketchybar --set "$NAME" label="$name" drawing=on

# An empty workspace has no focused window and so no name to show. Drawing the
# item anyway would leave a bare gap between the workspace pills and the bar.
[ -n "$name" ] || sketchybar --set "$NAME" drawing=off
