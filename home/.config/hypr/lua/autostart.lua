hl.on("hyprland.start", function ()
    -- grey text antialiasing: Qt's subpixel AA fringes the bar's flat glyphs
    hl.exec_cmd("env QSG_DISTANCEFIELD_ANTIALIASING=gray qs")
    hl.exec_cmd(os.getenv("HOME") .. "/.config/quickshell/scripts/wallpaper-init.sh")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("nm-applet")
    hl.exec_cmd("env CLIPHIST_MAX_ITEMS=200 wl-paste --type text --watch cliphist store")
    hl.exec_cmd("env CLIPHIST_MAX_ITEMS=200 wl-paste --type image --watch cliphist store")
end)
