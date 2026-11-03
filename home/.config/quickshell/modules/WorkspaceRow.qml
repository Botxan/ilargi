import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import "../theme"
import "../state"

Item {
    id: workspaceRow
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    readonly property var metalGlyphs: {
        1: "",
        2: "",
        3: "",
        4: "",
        5: "",
        6: "",
        7: "",
        8: ""
    }

    RowLayout {
        id: row
        spacing: Theme.wsSpacing

        Repeater {
            model: 8

            delegate: Item {
                id: wsItem
                required property int index
                readonly property int wsId: index + 1
                readonly property var metal: Theme.metalFor(wsId)

                readonly property var wsData: Hyprland.workspaces.values.find(w => w.id === wsId)
                readonly property bool isFocused: wsData ? wsData.focused : false
                readonly property bool isOccupied: wsData ? (wsData.toplevels.values.length > 0) : false

                property real busyPulse: Theme.wsBusyOpacityMin
                property real flicker: 1.0
                property real glowFlicker: 0.85
                property real ignitionBoost: 0
                property real igniteFlareBoost: 0

                property bool hovered: false
                property real hoverGlow: hovered ? 1 : 0
                Behavior on hoverGlow { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }

                width: Theme.wsIconSize
                height: Theme.wsIconSize

                Canvas {
                    id: flame
                    anchors.centerIn: parent
                    width: 40
                    height: 40
                    visible: wsItem.isFocused

                    readonly property real radius: (10 + wsItem.igniteFlareBoost) * wsItem.flicker

                    onRadiusChanged: requestPaint()
                    onVisibleChanged: requestPaint()
                    Connections {
                        target: wsItem
                        function onGlowFlickerChanged() { flame.requestPaint() }
                    }

                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        if (!visible) return;
                        const cx = width / 2, cy = height / 2;
                        const r = Math.max(radius, 2);
                        const g = Qt.color(metal.glow);
                        const rgb = Math.round(g.r * 255) + "," + Math.round(g.g * 255) + "," + Math.round(g.b * 255);
                        const a = wsItem.glowFlicker;
                        const grad = ctx.createRadialGradient(cx, cy, 0, cx, cy, r);
                        grad.addColorStop(0, "rgba(" + rgb + "," + (0.42 * a) + ")");
                        grad.addColorStop(0.35, "rgba(" + rgb + "," + (0.30 * a) + ")");
                        grad.addColorStop(1, "rgba(" + rgb + ",0)");
                        ctx.fillStyle = grad;
                        ctx.beginPath();
                        ctx.arc(cx, cy, r, 0, Math.PI * 2);
                        ctx.fill();
                    }
                }

                Canvas {
                    id: softGlow
                    anchors.centerIn: parent
                    width: 32
                    height: 32
                    visible: (wsItem.isOccupied || wsItem.hoverGlow > 0) && !wsItem.isFocused

                    readonly property real radius: 6 + wsItem.busyPulse * 2.5 + wsItem.hoverGlow * 1.6

                    onRadiusChanged: requestPaint()
                    onVisibleChanged: requestPaint()

                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        if (!visible) return;
                        const cx = width / 2, cy = height / 2;
                        const r = Math.max(radius, 2);
                        const g = Qt.color(metal.glow);
                        const rgb = Math.round(g.r * 255) + "," + Math.round(g.g * 255) + "," + Math.round(g.b * 255);
                        const busyAlpha = wsItem.isOccupied ? wsItem.busyPulse * 0.5 : 0;
                        const a = Math.min(busyAlpha + wsItem.hoverGlow * 0.3, 0.6) * 0.55;
                        const grad = ctx.createRadialGradient(cx, cy, 0, cx, cy, r);
                        grad.addColorStop(0, "rgba(" + rgb + "," + a + ")");
                        grad.addColorStop(1, "rgba(" + rgb + ",0)");
                        ctx.fillStyle = grad;
                        ctx.beginPath();
                        ctx.arc(cx, cy, r, 0, Math.PI * 2);
                        ctx.fill();
                    }
                }

                SequentialAnimation {
                    running: wsItem.isOccupied && !wsItem.isFocused
                    loops: Animation.Infinite
                    PauseAnimation { duration: wsItem.wsId * 140 }
                    NumberAnimation { target: wsItem; property: "busyPulse"; to: Theme.wsBusyOpacityMax; duration: Theme.busyBreatheHalfDuration; easing.type: Easing.InOutSine }
                    NumberAnimation { target: wsItem; property: "busyPulse"; to: Theme.wsBusyOpacityMin; duration: Theme.busyBreatheHalfDuration; easing.type: Easing.InOutSine }
                }

                SequentialAnimation {
                    running: wsItem.isFocused
                    loops: Animation.Infinite
                    NumberAnimation { target: wsItem; property: "flicker"; to: 1.08; duration: 180; easing.type: Easing.InOutQuad }
                    NumberAnimation { target: wsItem; property: "flicker"; to: 0.97; duration: 130; easing.type: Easing.InOutQuad }
                    NumberAnimation { target: wsItem; property: "flicker"; to: 1.05; duration: 220; easing.type: Easing.InOutQuad }
                    NumberAnimation { target: wsItem; property: "flicker"; to: 1.0; duration: 160; easing.type: Easing.InOutQuad }
                }
                SequentialAnimation {
                    running: wsItem.isFocused
                    loops: Animation.Infinite
                    PauseAnimation { duration: 90 }
                    NumberAnimation { target: wsItem; property: "glowFlicker"; to: 1.0; duration: 210; easing.type: Easing.InOutQuad }
                    NumberAnimation { target: wsItem; property: "glowFlicker"; to: 0.72; duration: 170; easing.type: Easing.InOutQuad }
                    NumberAnimation { target: wsItem; property: "glowFlicker"; to: 0.9; duration: 240; easing.type: Easing.InOutQuad }
                    NumberAnimation { target: wsItem; property: "glowFlicker"; to: 0.78; duration: 150; easing.type: Easing.InOutQuad }
                }

                Canvas {
                    id: embers
                    anchors.centerIn: parent
                    width: 36
                    height: 36
                    visible: wsItem.isFocused
                    readonly property int emberCount: 4
                    property real t: 0

                    NumberAnimation on t {
                        running: embers.visible
                        loops: Animation.Infinite
                        from: 0; to: 1; duration: 1400
                    }
                    onTChanged: requestPaint()

                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        if (!visible) return;
                        const cx = width / 2, cy = height / 2 - 3;
                        const g = Qt.color(metal.glow);
                        const rgb = Math.round(g.r * 255) + "," + Math.round(g.g * 255) + "," + Math.round(g.b * 255);
                        for (let i = 0; i < emberCount; i++) {
                            const phase = (t + i / emberCount) % 1;
                            const x = cx + Math.sin((phase + i) * 6.283) * 4;
                            const y = cy - phase * 12;
                            const a = (1 - phase) * 0.45;
                            ctx.beginPath();
                            ctx.arc(x, y, 1.1, 0, Math.PI * 2);
                            ctx.fillStyle = "rgba(" + rgb + "," + a + ")";
                            ctx.fill();
                        }
                    }
                }

                Text {
                    id: icon
                    anchors.centerIn: parent
                    text: workspaceRow.metalGlyphs[wsItem.wsId] || ""
                    font.family: "allomancy"
                    font.pixelSize: Theme.wsFontSize
                    color: (wsItem.isFocused || wsItem.isOccupied) ? metal.color : Theme.text

                    opacity: wsItem.isFocused
                        ? 1.0
                        : Math.min((wsItem.isOccupied ? wsItem.busyPulse : Theme.wsEmptyOpacity) + wsItem.hoverGlow * 0.25, 0.95)
                    scale: (wsItem.isFocused ? Theme.focusScale * wsItem.flicker : 1.0) + wsItem.ignitionBoost + wsItem.hoverGlow * 0.06

                    Behavior on opacity { NumberAnimation { duration: Theme.durationBase } }
                }

                SequentialAnimation {
                    id: ignition
                    NumberAnimation { target: wsItem; property: "ignitionBoost"; to: 0.35; duration: 130; easing.type: Easing.OutQuad }
                    NumberAnimation { target: wsItem; property: "ignitionBoost"; to: 0; duration: 260; easing.type: Easing.OutQuad }
                }
                SequentialAnimation {
                    id: ignitionFlare
                    NumberAnimation { target: wsItem; property: "igniteFlareBoost"; to: 6; duration: 150; easing.type: Easing.OutQuad }
                    NumberAnimation { target: wsItem; property: "igniteFlareBoost"; to: 0; duration: 350; easing.type: Easing.OutQuad }
                }

                Connections {
                    target: wsItem
                    function onIsFocusedChanged() {
                        if (!wsItem.isFocused) return;
                        ignition.start();
                        ignitionFlare.start();
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: wsItem.hovered = true
                    onExited: wsItem.hovered = false
                    onClicked: {
                        const id = wsItem.wsId
                        Popups.closeThen(() => Hyprland.dispatch("hl.dsp.focus({ workspace = " + id + " })"))
                    }
                }
            }
        }
    }
}
