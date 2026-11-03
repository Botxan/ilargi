#!/bin/sh
# Toggle recording of the focused monitor.
exec qs ipc call recorder toggle "$(hyprctl activeworkspace -j | jq -r .monitor)"
