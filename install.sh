#!/usr/bin/env bash
# Ilargi installer for Arch Linux. Safe to run again.
#   ./install.sh [--yes] [--dry-run] [--no-packages] [--system | --no-system]
set -euo pipefail

REPO=$(cd "$(dirname "$0")" && pwd)
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/ilargi"
BACKUP="$STATE/backup/$(date +%Y%m%d-%H%M%S)"
YES=0 DRY=0 PACKAGES=1 SYSTEM=ask

for a in "$@"; do
    case $a in
        -y|--yes) YES=1 ;;
        -n|--dry-run) DRY=1 ;;
        --no-packages) PACKAGES=0 ;;
        --system) SYSTEM=yes ;;
        --no-system) SYSTEM=no ;;
        -h|--help) sed -n 2,3p "$0"; exit 0 ;;
        *) echo "unknown option: $a"; exit 1 ;;
    esac
done

say()  { printf '\n\033[1;34m::\033[0m \033[1m%s\033[0m\n' "$*"; }
info() { printf '   %s\n' "$*"; }
mk()   { [ $DRY = 1 ] || mkdir -p "$@"; }
run()  { if [ $DRY = 1 ]; then info "[dry-run] $*"; else "$@"; fi; }
ask()  { [ $YES = 1 ] && return 0; read -r -p "   $1 [Y/n] " r; [[ ! $r =~ ^[Nn] ]]; }

# ---------------------------------------------------------------- checks
[ "$(id -u)" != 0 ] || { echo "run as your user, not root"; exit 1; }
command -v pacman >/dev/null || { echo "Ilargi needs Arch Linux (pacman)"; exit 1; }

