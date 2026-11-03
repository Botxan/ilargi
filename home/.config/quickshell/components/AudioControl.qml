import QtQuick
import Quickshell.Services.Pipewire
import "../theme"
import "../state"

Item {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    property string page: Popups.audioPage
    Connections {
        target: Popups
        function onAudioPageChanged() { root.page = Popups.audioPage }
    }
    function reset() { Popups.audioPage = "output" }

    readonly property var activeNode: page === "output" ? sink : source
    readonly property var activeNodes: page === "output" ? sinkNodes : sourceNodes

    readonly property real maxVolume: 1.5

    function step(delta) {
        var n = root.activeNode
        if (!n || !n.ready) return
        n.audio.volume = Math.max(0, Math.min(root.maxVolume, n.audio.volume + delta))
    }
    function toggleMute() {
        var n = root.activeNode
        if (n && n.audio) n.audio.muted = !n.audio.muted
    }
    function switchSide() {
        Popups.audioPage = root.page === "output" ? "input" : "output"
    }

    Keys.onUpPressed: root.step(0.05)
    Keys.onDownPressed: root.step(-0.05)
    Keys.onLeftPressed: root.switchSide()
    Keys.onRightPressed: root.switchSide()
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_M) { root.toggleMute(); event.accepted = true }
    }

    PwObjectTracker { objects: Pipewire.nodes.values }

    readonly property var sinkNodes: {
        var result = []
        var nodes = Pipewire.nodes.values
        for (var i = 0; i < nodes.length; i++) {
            var n = nodes[i]
            if (n.audio !== null && !n.isStream && n.isSink) result.push(n)
        }
        result.sort(function(a, b) { return root.deviceName(a).localeCompare(root.deviceName(b)) })
        return result
    }
    readonly property var sourceNodes: {
        var result = []
        var nodes = Pipewire.nodes.values
        for (var i = 0; i < nodes.length; i++) {
            var n = nodes[i]
            if (n.audio !== null && !n.isStream && !n.isSink) result.push(n)
        }
        result.sort(function(a, b) { return root.deviceName(a).localeCompare(root.deviceName(b)) })
        return result
    }

    function deviceName(node) {
        if (!node) return "Unknown"
        return node.description || node.nickname || node.name || "Unknown"
    }

    readonly property string icon: {
        var n = root.activeNode
        if (root.page === "output") {
            if (!n || !n.ready) return "󰕾"
            if (n.audio.muted) return "󰖁"
            if (n.audio.volume > 0.6) return "󰕾"
            if (n.audio.volume > 0.2) return "󰖀"
            return "󰕿"
        }
        if (!n || !n.audio) return "󰍬"
        return n.audio.muted ? "󰍭" : "󰍬"
    }
    readonly property int pct: (activeNode && activeNode.ready) ? Math.round(activeNode.audio.volume * 100) : 0
    readonly property bool muted: (activeNode && activeNode.audio) ? activeNode.audio.muted : false
    readonly property bool active: (activeNode && activeNode.ready) || false

    Column {
        id: topBlock
        anchors { top: parent.top; left: parent.left; right: parent.right }
        spacing: 16

        TabSwitcher {
            orientation: "horizontal"
            width: parent.width
            model: [
                { key: "input",  icon: "󰍬", label: "Input" },
                { key: "output", icon: "󰕾", label: "Output" }
            ]
            currentPage: root.page
            onPageChanged: function(key) { Popups.audioPage = key }
        }

        Column {
            width: parent.width
            spacing: 6

            Item {
                width: parent.width
                height: 26

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    Text {
                        text: root.icon
                        font.family: Theme.iconFont
                        font.pixelSize: 17
                        color: root.muted ? Qt.rgba(1, 1, 1, 0.35) : Theme.accent
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    Text {
                        font.family: Theme.fontText
                        text: root.active ? root.pct + "%" : "--%"
                        color: root.muted ? Qt.rgba(1, 1, 1, 0.35) : Theme.text
                        font.pixelSize: 20
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26; height: 26; radius: 8
                    color: root.muted
                        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.20)
                        : (muteHov.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                    border.color: root.muted ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.4) : Qt.rgba(1, 1, 1, 0.12)
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Text {
                        anchors.centerIn: parent
                        text: root.muted ? "󰖁" : "󰕾"
                        font.family: Theme.iconFont
                        font.pixelSize: 13
                        color: root.muted ? Theme.accent : Qt.rgba(1, 1, 1, 0.55)
                    }
                    HoverHandler { id: muteHov; cursorShape: Qt.PointingHandCursor }
                    MouseArea { anchors.fill: parent; onClicked: root.toggleMute() }
                }
            }

            VolumeBar {
                width: parent.width
                value: root.active ? root.activeNode.audio.volume : 0
                maxValue: root.maxVolume
                muted: root.muted
                onChanged: function(v) { if (root.active) root.activeNode.audio.volume = v }
            }
        }

        Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.07) }

        SectionLabel { text: root.page === "output" ? "Output Devices" : "Input Devices" }
    }

    Flickable {
        anchors {
            top: topBlock.bottom
            topMargin: 6
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        clip: true
        contentWidth: width
        contentHeight: deviceCol.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: deviceCol
            width: parent.width
            spacing: 2

            Repeater {
                model: root.activeNodes
                delegate: DeviceRow {
                    required property var modelData
                    width: parent.width
                    label: root.deviceName(modelData)
                    isDefault: (root.activeNode && root.activeNode.ready && modelData.name === root.activeNode.name) || false
                    onClicked: {
                        if (root.page === "output") Pipewire.preferredDefaultAudioSink = modelData
                        else Pipewire.preferredDefaultAudioSource = modelData
                    }
                }
            }
            Text {
                font.family: Theme.fontText
                visible: root.activeNodes.length === 0
                text: root.page === "output" ? "No output devices" : "No input devices"
                color: Qt.rgba(1, 1, 1, 0.2)
                font.pixelSize: 11
                leftPadding: 4
            }
        }
    }

    component VolumeBar: Item {
        id: bar
        property real value: 0
        property real maxValue: 1.0
        property bool muted: false
        signal changed(real v)

        implicitHeight: 14

        readonly property real frac: maxValue > 0 ? Math.min(1, value / maxValue) : 0
        readonly property real unityFrac: maxValue > 0 ? Math.min(1, 1.0 / maxValue) : 1
        readonly property bool boosted: value > 1.0

        property real _pulse: 0
        onValueChanged: pulseAnim.restart()
        SequentialAnimation {
            id: pulseAnim
            NumberAnimation { target: bar; property: "_pulse"; to: 1;   duration: 60;  easing.type: Easing.OutQuad }
            NumberAnimation { target: bar; property: "_pulse"; to: 0;   duration: 280; easing.type: Easing.OutQuad }
        }

        Rectangle {
            id: track
            anchors.fill: parent
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.08)

            Rectangle {
                id: fill
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                width: Math.max(height, track.width * bar.frac)
                radius: height / 2
                color: bar.muted
                    ? Qt.rgba(1, 1, 1, 0.22)
                    : (bar.boosted ? Qt.rgba(1, 0.67, 0.25, 1) : Theme.accent)
                Behavior on width { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 140 } }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "white"
                    opacity: bar._pulse * 0.30
                }
            }

            Rectangle {
                visible: bar.maxValue > 1.0
                x: track.width * bar.unityFrac - width / 2
                width: 2
                height: parent.height
                color: Qt.rgba(0, 0, 0, 0.35)
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            function calc(mx) { return Math.max(0, Math.min(bar.maxValue, (mx / width) * bar.maxValue)) }
            onPressed: bar.changed(calc(mouseX))
            onPositionChanged: if (pressed) bar.changed(calc(mouseX))
        }
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: function(event) {
                var step = 0.05
                var delta = event.angleDelta.y > 0 ? step : -step
                bar.changed(Math.max(0, Math.min(bar.maxValue, bar.value + delta)))
            }
        }
    }

    component SectionLabel: Text {
        color: Qt.rgba(1, 1, 1, 0.35)
        font.pixelSize: 10
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 0.8
    }

    component DeviceRow: Item {
        id: row
        implicitHeight: 26

        property string label: ""
        property bool isDefault: false
        signal clicked()

        Rectangle {
            anchors.fill: parent
            radius: Theme.cornerRadius - 4
            color: row.isDefault
                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12)
                : (rowHov.hovered ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        Rectangle {
            id: dot
            width: 6; height: 6; radius: 3
            anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
            color: row.isDefault ? Theme.accent : Qt.rgba(1, 1, 1, 0.2)
            Behavior on color { ColorAnimation { duration: 150 } }
        }
        Text {
            font.family: Theme.fontText
            text: row.label
            color: row.isDefault ? Theme.text : Qt.rgba(1, 1, 1, 0.5)
            font.pixelSize: 11
            elide: Text.ElideMiddle
            anchors { left: dot.right; leftMargin: 6; right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        HoverHandler { id: rowHov; cursorShape: Qt.PointingHandCursor }
        MouseArea { anchors.fill: parent; onClicked: row.clicked() }
    }
}
