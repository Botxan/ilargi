pragma Singleton
import QtQuick
import Quickshell

Singleton {
    readonly property var palette: ({
        black: "#0c0e0f", darker: "#060809", panel: "#101213",
        bg1: "#161819", bg2: "#1b1d1e", bg3: "#1f2122", bg4: "#27292a",
        grey: "#343637", greyFg: "#484a4b", lightGrey: "#505253",
        white: "#edeff0",
        red: "#df5b61", green: "#78b892", yellow: "#de8f78",
        blue: "#6791c9", blueBright: "#709ad2", magenta: "#bc83e3", cyan: "#67afc1"
    })
    readonly property color ground: palette.panel
    readonly property color text: palette.white
    readonly property color accent: palette.blue
    readonly property color accentText: palette.black
    readonly property color surfaceWell: palette.bg1
    readonly property color surfaceRecess: palette.bg2
    readonly property color surfaceSunk: palette.bg3
    readonly property string fontText: "Roboto"
    readonly property string iconFont: "JetBrainsMono Nerd Font"
    readonly property var tabularNums: ({ "tnum": 1 })
    readonly property int cornerRadius: 12
    readonly property int borderWidth: 4
    readonly property int animTransition: 320
    readonly property int animCurve: Easing.OutQuart
    readonly property int animContentIn: Math.round(animTransition * 0.5)
    readonly property int animContentOut: Math.round(animTransition * 0.15)

    function withAlpha(hex, alpha) {
        const c = Qt.color(hex)
        return Qt.rgba(c.r, c.g, c.b, alpha)
    }
}
