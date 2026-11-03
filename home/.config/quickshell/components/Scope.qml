import QtQuick
import "../theme"
import "../services"

Item {
    id: root

    property color tint: Theme.accent
    property int scrubIndex: -1
    readonly property bool scrubbing: scrubIndex >= 0

    readonly property int n: SysStatsService.historyLength
    readonly property real step: width / (n - 1)

    implicitHeight: 168
    clip: true

    readonly property var traces: [
        { key: "CPU", color: "#6791c9", hist: SysStatsService.histCpu, scale: 1 },
        { key: "GPU", color: "#6791c9", hist: SysStatsService.histGpu, scale: 1 },
        { key: "MEM", color: "#6791c9", hist: SysStatsService.histMem, scale: 1 },
        { key: "NET", color: "#6791c9", hist: SysStatsService.histNet, scale: SysStatsService.netScale }
    ]

    Rectangle {
        anchors.fill: parent
        radius: 12
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.shade(Theme.surfaceSunk, 0.10) }
            GradientStop { position: 1.0; color: Theme.surfaceSunk }
        }
        border.width: 1
        border.color: Theme.grooveDark
    }
    Rule {
        anchors { top: parent.top; topMargin: 1; left: parent.left; right: parent.right
                  leftMargin: 7; rightMargin: 7 }
        tint: Theme.grooveDark; fade: 0.14
    }
    Rule {
        anchors { bottom: parent.bottom; bottomMargin: 1; left: parent.left; right: parent.right
                  leftMargin: 7; rightMargin: 7 }
        tint: Theme.grooveLight; fade: 0.14
    }

    Canvas {
        id: cv
        width: root.width + root.step
        height: root.height
        x: 0

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const W = width, H = height, pad = 9
            const step = root.step
            const n = root.n

            ctx.lineWidth = 1
            ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.05)
            for (let g = 1; g < 4; g++) {
                const y = Math.round(H / 4 * g) + 0.5
                ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(W, y); ctx.stroke()
            }
            ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.038)
            for (let d = 1; d <= 5; d++) {
                const x = Math.round(W - d * 10 * step) + 0.5
                if (x < 0) break
                ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, H); ctx.stroke()
            }

            const ts = root.traces
            for (let t = ts.length - 1; t >= 0; t--) {
                const h = ts[t].hist
                if (!h || h.length < 2) continue
                const sc = ts[t].scale > 0 ? ts[t].scale : 1
                const x0 = W - (h.length - 1) * step

                ctx.beginPath()
                for (let i = 0; i < h.length; i++) {
                    const px = x0 + i * step
                    const py = H - pad - Math.max(0, Math.min(1, h[i] / sc)) * (H - pad * 2)
                    i === 0 ? ctx.moveTo(px, py) : ctx.lineTo(px, py)
                }
                const lastX = x0 + (h.length - 1) * step
                ctx.lineTo(lastX, H); ctx.lineTo(x0, H); ctx.closePath()
                const grd = ctx.createLinearGradient(0, 0, 0, H)
                grd.addColorStop(0, Theme.withAlpha(ts[t].color, 0.26))
                grd.addColorStop(1, Theme.withAlpha(ts[t].color, 0.0))
                ctx.fillStyle = grd
                ctx.fill()

                ctx.beginPath()
                for (let j = 0; j < h.length; j++) {
                    const qx = x0 + j * step
                    const qy = H - pad - Math.max(0, Math.min(1, h[j] / sc)) * (H - pad * 2)
                    j === 0 ? ctx.moveTo(qx, qy) : ctx.lineTo(qx, qy)
                }
                ctx.strokeStyle = ts[t].color
                ctx.lineWidth = 1.4
                ctx.stroke()
            }
        }

        NumberAnimation {
            id: slide
            target: cv; property: "x"
            from: 0; to: -root.step
            duration: 1000
            easing.type: Easing.Linear
        }

        Connections {
            target: SysStatsService
            function onSampled() {
                cv.requestPaint()
                if (!Theme.reducedMotion) slide.restart()
            }
        }
        Component.onCompleted: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    Rectangle {
        anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
        width: 1
        color: Theme.withAlpha(root.tint, 0.5)
        visible: !root.scrubbing
    }

    Rectangle {
        visible: root.scrubbing
        x: root.scrubIndex * root.step
        width: 1
        anchors { top: parent.top; bottom: parent.bottom }
        color: Qt.rgba(1, 1, 1, 0.45)
    }
    Repeater {
        model: root.scrubbing ? root.traces : []
        delegate: Rectangle {
            required property var modelData
            readonly property var h: modelData.hist
            readonly property int idx: Math.max(0, Math.min(h.length - 1,
                root.scrubIndex - (root.n - h.length)))
            visible: h.length > 0 && idx >= 0
            width: 6; height: 6; radius: 3
            color: modelData.color
            x: root.scrubIndex * root.step - 3
            y: {
                const pad = 9
                const sc = modelData.scale > 0 ? modelData.scale : 1
                return root.height - pad - Math.max(0, Math.min(1, h[idx] / sc)) * (root.height - pad * 2) - 3
            }
        }
    }

    HoverHandler {
        id: hov
        onPointChanged: {
            if (!hovered) return
            root.scrubIndex = Math.max(0, Math.min(root.n - 1,
                Math.round(point.position.x / root.step)))
        }
        onHoveredChanged: if (!hovered) root.scrubIndex = -1
    }

    Rectangle {
        anchors { top: parent.top; right: parent.right; topMargin: 8; rightMargin: 9 }
        width: 92
        height: legendCol.implicitHeight + 12
        radius: 7
        color: Theme.withAlpha(Theme.shade(Theme.ground, 0.55), 0.72)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.06)

        Column {
            id: legendCol
            anchors.fill: parent
            anchors.margins: 6
            spacing: 3

            Repeater {
                model: root.traces
                delegate: Item {
                    required property var modelData
                    readonly property var h: modelData.hist
                    readonly property int idx: root.scrubbing
                        ? Math.max(0, Math.min(h.length - 1, root.scrubIndex - (root.n - h.length)))
                        : h.length - 1
                    width: legendCol.width
                    height: 13

                    Rectangle {
                        id: dot
                        anchors.verticalCenter: parent.verticalCenter
                        width: 5; height: 5; radius: 2.5
                        color: modelData.color
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: dot.right
                        anchors.leftMargin: 6
                        text: modelData.key
                        color: Theme.text
                        opacity: 0.42
                        font.family: Theme.fontText
                        font.pixelSize: Theme.fsSection
                        font.letterSpacing: 1.0
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        text: {
                            if (!parent.h || parent.h.length === 0) return "--"
                            var v = parent.h[Math.max(0, parent.idx)]
                            return modelData.key === "NET"
                                ? v.toFixed(1) : Math.round(v * 100) + "%"
                        }
                        color: modelData.color
                        font.family: Theme.iconFont
                        font.pixelSize: 10
                    }
                }
            }
        }
    }

    Rectangle {
        anchors { left: parent.left; top: parent.top; leftMargin: 9; topMargin: 8 }
        width: axisLabel.implicitWidth + (root.scrubbing ? 14 : 0)
        height: root.scrubbing ? 17 : 13
        radius: 5
        color: root.scrubbing ? Theme.withAlpha(root.tint, 0.16) : "transparent"
        border.width: root.scrubbing ? 1 : 0
        border.color: Theme.withAlpha(root.tint, 0.35)
        Behavior on height { NumberAnimation { duration: 140 } }

        Text {
            id: axisLabel
            anchors.centerIn: parent
            text: root.scrubbing
                ? ("\u2212" + (root.n - 1 - root.scrubIndex) + "s")
                : "HOVER TO SCRUB"
            color: root.scrubbing ? root.tint : Theme.text
            opacity: root.scrubbing ? 1 : 0.26
            font.family: Theme.iconFont
            font.pixelSize: root.scrubbing ? 10 : Theme.fsSection
            font.letterSpacing: root.scrubbing ? 0 : Theme.trSection
        }
    }
}
