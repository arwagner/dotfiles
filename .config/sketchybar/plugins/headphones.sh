#!/usr/bin/env bash

# The stock Control Center sound icon in its headphones form. Like the menu
# bar item it replaces, it appears only while audio is actually routed to a
# headset — headphones merely being connected is not enough, and a Bluetooth
# speaker is still a speaker. Bluetooth sets also get their battery level as
# the label, which the stock item only reveals on click.
#
# system_profiler is the only source that reports headset battery: headsets
# are not HID devices, so they never appear in ioreg the way a Magic Mouse or
# keyboard does. Each query answers in about a tenth of a second, and the
# second one only runs for Bluetooth output, so this is fine at this rate.

set -euo pipefail

PATH="/opt/homebrew/bin:$PATH"
NAME="${NAME:-headphones}"

# U+F025 nf-fa-headphones, spelled as UTF-8 octal escapes rather than pasted
# in raw. Nerd Font glyphs live in the private use area, where they show as
# blank boxes in most editors and get quietly eaten by tooling that rewrites
# the file — which is how this icon went missing once already. Octal is the
# escape bash 3.2 understands, and /usr/bin/env bash is still 3.2 on macOS.
ICON=$'\357\200\245'

# Prints the label to show, and fails when the item should not be drawn at all.
if ! label="$(python3 -c '
import json, subprocess, sys


def profile(datatype):
    """The system_profiler report for one data type, or nothing on failure."""
    try:
        report = subprocess.run(["system_profiler", datatype, "-json"],
                                capture_output=True, text=True, timeout=10)
        return json.loads(report.stdout)
    except (OSError, ValueError, subprocess.SubprocessError):
        return {}


def default_output():
    """Whatever CoreAudio is currently playing through."""
    for entry in profile("SPAudioDataType").get("SPAudioDataType", []):
        for item in entry.get("_items", []):
            if item.get("coreaudio_default_audio_output_device") == "spaudio_yes":
                return item
    return None


def connected_headset(name):
    """The named Bluetooth device, but only if it is a headset."""
    for entry in profile("SPBluetoothDataType").get("SPBluetoothDataType", []):
        for device in entry.get("device_connected", []):
            for key, info in device.items():
                if key.strip() != name.strip():
                    continue
                if "head" in str(info.get("device_minorType", "")).lower():
                    return info
    return None


def percent(value):
    try:
        return int(str(value).rstrip("%"))
    except (TypeError, ValueError):
        return None


def battery(info):
    main = percent(info.get("device_batteryLevelMain"))
    if main is not None:
        return main
    # AirPods-style buds report each side separately and no main level.
    # The lower side is the one that runs out first.
    sides = [p for p in (percent(info.get("device_batteryLevelLeft")),
                         percent(info.get("device_batteryLevelRight")))
             if p is not None]
    return min(sides) if sides else None


output = default_output()
if output is None:
    sys.exit(1)

name = str(output.get("_name", ""))

if str(output.get("coreaudio_device_transport", "")).endswith("bluetooth"):
    info = connected_headset(name)
    if info is None:
        sys.exit(1)
    level = battery(info)
    print("" if level is None else str(level) + "%")
elif any(word in name.lower() for word in ("headphone", "headset", "airpod")):
    # Wired sets, which report no battery of their own.
    print("")
else:
    sys.exit(1)
')"; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

# A wired set has no battery to report, so it gets the bare icon rather than
# the icon plus the padding an empty label would still take up.
if [ -n "$label" ]; then
  sketchybar --set "$NAME" drawing=on icon="$ICON" label="$label" label.drawing=on
else
  sketchybar --set "$NAME" drawing=on icon="$ICON" label.drawing=off
fi
