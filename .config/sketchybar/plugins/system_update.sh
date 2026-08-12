#!/usr/bin/env bash

# What Software Update last installed, and whether macOS itself is running the
# version it last recorded.
#
# The source is /Library/Receipts/InstallHistory.plist, which every installer on
# the machine appends to. It is world readable, so this needs no privileges.
# `softwareupdate --history` prints the same records as a table, but it reports
# marketing names ("macOS Sequoia 15.7.8") rather than version strings, which
# leaves nothing to compare against the running system.
#
# Only the three things that actually appear in the Software Update pane are
# counted — macOS, Safari and the Command Line Tools. The same file also holds:
#
#   * XProtect and friends (contentType config-data), which land silently every
#     week or two. Counting those would peg the label a day or two old forever
#     and answer a question nobody asked.
#   * "Mobile Device", a support package that arrives through softwareupdated
#     but is never offered, never announced and never restarts anything.
#   * Everything from `installer` and `appstoreagent` — third-party packages and
#     App Store apps, which are not system software at all.
#
# The colour is the other half. A macOS update is written to the history when it
# is staged, and only takes effect on the restart after that. So when the last
# recorded macOS version is not the version booted, the install did not land:
# either the restart has not happened yet or it happened and rolled back. That
# is the failure this item exists to catch, and it is why versions are compared
# rather than a date simply being shown.

set -euo pipefail

PATH="/opt/homebrew/bin:$PATH"
NAME="${NAME:-system_update}"

# U+F021 nf-fa-refresh, written as UTF-8 octal escapes rather than pasted in
# raw, for the reason spelled out in headphones.sh: Private Use Area glyphs are
# invisible in most editors and get silently dropped by tooling. Octal is what
# bash 3.2 understands, and /usr/bin/env bash is still 3.2 on macOS.
ICON=$'\357\200\241'

# The white and amber the workspace indicators use in aerospace.sh, where the
# amber is documented at 9.0:1 against the bar.
COLOR_OK=0xffffffff
COLOR_STALLED=0xffe6b450

# Three tab-separated fields — what was installed, when, and the newest macOS
# version on record — or nothing at all.
last="$(python3 -c '
import plistlib
import sys

OFFERED = ("macOS", "Safari", "Command Line Tools")

try:
    with open("/Library/Receipts/InstallHistory.plist", "rb") as handle:
        history = plistlib.load(handle)
except (OSError, ValueError):
    sys.exit(1)


def offered(entry):
    return (entry.get("processName") == "softwareupdated"
            and entry.get("contentType") != "config-data"
            and entry.get("date") is not None
            and str(entry.get("displayName", "")).startswith(OFFERED))


def version(entry):
    stated = str(entry.get("displayVersion") or "").strip()
    # Pre-Sequoia records sometimes carry the version only in the name.
    return stated or str(entry.get("displayName", "")).split()[-1]


updates = [entry for entry in history if offered(entry)]
if not updates:
    sys.exit(1)

newest = max(updates, key=lambda entry: entry["date"])
name = str(newest.get("displayName", "")).strip()
# "macOS 15.7.8" already names its version; "Safari" does not.
title = name if name.endswith(version(newest)) else name + " " + version(newest)

mac = [e for e in updates if str(e.get("displayName", "")).startswith("macOS")]
latest_mac = version(max(mac, key=lambda entry: entry["date"])) if mac else ""

print("\t".join([title, str(int(newest["date"].timestamp())), latest_mac]))
' 2>/dev/null || true)"

# Nothing to report is not the same as a broken bar: hide rather than lie.
if [ -z "$last" ]; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

IFS=$'\t' read -r title when latest_mac <<< "$last"

# The plist stores an absolute instant and `date +%s` is absolute too, so this
# needs no timezone work.
elapsed=$(( $(date +%s) - when ))
if [ "$elapsed" -lt 3600 ]; then
  age="just now"
elif [ "$elapsed" -lt 172800 ]; then
  age="$(( elapsed / 3600 ))h ago"
else
  age="$(( elapsed / 86400 ))d ago"
fi

running="$(sw_vers -productVersion)"

if [ -n "$latest_mac" ] && [ "$latest_mac" != "$running" ]; then
  # Staged but not booted. Name both versions: which way round they sit is the
  # whole diagnosis, and it outranks whatever installed most recently.
  color="$COLOR_STALLED"
  label="$running  $latest_mac staged"
else
  color="$COLOR_OK"
  label="$title  $age"
fi

# A Safari seed can push the label out to something like "Safari 27.0 Seed 3",
# so cap it the way next_event.sh caps a meeting title.
if [ "${#label}" -gt 26 ]; then
  label="${label:0:25}…"
fi

sketchybar --set "$NAME" drawing=on icon="$ICON" icon.color="$color" \
                         label="$label" label.color="$color"
