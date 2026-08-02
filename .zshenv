export PATH="/Users/andrew/Downloads/flutter/bin:$PATH"

# tfenv keeps its downloaded terraform binaries in the same directory as its
# config, and Homebrew's shims default that to ~/.config/tfenv — which is a
# symlink into the dotfiles repo. Point it at the XDG data dir instead.
#
# This lives here rather than in .zshrc so that non-interactive shells — a
# script, a Makefile, a cron job — get it too. Without it they fall back to
# the Homebrew default and re-download 84MB into the repo.
export TFENV_CONFIG_DIR="$HOME/.local/share/tfenv"

# Secrets live outside the repo and sync via Dropbox; set -a exports whatever
# the file defines. Here rather than in .zshrc for the same reason as above:
# `listen` reads SPEECHIFY_API_KEY, and it runs from a Claude Code slash
# command, which is a non-interactive shell that never sources .zshrc.
if [ -f "$HOME/Dropbox/andrew/.env" ]; then
  set -a
  source "$HOME/Dropbox/andrew/.env"
  set +a
fi
