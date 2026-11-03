pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: theme

    function withAlpha(hex, alpha) {
        const c = Qt.color(hex);
        return Qt.rgba(c.r, c.g, c.b, alpha);
    }

    readonly property bool dnd: cfg.dnd
    readonly property bool dndHeldByRecorder: cfg.dndHeldByRecorder

    function desaturate(c, amount) {
        const col = Qt.color(c);
        const l = 0.2126 * col.r + 0.7152 * col.g + 0.0722 * col.b;
        return Qt.rgba(
            col.r + (l - col.r) * amount,
            col.g + (l - col.g) * amount,
            col.b + (l - col.b) * amount,
            col.a
        );
    }

    readonly property FileView settingsFile: FileView {
        id: settingsFile
        path: Paths.state + "/settings.json"
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: cfg
            property string motion: "full"
            property bool causticsEnabled: true
            property bool spectrumEnabled: true
            property bool telemetryEnabled: true
            property bool dnd: false
            property bool dndHeldByRecorder: false
            property int topbarItemGap: 10
            property int topbarDividerGap: 16
        }
    }

    function phase(t, start, span) {
        return Math.max(0, Math.min(1, (t - start) / span));
    }

    function set(key, value) {
        cfg[key] = value;
        settingsFile.writeAdapter();
    }

    readonly property var palette: ({
        black: "#0c0e0f", darker: "#060809", panel: "#101213",
        bg1: "#161819", bg2: "#1b1d1e", bg3: "#1f2122", bg4: "#27292a",
        grey: "#343637", greyFg: "#484a4b", lightGrey: "#505253",
        white: "#edeff0",
        red: "#df5b61", green: "#78b892", yellow: "#de8f78",
        blue: "#6791c9", blueBright: "#709ad2", magenta: "#bc83e3", cyan: "#67afc1"
    })

    readonly property color accent: dnd
        ? theme.desaturate(palette.blue, 0.55)
        : Qt.color(palette.blue)

    readonly property color ground: palette.panel

    readonly property color text: palette.white
    readonly property color accentText: palette.black

    readonly property color groundText:
        theme.relLum(Qt.color(theme.text)) >= 0.78
            ? theme.text
            : theme.atLum(theme.text, 0.78)

    readonly property string fontText: "Roboto"
    readonly property string fontMono: "JetBrainsMono Nerd Font"
    readonly property string iconFont: "JetBrainsMono Nerd Font"

    readonly property var tabularNums: ({ "tnum": 1 })

    readonly property int notchHeight: 36
    readonly property int notchPaddingH: 14

    readonly property int topbarItemGap: cfg.topbarItemGap
    readonly property int topbarDividerGap: cfg.topbarDividerGap
    readonly property int cornerRadius: 12
    readonly property int borderWidth: 4

    readonly property var apertureRooms: [
        { key: "media", glyph: "󰝚", label: "Media", hue: "#6791c9", corner: "tl" },
        { key: "vitals", glyph: "󰓅", label: "Vitals", hue: "#6791c9", corner: "tr" },
        { key: "capture", glyph: "󰄀", label: "Capture", hue: "#6791c9", corner: "bl" },
        { key: "displays", glyph: "󰍹", label: "Displays", hue: "#6791c9", corner: "br" }
    ]
    function apertureRoomFor(key) {
        for (var i = 0; i < apertureRooms.length; i++)
            if (apertureRooms[i].key === key) return apertureRooms[i]
        return null
    }

    readonly property int aperturePanelWidth:  840
    readonly property int aperturePanelHeight: 520
    readonly property int apertureDialSize:   50

    readonly property int almanacWidth: 400

    readonly property int clipboardWidth: 400
    readonly property int clipboardKeyed: 9
    readonly property var clipboardKinds: [
        { key: "text",  glyph: "󰈙", hue: "#6791c9" },
        { key: "url",   glyph: "󰌷", hue: "#6791c9" },
        { key: "image", glyph: "󰋩", hue: "#6791c9" },
        { key: "color", glyph: "󰝥", hue: "#6791c9" }
    ]
    function clipKind(k) {
        for (var i = 0; i < clipboardKinds.length; i++)
            if (clipboardKinds[i].key === k) return clipboardKinds[i]
        return clipboardKinds[0]
    }

    readonly property var almanacRooms: [
        { key: "day",   label: "Day",       glyph: "󰃭", hue: "#6791c9" },
        { key: "timer", label: "Timer",     glyph: "󰔟", hue: "#6791c9" },
        { key: "watch", label: "Stopwatch", glyph: "󰔛", hue: "#6791c9" },
        { key: "alarm", label: "Alarms",    glyph: "󰀠", hue: "#6791c9" },
        { key: "tasks", label: "Tasks",     glyph: String.fromCodePoint(0xF0756), hue: "#6791c9" }
    ]
    function almanacHue(key) {
        var r = almanacRooms.find(x => x.key === key)
        var c = Qt.color(r ? r.hue : "#94BFFF")
        return dnd ? theme.desaturate(c, 0.55) : c
    }

    readonly property int almanacRevealDelay: 0
    readonly property int almanacReveal:      animTransition

    readonly property int almanacRoomSlide: 300

    readonly property int almanacCloseReveal: animContentOut

    readonly property int wsIconSize: 24
    readonly property int wsFontSize: 16
    readonly property int wsSpacing: 7

    readonly property int  animTransition: 320
    readonly property int  animCurve:      Easing.OutQuart
    readonly property int  animContentIn:  Math.round(animTransition * 0.5)
    readonly property int  animContentOut: Math.round(animTransition * 0.15)
    readonly property int  animColor:      120
    readonly property int  animFast:       100

    readonly property int durationFast: 220
    readonly property int durationBase: 300

    readonly property real wsEmptyOpacity: 0.40
    readonly property real wsBusyOpacityMin: 0.64
    readonly property real wsBusyOpacityMax: 0.86
    readonly property int busyBreatheHalfDuration: 2200

    readonly property real focusScale: 1.22

    readonly property var metals: [
        { id: 1, name: "iron",   tone: "#6791c9" },
        { id: 2, name: "steel",  tone: "#67afc1" },
        { id: 3, name: "tin",    tone: "#c9cdd0" },
        { id: 4, name: "pewter", tone: "#a8a194" },
        { id: 5, name: "zinc",   tone: "#cfb27a" },
        { id: 6, name: "brass",  tone: "#de8f78" },
        { id: 7, name: "copper", tone: "#d4726a" },
        { id: 8, name: "bronze", tone: "#b088c9" }
    ]

    function relLum(c) { return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b }

    function atLum(c, target) {
        var col = Qt.color(c)
        var y = theme.relLum(col)
        if (y <= 0.0001) return col
        if (target <= y) {
            var k = target / y
            return Qt.rgba(col.r * k, col.g * k, col.b * k, col.a)
        }
        var mx = Math.max(col.r, col.g, col.b)
        var kmax = mx > 0 ? 1 / mx : 1
        var r = Math.min(col.r * kmax, 1)
        var g = Math.min(col.g * kmax, 1)
        var b = Math.min(col.b * kmax, 1)
        var y2 = 0.2126 * r + 0.7152 * g + 0.0722 * b
        if (target <= y2) {
            var k2 = target / y2
            return Qt.rgba(r * k2, g * k2, b * k2, col.a)
        }
        var t = (target - y2) / (1 - y2)
        return Qt.rgba(r + (1 - r) * t, g + (1 - g) * t, b + (1 - b) * t, col.a)
    }

    function metalFor(wsId) {
        var m = metals[wsId - 1]
        return { id: m.id, name: m.name, color: m.tone, glow: theme.lift(m.tone, 0.12) }
    }

    readonly property int trayIconNetwork:      15
    readonly property int trayIconNetworkWired: 13
    readonly property int trayIconVpn:       13
    readonly property int trayIconAudio:     18
    readonly property int trayIconBluetooth: 17
    readonly property int trayIconBattery:   15
    readonly property int trayIconSoundboard: 14

    readonly property color statusActive:  theme.groundText
    readonly property color statusStandby: theme.withAlpha(theme.groundText, 0.52)
    readonly property color statusIdle:    theme.withAlpha(theme.groundText, 0.26)
    readonly property color statusNotice:  palette.yellow
    readonly property color statusWarn:    palette.yellow
    readonly property color statusAlert:   palette.red

    readonly property color statusLive: palette.red

    readonly property string motion: cfg.motion

    readonly property bool reducedMotion: motion === "off"
    readonly property bool ambientMotion: motion === "full"

    readonly property bool causticsEnabled:  cfg.causticsEnabled
    readonly property bool spectrumEnabled:  cfg.spectrumEnabled
    readonly property bool telemetryEnabled: cfg.telemetryEnabled

    function shade(c, amount) {
        const col = Qt.color(c);
        return Qt.rgba(col.r * (1 - amount), col.g * (1 - amount), col.b * (1 - amount), col.a);
    }
    function lift(c, amount) {
        const col = Qt.color(c);
        return Qt.rgba(col.r + (1 - col.r) * amount,
                       col.g + (1 - col.g) * amount,
                       col.b + (1 - col.b) * amount, col.a);
    }

    readonly property color surfaceWell:    palette.bg1
    readonly property color surfaceRecess:  palette.bg2
    readonly property color surfaceSunk:    palette.bg3

    readonly property color edgeLight: "transparent"
    readonly property color edgeShade: "transparent"

    readonly property color grooveDark:  "transparent"
    readonly property color grooveLight: Qt.rgba(1, 1, 1, 0.05)

    readonly property int   fsSection: 10
    readonly property real  trSection: 0.4
    readonly property int   fsMicro: 9
    readonly property int   fsBody: 11
    readonly property int   fsTitle: 17

    readonly property int chassisRail:      56
    readonly property int plateInsetTop:    10
    readonly property int plateInsetBottom: 10
    readonly property int plateRadius:      12
    readonly property int dialBiteRadius:   33
    readonly property int dialCx:           37
    readonly property int dialCy:           54
    readonly property int plateGutterX:     84
    readonly property int plateGutterY:     30
}
