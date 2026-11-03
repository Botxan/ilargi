import Quickshell
import Quickshell.Io
import QtQuick
import Quickshell.Wayland
import "../shapes"
import "../components"
import "../theme"
import "../state"

Item {
    id: root
    readonly property bool open: Popups.audioOpen
    readonly property int headShift: 18
    readonly property real panelW: popupWidth - fw
    readonly property real panelH: popupHeight - fh - Theme.borderWidth + headShift
    visible: open || hold.running
    onOpenChanged: if (!open) hold.restart()
    Timer { id: hold; interval: Theme.animTransition + 40 }

    readonly property int fw: Theme.borderWidth + Theme.cornerRadius
    readonly property int fh: Theme.borderWidth + Theme.cornerRadius

    readonly property int popupWidth:
        Math.max(270, BarGeometry.rightMinPanelWidth)
    readonly property int popupHeight: 268

    Timer {
        id: focusTimer
        interval: 80
        onTriggered: audioControl.forceActiveFocus()
    }

    IpcHandler {
        target: "audio-toggle"
        function toggle() {
            var next = !Popups.audioOpen
            Popups.closeAll()
            Popups.audioOpen = next
        }
    }

    Connections {
        target: Popups
        function onAudioOpenChanged() {
            if (Popups.audioOpen) {
                closeTimer.stop()
                {}
                audioControl.forceActiveFocus()
                focusTimer.restart()
            } else {
                closeTimer.restart()
            }
        }
    }
    Timer {
        id: closeTimer
        interval: Theme.durationBase + 20
        onTriggered: { if (!Popups.audioOpen) { {}; audioControl.reset() } }
    }

    Item {
        id: sizer
        x: -root.fw
        y: -Theme.borderWidth + root.headShift
        width: root.popupWidth
        height: root.popupHeight

        Keys.onEscapePressed: Popups.audioOpen = false

        AudioControl {
            id: audioControl
            anchors {
                fill: parent
                topMargin: root.fh + 8
                bottomMargin: root.fh + 8
                leftMargin: root.fw * 2 + Theme.borderWidth
                rightMargin: root.fw
            }
            opacity: Popups.audioOpen ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.durationBase * 0.5 } }
        }
    }
}
