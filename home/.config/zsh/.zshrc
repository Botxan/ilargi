# Powerlevel10k instant prompt: keep at the top.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export ZSH="${XDG_DATA_HOME:-$HOME/.local/share}/oh-my-zsh"
ZSH_CUSTOM="$ZSH/custom"
ZSH_COMPDUMP="${XDG_CACHE_HOME:-$HOME/.cache}/zcompdump-$ZSH_VERSION"
ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(
  git
  archlinux
  sudo
  zsh-autosuggestions
  zsh-completions
  zsh-syntax-highlighting  # must be last
)

source "$ZDOTDIR/exports.zsh"
source "$ZDOTDIR/aliases.zsh"
source "$ZSH/oh-my-zsh.sh"
unsetopt hist_verify

[[ -f "$ZDOTDIR/.p10k.zsh" ]] && source "$ZDOTDIR/.p10k.zsh"
source "$ZDOTDIR/colors.zsh"
