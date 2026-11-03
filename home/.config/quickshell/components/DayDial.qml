import QtQuick
import "../theme"
import "../services"

Item {
    id: root

    property color tint: Theme.accent
    property real reveal: 1
    property var events: []

    implicitWidth: 260
    implicitHeight: 260

    readonly property real trackR: Math.min(width, height) / 2 - 20
    readonly property real trackW: 15

    property date now: new Date()
    Timer {
        interval: 20000; repeat: true; running: root.visible
        onTriggered: root.now = new Date()
    }

    readonly property real nowFrac:
        (now.getHours() * 3600 + now.getMinutes() * 60 + now.getSeconds()) / 86400

    onRevealChanged: face.requestPaint()
    onEventsChanged: face.requestPaint()
    onNowChanged:    face.requestPaint()
    onTintChanged:   face.requestPaint()

    Canvas {
        id: face
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const cx = width / 2, cy = height / 2
            const R = root.trackR, LW = root.trackW
            const TAU = Math.PI * 2
            const A0 = -Math.PI / 2 + root.nowFrac * TAU
            const sweep = TAU * Math.max(0, Math.min(1, root.reveal))
            if (sweep <= 0.001) return

            function mod(a) { var x = a % TAU; return x < 0 ? x + TAU : x }

            function span(f0, f1, style, lw, radius, cap) {
                const a0 = -Math.PI / 2 + f0 * TAU
                const len = (f1 - f0) * TAU
                const base = mod(a0 - A0)
                for (var pass = 0; pass < 2; pass++) {
                    const o0 = base - pass * TAU
                    const o1 = o0 + len
                    const c0 = Math.max(o0, 0), c1 = Math.min(o1, sweep)
                    if (c1 - c0 < 0.0015) continue
                    ctx.beginPath()
                    ctx.lineCap = cap ? cap : "butt"
                    ctx.lineWidth = lw
                    ctx.strokeStyle = style
                    ctx.arc(cx, cy, radius, A0 + c0, A0 + c1)
                    ctx.stroke()
                }
            }

            function daylight(f) {
                const h = f * 24
                if (h <= 5 || h >= 21.5) return 0
                if (h < 8)    return (h - 5) / 3
                if (h <= 17)  return 1
                return 1 - (h - 17) / 4.5
            }
            const floorNight = Theme.palette.bg4
            const floorDay   = Qt.color(Theme.palette.grey)

            const SEG = 96
            for (var si = 0; si < SEG; si++) {
                const sf = si / SEG
                const a0 = -Math.PI / 2 + sf * TAU
                const off = mod(a0 - A0)
                if (off > sweep) continue
                const len = Math.min(TAU / SEG * 1.35, sweep - off)
                if (len <= 0) continue
                ctx.beginPath()
                ctx.lineWidth = LW
                ctx.strokeStyle = Qt.tint(floorNight,
                    Theme.withAlpha(floorDay, daylight(sf + 0.5 / SEG)))
                ctx.arc(cx, cy, R, A0 + off, A0 + off + len)
                ctx.stroke()
            }

            ctx.beginPath()
            ctx.lineWidth = 1
            ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.09)
            ctx.arc(cx, cy, R + LW / 2 + 0.5, A0, A0 + sweep)
            ctx.stroke()

            span(0, root.nowFrac, Qt.rgba(1, 1, 1, 0.035), LW - 4, R)

            const ev = root.events
            const nf = root.nowFrac
            for (var i = 0; i < ev.length; i++) {
                const e = ev[i]
                if (e.allDay) continue
                const s = new Date(e.start), en = new Date(e.end)
                var f0 = (s.getHours() * 3600 + s.getMinutes() * 60) / 86400
                var f1 = (en.getHours() * 3600 + en.getMinutes() * 60) / 86400
                if (f1 <= f0) f1 = Math.min(1, f0 + 0.02)
                if (f1 - f0 < 0.008) f1 = f0 + 0.008
                const past = f1 < nf
                span(f0, f1, Theme.withAlpha(root.tint, past ? 0.26 : 0.78), LW - 3, R)

                if (!past) span(f0, f0 + 0.0028, Theme.atLum(root.tint, 0.95), LW - 1, R)
            }

            ctx.lineWidth = 1
            for (var h = 0; h < 24; h++) {
                const major = h % 6 === 0
                const a = -Math.PI / 2 + h / 24 * TAU
                if (mod(a - A0) > sweep) continue
                const r0 = R + LW / 2 + 3
                const r1 = r0 + (major ? 6 : 3)
                ctx.beginPath()
                ctx.strokeStyle = Qt.rgba(1, 1, 1, major ? 0.22 : 0.10)
                ctx.moveTo(cx + Math.cos(a) * r0, cy + Math.sin(a) * r0)
                ctx.lineTo(cx + Math.cos(a) * r1, cy + Math.sin(a) * r1)
                ctx.stroke()
            }

            if (root.reveal > 0.985) {
                const rIn = R - LW / 2 - 10
                ctx.beginPath()
                ctx.lineWidth = 1
                ctx.strokeStyle = Theme.withAlpha(Theme.groundText, 0.55)
                ctx.moveTo(cx + Math.cos(A0) * (rIn * 0.76), cy + Math.sin(A0) * (rIn * 0.76))
                ctx.lineTo(cx + Math.cos(A0) * rIn, cy + Math.sin(A0) * rIn)
                ctx.stroke()

                ctx.beginPath()
                ctx.fillStyle = Theme.groundText
                ctx.arc(cx + Math.cos(A0) * (R - LW / 2 - 4), cy + Math.sin(A0) * (R - LW / 2 - 4), 2.5, 0, TAU)
                ctx.fill()
            }
        }
    }

    Repeater {
        model: [{ h: 0, l: "00" }, { h: 6, l: "06" }, { h: 12, l: "12" }, { h: 18, l: "18" }]
        delegate: Text {
            required property var modelData
            readonly property real ang: -Math.PI / 2 + modelData.h / 24 * Math.PI * 2
            x: root.width / 2 + Math.cos(ang) * (root.trackR + root.trackW / 2 + 15) - width / 2
            y: root.height / 2 + Math.sin(ang) * (root.trackR + root.trackW / 2 + 15) - height / 2
            text: modelData.l
            color: Theme.text
            opacity: 0.26 * Theme.phase(root.reveal, 0.7, 0.3)
            font.family: Theme.fontText
            font.pixelSize: Theme.fsSection
            font.letterSpacing: Theme.trSection
        }
    }
}
