# Ilargi colours for ls, the prompt, syntax highlighting and man pages.
# Sourced from .zshrc after oh-my-zsh and .p10k.zsh so these win.

eval "$(dircolors -b)"
export LS_COLORS="${LS_COLORS/di=01;34/di=38;2;103;145;201}"
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

ZSH_HIGHLIGHT_STYLES[arg0]="fg=#6791c9"
ZSH_HIGHLIGHT_STYLES[precommand]="fg=#6791c9,underline"
ZSH_HIGHLIGHT_STYLES[autodirectory]="fg=#6791c9,underline"
ZSH_HIGHLIGHT_STYLES[suffix-alias]="fg=#6791c9,underline"
ZSH_HIGHLIGHT_STYLES[unknown-token]="fg=#df5b61,bold"

typeset -g POWERLEVEL9K_DIR_BACKGROUND="#6791c9"
typeset -g POWERLEVEL9K_DIR_{,SHORTENED_,ANCHOR_}FOREGROUND="#0c0e0f"
typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND=2
typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND=1

# man: less applies these to groff's bold/underline/standout
export GROFF_NO_SGR=1
export LESS_TERMCAP_md=$'\e[1;38;2;103;145;201m'
export LESS_TERMCAP_mb=$'\e[1;38;2;223;91;97m'
export LESS_TERMCAP_me=$'\e[0m'
export LESS_TERMCAP_us=$'\e[4;38;2;120;184;146m'
export LESS_TERMCAP_ue=$'\e[0m'
export LESS_TERMCAP_so=$'\e[38;2;12;14;15;48;2;236;210;139m'
export LESS_TERMCAP_se=$'\e[0m'
