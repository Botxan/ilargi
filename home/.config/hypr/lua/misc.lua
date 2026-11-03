hl.config({
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        force_default_wallpaper = 0,
        -- without these, "Displays off" in the session menu can't be undone
        mouse_move_enables_dpms = true,
        key_press_enables_dpms = true,
        -- relaunching qs after a crash takes the lock back
        allow_session_lock_restore = true,
    },
})
