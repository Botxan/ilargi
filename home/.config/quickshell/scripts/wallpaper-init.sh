#!/bin/sh
# Start awww; on a first login (no awww cache yet) show the saved wallpaper.
awww-daemon &
[ -d "${XDG_CACHE_HOME:-$HOME/.cache}/awww" ] && exit 0
wall=$(cat "${XDG_STATE_HOME:-$HOME/.local/state}/ilargi/wallpaper" 2>/dev/null) || exit 0
for _ in 1 2 3 4 5 6 7 8 9 10; do
    awww query >/dev/null 2>&1 && exec awww img "$wall"
    sleep 0.5
done
