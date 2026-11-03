pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"

QtObject {
    id: root

    readonly property FileView cache: FileView {
        path: Paths.cache + "/calendar.json"
        watchChanges: true
        onFileChanged: reload()
        JsonAdapter {
            id: data
            property string updated: ""
            property bool ok: false
            property string note: ""
            property var events: []
            property var tasks: []
            property var calendars: []
            property var taskLists: []
        }
    }

    readonly property var taskLists: data.taskLists
    function subtasksOf(id) {
        var out = []
        for (var i = 0; i < tasks.length; i++) if (tasks[i].parent === id) out.push(tasks[i])
        return out.sort(function (a, b) { return a.position < b.position ? -1 : 1 })
    }
    function saveTask(p) {
        if (p.id) {
            var v = data.tasks.slice()
            for (var i = 0; i < v.length; i++) if (v[i].id === p.id) {
                var c = Object.assign({}, v[i]); c.title = p.title; c.notes = p.notes; c.due = p.due; v[i] = c
            }
            data.tasks = v
        }
        root.run(["save-task", "--json", JSON.stringify(p)])
    }
    readonly property var calendars: data.calendars
    readonly property var writableCalendars: {
        var out = []
        for (var i = 0; i < calendars.length; i++) if (calendars[i].writable) out.push(calendars[i])
        return out
    }
    function calendarById(id) {
        for (var i = 0; i < calendars.length; i++) if (calendars[i].id === id) return calendars[i]
        return null
    }
    readonly property var primaryCalendar: {
        for (var i = 0; i < writableCalendars.length; i++) if (writableCalendars[i].primary) return writableCalendars[i]
        return writableCalendars.length > 0 ? writableCalendars[0] : null
    }

    readonly property var events: data.events
    readonly property var tasks: data.tasks
    readonly property var tasksByDay: {
        var m = ({})
        for (var i = 0; i < tasks.length; i++) {
            var t = tasks[i]
            if (t.done || !t.due) continue
            if (!m[t.due]) m[t.due] = []
            m[t.due].push(t)
        }
        return m
    }
    function tasksOn(dt) { var t = tasksByDay[key(dt)]; return t === undefined ? [] : t }
    readonly property string updated: data.updated
    readonly property string note: data.note
    readonly property bool configured: data.note.indexOf("no config") !== 0
    readonly property bool healthy: data.ok

    readonly property var byDay: {
        var m = ({})
        var v = events
        for (var i = 0; i < v.length; i++) {
            var s0 = new Date(v[i].start), e0 = new Date(v[i].end)
            var d = new Date(s0.getFullYear(), s0.getMonth(), s0.getDate())
            for (var n = 0; n < 62; n++) {
                var k = root.key(d)
                if (!m[k]) m[k] = []
                m[k].push(v[i])
                d = new Date(d.getFullYear(), d.getMonth(), d.getDate() + 1)
                if (d.getTime() >= e0.getTime()) break
            }
        }
        return m
    }

    function key(dt) {
        return dt.getFullYear() + "-"
             + ("0" + (dt.getMonth() + 1)).slice(-2) + "-"
             + ("0" + dt.getDate()).slice(-2)
    }
    function on(dt) { var e = byDay[key(dt)]; return e === undefined ? [] : e }
    function has(dt) { return byDay[key(dt)] !== undefined }

    function timeLabel(ev) {
        if (ev.allDay) return "all day"
        return Qt.formatDateTime(new Date(ev.start), "HH:mm")
    }

    property double nowMs: Date.now()
    readonly property Timer minute: Timer {
        interval: 30000; repeat: true; running: true
        onTriggered: root.nowMs = Date.now()
    }

    property bool fetching: false

    function refresh() {
        if (fetchProc.running) return
        fetching = true
        fetchProc.running = true
    }

    readonly property string script: Paths.scripts + "/gcal2json.py"
    property var queue: []
    property bool writing: false
    property string lastError: ""
    function run(args) {
        var q = root.queue.slice(); q.push(args); root.queue = q
        root.pump()
    }
    function pump() {
        if (writeProc.running || root.queue.length === 0) return
        var q = root.queue.slice(); var next = q.shift(); root.queue = q
        writeProc.command = ["python3", root.script].concat(next)
        root.writing = true
        writeProc.running = true
    }
    readonly property Process writeProc: Process {
        id: writeProc
        stderr: StdioCollector { id: writeErr }
        onExited: function (code) {
            root.lastError = code === 0 ? "" : writeErr.text.trim().split("\n").pop()
            root.writing = root.queue.length > 0
            root.pump()
        }
    }

    function saveEvent(p) { root.run(["save-event", "--json", JSON.stringify(p)]) }
    function deleteEvent(ev, series) {
        var v = []
        for (var i = 0; i < data.events.length; i++) {
            var x = data.events[i]
            if (x.id === ev.id) continue
            if (series && ev.recurringId !== "" && x.recurringId === ev.recurringId) continue
            v.push(x)
        }
        data.events = v
        var a = ["delete-event", "--calendar", ev.calendar, "--id", ev.id]
        if (series && ev.recurringId) a = a.concat(["--series", ev.recurringId])
        root.run(a)
    }

    readonly property FileView firedFile: FileView {
        id: firedFile
        path: Paths.cache + "/calendar-reminders.json"
        onLoadFailed: firedFile.writeAdapter()
        JsonAdapter { id: firedStore; property var fired: ({}) }
    }
    function reminderText(e, m) {
        var st = new Date(e.start)
        var when = e.allDay ? "all day" : Qt.formatDateTime(st, "HH:mm") + "–" + Qt.formatDateTime(new Date(e.end), "HH:mm")
        var lead = m === 0 ? "Now"
                 : m < 60 ? "In " + m + " min"
                 : m < 1440 && m % 60 === 0 ? "In " + (m / 60) + " h"
                 : m < 1440 ? "In " + Math.floor(m / 60) + " h " + (m % 60) + " min"
                 : Qt.formatDate(st, "ddd d MMM")
        return lead + " · " + when + (e.location ? " · " + e.location : "")
    }
    function checkReminders() {
        if (!firedFile.loaded) return
        var now = Date.now(), f = Object.assign({}, firedStore.fired), changed = false
        for (var k in f) if (now - f[k] > 3 * 86400000) { delete f[k]; changed = true }
        var v = data.events
        for (var i = 0; i < v.length; i++) {
            var e = v[i], mins = e.reminders
            if (!mins || mins.length === 0) continue
            var st = new Date(e.start).getTime()
            if (st - now > 30 * 86400000 || st < now - 86400000) continue
            for (var j = 0; j < mins.length; j++) {
                var at = st - mins[j] * 60000
                if (now < at || now - at > 600000) continue
                var key = e.id + "|" + e.start + "|" + mins[j]
                if (f[key]) continue
                f[key] = now; changed = true
                root.notify(e.title, root.reminderText(e, mins[j]))
            }
        }
        if (changed) { firedStore.fired = f; firedFile.writeAdapter() }
    }
    readonly property string reminderIcon: "/usr/share/icons/breeze-dark/mimetypes/64/x-office-calendar.svg"
    property var notifyQueue: []
    function notify(title, body) {
        var q = root.notifyQueue.slice(); q.push([title, body]); root.notifyQueue = q
        root.pumpNotify()
    }
    function pumpNotify() {
        if (notifyProc.running || root.notifyQueue.length === 0) return
        var q = root.notifyQueue.slice(); var n = q.shift(); root.notifyQueue = q
        notifyProc.command = ["notify-send", "-a", "Calendar", "-i", root.reminderIcon, n[0], n[1]]
        notifyProc.running = true
    }
    readonly property Process notifyProc: Process {
        id: notifyProc
        onExited: root.pumpNotify()
    }
    readonly property Timer reminderTick: Timer {
        interval: 20000; repeat: true; running: true; triggeredOnStart: true
        onTriggered: root.checkReminders()
    }
    function setTaskDone(t, done) {
        var v = data.tasks.slice()
        for (var i = 0; i < v.length; i++) if (v[i].id === t.id) {
            var c = Object.assign({}, v[i]); c.done = done; v[i] = c
        }
        data.tasks = v
        root.run(["set-task", "--list", t.list, "--id", t.id, "--done", done ? "1" : "0"])
    }
    function deleteTask(t) {
        var v = []
        for (var i = 0; i < data.tasks.length; i++)
            if (data.tasks[i].id !== t.id && data.tasks[i].parent !== t.id) v.push(data.tasks[i])
        data.tasks = v
        root.run(["delete-task", "--list", t.list, "--id", t.id])
    }

    readonly property Process fetchProc: Process {
        id: fetchProc
        command: ["python3", Paths.scripts + "/gcal2json.py"]
        running: false
        onExited: root.fetching = false
    }

    readonly property Timer poll: Timer {
        interval: 180000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
