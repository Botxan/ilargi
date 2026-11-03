import QtQuick
import Quickshell.Io
import "../theme"
import "../state"

Item {
    id: root

    property var    _connections:  []
    property var    _buf:          []
    property bool   _loading:      false
    property bool   _killSwitch:   false
    property string _activeName:   ""

    readonly property alias listContentHeight: conCol.height
    readonly property int   headerBlock: _killSwitch ? 78 : 49

    Process {
        id: disableAutoconnectProc
        command: ["bash", "-c",
            "nmcli -t -f NAME,TYPE con show" +
            " | awk -F: '$2==\"wireguard\"{print $1}'" +
            " | while IFS= read -r name; do" +
            "     nmcli con modify \"$name\" connection.autoconnect no 2>/dev/null;" +
            "   done"]
        running: false
    }

    Process {
        id: wgProc
        running: false
        command: ["sh", "-c",
            "nmcli -t -f NAME,TYPE,ACTIVE con show" +
            " | awk -F: '$2==\"wireguard\"{print $1 \"|\" ($3==\"yes\" ? \"active\" : \"inactive\")}'"]
        stdout: SplitParser {
            onRead: function(data) {
                var line = data.trim()
                if (!line) return
                var sep = line.lastIndexOf("|")
                if (sep < 0) return
                root._buf = root._buf.concat([{
                    name:   line.substring(0, sep),
                    active: line.substring(sep + 1) === "active",
                    busy:   false
                }])
            }
        }
        onExited: function(code, status) {
            var buf = root._buf.slice()

            var connectingName    = connectProc.running    ? connectProc._name    : ""
            var disconnectingName = disconnectProc.running ? disconnectProc._name : ""

            buf.sort(function(a, b) { return a.name.localeCompare(b.name) })
            for (var j = 0; j < buf.length; j++) {
                if (buf[j].name === connectingName || buf[j].name === disconnectingName)
                    buf[j].busy = true
            }

            root._buf         = []
            root._connections = buf
            root._loading      = false

            var active = buf.filter(function(c) { return c.active })
            root._activeName = active.length > 0 ? active[0].name : ""
        }
    }

    Process {
        id: connectProc
        running: false
        command: []
        property string _name: ""

        stderr: StdioCollector { id: connectStderr }

        onExited: function(code, status) {
            if (code === 0) {
                var cname = connectProc._name
                var cons = root._connections.slice()
                for (var i = 0; i < cons.length; i++) {
                    var isTarget = cons[i].name === cname
                    cons[i] = { name: cons[i].name, active: isTarget, busy: false }
                }
                root._connections = cons
                root._activeName  = cname

                root._notify(
                    "VPN Connected",
                    "󰦝  " + cname + " is now active.\nYour traffic is encrypted.",
                    "normal"
                )

                if (root._killSwitch) root._armKillSwitch(cname)
            } else {
                var cons2 = root._connections.slice()
                for (var j = 0; j < cons2.length; j++)
                    cons2[j] = { name: cons2[j].name, active: cons2[j].active, busy: false }
                root._connections = cons2
                root._activeName  = ""

                root._notify(
                    "VPN Failed",
                    "Could not connect to " + connectProc._name + ".\n" + connectStderr.text.trim(),
                    "critical"
                )
            }
            root._refresh()
        }
    }

    Process {
        id: disconnectProc
        running: false
        command: []
        property string _name: ""

        onExited: function(code, status) {
            var dname = disconnectProc._name
            var cons = root._connections.slice()
            for (var i = 0; i < cons.length; i++)
                cons[i] = { name: cons[i].name, active: false, busy: false }
            root._connections = cons
            root._activeName  = ""

            root._notify(
                "VPN Disconnected",
                "󰦝  " + dname + " has been disconnected.",
                "low"
            )

            if (root._killSwitch) root._disarmKillSwitch(true)

            root._refresh()
        }
    }

    Process { id: getIfaceProc; running: false; command: []
        stdout: StdioCollector { id: getIfaceOut }
        onExited: function(code, status) {
            var iface = getIfaceOut.text.trim()
            if (iface === "") return
            killSwitchApplyProc.command = ["pkexec", Paths.bin + "/vpn-killswitch", "on", iface]
            killSwitchApplyProc.running = false
            killSwitchApplyProc.running = true
        }
    }
    Process { id: killSwitchApplyProc; running: false; command: [] }
    Process { id: killSwitchRemoveProc; running: false; command: [] }

    function _armKillSwitch(name) {
        getIfaceProc.command = ["bash", "-c", "nmcli -g GENERAL.DEVICES connection show \"" + name + "\" 2>/dev/null | head -1"]
        getIfaceProc.running = false
        getIfaceProc.running = true
    }
    function _disarmKillSwitch(alsoUntoggle) {
        killSwitchRemoveProc.command = ["pkexec", Paths.bin + "/vpn-killswitch", "off"]
        killSwitchRemoveProc.running = false
        killSwitchRemoveProc.running = true
        if (alsoUntoggle) root._killSwitch = false
    }
    function _toggleKillSwitch() {
        if (root._killSwitch) {
            root._killSwitch = false
            root._disarmKillSwitch(false)
        } else {
            root._killSwitch = true
            if (root._activeName !== "") root._armKillSwitch(root._activeName)
        }
    }

    Process { id: notifyProc; running: false; command: [] }

    Process {
        id: monitorProc
        running: Popups.vpnOpen
        command: ["nmcli", "monitor"]
        stdout: SplitParser { onRead: function(data) { monitorDebounce.restart() } }
    }
    Timer { id: monitorDebounce; interval: 600; repeat: false; onTriggered: root._refresh() }
    Timer { interval: 8000; repeat: true; running: Popups.vpnOpen; onTriggered: root._refresh() }

    function _refresh() {
        if (wgProc.running) return
        root._loading  = true
        root._buf      = []
        wgProc.running = false
        wgProc.running = true
    }

    function _notify(title, body, urgency) {
        notifyProc.command = ["notify-send", "--app-name=quickshell", "--urgency=" + urgency, "--icon=network-vpn", title, body]
        notifyProc.running = false
        notifyProc.running = true
    }

    function _connect(name) {
        if (connectProc.running || disconnectProc.running) return

        var activeNames = root._connections.filter(function(c) { return c.active }).map(function(c) { return c.name })
        var cons = root._connections.slice()
        for (var i = 0; i < cons.length; i++) {
            var isBusy = cons[i].name === name || activeNames.indexOf(cons[i].name) >= 0
            if (isBusy) cons[i] = { name: cons[i].name, active: cons[i].active, busy: true }
        }
        root._connections = cons
        connectProc._name = name

        var downCmd = "nmcli -g NAME,TYPE connection show --active" +
            " | awk -F: '$2==\"wireguard\" {print $1}'" +
            " | xargs -r -I {} nmcli connection down \"{}\""

        connectProc.command = ["bash", "-c", downCmd + "; nmcli con up \"" + name + "\" 2>&1"]
        connectProc.running = false
        connectProc.running = true
    }

    function _disconnect(name) {
        if (connectProc.running || disconnectProc.running) return

        var cons = root._connections.slice()
        for (var i = 0; i < cons.length; i++)
            if (cons[i].name === name) cons[i] = { name: cons[i].name, active: cons[i].active, busy: true }
        root._connections = cons

        disconnectProc._name   = name
        disconnectProc.command = ["bash", "-c", "nmcli con down \"" + name + "\" 2>/dev/null"]
        disconnectProc.running = false
        disconnectProc.running = true
    }

    Connections {
        target: Popups
        function onVpnOpenChanged() { if (Popups.vpnOpen) root._refresh() }
    }

    Component.onCompleted: {
        disableAutoconnectProc.running = true
        root._refresh()
    }

    Column {
        anchors.fill: parent; spacing: 0

        Item {
            width: parent.width; height: 40

            Text {
                font.family: Theme.fontText
                anchors { left: parent.left; leftMargin: 2; verticalCenter: parent.verticalCenter }
                text: "VPN"; font.pixelSize: 15; font.weight: Font.Bold; color: Theme.text
            }

            Row {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 8

                Rectangle {
                    height: 28; radius: 14
                    width: ksRow.implicitWidth + 18
                    color: root._killSwitch
                        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                        : ksH.hovered ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.04)
                    border.color: root._killSwitch
                        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.40)
                        : Qt.rgba(1,1,1,0.10)
                    border.width: 1
                    Behavior on color        { ColorAnimation { duration: 130 } }
                    Behavior on border.color { ColorAnimation { duration: 130 } }

                    Row {
                        id: ksRow; anchors.centerIn: parent; spacing: 6
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰒃"; font.family: Theme.iconFont; font.pixelSize: 13
                            color: root._killSwitch ? Theme.accent : Qt.rgba(1,1,1,0.40)
                            Behavior on color { ColorAnimation { duration: 130 } }
                        }
                        Text {
                            font.family: Theme.fontText
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Kill Switch"; font.pixelSize: 11; font.weight: Font.Medium
                            color: root._killSwitch ? Theme.accent : Qt.rgba(1,1,1,0.45)
                            Behavior on color { ColorAnimation { duration: 130 } }
                        }
                    }

                    HoverHandler { id: ksH; cursorShape: Qt.PointingHandCursor }
                    MouseArea { anchors.fill: parent; onClicked: root._toggleKillSwitch() }
                }

                Rectangle {
                    width: 32; height: 32; radius: 8
                    color: rfH.hovered ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15) : Qt.rgba(1,1,1,0.05)
                    border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.28)
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        id: rfIcon; anchors.centerIn: parent; text: "󰑐"; font.family: Theme.iconFont; font.pixelSize: 15
                        color: root._loading ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.4) : Theme.accent
                        Behavior on color { ColorAnimation { duration: 150 } }
                        RotationAnimator { target: rfIcon; from: 0; to: 360; duration: 900; loops: Animation.Infinite; running: root._loading; easing.type: Easing.Linear }
                    }
                    HoverHandler { id: rfH; cursorShape: Qt.PointingHandCursor }
                    MouseArea { anchors.fill: parent; onClicked: if (!root._loading) root._refresh() }
                }
            }
        }

        Text {
            font.family: Theme.fontText
            visible: root._killSwitch
            width: parent.width
            text: root._activeName !== ""
                ? "Blocking all non-VPN traffic while connected."
                : "Armed — will block everything if the tunnel drops unexpectedly."
            font.pixelSize: 10
            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.55)
            wrapMode: Text.WordWrap
            topPadding: 4
            bottomPadding: 4
        }

        Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.07) }
        Item      { width: parent.width; height: 8 }

        Flickable {
            width: parent.width; height: parent.height - (root._killSwitch ? 78 : 49)
            contentWidth: width; contentHeight: conCol.height
            clip: true; boundsBehavior: Flickable.StopAtBounds
            Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

            Column {
                id: conCol; width: parent.width; height: implicitHeight; spacing: 6

                Item {
                    width: parent.width; height: visible ? aLbl.implicitHeight + 4 : 0
                    visible: root._connections.some(function(c) { return c.active })
                    Text {
                        font.family: Theme.fontText
                        id: aLbl; text: "ACTIVE"
                        font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1.2
                        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.5)
                    }
                }

                Repeater {
                    model: root._connections.filter(function(c) { return c.active })
                    delegate: VPNRow {
                        required property var modelData
                        width: conCol.width - 2; x: 1; con: modelData
                    }
                }

                Item {
                    width: parent.width; height: 6
                    visible: root._connections.some(function(c) { return c.active })
                          && root._connections.some(function(c) { return !c.active })
                }

                Item {
                    width: parent.width; height: visible ? iLbl.implicitHeight + 4 : 0
                    visible: root._connections.some(function(c) { return !c.active })
                    Text {
                        font.family: Theme.fontText
                        id: iLbl; text: "AVAILABLE"
                        font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1.2
                        color: Qt.rgba(1,1,1,0.25)
                    }
                }

                Repeater {
                    model: root._connections.filter(function(c) { return !c.active })
                    delegate: VPNRow {
                        required property var modelData
                        width: conCol.width - 2; x: 1; con: modelData
                    }
                }

                Item {
                    width: parent.width; height: 180
                    visible: !root._loading && root._connections.length === 0
                    Column {
                        anchors.centerIn: parent; spacing: 12
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "󰦝"; font.family: Theme.iconFont; font.pixelSize: 36; color: Qt.rgba(1,1,1,0.08) }
                        Text { font.family: Theme.fontText; anchors.horizontalCenter: parent.horizontalCenter; text: "No WireGuard connections"; font.pixelSize: 13; color: Qt.rgba(1,1,1,0.2) }
                        Text { font.family: Theme.fontText; anchors.horizontalCenter: parent.horizontalCenter; text: "Import a config to get started:"; font.pixelSize: 10; color: Qt.rgba(1,1,1,0.14); horizontalAlignment: Text.AlignHCenter }
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: codeText.implicitWidth + 24; height: 26; radius: 6
                            color: Qt.rgba(1,1,1,0.05); border.color: Qt.rgba(1,1,1,0.10); border.width: 1
                            Text {
                                id: codeText; anchors.centerIn: parent
                                text: "nmcli con import type wireguard file <conf>"
                                font.pixelSize: 9; font.family: "JetBrainsMono Nerd Font"
                                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.5)
                            }
                        }
                    }
                }

                Item {
                    width: parent.width; height: 80
                    visible: root._loading && root._connections.length === 0
                    Column {
                        anchors.centerIn: parent; spacing: 8
                        Text {
                            font.family: Theme.fontText
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "○"; font.pixelSize: 20; color: Theme.accent
                            SequentialAnimation on opacity {
                                running: root._loading && root._connections.length === 0
                                loops:   Animation.Infinite
                                NumberAnimation { to: 0.15; duration: 550 }
                                NumberAnimation { to: 1.0;  duration: 550 }
                            }
                        }
                        Text { font.family: Theme.fontText; anchors.horizontalCenter: parent.horizontalCenter; text: "Loading…"; font.pixelSize: 11; color: Qt.rgba(1,1,1,0.25) }
                    }
                }
            }
        }
    }

    component VPNRow: Item {
        id: vRow
        required property var con
        height: 54

        property bool _wasActive: false
        onConChanged: {
            if (con.active && !_wasActive) pulseAnim.restart()
            _wasActive = con.active
        }

        Rectangle {
            id: card; anchors.fill: parent; radius: Theme.cornerRadius
            color: vRow.con.active
                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.08)
                : vHov.hovered ? Qt.rgba(1,1,1,0.04) : "transparent"
            border.color: vRow.con.active
                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
                : Qt.rgba(1,1,1,0.07)
            border.width: 1
            Behavior on color        { ColorAnimation { duration: 200 } }
            Behavior on border.color { ColorAnimation { duration: 200 } }

            SequentialAnimation {
                id: pulseAnim; running: false
                ColorAnimation { target: card; to: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.30); duration: 160 }
                ColorAnimation { target: card; to: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.08); duration: 500; easing.type: Easing.OutCubic }
            }
        }

        Row {
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            spacing: 12

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰦝"; font.family: Theme.iconFont; font.pixelSize: 20
                color: vRow.con.active
                    ? Theme.accent
                    : vRow.con.busy
                        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.5)
                        : Qt.rgba(1,1,1,0.28)
                Behavior on color { ColorAnimation { duration: 200 } }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter; spacing: 4

                Text {
                    font.family: Theme.fontText
                    text: vRow.con.name; font.pixelSize: 13
                    font.weight: vRow.con.active ? Font.Medium : Font.Normal
                    color: vRow.con.active ? Theme.text : Qt.rgba(1,1,1,0.65)
                    width: 160; elide: Text.ElideRight
                }
                Text {
                    font.family: Theme.fontText
                    font.pixelSize: 10
                    text: vRow.con.busy
                        ? (vRow.con.active ? "Disconnecting…" : "Connecting…")
                        : vRow.con.active ? "Connected" : "Disconnected"
                    color: vRow.con.busy
                        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.60)
                        : vRow.con.active ? Theme.accent : Qt.rgba(1,1,1,0.32)
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
            }
        }

        Item {
            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
            width: 28; height: 28

            Text {
                font.family: Theme.fontText
                anchors.centerIn: parent; visible: vRow.con.busy
                text: "○"; font.pixelSize: 16; color: Theme.accent
                SequentialAnimation on opacity {
                    running: vRow.con.busy; loops: Animation.Infinite
                    NumberAnimation { to: 0.15; duration: 450 }
                    NumberAnimation { to: 1.0;  duration: 450 }
                }
            }

            Rectangle {
                anchors.centerIn: parent; visible: !vRow.con.busy
                width: 10; height: 10; radius: 5
                color: vRow.con.active
                    ? Theme.accent
                    : vHov.hovered ? Qt.rgba(1,1,1,0.35) : Qt.rgba(1,1,1,0.18)
                Behavior on color { ColorAnimation { duration: 200 } }
            }
        }

        HoverHandler { id: vHov; cursorShape: Qt.PointingHandCursor }
        MouseArea {
            anchors.fill: parent
            enabled: !vRow.con.busy
            onClicked: vRow.con.active ? root._disconnect(vRow.con.name) : root._connect(vRow.con.name)
        }
    }
}
