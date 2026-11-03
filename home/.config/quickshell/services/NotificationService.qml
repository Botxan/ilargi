pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Io
import "../theme"

QtObject {
    id: root

    readonly property var all: {
        var v = server.trackedNotifications.values
        var out = []
        for (var i = v.length - 1; i >= 0; i--) out.push(v[i])
        return out
    }
    readonly property int count: all.length

    property var times: ({})
    function timeOf(n) { return times[n.id] !== undefined ? times[n.id] : Date.now() }

    function ageOf(n) {
        var secs = Math.max(0, (Date.now() - timeOf(n)) / 1000)
        if (secs < 45)   return "now"
        if (secs < 3600) return Math.round(secs / 60) + "m"
        if (secs < 86400) return Math.round(secs / 3600) + "h"
        return Math.round(secs / 86400) + "d"
    }

    property var live: []

    function isCritical(n) { return n.urgency === NotificationUrgency.Critical }

    function show(n) {
        var l = live.slice()
        l.push(n)
        while (l.length > 4) l.shift()
        live = l
    }

    function retire(n) {
        var l = []
        for (var i = 0; i < live.length; i++) if (live[i] !== n) l.push(live[i])
        live = l
    }

    function dismiss(n) {
        retire(n)
        n.dismiss()
    }

    function clearAll() {
        var snapshot = all.slice()
        live = []
        for (var i = 0; i < snapshot.length; i++) snapshot[i].dismiss()
    }

    function dismissApp(app) {
        var snapshot = all.filter(n => n.appName === app)
        for (var i = 0; i < snapshot.length; i++) dismiss(snapshot[i])
        return snapshot.length
    }
    readonly property IpcHandler ipc: IpcHandler {
        target: "notifications"
        function dismissApp(app: string): int { return root.dismissApp(app) }
        function clearAll() { root.clearAll() }
    }

    readonly property NotificationServer server: NotificationServer {
        id: server

        keepOnReload: true

        bodySupported:          true
        bodyMarkupSupported:    true
        bodyHyperlinksSupported: false
        bodyImagesSupported:    true
        imageSupported:         true
        actionsSupported:       true
        actionIconsSupported:   true
        inlineReplySupported:   true
        persistenceSupported:   true

        onNotification: function (n) {
            n.tracked = true

            var t = {}
            for (var k in root.times) t[k] = root.times[k]
            t[n.id] = Date.now()
            root.times = t

            if (Theme.dnd && !root.isCritical(n)) return
            if (n.transient) return

            root.show(n)
        }
    }

}
