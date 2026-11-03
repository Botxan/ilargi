import QtQuick
import Quickshell.Io
import "../../theme"
import "../../state"

Item {
    id: root

    anchors.verticalCenter: parent.verticalCenter
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    property int    _signal:       0
    property bool   _ethernet:     false
    property string _connectivity: "unknown"

    readonly property bool _limited: {
        var c = _connectivity
        return c === "limited" || c === "portal" || c === "none"
    }

    readonly property string _netIcon: {
        if (_ethernet) return _limited ? "󰅢" : "󰈀"
        if (_signal <= 0) return "󰤭"
        if (_signal > 75) return "󰤨"
        if (_signal > 50) return "󰤥"
        if (_signal > 25) return "󰤢"
        return "󰤟"
    }

    readonly property color _netColor: {
        if (hov.hovered) return Theme.accent
        if (!_ethernet && _signal <= 0) return Theme.statusIdle
        if (_connectivity === "none") return Theme.statusAlert
        if (_limited) return Theme.statusNotice
        return Theme.statusActive
    }

    Process {
        id: wifiPoll
        command: ["bash", "-c", "LC_ALL=C nmcli -t -f ACTIVE,SIGNAL dev wifi 2>/dev/null | awk -F: '$1==\"yes\"{print $2; f=1} END{if(!f) print 0}'"]
        running: false
        stdout: SplitParser { onRead: function(l) { var s = parseInt(l.trim()); root._signal = isNaN(s) ? 0 : s } }
    }
    Process {
        id: ethPoll
        command: ["bash", "-c", "LC_ALL=C nmcli -t -f TYPE,STATE dev 2>/dev/null | grep -c 'ethernet:connected'"]
        running: false
        stdout: SplitParser { onRead: function(l) { root._ethernet = parseInt(l.trim()) > 0 } }
    }
    Process {
        id: connPoll
        command: ["bash", "-c", "LC_ALL=C nmcli -t -f CONNECTIVITY general 2>/dev/null | head -1"]
        running: false
        stdout: SplitParser { onRead: function(l) { var v = l.trim().toLowerCase(); if (v !== "") root._connectivity = v } }
    }
    Timer {
        interval: 5000; running: true; repeat: true
        onTriggered: {
            wifiPoll.running = false; wifiPoll.running = true
            ethPoll.running  = false; ethPoll.running  = true
            connPoll.running = false; connPoll.running = true
        }
    }
    Component.onCompleted: { wifiPoll.running = true; ethPoll.running = true; connPoll.running = true }

    HoverHandler { id: hov }

    Row {
        id: row
        anchors.centerIn: parent

        Text {
            text: root._netIcon
            color: root._netColor
            font.family: Theme.iconFont
            font.pixelSize: root._ethernet ? Theme.trayIconNetworkWired : Theme.trayIconNetwork
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 200 } }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            Popups.closeAll()
            Popups.networkOpen = true
        }
    }
}