# ---------------------------------------------------------------- packages
if [ $PACKAGES = 1 ]; then
    say "Packages"
    mapfile -t pkgs < <(sed 's/#.*//' "$REPO/packages.txt" | tr ' ' '\n' | grep -v '^$')
    repo=() aur=()
    for p in "${pkgs[@]}"; do [[ $p == aur:* ]] && aur+=("${p#aur:}") || repo+=("$p"); done
    run sudo pacman -Syu --needed --noconfirm "${repo[@]}"

    helper=$(command -v paru || command -v yay || true)
    if [ -z "$helper" ]; then
        info "installing yay (AUR helper)"
        run sudo pacman -S --needed --noconfirm base-devel
        tmp=$(mktemp -d)
        run git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
        [ $DRY = 1 ] || (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
        rm -rf "$tmp"
        helper=yay
    fi
    run "$helper" -S --needed --noconfirm "${aur[@]}"
fi

# ---------------------------------------------------------------- dotfiles
say "Linking dotfiles"
# Owned whole; everything else is linked file by file so apps can keep
# writing their own files next to ours.
LINK_DIRS=(.config/quickshell .config/hypr .config/kitty .config/zsh .config/fontconfig .config/satty)

link() {  # link <repo path> <target>
    local src=$1 dst=$2
    [ "$(readlink "$dst" 2>/dev/null)" = "$src" ] && return
    if [ -e "$dst" ] || [ -L "$dst" ]; then
        mk "$(dirname "$BACKUP/${dst#$HOME/}")"
        run mv "$dst" "$BACKUP/${dst#$HOME/}"
        info "backed up ~/${dst#$HOME/}"
    fi
    mk "$(dirname "$dst")"
    run ln -s "$src" "$dst"
}

for d in "${LINK_DIRS[@]}"; do link "$REPO/home/$d" "$HOME/$d"; done
while IFS= read -r -d '' f; do
    rel=${f#"$REPO/home/"}
    skip=0
    for d in "${LINK_DIRS[@]}"; do [[ $rel == "$d/"* ]] && skip=1; done
    [ $skip = 1 ] || link "$f" "$HOME/$rel"
done < <(find "$REPO/home" -type f -print0)

# ---------------------------------------------------------------- per-machine files
say "Machine settings"
mk "$STATE"

render() {  # render <template> <target>: copy, replacing @HOME@ and @MIC@
    if [ -e "$2" ] && [ ! -L "$2" ] && ! cmp -s <(sed -e "s|@HOME@|$HOME|g" -e "s|@MIC@|${MIC:-}|g" "$1") "$2"; then
        mk "$(dirname "$BACKUP/${2#$HOME/}")"
        run cp -a "$2" "$BACKUP/${2#$HOME/}"
    fi
    mk "$(dirname "$2")"
    [ $DRY = 1 ] || sed -e "s|@HOME@|$HOME|g" -e "s|@MIC@|${MIC:-}|g" "$1" > "$2"
}
render "$REPO/templates/qt6ct.conf" "$HOME/.config/qt6ct/qt6ct.conf"
render "$REPO/templates/kdeglobals" "$HOME/.config/kdeglobals"

KB_LAYOUT=$(sed -n 's/.*kb_layout *= *"\([^"]*\)".*/\1/p' "$STATE/local.lua" 2>/dev/null | head -1)
[ -n "$KB_LAYOUT" ] || KB_LAYOUT=$(localectl status 2>/dev/null | awk -F': ' '/X11 Layout/ {print $2}' | cut -d, -f1)
[ -n "$KB_LAYOUT" ] && [ "$KB_LAYOUT" != "(unset)" ] || KB_LAYOUT=us
if [ ! -e "$STATE/local.lua" ]; then
    info "keyboard layout: $KB_LAYOUT"
    {
        echo "-- This machine only. Edit freely; install.sh never overwrites it."
        echo "hl.config({ input = { kb_layout = \"$KB_LAYOUT\" } })"
        if [ -d /sys/module/nvidia_drm ]; then
            info "NVIDIA GPU: adding its environment"
            for kv in LIBVA_DRIVER_NAME=nvidia __GLX_VENDOR_LIBRARY_NAME=nvidia GBM_BACKEND=nvidia-drm \
                      WLR_NO_HARDWARE_CURSORS=1 NVD_BACKEND=direct; do
                echo "hl.env(\"${kv%%=*}\", \"${kv#*=}\")"
            done
        fi
    } | { [ $DRY = 1 ] && cat >/dev/null || cat > "$STATE/local.lua"; }
fi

run xdg-user-dirs-update
PICS="$HOME/Pictures"
mk "$PICS/Wallpapers" "$PICS/Screenshots" "$HOME/.local/share/soundboard"
[ -e "$PICS/Wallpapers/ilargi.png" ] || run cp "$REPO/wallpapers/ilargi.png" "$PICS/Wallpapers/"
[ -s "$STATE/wallpaper" ] || { [ $DRY = 1 ] || printf %s "$PICS/Wallpapers/ilargi.png" > "$STATE/wallpaper"; }
run fc-cache -f >/dev/null

# ---------------------------------------------------------------- zsh
say "zsh"
OMZ="${XDG_DATA_HOME:-$HOME/.local/share}/oh-my-zsh"
clone() { [ -d "$2" ] || run git clone -q --depth 1 "$1" "$2"; }
clone https://github.com/ohmyzsh/ohmyzsh.git "$OMZ"
clone https://github.com/romkatv/powerlevel10k.git "$OMZ/custom/themes/powerlevel10k"
clone https://github.com/zsh-users/zsh-autosuggestions.git "$OMZ/custom/plugins/zsh-autosuggestions"
clone https://github.com/zsh-users/zsh-completions.git "$OMZ/custom/plugins/zsh-completions"
clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$OMZ/custom/plugins/zsh-syntax-highlighting"
if [ "$(basename "$(getent passwd "$USER" | cut -d: -f7)")" != zsh ] && ask "Make zsh your login shell?"; then
    run sudo chsh -s /usr/bin/zsh "$USER" || info "chsh failed; run it yourself: chsh -s /usr/bin/zsh"
fi

# ---------------------------------------------------------------- app themes
say "App themes"
for ini in "$HOME/.config/mozilla/firefox/profiles.ini" "$HOME/.mozilla/firefox/profiles.ini"; do
    [ -f "$ini" ] || continue
    dir=$(dirname "$ini")
    prof=$(awk -F= '/^\[Install/ {i=1} i && /^Default=/ {print $2; exit}' "$ini")
    [ -n "$prof" ] || prof=$(awk -F= '/^Path=/ {print $2; exit}' "$ini")
    [ -n "$prof" ] && [ -d "$dir/$prof" ] || continue
    link "$REPO/themes/firefox/userChrome.css" "$dir/$prof/chrome/userChrome.css"
    link "$REPO/themes/firefox/userContent.css" "$dir/$prof/chrome/userContent.css"
    link "$REPO/themes/firefox/user.js" "$dir/$prof/user.js"
    info "Firefox: $prof"
done
if [ -d "$HOME/.config/vesktop" ]; then
    link "$REPO/themes/vesktop/ilargi.theme.css" "$HOME/.config/vesktop/themes/ilargi.theme.css"
    info "Vesktop: enable 'ilargi' in Settings > Themes"
fi
if [ -f "$HOME/.config/obsidian/obsidian.json" ]; then
    jq -r '.vaults[].path' "$HOME/.config/obsidian/obsidian.json" | while read -r vault; do
        [ -d "$vault/.obsidian" ] || continue
        link "$REPO/themes/obsidian/ilargi.css" "$vault/.obsidian/snippets/ilargi.css"
        info "Obsidian: $vault (enable the 'ilargi' snippet in Appearance)"
    done
fi

if command -v gsettings >/dev/null; then
    run gsettings set org.gnome.desktop.interface color-scheme prefer-dark
    run gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3-dark
    run gsettings set org.gnome.desktop.interface icon-theme Papirus-Dark
    run gsettings set org.gnome.desktop.interface font-name "Roboto 11"
    run gsettings set org.gnome.desktop.interface cursor-theme Bibata-Modern-Classic
    run gsettings set org.gnome.desktop.interface cursor-size 24
fi

# ---------------------------------------------------------------- services
say "Services"
units=(NetworkManager.service power-profiles-daemon.service)
[ -n "$(ls -A /sys/class/bluetooth 2>/dev/null)" ] && units+=(bluetooth.service)
for u in "${units[@]}"; do
    systemctl is-enabled -q "$u" 2>/dev/null || systemctl is-active -q "$u" || run sudo systemctl enable --now "$u"
done
run systemctl --user enable pipewire.socket pipewire-pulse.socket wireplumber.service
run systemctl --user restart pipewire pipewire-pulse wireplumber 2>/dev/null || true

# soundboard virtual mic, fed by the current default (physical) microphone
[ $DRY = 1 ] || sleep 2
SB_CONF="$HOME/.config/pipewire/pipewire.conf.d/99-soundboard.conf"
sources=$(pactl list short sources 2>/dev/null | cut -f2 | grep -E '^(alsa|bluez)_input' || true)
MIC=$(sed -n 's/.*target.object *= *"\([a-z]*_input[^"]*\)".*/\1/p' "$SB_CONF" 2>/dev/null | head -1 || true)
grep -qxF "$MIC" <<<"$sources" || MIC=$(pactl get-default-source 2>/dev/null || true)
if [[ $MIC != alsa_input* && $MIC != bluez_input* ]]; then
    MIC=$(head -1 <<<"$sources")
fi
if [ -n "$MIC" ]; then
    info "soundboard mic: $MIC"
    render "$REPO/templates/pipewire-soundboard.conf" "$SB_CONF"
    run systemctl --user restart pipewire pipewire-pulse wireplumber 2>/dev/null || true
else
    info "no microphone found; run ./install.sh --no-packages again later for the soundboard mic"
fi

# ---------------------------------------------------------------- system
if [ $SYSTEM = ask ]; then
    say "System"
    info "Optional: Ilargi login screen (greetd), GRUB theme and console colours."
    ask "Install them? (needs sudo; undo with system/restore.sh)" && SYSTEM=yes || SYSTEM=no
fi
if [ $SYSTEM = yes ]; then
    run sudo env KB_LAYOUT="$KB_LAYOUT" "$REPO/system/install.sh"
fi

say "Done"
info "Log out and start Hyprland (uwsm), or reboot if you installed the login screen."
[ -d "$BACKUP" ] && info "Replaced files were saved in $BACKUP"
true
