#!/usr/bin/env bash
# Undo system/install.sh:  sudo system/restore.sh [greeter|grub|all]
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "run with sudo"; exit 1; }
what=${1:-all}

if [[ $what == all || $what == greeter ]]; then
    f=/etc/greetd/config.toml
    if [ -e "$f.ilargi-bak" ]; then cp -a "$f.ilargi-bak" "$f" && echo "greetd: previous config restored"; fi
    if [ -f /etc/greetd/.ilargi-previous-dm ]; then
        dm=$(cat /etc/greetd/.ilargi-previous-dm)
        systemctl disable greetd.service
        if [ "$dm" = none ]; then echo "greetd disabled (back to the text console)"
        else systemctl enable "$dm" && echo "display manager: $dm re-enabled"; fi
        rm -f /etc/greetd/.ilargi-previous-dm
    fi
    rm -rf /etc/greetd/ilargi-greeter
fi

if [[ $what == all || $what == grub || $what == console ]] && [ -e /etc/default/grub.ilargi-bak ]; then
    cp -a /etc/default/grub.ilargi-bak /etc/default/grub
    rm -rf /usr/share/grub/themes/ilargi
    grub-mkconfig -o /boot/grub/grub.cfg
    echo "GRUB: previous /etc/default/grub restored"
fi
