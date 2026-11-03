-- Ilargi — Hyprland config
local state = (os.getenv("XDG_STATE_HOME") or os.getenv("HOME") .. "/.local/state") .. "/ilargi"

require("lua/env")
require("lua/input")
require("lua/look_and_feel")
require("lua/layout")
require("lua/misc")
require("lua/windows")
require("lua/keybindings")
require("lua/autostart")

-- Per-machine files, written by install.sh and the shell (never in the repo):
--   local.lua         keyboard layout, GPU env, device tweaks
--   displays.lua      monitor layout from the shell's Displays room
--   soundboard.lua    soundboard key binds
for _, f in ipairs({ "local.lua", "displays.lua", "soundboard.lua" }) do
    local path = state .. "/" .. f
    if io.open(path) then
        local ok, err = pcall(dofile, path)
        if not ok then print("ilargi: " .. path .. ": " .. tostring(err)) end
    end
end
