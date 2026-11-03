import QtQuick
import QtQuick.Shapes
import "../theme"

Shape {
    id: root

    property real t: Theme.borderWidth
    property real r: Theme.cornerRadius
    property real fr: Theme.cornerRadius
    property color color: Theme.ground
    property color lip: Theme.grooveLight

    property real leftW: 200
    property real leftH: 32
    property real centerW: 300
    property real centerH: 32
    property real rightW: 200
    property real rightH: 32
    property real lcDepth: 0.001
    property real lcHeight: 0.001
    property real rcDepth: 0.001
    property real rcHeight: 0.001
    property real bcWidth: 0.001
    property real sideCy: height / 2
    property real bcDepth: 0.001
    property real rtTop: 66
    property real rtDepth: 0.001
    property real rtHeight: 0.001
    readonly property real rtTopEff: Math.max(rtTop,
        t + rightH + Math.min(fr, rightH) + Math.min(fr, rtDepth))
    readonly property real rtHeightEff: Math.max(0.001, Math.min(rtTop + rtHeight,
        sideCy - rcHeight / 2 - Math.min(fr, rcDepth) - Math.min(fr, rtDepth)) - rtTopEff)

    component Anim: NumberAnimation { duration: Theme.animTransition; easing.type: Theme.animCurve }
    Behavior on leftW    { Anim {} }
    Behavior on leftH    { Anim {} }
    Behavior on centerW  { Anim {} }
    Behavior on centerH  { Anim {} }
    Behavior on rightW   { Anim {} }
    Behavior on rightH   { Anim {} }
    Behavior on lcDepth  { Anim {} }
    Behavior on lcHeight { Anim {} }
    Behavior on rcDepth  { Anim {} }
    Behavior on rcHeight { Anim {} }
    Behavior on bcWidth  { Anim {} }
    Behavior on bcDepth  { Anim {} }
    Behavior on rtDepth  { Anim {} }
    Behavior on rtHeight { enabled: root.rtDepth > 1; Anim {} }

    preferredRendererType: Shape.CurveRenderer

    function f(n) { return Math.round(n * 100) / 100 }

    readonly property string loop: {
        const t = root.t, w = root.width, h = root.height
        const cx = w / 2, cy = root.sideCy, R = root.r, FR = root.fr
        const min = Math.min
        const lW = root.leftW, lH = root.leftH, cW = root.centerW, cH = root.centerH
        const rW = root.rightW, rH = root.rightH
        const lcD = root.lcDepth, lcH = root.lcHeight, rcD = root.rcDepth, rcH = root.rcHeight
        const bcW = root.bcWidth, bcD = root.bcDepth
        const rtT = root.rtTopEff, rtD = root.rtDepth, rtH = root.rtHeightEff
        const rtF = min(FR, rtD), rtR = min(R, rtD, rtH / 2)

        const lM = min(FR, lH), lF = min(FR, lH), lR = min(R, lH, lW)
        const cF = min(FR, cH), cR = min(R, cH, cW / 2)
        const rM = min(FR, rH), rF = min(FR, rH), rR = min(R, rH, rW)
        const lcF = min(FR, lcD), lcR = min(R, lcD, lcH / 2)
        const rcF = min(FR, rcD), rcR = min(R, rcD, rcH / 2)
        const bcF = min(FR, bcD), bcR = min(R, bcD, bcW / 2)

        let s = ""
        const M = (x, y) => { s += "M" + f(x) + " " + f(y) }
        const L = (x, y) => { s += "L" + f(x) + " " + f(y) }
        const A = (rad, sweep, x, y) => {
            if (rad < 0.01) { L(x, y); return }
            s += "A" + f(rad) + " " + f(rad) + " 0 0 " + sweep + " " + f(x) + " " + f(y)
        }

        M(t, t + lH + lM)
        L(t, cy - lcH / 2 - lcF)
        A(lcF, 0, t + lcF, cy - lcH / 2)
        L(t + lcD - lcR, cy - lcH / 2)
        A(lcR, 1, t + lcD, cy - lcH / 2 + lcR)
        L(t + lcD, cy + lcH / 2 - lcR)
        A(lcR, 1, t + lcD - lcR, cy + lcH / 2)
        L(t + lcF, cy + lcH / 2)
        A(lcF, 0, t, cy + lcH / 2 + lcF)
        L(t, h - t - R)
        A(R, 0, t + R, h - t)
        L(cx - bcW / 2 - bcF, h - t)
        A(bcF, 0, cx - bcW / 2, h - t - bcF)
        L(cx - bcW / 2, h - t - bcD + bcR)
        A(bcR, 1, cx - bcW / 2 + bcR, h - t - bcD)
        L(cx + bcW / 2 - bcR, h - t - bcD)
        A(bcR, 1, cx + bcW / 2, h - t - bcD + bcR)
        L(cx + bcW / 2, h - t - bcF)
        A(bcF, 0, cx + bcW / 2 + bcF, h - t)
        L(w - t - R, h - t)
        A(R, 0, w - t, h - t - R)
        L(w - t, cy + rcH / 2 + rcF)
        A(rcF, 0, w - t - rcF, cy + rcH / 2)
        L(w - t - rcD + rcR, cy + rcH / 2)
        A(rcR, 1, w - t - rcD, cy + rcH / 2 - rcR)
        L(w - t - rcD, cy - rcH / 2 + rcR)
        A(rcR, 1, w - t - rcD + rcR, cy - rcH / 2)
        L(w - t - rcF, cy - rcH / 2)
        A(rcF, 0, w - t, cy - rcH / 2 - rcF)
        L(w - t, rtT + rtH + rtF)
        A(rtF, 0, w - t - rtF, rtT + rtH)
        L(w - t - rtD + rtR, rtT + rtH)
        A(rtR, 1, w - t - rtD, rtT + rtH - rtR)
        L(w - t - rtD, rtT + rtR)
        A(rtR, 1, w - t - rtD + rtR, rtT)
        L(w - t - rtF, rtT)
        A(rtF, 0, w - t, rtT - rtF)
        L(w - t, t + rH + rM)
        A(rM, 0, w - t - rM, t + rH)
        L(w - t - rW + rR, t + rH)
        A(rR, 1, w - t - rW, t + rH - rR)
        L(w - t - rW, t + rF)
        A(rF, 0, w - t - rW - rF, t)
        L(cx + cW / 2 + cF, t)
        A(cF, 0, cx + cW / 2, t + cF)
        L(cx + cW / 2, t + cH - cR)
        A(cR, 1, cx + cW / 2 - cR, t + cH)
        L(cx - cW / 2 + cR, t + cH)
        A(cR, 1, cx - cW / 2, t + cH - cR)
        L(cx - cW / 2, t + cF)
        A(cF, 0, cx - cW / 2 - cF, t)
        L(t + lW + lF, t)
        A(lF, 0, t + lW, t + lF)
        L(t + lW, t + lH - lR)
        A(lR, 1, t + lW - lR, t + lH)
        L(t + lM, t + lH)
        A(lM, 0, t, t + lH + lM)
        s += "Z"
        return s
    }

    ShapePath {
        fillColor: root.color
        strokeColor: "transparent"
        strokeWidth: 0
        fillRule: ShapePath.OddEvenFill
        PathSvg { path: "M0 0L" + root.width + " 0L" + root.width + " " + root.height + "L0 " + root.height + "Z" + root.loop }
    }

    ShapePath {
        fillColor: "transparent"
        strokeColor: root.lip
        strokeWidth: 1
        PathSvg { path: root.loop }
    }
}
