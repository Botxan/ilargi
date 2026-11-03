local apps = require("lua/variables").apps
local mod = "SUPER"
local grave = "code:49"

hl.bind(mod .. " + R", hl.dsp.exec_cmd("hyprctl reload"))

hl.bind(mod .. " + W", hl.dsp.window.close())

-- apps
hl.bind(mod .. " + RETURN", hl.dsp.exec_cmd(apps.terminal))
hl.bind(mod .. " + D", hl.dsp.exec_cmd(apps.menu))
hl.bind(mod .. " + SHIFT + N", hl.dsp.exec_cmd(apps.fileManager))
hl.bind(mod .. " + SHIFT + F", hl.dsp.exec_cmd(apps.browser))
hl.bind(mod .. " + SHIFT + O", hl.dsp.exec_cmd(apps.obsidian))
hl.bind(mod .. " + SHIFT + D", hl.dsp.exec_cmd(apps.discord))
hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd(apps.steam))

hl.bind(mod .. " + SHIFT + right", hl.dsp.exec_cmd(apps.almanac))
hl.bind(mod .. " + SHIFT + left",  hl.dsp.exec_cmd(apps.clipboard))
hl.bind(mod .. " + SHIFT + up",    hl.dsp.exec_cmd(apps.aperture))
hl.bind(mod .. " + SHIFT + down",  hl.dsp.exec_cmd(apps.wallpaper_changer))
hl.bind(mod .. " + Escape", hl.dsp.exec_cmd(apps.sunset))
hl.bind(mod .. " + SHIFT + L", hl.dsp.exec_cmd(apps.lock))

hl.bind(mod .. " + Print",           hl.dsp.exec_cmd(apps.recorder_toggle))
hl.bind(mod .. " + SHIFT + Print",   hl.dsp.exec_cmd(apps.recorder_region))

hl.bind(mod .. " + L", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + P", hl.dsp.window.pseudo())
hl.bind(mod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(mod .. " + M", hl.dsp.window.fullscreen({ action = "toggle" }))
hl.bind("Print", hl.dsp.exec_cmd(apps.screenshot))

hl.bind(mod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + down",  hl.dsp.focus({ direction = "down" }))

for i = 1, 8 do
    hl.bind(mod .. " + " .. i,         hl.dsp.focus({ workspace = i}))
    hl.bind(mod .. " + SHIFT + " .. i, hl.dsp.global("quickshell:send-" .. i))
end

local aux = { { key = grave, ws = "name:aux-l" }, { key = "0", ws = "name:aux-r" }, { key = "9", ws = "name:aux-x" } }
for _, a in ipairs(aux) do
    hl.bind(mod .. " + " .. a.key,         hl.dsp.focus({ workspace = a.ws }))
    hl.bind(mod .. " + SHIFT + " .. a.key, hl.dsp.global("quickshell:send-" .. a.ws:gsub("^name:", "")))
end

hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })

hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
