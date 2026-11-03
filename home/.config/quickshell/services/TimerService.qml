pragma Singleton
import QtQuick
import Quickshell.Io
import Quickshell

QtObject {
    id: root

    property string label: ""
    property real   totalSeconds: 0
    property real   remaining: 0
    property bool   running: false
    property bool   finished: false

    readonly property real progress: totalSeconds > 0
        ? Math.max(0, Math.min(1, remaining / totalSeconds)) : 0

    function start(seconds, name) {
        totalSeconds = seconds
        remaining = seconds
        label = name !== undefined ? name : ""
        finished = false
        running = true
    }
    function stop() {
        running = false
        finished = false
        remaining = 0
        totalSeconds = 0
        label = ""
    }
    function toggle() { if (totalSeconds > 0) running = !running }

    function display() {
        var s = Math.max(0, Math.ceil(remaining))
        var h = Math.floor(s / 3600)
        var m = Math.floor((s % 3600) / 60)
        var ss = ("0" + (s % 60)).slice(-2)
        if (h > 0) return h + ":" + ("0" + m).slice(-2) + ":" + ss
        return m + ":" + ss
    }

    readonly property Timer tick: Timer {
        running: root.running && root.remaining > 0
        interval: 250
        repeat: true
        onTriggered: {
            root.remaining = Math.max(0, root.remaining - 0.25)
            if (root.remaining <= 0) {
                root.running = false
                root.finished = true
                root.fired()
            }
        }
    }

    signal fired()

    onFired: {
        notifyProc.command = [
            "notify-send", "-u", "critical", "-a", "Almanac",
            "-i", "alarm-symbolic",
            root.label !== "" ? root.label : "Timer",
            "Time is up"
        ]
        notifyProc.running = false
        notifyProc.running = true
    }

    readonly property Process notifyProc: Process { id: notifyProc; running: false }
}
