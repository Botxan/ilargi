mkdir -p "${XDG_STATE_HOME:-$HOME/.local/state}/zsh"
export HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history"
export HISTSIZE=10000
export SAVEHIST=10000
export EDITOR="vim"
export PATH="$HOME/.local/bin:$PATH"
[[ -n "$SSH_AUTH_SOCK" ]] || eval "$(ssh-agent -s)" > /dev/null
