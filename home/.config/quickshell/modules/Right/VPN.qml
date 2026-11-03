import QtQuick
import Quickshell.Io
import "../../theme"
import "../../state"

Item {
    id: root

    anchors.verticalCenter: parent.verticalCenter
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    property bool _connected: false

    readonly property color iconColor: {
        if (hov.hovered) return Theme.accent
        return _connected ? Theme.statusActive : Theme.statusIdle
    }

    Process {
        id: statePoll
        command: ["bash", "-c",
            "nmcli -t -f NAME,TYPE,ACTIVE con show" +
            " | awk -F: '$2==\"wireguard\" && $3==\"yes\"{f=1} END{print f?1:0}'"]
        running: false
        stdout: SplitParser { onRead: function(l) { root._connected = l.trim() === "1" } }
    }
    Timer {
        interval: 5000; running: true; repeat: true
        onTriggered: { statePoll.running = false; statePoll.running = true }
    }
    Component.onCompleted: statePoll.running = true

    HoverHandler { id: hov }

    Row {
        id: row
        anchors.centerIn: parent

        Text {
            text: "󰦝"
            color: root.iconColor
            font.family: Theme.iconFont
            font.pixelSize: Theme.trayIconVpn
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 200 } }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            var next = !Popups.vpnOpen
            Popups.closeAll()
            Popups.vpnOpen = next
        }
    }
}
