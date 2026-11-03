#!/usr/bin/env bash
# Root part of Ilargi: login screen (greetd), GRUB theme, console colours.
#   sudo system/install.sh [greeter] [grub] [console]     (no args = all that apply)
# Every file it changes is backed up once as <file>.ilargi-bak; system/restore.sh undoes it.
# KB_LAYOUT can be passed in the environment; otherwise it is read from local.lua or localectl.
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "run with sudo"; exit 1; }
USER_NAME=${SUDO_USER:?run with sudo from your user}
USER_HOME=$(getent passwd "$USER_NAME" | cut -d: -f6)
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(dirname "$HERE")
STATE="$USER_HOME/.local/state/ilargi"
[ -n "${KB_LAYOUT:-}" ] || KB_LAYOUT=$(sed -n 's/.*kb_layout *= *"\([^"]*\)".*/\1/p' "$STATE/local.lua" 2>/dev/null | head -1)
[ -n "$KB_LAYOUT" ] || KB_LAYOUT=$(localectl status 2>/dev/null | awk -F': ' '/X11 Layout/ {print $2}' | cut -d, -f1)
[ -n "$KB_LAYOUT" ] && [ "$KB_LAYOUT" != "(unset)" ] || KB_LAYOUT=us
steps=${*:-greeter grub console}
want() { [[ " $steps " == *" $1 "* ]]; }
say() { printf '\033[1;34m::\033[0m %s\n' "$*"; }

bak() {
    # migrate backups from the old name, then back up once
    [ -e "$1.yoru-bak" ] && [ ! -e "$1.ilargi-bak" ] && mv "$1.yoru-bak" "$1.ilargi-bak"
    [ -e "$1" ] && [ ! -e "$1.ilargi-bak" ] && cp -a "$1" "$1.ilargi-bak"
    true
}
set_kv() {
    if grep -q -E "^#?$1=" /etc/default/grub; then
        sed -i -E "s|^#?$1=.*|$1=$2|" /etc/default/grub
    else
        echo "$1=$2" >> /etc/default/grub
    fi
}

has_grub=0
[ -f /etc/default/grub ] && command -v grub-mkconfig >/dev/null && has_grub=1
regen_grub=0

if want console; then
    if [ $has_grub = 1 ]; then
        say "console colours"
        bak /etc/default/grub
        vt=$(cat "$HERE/vt-colors.txt")
        sed -i -E 's/ ?vt\.default_(red|grn|blu)=[0-9,]+//g' /etc/default/grub
        sed -i -E "s|^(GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*)\"|\1 $vt\"|" /etc/default/grub
        regen_grub=1
    else
        say "console colours: skipped (needs GRUB)"
    fi
fi

if want grub; then
    if [ $has_grub = 1 ]; then
        say "GRUB theme"
        bak /etc/default/grub
        rm -rf /usr/share/grub/themes/yoru
        install -d /usr/share/grub/themes/ilargi
        install -m 644 "$HERE/grub/"{theme.txt,*.pf2} /usr/share/grub/themes/ilargi/
        set_kv GRUB_TIMEOUT 3
        set_kv GRUB_TIMEOUT_STYLE menu
        set_kv GRUB_THEME '"/usr/share/grub/themes/ilargi/theme.txt"'
        set_kv GRUB_TERMINAL_OUTPUT gfxterm
        regen_grub=1
    else
        say "GRUB theme: skipped (GRUB not found)"
    fi
fi

[ $regen_grub = 1 ] && grub-mkconfig -o /boot/grub/grub.cfg

if want greeter; then
    say "login screen (greetd)"
    pacman -S --needed --noconfirm greetd >/dev/null
    final=/etc/greetd/ilargi-greeter
    out=$final.new
    rm -rf "$out"
    install -d "$out/components" "$out/shapes" "$out/theme"
    cp "$HERE/greeter/shell.qml" "$out/"
    cp "$HERE/greeter/theme/"{Theme.qml,qmldir} "$out/theme/"
    shell="$REPO/home/.config/quickshell"
    cp "$shell/components/"{LockFace.qml,PasswordDots.qml} "$out/components/"
    cp "$shell/shapes/NotchShape.qml" "$out/shapes/"

    primary=$(jq -r '.lastPrimaryName // ""' "$STATE/displays.json" 2>/dev/null || true)
    sed -i -e "s/property string user: \".*\"/property string user: \"$USER_NAME\"/" \
           -e "s/property string primaryName: \".*\"/property string primaryName: \"$primary\"/" "$out/shell.qml"

    env_lines=""
    if [ -d /sys/module/nvidia_drm ]; then
        env_lines=$(printf 'hl.env("%s", "%s")\n' LIBVA_DRIVER_NAME nvidia __GLX_VENDOR_LIBRARY_NAME nvidia \
            GBM_BACKEND nvidia-drm WLR_NO_HARDWARE_CURSORS 1 NVD_BACKEND direct)
    fi
    monitors=$(grep -E '^hl\.monitor\(\{ output = "[^"]+"' "$STATE/displays.lua" 2>/dev/null || true)
    python3 - "$HERE/greeter/hyprland.lua" "$out/hyprland.lua" "$env_lines" "$KB_LAYOUT" "$monitors" <<'PY'
import sys
src, dst, env, kb, mon = sys.argv[1:]
s = open(src).read().replace("@ENV@", env).replace("@KB_LAYOUT@", kb).replace("@MONITORS@", mon)
open(dst, "w").write(s)
PY
    # never install a config Hyprland can't parse: the login screen would drop to emergency mode
    rt=$(mktemp -d); chown "$USER_NAME" "$rt"; chmod -R a+rX "$out"
    runuser -u "$USER_NAME" -- env XDG_RUNTIME_DIR="$rt" Hyprland --verify-config -c "$out/hyprland.lua" >"$rt/verify.log" 2>&1 || true
    if ! grep -q "config ok" "$rt/verify.log"; then
        grep -i -A3 "parsing result" "$rt/verify.log"
        rm -rf "$out" "$rt"
        echo "login screen config is invalid; the current login screen was left untouched"
        exit 1
    fi
    rm -rf "$rt" /etc/greetd/yoru-greeter "$final"
    mv "$out" "$final"
    out=$final
    chown -R root:root "$out"
    chmod -R a+rX "$out"

    bak /etc/greetd/config.toml
    cat > /etc/greetd/config.toml <<CONF
# Ilargi login screen. Previous config: /etc/greetd/config.toml.ilargi-bak
[terminal]
vt = 1

[default_session]
command = "start-hyprland -- -c $out/hyprland.lua"
user = "greeter"
CONF

    dm=$(basename "$(readlink /etc/systemd/system/display-manager.service 2>/dev/null)" 2>/dev/null || true)
    if [ "$dm" != greetd.service ]; then
        echo "${dm:-none}" > /etc/greetd/.ilargi-previous-dm
        [ -n "$dm" ] && systemctl disable "$dm"
    fi
    systemctl enable greetd.service
    say "greetd will show the Ilargi login on the next boot"
fi

cat <<MSG

If the login screen ever fails: Ctrl+Alt+F2, log in, then
  sudo $HERE/restore.sh greeter && sudo systemctl restart greetd
MSG
