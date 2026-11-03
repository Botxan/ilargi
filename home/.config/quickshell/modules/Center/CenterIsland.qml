import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../../theme"
import "../../state"
import "../../services"

Item {
    id: root

    readonly property color ink: Theme.groundText
    readonly property color light: Theme.accent
    readonly property int itemH: Theme.notchHeight - Theme.borderWidth
    readonly property int stride: itemH + 12

    readonly property var activeToplevel: {
        var list = ToplevelManager.toplevels.values
        for (var i = 0; i < list.length; i++) if (list[i].activated) return list[i]
        return null
    }
    function prettyApp(t) {
        if (!t) return "Desktop"
        var id = t.appId || ""
        var entry = id ? DesktopEntries.heuristicLookup(id) : null
        if (entry && entry.name) return entry.name
        if (id === "") return t.title || "Desktop"
        id = id.split(".").pop()
        return id.charAt(0).toUpperCase() + id.slice(1)
    }
    readonly property string appName: prettyApp(activeToplevel)

    property var items: ["title"]
    property int index: 0
    function rebuild(jumpTo) {
        var cur = items[index] || "title"
        var list = ["title"]
        if (MediaService.playing) list.push("music")
        if (TimerService.totalSeconds > 0) list.push("timer")
        if (!StopwatchService.idle) list.push("stopwatch")
        if (RecorderService.recording) list.push("record")
        items = list
        var i = list.indexOf(cur)
        if (jumpTo && list.indexOf(jumpTo) >= 0 && (jumpTo === "record" || cur === "title")) i = list.indexOf(jumpTo)
        index = Math.max(0, i)
    }
    Component.onCompleted: rebuild(null)
    Connections { target: MediaService; function onPlayingChanged() { root.rebuild(MediaService.playing ? "music" : null) } }
    Connections { target: TimerService; function onTotalSecondsChanged() { root.rebuild(TimerService.totalSeconds > 0 ? "timer" : null) } }
    Connections { target: StopwatchService; function onIdleChanged() { root.rebuild(!StopwatchService.idle ? "stopwatch" : null) } }
    Connections { target: RecorderService; function onRecordingChanged() { root.rebuild(RecorderService.recording ? "record" : null) } }

    Binding { target: CavaService; property: "barWanted"; value: root.items[root.index] === "music" }

    property bool wheelBusy: false
    Timer { id: wheelCool; interval: 250; onTriggered: root.wheelBusy = false }
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: function (e) {
            if (root.wheelBusy) return
            root.wheelBusy = true; wheelCool.restart()
            root.index = e.angleDelta.y < 0 ? Math.min(root.items.length - 1, root.index + 1)
                                             : Math.max(0, root.index - 1)
        }
    }
    HoverHandler { cursorShape: Qt.PointingHandCursor }
    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: { var next = !Popups.sessionOpen; Popups.closeAll(); Popups.sessionOpen = next }
    }
    TapHandler {
        onTapped: {
            var next = !Popups.apertureOpen
            Popups.closeAll()
            Popups.apertureOpen = next
        }
    }

    Item {
        anchors.fill: parent
        clip: true

        Column {
            id: strip
            width: parent.width
            spacing: root.stride - root.itemH
            y: -root.index * root.stride
            Behavior on y { NumberAnimation { duration: 250; easing.type: Theme.animCurve } }

            Repeater {
                model: root.items
                delegate: Item {
                    required property string modelData
                    width: strip.width
                    height: root.itemH

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 16; anchors.rightMargin: 16
                        visible: parent.modelData === "title"
                        text: root.appName
                        color: root.ink
                        font.family: Theme.fontText; font.pixelSize: 13; font.weight: Font.Medium
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }

                    Item {
                        anchors.fill: parent
                        anchors.leftMargin: 10; anchors.rightMargin: 12
                        visible: parent.modelData === "music"
                        readonly property int artSize: 20

                        Item {
                            id: art
                            width: parent.artSize; height: parent.artSize
                            anchors.verticalCenter: parent.verticalCenter
                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                visible: MediaService.artUrl === ""
                                color: Theme.withAlpha(root.light, 0.18)
                                border.width: 1; border.color: Theme.withAlpha(root.light, 0.38)
                                Text { anchors.centerIn: parent; text: "♪"; color: root.light; font.pixelSize: 9 }
                            }
                            Rectangle { id: artMask; anchors.fill: parent; radius: width / 2; visible: false; layer.enabled: true }
                            Image {
                                anchors.fill: parent
                                source: MediaService.artUrl
                                visible: MediaService.artUrl !== ""
                                fillMode: Image.PreserveAspectCrop
                                sourceSize.width: 64; sourceSize.height: 64
                                smooth: true; cache: true; asynchronous: true
                                layer.enabled: true
                                layer.effect: MultiEffect { maskEnabled: true; maskSource: artMask; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }
                            }
                        }

                        Item {
                            id: bars
                            anchors { left: art.right; leftMargin: 8; right: parent.right; rightMargin: 8; top: parent.top; bottom: parent.bottom }
                            readonly property int n: CavaService.barCount
                            readonly property real barW: 4
                            readonly property real gap: Math.max(1, (width - barW * n) / Math.max(1, n - 1))
                            Row {
                                anchors.fill: parent
                                spacing: bars.gap
                                Repeater {
                                    model: bars.n
                                    delegate: Item {
                                        required property int index
                                        width: bars.barW; height: bars.height
                                        readonly property real amp: {
                                            var b = CavaService.bars
                                            return index < b.length ? Math.min(1, b[index]) : 0
                                        }
                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: bars.barW
                                            height: Math.max(2, parent.amp * (bars.height - 8))
                                            radius: width / 2
                                            color: Theme.withAlpha(root.light, 0.30 + parent.amp * 0.70)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 10
                        visible: parent.modelData === "timer"
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "󰔟"
                               color: TimerService.finished ? Theme.statusAlert : root.light
                               font.family: Theme.iconFont; font.pixelSize: 15 }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: TimerService.display()
                               color: root.ink; font.family: Theme.fontMono; font.pixelSize: 14; font.weight: Font.Bold }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: TimerService.label
                               visible: text !== ""; color: Theme.withAlpha(root.ink, 0.5)
                               font.family: Theme.fontText; font.pixelSize: 12 }
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 10
                        visible: parent.modelData === "stopwatch"
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "󰔛"; color: root.light
                               font.family: Theme.iconFont; font.pixelSize: 15 }
                        Text { anchors.verticalCenter: parent.verticalCenter
                               text: StopwatchService.format(StopwatchService.elapsed, false)
                               color: StopwatchService.running ? root.ink : Theme.withAlpha(root.ink, 0.5)
                               font.family: Theme.fontMono; font.pixelSize: 14; font.weight: Font.Bold }
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 9
                        visible: parent.modelData === "record"
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 8; height: 8; radius: 4
                            color: Theme.statusLive
                            SequentialAnimation on opacity {
                                running: RecorderService.recording && !Theme.reducedMotion
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.3; duration: 700; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
                            }
                        }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: RecorderService.display()
                               color: root.ink; font.family: Theme.fontMono; font.pixelSize: 14; font.weight: Font.Bold }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: RecorderService.scope
                               color: Theme.withAlpha(root.ink, 0.5); font.family: Theme.fontText; font.pixelSize: 12 }
                    }
                }
            }
        }
    }

    Column {
        anchors { right: parent.right; rightMargin: 5; verticalCenter: parent.verticalCenter }
        spacing: 3
        visible: root.items.length > 1
        Repeater {
            model: root.items.length
            delegate: Rectangle {
                required property int index
                width: 3; height: index === root.index ? 8 : 3; radius: 1.5
                color: index === root.index ? root.light : Theme.withAlpha(root.ink, 0.25)
                Behavior on height { NumberAnimation { duration: Theme.animColor; easing.type: Theme.animCurve } }
            }
        }
    }
}
