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
    readonly property bool open: Popups.bluetoothOpen
    readonly property int headShift: 18
    readonly property real panelW: popupWidth - fw
    readonly property real panelH: popupHeight - fh - Theme.borderWidth + headShift
    visible: open || hold.running
    onOpenChanged: if (!open) hold.restart()
    Timer { id: hold; interval: Theme.animTransition + 40 }

    readonly property int popupWidth:
        Math.max(380, BarGeometry.rightMinPanelWidth)
    readonly property int fw: Theme.borderWidth + Theme.cornerRadius
    readonly property int fh: Theme.borderWidth + Theme.cornerRadius

    readonly property int headerBlock: 49
    readonly property int maxListHeight: 363 - headerBlock
    readonly property int listHeight: Math.min(bluetoothTab.listContentHeight, maxListHeight)
    readonly property int popupHeight: (fh + 10) + headerBlock + listHeight + (fh + (fw / 2) + Theme.borderWidth)

    IpcHandler {
        target: "bluetooth-toggle"
        function toggle() {
            var next = !Popups.bluetoothOpen
            Popups.closeAll()
            Popups.bluetoothOpen = next
        }
    }

    Connections {
        target: Popups
        function onBluetoothOpenChanged() {
            if (Popups.bluetoothOpen) { closeTimer.stop(); {} }
            else closeTimer.restart()
        }
    }
    Timer {
        id: closeTimer
        interval: Theme.durationBase + 20
        onTriggered: { if (!Popups.bluetoothOpen) {} }
    }

    Item {
        id: sizer
        x: -root.fw
        y: -Theme.borderWidth + root.headShift
        width: root.popupWidth
        height: root.popupHeight

        Keys.onEscapePressed: Popups.bluetoothOpen = false

        Item {
            id: contentArea
            anchors {
                fill: parent
                topMargin: root.fh + 10
                leftMargin: root.fw * 1.5 + Theme.borderWidth
                rightMargin: root.fw / 2
                bottomMargin: root.fh + (root.fw / 2) + Theme.borderWidth
            }

            opacity: Popups.bluetoothOpen ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: Popups.bluetoothOpen ? Theme.durationBase * 0.5 : Theme.durationBase * 0.15 }
            }

            BluetoothTab { id: bluetoothTab; anchors.fill: parent }
        }
    }
}
