pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property bool dryRun: false

    readonly property bool hasLocker: true

    function commandFor(key) {
        switch (key) {
        case "displays": return "sleep 0.4; hyprctl dispatch 'hl.dsp.dpms({ action = \"off\" })'"
        case "lock":     return "qs ipc call lock lock"
        case "suspend":  return "qs ipc call lock lock; sleep 1; systemctl suspend"
        case "logout":   return "hyprctl dispatch 'hl.dsp.exit()'"
        case "reboot":   return "systemctl reboot"
        case "firmware": return "systemctl reboot --firmware-setup"
        case "poweroff": return "systemctl poweroff"
        }
        return ""
    }

    function run(key) {
        const cmd = commandFor(key)
        if (cmd === "") return
        if (dryRun) {
            console.log("sunset dry run:", key, "->", cmd)
            return
        }
        Quickshell.execDetached(["sh", "-c", cmd])
    }

    property real uptimeSeconds: 0
    readonly property Process uptimeProc: Process {
        command: ["cat", "/proc/uptime"]
        stdout: SplitParser {
            onRead: function (line) { root.uptimeSeconds = parseFloat(line.split(" ")[0]) || 0 }
        }
    }
    function refresh() {
        uptimeProc.running = false
        uptimeProc.running = true
    }
}
