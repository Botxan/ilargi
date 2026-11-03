#!/bin/sh
# Screenshot of the focused monitor, opened in satty with the crop tool.
dir="$HOME/Pictures/Screenshots"
mkdir -p "$dir"
grim -o "$(hyprctl activeworkspace -j | jq -r '.monitor')" - |
  satty --filename - \
    --fullscreen \
    --floating-hack \
    --initial-tool crop \
    --early-exit \
    --copy-command wl-copy \
    --output-filename "$dir/satty-%Y%m%d-%H%M%S.png"
