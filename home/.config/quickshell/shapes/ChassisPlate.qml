import QtQuick
import "../theme"

Canvas {
    id: root

    property color fillTop:    Theme.shade(Theme.surfaceWell, 0.22)
    property color fillBottom: Theme.surfaceWell
    property color edgeTop:    Theme.edgeShade
    property color edgeBottom: Theme.edgeLight
    property color scoopGlow:  "transparent"
    property real  scoopGlowStrength: 0

    property int radius:       Theme.plateRadius
    property int biteRadius:   Theme.dialBiteRadius
    property real biteLeftX:   -(Theme.chassisRail - Theme.dialCx)
    property real biteRightX:  width + (Theme.chassisRail - Theme.dialCx)
    property real biteTopY:    Theme.dialCy - Theme.plateInsetTop
    property real biteBottomY: height - (Theme.dialCy - Theme.plateInsetBottom)

    onWidthChanged:  requestPaint()
    onHeightChanged: requestPaint()
    onFillTopChanged: requestPaint()
    onFillBottomChanged: requestPaint()
    onScoopGlowChanged: requestPaint()
    onScoopGlowStrengthChanged: requestPaint()

    function tracePath(ctx) {
        const w = width, h = height, r = root.radius, br = root.biteRadius
        const lx = root.biteLeftX, rx = root.biteRightX
        const ty = root.biteTopY,  by = root.biteBottomY
        const dxL = 0 - lx
        const aL = Math.acos(Math.min(1, dxL / br))
        const dxR = rx - w
        const aR = Math.acos(Math.min(1, dxR / br))

        ctx.beginPath()
        ctx.moveTo(r, 0)
        ctx.lineTo(w - r, 0)
        ctx.arcTo(w, 0, w, r, r)
        ctx.lineTo(w, ty - br * Math.sin(aR))
        ctx.arc(rx, ty, br, Math.PI + aR, Math.PI - aR, true)
        ctx.lineTo(w, by - br * Math.sin(aR))
        ctx.arc(rx, by, br, Math.PI + aR, Math.PI - aR, true)
        ctx.lineTo(w, h - r)
        ctx.arcTo(w, h, w - r, h, r)
        ctx.lineTo(r, h)
        ctx.arcTo(0, h, 0, h - r, r)
        ctx.lineTo(0, by + br * Math.sin(aL))
        ctx.arc(lx, by, br, aL, -aL, true)
        ctx.lineTo(0, ty + br * Math.sin(aL))
        ctx.arc(lx, ty, br, aL, -aL, true)
        ctx.lineTo(0, r)
        ctx.arcTo(0, 0, r, 0, r)
        ctx.closePath()
    }

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        if (width <= 0 || height <= 0) return

        tracePath(ctx)

        const g = ctx.createLinearGradient(0, 0, 0, height)
        g.addColorStop(0.0, root.fillTop)
        g.addColorStop(0.18, root.fillBottom)
        g.addColorStop(1.0, Theme.lift(root.fillBottom, 0.018))
        ctx.fillStyle = g
        ctx.fill()

        const s = ctx.createLinearGradient(0, 0, 0, height)
        s.addColorStop(0.0, root.edgeTop)
        s.addColorStop(0.45, Qt.rgba(1, 1, 1, 0.05))
        s.addColorStop(1.0, root.edgeBottom)
        ctx.strokeStyle = s
        ctx.lineWidth = 1
        ctx.stroke()

        if (root.scoopGlowStrength > 0.004) {
            ctx.strokeStyle = Theme.withAlpha(root.scoopGlow, root.scoopGlowStrength)
            ctx.lineWidth = 2
            const br = root.biteRadius
            const dxL = 0 - root.biteLeftX
            const aL = Math.acos(Math.min(1, dxL / br))
            const dxR = root.biteRightX - width
            const aR = Math.acos(Math.min(1, dxR / br))
            const pairs = [[root.biteLeftX, root.biteTopY, true], [root.biteLeftX, root.biteBottomY, true],
                           [root.biteRightX, root.biteTopY, false], [root.biteRightX, root.biteBottomY, false]]
            for (var i = 0; i < pairs.length; i++) {
                ctx.beginPath()
                if (pairs[i][2]) ctx.arc(pairs[i][0], pairs[i][1], br, aL, -aL, true)
                else             ctx.arc(pairs[i][0], pairs[i][1], br, Math.PI + aR, Math.PI - aR, true)
                ctx.stroke()
            }
        }
    }
}
