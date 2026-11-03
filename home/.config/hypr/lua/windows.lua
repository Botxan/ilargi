hl.window_rule({
	name  = "suppress-maximize-events",
	match = { class = ".*" },
	suppress_event = "maximize",
})

hl.window_rule({
	name  = "fix-xwayland-drags",
	match = {
		class      = "^$",
		title      = "^$",
		xwayland   = true,
		float      = true,
		fullscreen = false,
		pin        = false,
	},
	no_focus = true,
})

hl.window_rule({
	name  = "move-hyprland-run",
	match = { class = "hyprland-run" },
	move  = "20 monitor_h-120",
	float = true,
})

hl.window_rule({
	name  = "fix-firefox-dialogs",
	match = { class = "firefox", title = "^(Guardar.*|Save.*|Abrir.*|Open.*)$" },
	float = true,
	size  = "900 600",
	center = true,
})

hl.window_rule({
    name = "steam-float",
    match = {
        class = "^steam$",
    },
    float = true,
})

hl.window_rule({
    name = "steam-main-tile",
    match = {
        class = "^steam$",
        title = "^Steam$",
    },
    float = false,
})

hl.window_rule({
  match = { class = "^([Ss]atty)$" },
  float = true,
  center = true,
})

hl.layer_rule({
    name    = "quickshell-gota-no-anim",
    match   = { namespace = "^quickshell-(gota|wallpaper|frame|strut|lock|polkit)$" },
    no_anim = true,
})
