pragma Singleton
import QtQuick

QtObject {
    id: root

    property bool   running: false
    property real   accumulated: 0
    property double startedAt: 0
    property double nowMs: Date.now()
    property var    laps: []

    readonly property real elapsed:
        running ? accumulated + Math.max(0, (nowMs - startedAt) / 1000) : accumulated
    readonly property bool idle: !running && accumulated === 0 && laps.length === 0

    function start() {
        if (running) return
        startedAt = Date.now()
        nowMs = startedAt
        running = true
    }
    function pause() {
        if (!running) return
        accumulated = accumulated + Math.max(0, (Date.now() - startedAt) / 1000)
        running = false
    }
    function toggle() { if (running) pause(); else start() }

    function reset() {
        running = false
        accumulated = 0
        startedAt = 0
        laps = []
    }

    function lap() {
        if (!running && accumulated === 0) return
        var at = elapsed
        var prev = laps.length > 0 ? laps[0].at : 0
        var next = [{ n: laps.length + 1, at: at, split: at - prev }]
        for (var i = 0; i < laps.length; i++) next.push(laps[i])
        laps = next
    }

    readonly property int bestLap: {
        if (laps.length < 2) return -1
        var b = 0
        for (var i = 1; i < laps.length; i++) if (laps[i].split < laps[b].split) b = i
        return laps[b].n
    }
    readonly property int worstLap: {
        if (laps.length < 2) return -1
        var w = 0
        for (var i = 1; i < laps.length; i++) if (laps[i].split > laps[w].split) w = i
        return laps[w].n
    }

    function format(s, precise) {
        var t = Math.max(0, s)
        var h = Math.floor(t / 3600)
        var m = Math.floor((t % 3600) / 60)
        var sec = Math.floor(t % 60)
        var frac = Math.floor((t - Math.floor(t)) * 100)
        var head = (h > 0 ? h + ":" + ("0" + m).slice(-2) : m) + ":" + ("0" + sec).slice(-2)
        if (precise === false) return head
        return head + "." + ("0" + frac).slice(-2)
    }

    readonly property Timer tick: Timer {
        running: root.running
        interval: 33
        repeat: true
        onTriggered: root.nowMs = Date.now()
    }
}
