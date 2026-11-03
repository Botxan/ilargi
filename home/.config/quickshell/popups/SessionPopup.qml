import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick
import "../theme"
import "../state"
import "../services"

Item {
    id: root

    readonly property int fw: Theme.borderWidth + Theme.cornerRadius
    readonly property int fh: Theme.borderWidth + Theme.cornerRadius
    readonly property int bodyWidth: 560
    readonly property int bodyHeight: 200
    readonly property int pad: 18

    readonly property bool open: Popups.sessionOpen
    readonly property real panelW: bodyWidth
    readonly property real panelH: bodyHeight + fh - Theme.borderWidth
    visible: open || hold.running
    onOpenChanged: if (!open) hold.restart()
    Timer { id: hold; interval: Theme.animTransition + 40 }

    readonly property var actions: [
        { key: "lock",     label: "Lock",       glyph: 0xF0341, hue: Theme.accent,      hotkey: "L", hard: false },
        { key: "displays", label: "Screen off", glyph: 0xF0D90, hue: Theme.accent,      hotkey: "D", hard: false },
        { key: "suspend",  label: "Suspend",    glyph: 0xF0904, hue: Theme.palette.green,  hotkey: "S", hard: false },
        { key: "logout",   label: "Log out",    glyph: 0xF0343, hue: Theme.palette.yellow, hotkey: "O", hard: true },
        { key: "reboot",   label: "Restart",    glyph: 0xF0709, hue: Theme.palette.yellow, hotkey: "R", hard: true },
        { key: "poweroff", label: "Power off",  glyph: 0xF0425, hue: Theme.palette.red,    hotkey: "P", hard: true }
    ]
    readonly property var firmware: ({ key: "firmware", label: "Firmware setup", glyph: 0xF061A,
                                       hue: Theme.palette.yellow, hotkey: "F", hard: true })

    function enabled(a) { return a.key !== "lock" || SessionService.hasLocker }
    function byKey(k) {
        if (k === "firmware") return firmware
        for (var i = 0; i < actions.length; i++) if (actions[i].key === k) return actions[i]
        return null
    }

    property int sel: 2
    property var pending: null
    property real countdown: 0
    readonly property int confirmMs: 3000

    function move(d) {
        var i = sel
        for (var n = 0; n < actions.length; n++) {
            i = (i + d + actions.length) % actions.length
            if (enabled(actions[i])) break
        }
        sel = i
    }

    function choose(a) {
        if (!a || !enabled(a)) return
        if (!a.hard || (pending && pending.key === a.key)) { execute(a); return }
        pending = a
        countAnim.restart()
    }
    function cancel() {
        countAnim.stop()
        pending = null
        countdown = 0
    }
    function execute(a) {
        countAnim.stop()
        pending = null
        countdown = 0
        Popups.sessionOpen = false
        runTimer.key = a.key
        runTimer.restart()
    }
    Timer {
        id: runTimer
        property string key: ""
        interval: Theme.animTransition
        onTriggered: SessionService.run(key)
    }
    NumberAnimation {
        id: countAnim
        target: root; property: "countdown"; from: 1; to: 0
        duration: root.confirmMs
        onFinished: if (root.pending) root.execute(root.pending)
    }

    Connections {
        target: Popups
        function onSessionOpenChanged() {
            if (Popups.sessionOpen) {
                SessionService.refresh()
                root.sel = 2
                keys.forceActiveFocus()
                focusTimer.restart()
            } else {
                root.cancel()
            }
        }
    }
    Timer { id: focusTimer; interval: 60; onTriggered: keys.forceActiveFocus() }

    IpcHandler {
        target: "sunset"
        function toggle(): void {
            var next = !Popups.sessionOpen
            Popups.closeAll()
            Popups.sessionOpen = next
        }
        function open(): void { Popups.closeAll(); Popups.sessionOpen = true }
        function close(): void { Popups.sessionOpen = false }
        function choose(key: string): void { root.choose(root.byKey(key)) }
        function cancel(): void { root.cancel() }
        function dryrun(on: bool): void { SessionService.dryRun = on }
        function status(): string {
            return "open=" + Popups.sessionOpen + " sel=" + root.actions[root.sel].key
                + " pending=" + (root.pending ? root.pending.key : "") + " dryRun=" + SessionService.dryRun
                + " hasLocker=" + SessionService.hasLocker
        }
    }

    Item {
        id: keys
        focus: root.open
        Keys.onPressed: function (e) {
            var k = e.key
            if (k === Qt.Key_Escape) {
                if (root.pending) root.cancel()
                else Popups.sessionOpen = false
            } else if (k === Qt.Key_Left || k === Qt.Key_Backtab || k === Qt.Key_H) {
                root.move(-1)
            } else if (k === Qt.Key_Right || k === Qt.Key_Tab) {
                root.move(1)
            } else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) {
                root.choose(root.actions[root.sel])
            } else {
                var t = e.text.toUpperCase()
                var a = t === "F" ? root.firmware : null
                for (var i = 0; i < root.actions.length && !a; i++)
                    if (root.actions[i].hotkey === t) { a = root.actions[i]; root.sel = i }
                if (!a) return
                root.choose(a)
            }
            e.accepted = true
        }
    }

    Item {
        id: content
        width: root.bodyWidth
        height: root.bodyHeight
        y: root.fh - Theme.borderWidth
        opacity: root.open ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: root.open ? Theme.animContentIn : Theme.animContentOut }
        }

        Item {
            id: head
            anchors { left: parent.left; right: parent.right; top: parent.top
                      leftMargin: root.pad; rightMargin: root.pad; topMargin: 10 }
            height: 36

            Rectangle {
                id: avatar
                width: 36; height: 36; radius: 18
                color: Theme.palette.bg4
                Text {
                    anchors.centerIn: parent
                    text: root.user.charAt(0).toUpperCase()
                    color: Theme.accent
                    font.family: Theme.fontText; font.pixelSize: 15; font.weight: Font.Medium
                }
            }
            Column {
                anchors { left: avatar.right; leftMargin: 12; verticalCenter: parent.verticalCenter }
                spacing: 2
                Text {
                    text: root.user
                    color: Theme.text
                    font.family: Theme.fontText; font.pixelSize: 14; font.weight: Font.Medium
                }
                Text {
                    text: root.host + " · up " + root.uptime
                    color: Theme.text; opacity: 0.5
                    font.family: Theme.fontText; font.pixelSize: 11
                }
            }

            Row {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 6
                Chip {
                    visible: root.bat && root.bat.isLaptopBattery
                    glyph: 0xF0079
                    text: root.bat ? Math.round(root.bat.percentage * 100) + " %" : ""
                }
                Chip {
                    glyph: root.firmware.glyph
                    text: "Firmware"
                    hotkey: "F"
                    clickable: true
                    active: root.pending === root.firmware
                    hue: root.firmware.hue
                    onClicked: root.choose(root.firmware)
                }
            }
        }

        Row {
            id: buttons
            anchors { left: parent.left; right: parent.right; top: head.bottom
                      leftMargin: root.pad; rightMargin: root.pad; topMargin: 16 }
            spacing: 8
            readonly property real cellW: (width - spacing * (root.actions.length - 1)) / root.actions.length

            Repeater {
                model: root.actions
                delegate: Rectangle {
                    id: cell
                    required property var modelData
                    required property int index
                    readonly property bool on: root.enabled(modelData)
                    readonly property bool selected: root.sel === index
                    readonly property bool armed: root.pending && root.pending.key === modelData.key

                    width: buttons.cellW
                    height: 82
                    radius: 12
                    opacity: on ? 1 : 0.35
                    color: armed ? Theme.withAlpha(modelData.hue, 0.20)
                         : selected ? Theme.withAlpha(modelData.hue, 0.12)
                         : Theme.surfaceWell
                    border.width: selected || armed ? 1.5 : 0
                    border.color: modelData.hue
                    Behavior on color { ColorAnimation { duration: Theme.animColor } }

                    Text {
                        anchors { top: parent.top; right: parent.right; topMargin: 7; rightMargin: 9 }
                        text: cell.modelData.hotkey
                        color: Theme.text
                        opacity: cell.selected ? 0.5 : 0.22
                        font.family: Theme.fontMono; font.pixelSize: 9
                    }
                    Column {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: 2
                        spacing: 9
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: String.fromCodePoint(cell.modelData.glyph)
                            color: cell.modelData.hue
                            font.family: Theme.iconFont; font.pixelSize: 24
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: cell.modelData.label
                            color: cell.selected || cell.armed ? cell.modelData.hue : Theme.text
                            opacity: cell.selected || cell.armed ? 1 : 0.8
                            font.family: Theme.fontText; font.pixelSize: 11
                            font.weight: cell.selected ? Font.Medium : Font.Normal
                        }
                    }

                    HoverHandler {
                        enabled: cell.on
                        cursorShape: Qt.PointingHandCursor
                        onHoveredChanged: if (hovered) root.sel = cell.index
                    }
                    TapHandler {
                        enabled: cell.on
                        onTapped: root.choose(cell.modelData)
                    }
                }
            }
        }

        Item {
            anchors { left: parent.left; right: parent.right; top: buttons.bottom
                      leftMargin: root.pad; rightMargin: root.pad; topMargin: 14 }
            height: 22

            Row {
                anchors.centerIn: parent
                spacing: 16
                visible: !root.pending
                Hint { keyText: "← →"; text: "choose" }
                Hint { keyText: "Enter"; text: "confirm" }
                Hint { keyText: "Esc"; text: "close" }
            }

            Item {
                anchors.fill: parent
                visible: root.pending !== null
                Text {
                    anchors { left: parent.left; top: parent.top }
                    text: root.pending ? root.pending.label + " in " + Math.ceil(root.countdown * root.confirmMs / 1000) + " s" : ""
                    color: root.pending ? root.pending.hue : Theme.text
                    font.family: Theme.fontText; font.pixelSize: 11; font.weight: Font.Medium
                }
                Text {
                    anchors { right: parent.right; top: parent.top }
                    text: "again to run now · Esc cancels"
                    color: Theme.text; opacity: 0.45
                    font.family: Theme.fontText; font.pixelSize: 11
                }
                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 3; radius: 2
                    color: Theme.surfaceSunk
                    Rectangle {
                        width: parent.width * root.countdown
                        height: parent.height; radius: 2
                        color: root.pending ? root.pending.hue : Theme.accent
                    }
                }
            }
        }
    }

    readonly property string user: Quickshell.env("USER") || "user"
    property string host: "arch"
    Process {
        running: true
        command: ["cat", "/etc/hostname"]
        stdout: SplitParser { onRead: function (l) { if (l.trim() !== "") root.host = l.trim() } }
    }
    readonly property var bat: UPower.displayDevice
    readonly property string uptime: {
        var m = Math.floor(SessionService.uptimeSeconds / 60)
        var d = Math.floor(m / 1440), h = Math.floor(m / 60) % 24, mm = m % 60
        if (d > 0) return d + " d " + h + " h"
        if (h > 0) return h + " h " + mm + " min"
        return mm + " min"
    }

    component Hint: Row {
        property string keyText
        property string text
        spacing: 6
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: kt.implicitWidth + 10; height: 18; radius: 5
            color: Theme.surfaceWell
            Text {
                id: kt
                anchors.centerIn: parent
                text: parent.parent.keyText
                color: Theme.text; opacity: 0.7
                font.family: Theme.fontMono; font.pixelSize: 10
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: parent.text
            color: Theme.text; opacity: 0.45
            font.family: Theme.fontText; font.pixelSize: 11
        }
    }

    component Chip: Rectangle {
        id: chip
        property int glyph: 0
        property string text
        property string hotkey: ""
        property bool clickable: false
        property bool active: false
        property color hue: Theme.text
        signal clicked()
        width: chipRow.implicitWidth + 16
        height: 26; radius: 7
        color: active ? Theme.withAlpha(hue, 0.20)
             : chipHov.hovered && clickable ? Theme.surfaceRecess : Theme.surfaceWell
        border.width: active ? 1 : 0
        border.color: hue
        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 6
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: String.fromCodePoint(chip.glyph)
                color: chip.clickable ? chip.hue : Theme.text
                opacity: chip.clickable ? 1 : 0.6
                font.family: Theme.iconFont; font.pixelSize: 13
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.text
                color: Theme.text; opacity: 0.7
                font.family: Theme.fontText; font.pixelSize: 11
            }
            Text {
                visible: chip.hotkey !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: chip.hotkey
                color: Theme.text; opacity: 0.3
                font.family: Theme.fontMono; font.pixelSize: 9
            }
        }
        HoverHandler { id: chipHov; enabled: chip.clickable; cursorShape: Qt.PointingHandCursor }
        TapHandler { enabled: chip.clickable; onTapped: chip.clicked() }
    }
}
