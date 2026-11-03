pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"

QtObject {
    id: root

    readonly property FileView file: FileView {
        id: file
        path: Paths.state + "/alarms.json"
        watchChanges: true
        onFileChanged: reload()
        onLoadFailed: function (error) {
            file.writeAdapter()
        }
        JsonAdapter {
            id: store
            property var items: []
        }
    }

    readonly property var alarms: store.items

    function _commit(next) {
        store.items = next
        file.writeAdapter()
    }

    function add(h, m, label, days) {
        var next = []
        for (var i = 0; i < alarms.length; i++) next.push(alarms[i])
        next.push({
            id: Date.now() + "-" + Math.floor(Math.random() * 1000),
            h: h, m: m,
            label: label !== undefined && label !== "" ? label : "Alarm",
            enabled: true,
            days: days !== undefined ? days : []
        })
        next.sort(function (a, b) { return (a.h * 60 + a.m) - (b.h * 60 + b.m) })
        _commit(next)
    }

    function remove(id) {
        var next = []
        for (var i = 0; i < alarms.length; i++) if (alarms[i].id !== id) next.push(alarms[i])
        _commit(next)
    }

    function setEnabled(id, on) {
        var next = []
        for (var i = 0; i < alarms.length; i++) {
            var a = alarms[i]
            next.push(a.id === id
                ? { id: a.id, h: a.h, m: a.m, label: a.label, enabled: on, days: a.days }
                : a)
        }
        _commit(next)
    }

    function nextFire(a) {
        var now = new Date()
        for (var i = 0; i < 8; i++) {
            var d = new Date(now.getFullYear(), now.getMonth(), now.getDate() + i, a.h, a.m, 0, 0)
            if (d.getTime() <= now.getTime()) continue
            if (!a.days || a.days.length === 0) return d
            var dow = (d.getDay() + 6) % 7
            if (a.days.indexOf(dow) >= 0) return d
        }
        return null
    }

    readonly property var next: {
        var _ = root.pollMs
        var best = null, bestAt = null
        for (var i = 0; i < alarms.length; i++) {
            var a = alarms[i]
            if (!a.enabled) continue
            var at = nextFire(a)
            if (at === null) continue
            if (bestAt === null || at.getTime() < bestAt.getTime()) { best = a; bestAt = at }
        }
        return best === null ? null : { alarm: best, at: bestAt }
    }

    function untilText(at) {
        if (!at) return ""
        var mins = Math.max(0, Math.round((at.getTime() - Date.now()) / 60000))
        var h = Math.floor(mins / 60), m = mins % 60
        if (h >= 24) return Math.floor(h / 24) + "d " + (h % 24) + "h"
        if (h > 0) return h + "h " + m + "m"
        return m + "m"
    }

    property double pollMs: Date.now()

    property int rearmToken: 0
    readonly property var armed: {
        var _ = root.rearmToken
        var m = ({})
        var v = alarms
        for (var i = 0; i < v.length; i++) {
            var a = v[i]
            if (!a.enabled) continue
            var at = nextFire(a)
            if (at !== null) m[a.id] = at.getTime()
        }
        return m
    }

    property var handled: ({})

    function _fire(a) {
        notifyProc.command = [
            "notify-send", "-u", "critical", "-a", "Almanac",
            "-i", "alarm-symbolic",
            a.label,
            ("0" + a.h).slice(-2) + ":" + ("0" + a.m).slice(-2)
        ]
        notifyProc.running = false
        notifyProc.running = true
        fired(a)
    }

    signal fired(var alarm)

    readonly property Process notifyProc: Process { id: notifyProc; running: false }

    readonly property Timer poll: Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            var now = Date.now()
            root.pollMs = now

            var due = []
            var seen = ({})
            for (var id in root.armed) {
                var at = root.armed[id]
                seen[id] = root.handled[id]
                if (now < at) continue
                if (root.handled[id] === at) continue
                seen[id] = at
                if (now - at < 120000) due.push(id)
            }
            if (due.length === 0 && JSON.stringify(seen) === JSON.stringify(root.handled)) return
            root.handled = seen

            for (var j = 0; j < due.length; j++) {
                var a = null
                for (var i2 = 0; i2 < root.alarms.length; i2++)
                    if (root.alarms[i2].id === due[j]) { a = root.alarms[i2]; break }
                if (a === null) continue
                root._fire(a)
                if (!a.days || a.days.length === 0) root.setEnabled(a.id, false)
            }
            root.rearmToken = root.rearmToken + 1
        }
    }
}
