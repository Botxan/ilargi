pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"

Singleton {
    id: root

    readonly property bool recording: rec.running
    property string scope: ""
    property string detail: ""
    property string lastFile: ""

    property double startedAt: 0
    property double nowMs: Date.now()
    readonly property real elapsed:
        recording ? Math.max(0, (nowMs - startedAt) / 1000) : 0

    function format(s) {
        var t = Math.floor(s)
        var h = Math.floor(t / 3600), m = Math.floor(t / 60) % 60, ss = t % 60
        function p(n) { return (n < 10 ? "0" : "") + n }
        return h > 0 ? (h + ":" + p(m) + ":" + p(ss)) : (p(m) + ":" + p(ss))
    }
    function display() { return format(elapsed) }

    Timer {
        interval: 500; repeat: true; running: root.recording
        onTriggered: root.nowMs = Date.now()
    }

    property string videoDir: ""
    Process {
        running: true
        command: ["sh", "-c",
                  "d=\"$(xdg-user-dir VIDEOS)/Recordings\"; mkdir -p \"$d\"; printf %s \"$d\""]
        stdout: StdioCollector {
            onStreamFinished: root.videoDir = text.trim()
        }
    }

    Process {
        id: rec
        onExited: function (code, status) {
            root.nowMs = Date.now()
            if (Theme.dndHeldByRecorder) {
                Theme.set("dnd", false)
                Theme.set("dndHeldByRecorder", false)
            }
            root.notifiedFile = root.lastFile
            root.refreshRecent()
            if (notify.running) notify.running = false
            notify.command = code === 0
                ? ["notify-send", "-a", "Recorder", "-i", "video-x-generic",
                   "-A", "open=Open", "-A", "folder=Show in folder",
                   "Recording saved", root.baseName(root.lastFile)]
                : ["notify-send", "-u", "critical", "-a", "Recorder",
                   "Recording failed", "wf-recorder exited " + code]
            notify.running = true
        }
    }
    property string notifiedFile: ""
    function baseName(p) { return p.substring(p.lastIndexOf("/") + 1) }
    function dirName(p)  { return p.substring(0, p.lastIndexOf("/")) }

    Process {
        id: notify
        stdout: StdioCollector {
            onStreamFinished: {
                var a = text.trim()
                if (a === "") return
                opener.command = ["xdg-open",
                                  a === "folder" ? root.dirName(root.notifiedFile)
                                                 : root.notifiedFile]
                opener.running = true
            }
        }
    }
    Process { id: opener }

    property bool recoveryArmed: true
    function recoverDnd() {
        if (!recoveryArmed || !Theme.dndHeldByRecorder) return
        recoveryArmed = false
        Theme.set("dnd", false)
        Theme.set("dndHeldByRecorder", false)
    }
    Component.onCompleted: recoverDnd()
    Connections {
        target: Theme
        function onDndHeldByRecorderChanged() { root.recoverDnd() }
    }

    property bool withAudio: false
    property string audioSource: ""
    onWithAudioChanged: if (withAudio) sinkProbe.running = true
    Process {
        id: sinkProbe
        command: ["pactl", "get-default-sink"]
        stdout: StdioCollector {
            onStreamFinished: {
                var sink = text.trim()
                root.audioSource = sink !== "" ? sink + ".monitor" : ""
            }
        }
    }

    property var recent: []
    function refreshRecent() {
        if (root.videoDir === "" || recentProc.running) return
        recentProc.running = true
    }
    Process {
        id: recentProc
        command: ["sh", "-c",
            "cd \"$1\" 2>/dev/null && ls -t -- *.mp4 2>/dev/null | head -n 6 | while IFS= read -r f; do "
            + "printf '%s\\t%s\\t%s\\n' \"$f\" \"$(du -h -- \"$f\" | cut -f1)\" \"$(date -r \"$f\" '+%d/%m %H:%M')\"; done",
            "sh", root.videoDir]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = []
                var lines = text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var p = lines[i].split("\t")
                    if (p.length < 3 || p[0] === "") continue
                    out.push({ file: root.videoDir + "/" + p[0], name: p[0], size: p[1], when: p[2] })
                }
                root.recent = out
            }
        }
    }

    function begin(args, scopeLabel, detailLabel) {
        if (rec.running || root.videoDir === "") return
        var stamp = Qt.formatDateTime(new Date(), "yyyyMMdd-hhmmss")
        root.lastFile = root.videoDir + "/rec-" + stamp + ".mp4"
        root.scope = scopeLabel
        root.detail = detailLabel
        root.startedAt = Date.now()
        root.nowMs = root.startedAt
        root.recoveryArmed = false
        if (!Theme.dnd) {
            Theme.set("dnd", true)
            Theme.set("dndHeldByRecorder", true)
        }
        var audio = root.withAudio && root.audioSource !== ""
            ? ["--audio=" + root.audioSource] : []
        rec.command = ["wf-recorder", "-y"].concat(args).concat(audio).concat(["-f", root.lastFile])
        rec.running = true
    }

    function startOutput(name) {
        if (!name || name === "") return
        begin(["-o", name], name, "Full monitor")
    }

    function startGeometry(g) {
        if (rec.running || !g || g.trim() === "") return
        var geom = g.trim()
        begin(["-g", geom], "Region", geom.split(" ")[1] || "")
    }

    IpcHandler {
        target: "recorder"
        function toggle(output: string): void { root.toggle(output) }
        function output(name: string): void   { root.startOutput(name) }
        function geometry(g: string): void    { root.startGeometry(g) }
        function stop(): void                 { root.stop() }
        function status(): string {
            return root.recording
                ? ("recording " + root.scope + " " + root.display() + " -> " + root.lastFile)
                : "idle"
        }
    }

    function stop() {
        if (rec.running) rec.signal(2)
    }
    function toggle(name) {
        if (rec.running) stop()
        else startOutput(name)
    }
}
