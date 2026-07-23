
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

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"

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

