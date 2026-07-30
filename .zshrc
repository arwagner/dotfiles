
# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"

autoload -Uz vcs_info
precmd() { vcs_info }

zstyle ':vcs_info:git:*' formats '%b '
setopt PROMPT_SUBST
PROMPT='%F{green}%*%f %F{blue}%~%f %F{red}${vcs_info_msg_0_}%f$ '

eval "$(/opt/homebrew/bin/brew shellenv)"

export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"

export PATH="$HOME/.local/bin:$PATH"

export PATH="$HOME/dotfiles/bin:$PATH"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"

# tfenv keeps its downloaded terraform binaries in the same directory as its
# config, and Homebrew's shims default that to ~/.config/tfenv — which is a
# symlink into the dotfiles repo. Point it at the XDG data dir instead.
export TFENV_CONFIG_DIR="$HOME/.local/share/tfenv"

# if [ -f "$HOME/Dropbox/andrew/.env" ]; then
#   set -a
#  source "$HOME/Dropbox/andrew/.env"
#  set +a
#fi

# `claude`    -> your Claude subscription (no env overrides)
# `claude-or` -> route this invocation through OpenRouter
# claude-or() {
#  ANTHROPIC_BASE_URL="https://openrouter.ai/api" \
#  ANTHROPIC_AUTH_TOKEN="$OPENROUTER_API_KEY" \
#  ANTHROPIC_API_KEY="" \
#  command claude "$@"
#}

# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/andrew/.lmstudio/bin"
# End of LM Studio CLI section

export SKYLIGHT=$HOME/Dropbox/andrew/skylight
export DTAK=$SKYLIGHT/code/dtak-prototype
