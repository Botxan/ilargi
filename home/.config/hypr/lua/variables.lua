local M = {}

local scripts = os.getenv("HOME") .. "/.config/quickshell/scripts/"

M.apps = {
    terminal = "kitty",
    fileManager = "dolphin",
    browser = "firefox",
    obsidian = "obsidian",
    discord = "vesktop",
    steam = "steam",

    menu = "qs ipc call aperture-toggle launcher",
    aperture = "qs ipc call aperture-toggle toggle",
    wallpaper_changer = "qs ipc call wallpaper-toggle toggle",
    almanac = "qs ipc call almanac-toggle toggle",
    clipboard = "qs ipc call clipboard-toggle toggle",
    sunset = "qs ipc call sunset toggle",
    lock = "qs ipc call lock lock",

    screenshot = scripts .. "screenshot.sh",
    recorder_toggle = scripts .. "record-screen.sh",
    recorder_region = scripts .. "record-region.sh",
}

return M
