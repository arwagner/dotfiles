#!/bin/bash

# Raycast script command. Add this directory under Raycast Settings ->
# Extensions -> Script Commands, then give the command a hotkey or alias.

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Rename Workspace
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🏷️
# @raycast.packageName AeroSpace
# @raycast.argument1 { "type": "text", "placeholder": "name", "optional": true }

# Documentation:
# @raycast.description Label the focused AeroSpace workspace in sketchybar. Leave the name empty to clear it.
# @raycast.author Andrew Wagner

set -euo pipefail

PATH="/opt/homebrew/bin:$PATH"

workspace="$(aerospace list-workspaces --focused)"
"$HOME/dotfiles/bin/rename-workspace" "$workspace" "${1:-}"

echo "Workspace $workspace: ${1:-name cleared}"
