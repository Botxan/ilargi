import QtQuick
import Quickshell.Services.Notifications
import "../components"
import "../theme"
import "../services"

Item {
    id: stack

    property bool suppressed: false

    readonly property int cardW: 340
    readonly property int pad: 10
    readonly property int active: activeCount
    property int activeCount: 0
    readonly property bool open: activeCount > 0 && ready && !suppressed
    property bool ready: false
    onActiveCountChanged: {
        if (activeCount > 0 && !ready) readyTimer.restart()
        if (activeCount === 0) { readyTimer.stop(); ready = false }
    }
    Timer { id: readyTimer; interval: 20; onTriggered: { stack.syncHeight(); stack.ready = true } }
    readonly property real panelW: cardW + pad * 2
    property real panelH: 1
    function syncHeight() {
        if (column.implicitHeight > 0) panelH = column.implicitHeight + pad * 2
    }

    ListModel { id: toastModel }
    property var objs: ({})

    function sync() {
        var live = NotificationService.live
        var byId = {}
        for (var i = 0; i < live.length; i++) byId[live[i].id] = live[i]
        var going = []
        var stay = 0
        for (var j = 0; j < toastModel.count; j++) {
            var row = toastModel.get(j)
            if (row.leaving) continue
            if (byId[row.nid] === undefined) going.push(j)
            else stay++
        }
        for (var q = 0; q < live.length; q++) if (objs[live[q].id] === undefined) stay++
        activeCount = stay
        for (var g = 0; g < going.length; g++) toastModel.setProperty(going[g], "leaving", true)
        for (var k = 0; k < live.length; k++) {
            var n = live[k]
            if (objs[n.id] === undefined || objs[n.id] !== n) {
                var at = -1
                for (var m = 0; m < toastModel.count; m++) if (toastModel.get(m).nid === n.id) at = m
                objs[n.id] = n
                if (at >= 0) { toastModel.setProperty(at, "rev", toastModel.get(at).rev + 1); continue }
                toastModel.insert(0, { nid: n.id, leaving: false, rev: 0 })
            }
        }
        recount()
    }
    function recount() {
        var c = 0
        for (var i = 0; i < toastModel.count; i++) if (!toastModel.get(i).leaving) c++
        activeCount = c
    }
    function drop(nid) {
        for (var i = 0; i < toastModel.count; i++) if (toastModel.get(i).nid === nid) { toastModel.remove(i); break }
        if (objs[nid] !== undefined && !NotificationService.live.some(n => n.id === nid)) delete objs[nid]
        recount()
    }

    Connections {
        target: NotificationService
        function onLiveChanged() { stack.sync() }
    }
    Component.onCompleted: sync()

    Column {
        id: column
        x: stack.pad
        y: stack.pad
        width: stack.cardW
        spacing: 8
        onImplicitHeightChanged: stack.syncHeight()

        move: Transition {
            NumberAnimation { property: "y"; duration: Theme.animTransition; easing.type: Theme.animCurve }
        }

        Repeater {
            model: toastModel

            delegate: Item {
                id: slot
                required property int index
                required property int nid
                required property bool leaving
                required property int rev
                readonly property var notif: { rev; return stack.objs[nid] }

                width: column.width
                height: card.implicitHeight
                visible: notif !== undefined

                property real slide: 0
                Component.onCompleted: {
                    if (stack.panelOpenAlready && !stack.suppressed) {
                        slide = stack.panelW
                        enter.start()
                    }
                    stack.panelOpenAlready = true
                }
                NumberAnimation {
                    id: enter
                    target: slot; property: "slide"; to: 0
                    duration: Theme.animTransition; easing.type: Theme.animCurve
                }

                onLeavingChanged: if (leaving) {
                    if (stack.activeCount === 0 || stack.suppressed) sinkTimer.start()
                    else leave.start()
                }
                SequentialAnimation {
                    id: leave
                    NumberAnimation {
                        target: slot; property: "slide"; to: stack.panelW
                        duration: Theme.animTransition * 0.75; easing.type: Easing.InQuart
                    }
                    ScriptAction { script: stack.drop(slot.nid) }
                }
                Timer {
                    id: sinkTimer
                    interval: Theme.animTransition + 40
                    onTriggered: stack.drop(slot.nid)
                }

                NotifCard {
                    id: card
                    x: slot.slide
                    width: parent.width
                    notif: slot.notif
                    compact: true
                    color: Theme.surfaceWell
                    progress: life.value
                    onDismissed: NotificationService.dismiss(slot.notif)
                }

                QtObject {
                    id: life
                    property real value: NotificationService.isCritical(slot.notif) ? -1 : 1
                }
                NumberAnimation {
                    id: lifeAnim
                    target: life; property: "value"; from: 1; to: 0
                    duration: slot.notif && slot.notif.expireTimeout > 0
                        ? Math.max(3000, slot.notif.expireTimeout) : 6000
                    running: slot.notif !== undefined && !NotificationService.isCritical(slot.notif)
                             && !slot.leaving
                    paused: running && (hov.hovered || stack.suppressed)
                    onFinished: NotificationService.retire(slot.notif)
                }
                HoverHandler { id: hov }
            }
        }
    }
    property bool panelOpenAlready: false
    onOpenChanged: if (!open) closeReset.restart()
    Timer {
        id: closeReset
        interval: Theme.animTransition
        onTriggered: if (!stack.open) stack.panelOpenAlready = false
    }
}
