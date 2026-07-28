#!/usr/bin/env bash

# Battery level of the connected Bluetooth headset, in place of the stock
# volume readout. The item hides itself when nothing is connected.
#
# system_profiler is the only source that reports this: headsets are not HID
# devices, so they never appear in ioreg the way a Magic Mouse or keyboard
# does. It answers in well under a second, which is fine at this update rate.

set -euo pipefail

PATH="/opt/homebrew/bin:$PATH"
NAME="${NAME:-headphones}"

level="$(system_profiler SPBluetoothDataType -json 2>/dev/null | python3 -c '
import json, sys

try:
    data = json.load(sys.stdin)
except ValueError:
    sys.exit(0)

def percent(value):
    try:
        return int(str(value).rstrip("%"))
    except (TypeError, ValueError):
        return None

for entry in data.get("SPBluetoothDataType", []):
    for device in entry.get("device_connected", []):
        for info in device.values():
            if "head" not in str(info.get("device_minorType", "")).lower():
                continue
            main = percent(info.get("device_batteryLevelMain"))
            if main is not None:
                print(main)
                sys.exit(0)
            # AirPods-style buds report each side separately and no main level.
            # The lower side is the one that runs out first.
            sides = [p for p in (percent(info.get("device_batteryLevelLeft")),
                                 percent(info.get("device_batteryLevelRight")))
                     if p is not None]
            if sides:
                print(min(sides))
                sys.exit(0)
')"

if [ -z "$level" ]; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

sketchybar --set "$NAME" drawing=on icon="" label="$level%"
