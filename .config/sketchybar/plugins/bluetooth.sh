#!/usr/bin/env bash

# The stock Control Center Bluetooth icon: the rune while the controller is
# powered on, struck through and dimmed while it is off. Like the menu bar
# item it replaces, it stays on the bar either way rather than hiding itself.
# Clicking it opens the Bluetooth settings pane.
#
# system_profiler is the only unprivileged source for the power state on
# current macOS — the ControllerPowerState key that used to sit in
# /Library/Preferences/com.apple.Bluetooth is gone. blueutil would answer six
# times faster, but it has to reach the Bluetooth API, which aborts outright
# unless the calling app holds Bluetooth access in System Settings; an icon
# that reads "off" whenever a permission is missing is worse than one that
# takes a tenth of a second.

set -euo pipefail

PATH="/opt/homebrew/bin:$PATH"
NAME="${NAME:-bluetooth}"

# U+F00AF nf-md-bluetooth and U+F00B2 nf-md-bluetooth-off, spelled as UTF-8
# octal escapes rather than pasted in raw. Nerd Font glyphs live in the
# private use area, where they show as blank boxes in most editors and get
# quietly eaten by tooling that rewrites the file. Octal is the escape bash
# 3.2 understands, and /usr/bin/env bash is still 3.2 on macOS.
ICON_ON=$'\363\260\202\257'
ICON_OFF=$'\363\260\202\262'

state="$(system_profiler SPBluetoothDataType -json 2>/dev/null | python3 -c '
import json, sys

try:
    data = json.load(sys.stdin)
except ValueError:
    print("off")
    sys.exit(0)

for entry in data.get("SPBluetoothDataType", []):
    if entry.get("controller_properties", {}).get("controller_state") == "attrib_on":
        print("on")
        sys.exit(0)

print("off")
')"

if [ "$state" = "on" ]; then
  sketchybar --set "$NAME" icon="$ICON_ON" icon.color=0xffffffff
else
  sketchybar --set "$NAME" icon="$ICON_OFF" icon.color=0x80ffffff
fi
