import QtQuick
import Quickshell.Io
import "../../theme"
import "../../state"

Item {
    id: root

    property bool showPercentage: false

    anchors.verticalCenter: parent.verticalCenter
    visible: _present
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    property bool   _present:     false
    property bool   _powered:     false
    property bool   _connected:   false
    property string _deviceName:  ""
    property int    _battery:     -1

    readonly property string icon: {
        if (!_powered) return "󰂲"
        if (_connected) return "󰂱"
        return "󰂯"
    }
    readonly property color iconColor: {
        if (hov.hovered && _powered) return Theme.accent
        if (!_powered) return Theme.statusIdle
        return _connected ? Theme.statusActive : Theme.statusStandby
    }

    Process {
        id: powerPoll
        command: ["bash", "-c", "LC_ALL=C bluetoothctl show 2>/dev/null | awk '/Powered:/{print $2}'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var t = text.trim().toLowerCase()
                root._present = t !== ""
                root._powered = t === "yes"
            }
        }
    }
    Process {
        id: connPoll
        command: [
            "bash", "-c",
            "mac=$(LC_ALL=C bluetoothctl devices Connected 2>/dev/null | awk '{print $2; exit}'); " +
            "if [ -z \"$mac\" ]; then echo 'NONE'; exit; fi; " +
            "name=$(LC_ALL=C bluetoothctl info \"$mac\" 2>/dev/null | awk -F': ' '/Name:/{print $2; exit}'); " +
            "batt=$(LC_ALL=C bluetoothctl info \"$mac\" 2>/dev/null | awk -F'[()]' '/Battery Percentage/{print $2}'); " +
            "echo \"$name|${batt:--1}\""
        ]
        running: false
        stdout: SplitParser {
            onRead: function(l) {
                var t = l.trim()
                if (t === "" || t === "NONE") {
                    root._connected = false
                    root._deviceName = ""
                    root._battery = -1
                    return
                }
                var sep = t.lastIndexOf("|")
                root._deviceName = sep >= 0 ? t.substring(0, sep) : t
                var b = sep >= 0 ? parseInt(t.substring(sep + 1)) : -1
                root._battery = isNaN(b) ? -1 : b
                root._connected = true
            }
        }
    }
    Timer {
        interval: 6000; running: true; repeat: true
        onTriggered: {
            powerPoll.running = false; powerPoll.running = true
            connPoll.running  = false; connPoll.running  = true
        }
    }
    Component.onCompleted: { powerPoll.running = true; connPoll.running = true }

    HoverHandler { id: hov }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: pctWrapper.show ? 3 : 0

        Text {
            text: root.icon
            color: root.iconColor
            font.family: Theme.iconFont
            font.pixelSize: Theme.trayIconBluetooth
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        Item {
            id: pctWrapper
            property bool show: root._connected && root._battery >= 0 && root.showPercentage
            implicitWidth: show ? pctText.implicitWidth + 2 : 0
            implicitHeight: pctText.implicitHeight
            clip: true
            anchors.verticalCenter: parent.verticalCenter
            Behavior on implicitWidth { NumberAnimation { duration: Theme.durationBase; easing.type: Easing.InOutCubic } }

            Text {
                font.family: Theme.fontText
                id: pctText
                text: root._battery + "%"
                color: hov.hovered ? Theme.accent : Theme.text
                font.pixelSize: 12
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: 120 } }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            var next = !Popups.bluetoothOpen
            Popups.closeAll()
            Popups.bluetoothOpen = next
        }
    }
}
