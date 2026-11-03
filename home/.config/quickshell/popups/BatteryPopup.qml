import Quickshell
import Quickshell.Io
import QtQuick
import QtQml.Models
import Quickshell.Wayland
import Quickshell.Services.UPower
import "../shapes"
import "../theme"
import "../state"

Item {
    id: root
    readonly property bool open: Popups.batteryOpen
    readonly property int headShift: 18
    readonly property real panelW: popupWidth - fw
    readonly property real panelH: popupHeight - fh - Theme.borderWidth + headShift
    visible: open || hold.running
    onOpenChanged: if (!open) hold.restart()
    Timer { id: hold; interval: Theme.animTransition + 40 }

    readonly property int fw: Theme.borderWidth + Theme.cornerRadius
    readonly property int fh: Theme.borderWidth + Theme.cornerRadius
    readonly property int popupWidth:
        Math.max(260, BarGeometry.rightMinPanelWidth)
    readonly property int extRowHeight: 56
    readonly property int popupHeight: 232 + extMonitorsModel.count * extRowHeight

    IpcHandler {
        target: "battery-toggle"
        function toggle() {
            var next = !Popups.batteryOpen
            Popups.closeAll()
            Popups.batteryOpen = next
        }
    }

    Connections {
        target: Popups
        function onBatteryOpenChanged() {
            if (Popups.batteryOpen) { closeTimer.stop(); {}; root._refresh(); root._refreshExternal() }
            else closeTimer.restart()
        }
    }
    Timer {
        id: closeTimer
        interval: Theme.durationBase + 20
        onTriggered: { if (!Popups.batteryOpen) {} }
    }

    readonly property var bat: UPower.displayDevice
    readonly property int pct: bat.ready ? Math.round(bat.percentage * 100) : 0
    readonly property bool charging: bat.ready
        ? (bat.state === UPowerDeviceState.Charging ||
           bat.state === UPowerDeviceState.PendingCharge ||
           bat.state === UPowerDeviceState.FullyCharged)
        : false
    readonly property string stateLabel: {
        if (!bat.ready) return "Unknown"
        switch (bat.state) {
            case UPowerDeviceState.Charging:      return "Charging"
            case UPowerDeviceState.PendingCharge:  return "Charging (pending)"
            case UPowerDeviceState.FullyCharged:   return "Fully charged"
            case UPowerDeviceState.Discharging:    return "Discharging"
            case UPowerDeviceState.PendingDischarge: return "Discharging (pending)"
            default: return "Idle"
        }
    }
    function formatSeconds(s) {
        if (!s || s <= 0) return ""
        var h = Math.floor(s / 3600)
        var m = Math.round((s % 3600) / 60)
        return h > 0 ? (h + "h " + m + "m") : (m + "m")
    }
    readonly property string timeLabel: {
        if (charging && bat.timeToFull > 0) return formatSeconds(bat.timeToFull) + " until full"
        if (!charging && bat.timeToEmpty > 0) return formatSeconds(bat.timeToEmpty) + " remaining"
        return ""
    }
    readonly property string detailLabel: {
        var parts = []
        if (timeLabel !== "") parts.push(timeLabel)
        if (bat.ready && bat.healthSupported) parts.push("Health " + Math.round(bat.healthPercentage) + "%")
        return parts.join("  ·  ")
    }

    readonly property bool full: bat.ready ? bat.state === UPowerDeviceState.FullyCharged : false
    function staticIcon(p) {
        if (p > 90) return "󰁹"
        if (p > 80) return "󰂂"
        if (p > 70) return "󰂁"
        if (p > 60) return "󰂀"
        if (p > 50) return "󰁿"
        if (p > 40) return "󰁾"
        if (p > 30) return "󰁽"
        if (p > 20) return "󰁼"
        if (p > 10) return "󰁻"
        return "󰁺"
    }
    readonly property var chargeFrames: ["󰢜", "󰂆", "󰂇", "󰂈", "󰂉", "󰂊", "󰂋", "󰂅"]
    property int chargeFrame: 0
    Timer {
        interval: 650
        running: root.charging && !root.full && Popups.batteryOpen
        repeat: true
        onTriggered: root.chargeFrame = (root.chargeFrame + 1) % root.chargeFrames.length
    }
    readonly property string icon: {
        if (full) return "󰂄"
        if (charging) return chargeFrames[chargeFrame % chargeFrames.length]
        return staticIcon(pct)
    }
    readonly property color statusColor: {
        if (full || charging) return Theme.accent
        if (pct <= 5) return "#df5b61"
        if (pct <= 10) return "#de8f78"
        if (pct <= 20) return "#de8f78"
        if (pct <= 30) return "#de8f78"
        return Theme.text
    }

    property string _profile: "balanced"
    property bool   _profileBusy: false

    Process {
        id: profileGetProc
        command: ["powerprofilesctl", "get"]
        running: false
        stdout: StdioCollector { id: profileGetOut }
        onExited: { if (!profileSetProc.running) root._profile = profileGetOut.text.trim() }
    }
    Process {
        id: profileSetProc
        command: []
        running: false
        onExited: { root._profileBusy = false; profileGetProc.running = false; profileGetProc.running = true }
    }
    function _setProfile(name) {
        if (name === root._profile) return
        root._profile = name
        root._profileBusy = true
        profileSetProc.command = ["powerprofilesctl", "set", name]
        profileSetProc.running = false
        profileSetProc.running = true
    }

    property real _brightness: 100
    property bool _brightnessDragging: false

    Process {
        id: brightGetProc
        command: ["bash", "-c", "brightnessctl g; brightnessctl m"]
        running: false
        stdout: StdioCollector { id: brightGetOut }
        onExited: {
            if (root._brightnessDragging) return
            var lines = brightGetOut.text.trim().split("\n")
            if (lines.length < 2) return
            var cur = parseInt(lines[0]); var max = parseInt(lines[1])
            if (!isNaN(cur) && !isNaN(max) && max > 0) root._brightness = (cur / max) * 100
        }
    }
    Process { id: brightSetProc; command: []; running: false }
    function _setBrightness(pct) {
        root._brightness = pct
        brightSetProc.command = ["brightnessctl", "set", Math.round(pct) + "%"]
        brightSetProc.running = false
        brightSetProc.running = true
    }

    function _refresh() {
        profileGetProc.running = false; profileGetProc.running = true
        brightGetProc.running  = false; brightGetProc.running  = true
    }

    Timer { interval: 3000; repeat: true; running: Popups.batteryOpen; onTriggered: root._refresh() }
    Component.onCompleted: { root._refresh(); root._refreshExternal() }

    ListModel { id: extMonitorsModel }
    property string _draggingBus: ""

    Process {
        id: extDetectProc
        command: ["bash", "-c",
            "ddcutil detect --brief 2>/dev/null | awk '" +
            "/^Display [0-9]+/ { active=1; next } " +
            "/^Invalid display/ { active=0; next } " +
            "active && /I2C bus:/ { bus=$3; gsub(\"/dev/i2c-\",\"\",bus) } " +
            "active && /Monitor:/ { " +
            "  split($0, a, \"Monitor:\"); mon=a[2]; gsub(/^[ \\t]+/,\"\",mon); " +
            "  n=split(mon, parts, \":\"); " +
            "  name = (n>=2 && parts[2] != \"\") ? parts[2] : parts[1]; " +
            "  print bus \"|\" name " +
            "}' | while IFS='|' read -r bus name; do " +
            "  vcp=$(ddcutil getvcp 10 --bus \"$bus\" --brief 2>/dev/null); " +
            "  cur=$(echo \"$vcp\" | awk '{print $4}'); " +
            "  max=$(echo \"$vcp\" | awk '{print $5}'); " +
            "  echo \"$bus|$name|$cur|$max\"; " +
            "done"]
        running: false
        property var _buf: []
        stdout: SplitParser {
            onRead: function(line) {
                var t = line.trim()
                if (t === "") return
                var parts = t.split("|")
                if (parts.length < 4) return
                extDetectProc._buf.push({ bus: parts[0], name: parts[1], cur: parseInt(parts[2]), max: parseInt(parts[3]) })
            }
        }
        onExited: {
            var seenBus = {}
            for (var i = 0; i < extDetectProc._buf.length; i++) {
                var d = extDetectProc._buf[i]
                if (isNaN(d.cur) || isNaN(d.max) || d.max <= 0) continue
                seenBus[d.bus] = true

                var idx = -1
                for (var k = 0; k < extMonitorsModel.count; k++) {
                    if (extMonitorsModel.get(k).bus === d.bus) { idx = k; break }
                }
                if (idx === -1) {
                    extMonitorsModel.append({ bus: d.bus, name: d.name, brightness: (d.cur / d.max) * 100 })
                } else {
                    extMonitorsModel.setProperty(idx, "name", d.name)
                    if (d.bus !== root._draggingBus)
                        extMonitorsModel.setProperty(idx, "brightness", (d.cur / d.max) * 100)
                }
            }
            for (var m = extMonitorsModel.count - 1; m >= 0; m--) {
                if (!seenBus[extMonitorsModel.get(m).bus]) extMonitorsModel.remove(m)
            }
            extDetectProc._buf = []
        }
    }
    property var _pendingExtSet: null
    Process {
        id: extSetProc
        command: []
        running: false
        onExited: root._flushExtSet()
    }
    function _setExternalBrightness(bus, pct) {
        for (var i = 0; i < extMonitorsModel.count; i++) {
            if (extMonitorsModel.get(i).bus === bus) { extMonitorsModel.setProperty(i, "brightness", pct); break }
        }
        root._pendingExtSet = { bus: bus, pct: pct }
        root._flushExtSet()
    }
    function _flushExtSet() {
        if (extSetProc.running || root._pendingExtSet === null) return
        var req = root._pendingExtSet
        root._pendingExtSet = null
        extSetProc.command = ["ddcutil", "setvcp", "10", Math.round(req.pct).toString(), "--bus", req.bus, "--noverify"]
        extSetProc.running = false
        extSetProc.running = true
    }
    function _refreshExternal() {
        if (extDetectProc.running) return
        extDetectProc.running = false
        extDetectProc.running = true
    }
    Timer { interval: 8000; repeat: true; running: Popups.batteryOpen; onTriggered: root._refreshExternal() }

    Item {
        id: sizer
        x: -root.fw
        y: -Theme.borderWidth + root.headShift
        width: root.popupWidth
        height: root.popupHeight

        Column {
            anchors {
                fill: parent
                topMargin: root.fh + 14
                bottomMargin: root.fh + 14
                leftMargin: root.fw * 2 + 4 + Theme.borderWidth
                rightMargin: root.fw + 4
            }
            spacing: 16
            opacity: Popups.batteryOpen ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.durationBase * 0.5 } }

            Row {
                width: parent.width
                spacing: 10

                Text {
                    text: root.icon
                    font.family: Theme.iconFont
                    font.pixelSize: 30
                    color: root.statusColor
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 150 } }

                    SequentialAnimation on opacity {
                        running: root.pct <= 10 && !root.charging && Popups.batteryOpen
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.25; duration: 600; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0;  duration: 600; easing.type: Easing.InOutSine }
                    }
                }

                Column {
                    spacing: 2
                    anchors.verticalCenter: parent.verticalCenter

                    Row {
                        spacing: 8
                        Text { font.family: Theme.fontText; text: root.pct + "%"; color: root.statusColor; font.pixelSize: 26; font.bold: true; anchors.verticalCenter: parent.verticalCenter; Behavior on color { ColorAnimation { duration: 150 } } }
                        Text { font.family: Theme.fontText; text: root.stateLabel; color: Theme.accent; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Text {
                        font.family: Theme.fontText
                        visible: root.detailLabel !== ""
                        text: root.detailLabel
                        color: Qt.rgba(1, 1, 1, 0.35)
                        font.pixelSize: 10
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 6

                Text {
                    font.family: Theme.fontText
                    text: "POWER MODE  ·  " + (root._profile === "power-saver" ? "Power Saver" : root._profile.charAt(0).toUpperCase() + root._profile.slice(1))
                    font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1.1
                    color: Qt.rgba(1, 1, 1, 0.35)
                }
                Row {
                    id: modeRow
                    width: parent.width

                    Repeater {
                        model: [
                            { key: "power-saver",  icon: "󰌪" },
                            { key: "balanced",     icon: "󰗑" },
                            { key: "performance",  icon: "󰓅" }
                        ]
                        delegate: Item {
                            required property var modelData
                            width: modeRow.width / 3
                            height: 40

                            readonly property bool isActive: root._profile === modelData.key

                            Canvas {
                                id: glow
                                anchors.centerIn: parent
                                width: 40; height: 40
                                visible: isActive
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.reset()
                                    var cx = width / 2, cy = height / 2, r = width / 2
                                    var c = Qt.color(Theme.accent)
                                    var rgb = Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255)
                                    var grad = ctx.createRadialGradient(cx, cy, 0, cx, cy, r)
                                    grad.addColorStop(0, "rgba(" + rgb + ",0.45)")
                                    grad.addColorStop(1, "rgba(" + rgb + ",0)")
                                    ctx.fillStyle = grad
                                    ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.fill()
                                }
                                onVisibleChanged: requestPaint()
                                Connections { target: Theme; function onAccentChanged() { glow.requestPaint() } }
                            }

                            Rectangle {
                                anchors.centerIn: parent
                                width: 32; height: 32; radius: 16
                                color: isActive
                                    ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                                    : (pillHov.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                                Behavior on color { ColorAnimation { duration: 130 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.icon
                                    font.family: Theme.iconFont
                                    font.pixelSize: 14
                                    color: isActive ? Theme.accent : (pillHov.hovered ? Qt.rgba(1, 1, 1, 0.75) : Qt.rgba(1, 1, 1, 0.4))
                                    Behavior on color { ColorAnimation { duration: 130 } }
                                }
                            }

                            HoverHandler { id: pillHov; cursorShape: Qt.PointingHandCursor }
                            MouseArea { anchors.fill: parent; onClicked: root._setProfile(modelData.key) }
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 10

                Text {
                    font.family: Theme.fontText
                    text: "BRIGHTNESS"
                    font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1.1
                    color: Qt.rgba(1, 1, 1, 0.35)
                }

                Column {
                    width: parent.width
                    spacing: 4
                    Text { font.family: Theme.fontText; text: "Laptop"; font.pixelSize: 10; color: Qt.rgba(1, 1, 1, 0.3) }
                    Row {
                        width: parent.width
                        spacing: 10
                        Text {
                            text: "󰖨"
                            font.family: Theme.iconFont; font.pixelSize: 15
                            color: Qt.rgba(1, 1, 1, 0.5)
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        BrightnessBar {
                            width: parent.width - 15 - 10 - 10 - 30
                            anchors.verticalCenter: parent.verticalCenter
                            value: root._brightness
                            onPressedChanged: root._brightnessDragging = pressed
                            onChanged: function(v) { root._setBrightness(v) }
                        }
                        Text {
                            font.family: Theme.fontText
                            text: Math.round(root._brightness) + "%"
                            color: Qt.rgba(1, 1, 1, 0.5)
                            font.pixelSize: 11
                            width: 30
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                Repeater {
                    model: extMonitorsModel
                    delegate: Column {
                        id: extRow
                        required property string bus
                        required property string name
                        required property real brightness
                        width: parent.width
                        spacing: 4
                        Text { font.family: Theme.fontText; text: extRow.name; font.pixelSize: 10; color: Qt.rgba(1, 1, 1, 0.3); width: parent.width; elide: Text.ElideRight }
                        Row {
                            width: parent.width
                            spacing: 10
                            Text {
                                text: "󰍹"
                                font.family: Theme.iconFont; font.pixelSize: 15
                                color: Qt.rgba(1, 1, 1, 0.5)
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            BrightnessBar {
                                width: parent.width - 15 - 10 - 10 - 30
                                anchors.verticalCenter: parent.verticalCenter
                                value: extRow.brightness
                                onPressedChanged: root._draggingBus = pressed ? extRow.bus : ""
                                onChanged: function(v) { root._setExternalBrightness(extRow.bus, v) }
                            }
                            Text {
                                font.family: Theme.fontText
                                text: Math.round(extRow.brightness) + "%"
                                color: Qt.rgba(1, 1, 1, 0.5)
                                font.pixelSize: 11
                                width: 30
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }
            }
        }
    }

    component BrightnessBar: Item {
        id: bar
        property real value: 0
        property bool pressed: false
        signal changed(real v)

        implicitHeight: 10
        readonly property real frac: Math.max(0, Math.min(1, value / 100))

        Rectangle {
            id: track
            anchors.fill: parent
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.08)

            Rectangle {
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                width: Math.max(height, track.width * bar.frac)
                radius: height / 2
                color: Theme.accent
                Behavior on width { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            function calc(mx) { return Math.max(0, Math.min(100, (mx / width) * 100)) }
            onPressed: { bar.pressed = true; bar.changed(calc(mouseX)) }
            onReleased: bar.pressed = false
            onPositionChanged: if (pressed) bar.changed(calc(mouseX))
        }
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: function(event) {
                var step = 5
                var delta = event.angleDelta.y > 0 ? step : -step
                bar.changed(Math.max(0, Math.min(100, bar.value + delta)))
            }
        }
    }
}
