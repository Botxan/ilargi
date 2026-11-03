import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "../shapes"
import "../theme"
import "../state"
import "../services"
import "../components"

Item {
    id: root
    readonly property bool open: Popups.clipboardOpen
    readonly property real panelW: sizerWidth - Theme.borderWidth
    readonly property real panelH: openHeight - fh * 2
    visible: open || hold.running
    onOpenChanged: if (!open) hold.restart()
    Timer {
        id: hold
        interval: Theme.animTransition + 40
        onTriggered: if (!Popups.clipboardOpen) {  }
    }

    readonly property int fw: Theme.borderWidth + Theme.cornerRadius
    readonly property int fh: Theme.borderWidth + Theme.cornerRadius

    readonly property real screenH: DisplayService.primaryScreen ? DisplayService.primaryScreen.height : 1080
    readonly property real openHeight: Math.round(screenH * 0.80) + fh * 2
    readonly property int  panelWidth: Theme.clipboardWidth
    readonly property int  sizerWidth: panelWidth + fw

    readonly property int padL: fw + 12
    readonly property int padR: 24

    IpcHandler {
        target: "clipboard-toggle"
        function toggle() {
            var next = !Popups.clipboardOpen
            Popups.closeAll()
            Popups.clipboardOpen = next
        }
    }

    property real reveal: 0

    SequentialAnimation {
        id: revealIn
        PauseAnimation { duration: Theme.almanacRevealDelay }
        NumberAnimation {
            target: root; property: "reveal"
            from: 0; to: 1
            duration: Theme.almanacReveal
            easing.type: Theme.animCurve
        }
    }
    NumberAnimation {
        id: revealOut
        target: root; property: "reveal"
        to: 0; duration: Theme.almanacCloseReveal
    }

    property string filter: ""

    readonly property var rows: {
        var v = ClipboardService.entries
        var q = filter.toLowerCase()
        var out = []
        for (var i = 0; i < v.length; i++) {
            if (q !== "" && v[i].preview.toLowerCase().indexOf(q) < 0) continue
            out.push(v[i])
        }
        return out
    }

    function take(i) {
        if (i < 0 || i >= rows.length) return
        ClipboardService.copy(rows[i].id)
        Popups.clipboardOpen = false
    }

    Connections {
        target: Popups
        function onClipboardOpenChanged() {
            if (Popups.clipboardOpen) {
                root.filter = ""
                ClipboardService.refresh()
                root.reveal = 0
                revealOut.stop()
                revealIn.restart()
                if (Theme.reducedMotion) { revealIn.stop(); root.reveal = 1 }
                keys.forceActiveFocus()
            } else {
                revealIn.stop()
                revealOut.restart()
            }
        }
    }

    Item {
        id: sizer
        x: -Theme.borderWidth
        y: -root.fh
        width: root.sizerWidth
        height: root.openHeight
        clip: true

        Item {
            id: keys
            anchors.fill: parent
            focus: true
            Keys.onPressed: function (e) {
                if (e.key === Qt.Key_Escape) {
                    if (root.filter !== "") root.filter = ""
                    else Popups.clipboardOpen = false
                    e.accepted = true
                } else if (e.key === Qt.Key_Backspace) {
                    root.filter = root.filter.slice(0, -1)
                    e.accepted = true
                } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                    root.take(0)
                    e.accepted = true
                } else if (root.filter === ""
                           && e.key >= Qt.Key_1 && e.key <= Qt.Key_9) {
                    root.take(e.key - Qt.Key_1)
                    e.accepted = true
                } else if (e.text && e.text.length === 1 && e.text >= " ") {
                    root.filter += e.text
                    e.accepted = true
                }
            }
        }

        Item {
            id: head
            anchors { left: parent.left; right: parent.right; top: parent.top
                      leftMargin: root.padL; rightMargin: root.padR; topMargin: root.fh + 16 }
            height: 62
            opacity: Theme.phase(root.reveal, 0, 0.3)

            Row {
                id: titleRow
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12
                Text {
                    text: "󰅍"
                    color: Theme.accent
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: Theme.iconFont; font.pixelSize: 26
                }
                Text {
                    text: "Clipboard"
                    color: Theme.text
                    font.family: Theme.fontText; font.pixelSize: 30; font.weight: Font.Bold
                }
            }
            Text {
                anchors { horizontalCenter: parent.horizontalCenter; top: titleRow.bottom; topMargin: 2 }
                text: ClipboardService.entries.length + " clips  ·  1–9 or Enter to copy"
                color: Theme.text
                opacity: 0.6
                font.family: Theme.fontText; font.pixelSize: 13; font.weight: Font.Medium
            }
        }

        Rectangle {
            id: body
            anchors { left: parent.left; right: parent.right; top: search.top; bottom: parent.bottom
                      leftMargin: root.padL - 12; rightMargin: root.padR - 12
                      topMargin: -12; bottomMargin: root.fh + 12 }
            radius: 16
            color: Theme.surfaceWell
            opacity: Theme.phase(root.reveal, 0, 0.3)
        }

        Rectangle {
            id: search
            anchors { left: parent.left; right: parent.right; top: head.bottom
                      leftMargin: root.padL; rightMargin: root.padR; topMargin: 26 }
            height: 44
            radius: 11
            color: Theme.surfaceRecess
            opacity: Theme.phase(root.reveal, 0.04, 0.3)

            Text {
                id: lens
                anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                text: "󰍉"
                color: root.filter === "" ? Theme.text : Theme.accent
                opacity: root.filter === "" ? 0.45 : 1
                font.family: Theme.iconFont; font.pixelSize: 17
            }
            Text {
                id: query
                anchors { left: lens.right; leftMargin: 10; verticalCenter: parent.verticalCenter }
                width: Math.min(implicitWidth, count.x - x - 24)
                elide: Text.ElideLeft
                text: root.filter === "" ? "Type to filter" : root.filter
                color: Theme.text
                opacity: root.filter === "" ? 0.4 : 1
                font.family: Theme.fontText; font.pixelSize: 14
                font.weight: root.filter === "" ? Font.Normal : Font.Medium
            }
            Rectangle {
                anchors { left: query.right; leftMargin: 3; verticalCenter: parent.verticalCenter }
                width: 2; height: 18; radius: 1
                visible: root.filter !== ""
                color: Theme.accent
                SequentialAnimation on opacity {
                    running: root.filter !== "" && !Theme.reducedMotion
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.15; duration: 520 }
                    NumberAnimation { to: 1; duration: 520 }
                }
            }
            Text {
                id: count
                anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                visible: root.filter !== ""
                text: root.rows.length + " / " + ClipboardService.entries.length
                color: Theme.text
                opacity: 0.45
                font.family: Theme.fontText; font.pixelSize: 12; font.weight: Font.Medium
                font.features: Theme.tabularNums
            }
        }

        ListView {
            id: list
            anchors {
                left: parent.left; right: parent.right
                top: search.bottom; bottom: parent.bottom
                leftMargin: root.padL; rightMargin: root.padR
                topMargin: 12; bottomMargin: root.fh + 24
            }
            clip: true
            spacing: 6
            model: root.rows
            boundsBehavior: Flickable.StopAtBounds
            opacity: Theme.phase(root.reveal, 0.10, 0.5)

            delegate: ClipRow {
                required property var modelData
                required property int index
                width: list.width
                clip_: modelData
                idx: index
                depth: Math.min(1, index / 11)
                phase: Theme.phase(root.reveal, 0.14 + Math.min(index, 12) * 0.03, 0.30)
                onTaken: root.take(index)
            }
        }

        Column {
            anchors.horizontalCenter: list.horizontalCenter
            anchors.top: search.bottom
            anchors.topMargin: 48
            spacing: 6
            visible: root.rows.length === 0
            opacity: Theme.phase(root.reveal, 0.14, 0.4)
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.filter === "" ? "󰅍" : "󰍉"
                color: Theme.text; opacity: 0.25
                font.family: Theme.iconFont; font.pixelSize: 34
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.filter === "" ? "Nothing copied yet" : "No clip matches"
                color: Theme.text; opacity: 0.6
                font.family: Theme.fontText; font.pixelSize: 14; font.weight: Font.Medium
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.filter === "" ? "Copy something and it lands here"
                                         : "Backspace to widen"
                color: Theme.text; opacity: 0.38
                font.family: Theme.fontText; font.pixelSize: 12
            }
        }

    }
}
