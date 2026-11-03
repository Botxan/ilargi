#!/usr/bin/env bash
# Wallpaper thumbnails: one 720px-tall JPEG per image, named by the md5 of
# its path (the picker computes the same with Qt.md5).
WALL_DIR="${1:-$HOME/Pictures/Wallpapers}"
CACHE_DIR="${2:-$HOME/.cache/ilargi/wall-thumbs}"
[ -d "$WALL_DIR" ] || exit 0
mkdir -p "$CACHE_DIR"
command -v magick >/dev/null 2>&1 || exit 0
export CACHE_DIR

thumb() {
    local file="$1" hash out
    hash=$(printf '%s' "$file" | md5sum | cut -d' ' -f1)
    out="$CACHE_DIR/$hash.jpg"
    if [ ! -f "$out" ] || [ "$file" -nt "$out" ]; then
        local src="$file"
        case "$file" in *.gif|*.GIF) src="${file}[0]" ;; esac
        magick "$src" -thumbnail "x720>" -quality 92 "$out" 2>/dev/null || true
    fi
}
export -f thumb

find "$WALL_DIR" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \
    -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.bmp' -o -iname '*.tif' -o -iname '*.tiff' \) -print0 |
    xargs -0 -n 1 -P 4 bash -c 'thumb "$@"' _ 2>/dev/null || true
