-- Minimal Hyprland that only runs the Ilargi login screen as the greeter user.
-- system/install.sh fills in the GPU environment, keyboard layout and monitors.
hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QSG_DISTANCEFIELD_ANTIALIASING", "gray")
@ENV@

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })
@MONITORS@

hl.config({
    input = { kb_layout = "@KB_LAYOUT@", numlock_by_default = true },
    general = { border_size = 0, gaps_in = 0, gaps_out = 0 },
    decoration = { rounding = 0, shadow = { enabled = false }, blur = { enabled = false } },
    animations = { enabled = false },
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        disable_hyprland_guiutils_check = true,
        background_color = 0xff101213,
    },
    ecosystem = { no_update_news = true, no_donation_nag = true },
})

hl.layer_rule({ name = "ilargi-greeter-no-anim", match = { namespace = "^ilargi-greeter$" }, no_anim = true })

-- The greeter user's home is "/", so keep Quickshell's files in the runtime dir.
hl.on("hyprland.start", function ()
    hl.exec_cmd([[sh -c 'export XDG_CACHE_HOME="$XDG_RUNTIME_DIR/cache" XDG_STATE_HOME="$XDG_RUNTIME_DIR/state" XDG_DATA_HOME="$XDG_RUNTIME_DIR/data"; qs -p /etc/greetd/ilargi-greeter; hyprctl dispatch "hl.dsp.exit()"']])
end)
