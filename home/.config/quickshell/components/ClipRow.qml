import QtQuick
import "../theme"

Item {
    id: root

    property var  clip_: null
    property int  idx: 0
    property real depth: 0
    property real phase: 1
    signal taken()

    implicitHeight: 52
    height: 52
    opacity: phase

    readonly property string preview: clip_ ? clip_.preview : ""

    readonly property var binary: {
        var m = /^\[\[\s*binary data\s+([\d.]+\s*\w+)\s+(\w+)(?:\s+(\d+)x(\d+))?/.exec(preview)
        return m ? { size: m[1], type: m[2].toUpperCase(),
                     dim: m[3] ? (m[3] + "×" + m[4]) : "" } : null
    }
    readonly property string colorHex: {
        var m = /^\s*(#[0-9a-fA-F]{6})\s*$/.exec(preview)
        return m ? m[1] : ""
    }
    readonly property var url: {
        var m = /^\s*(?:(https?):\/\/)?((?:www\.)?[\w.-]+\.[a-z]{2,})(\/\S*)?\s*$/i.exec(preview)
        if (!m || root.kind !== "url") return null
        return { host: m[2], path: m[3] || "" }
    }
    readonly property bool codeish: {
        if (kind !== "text" || colorHex !== "") return false
        var p = preview
        return /^\s{2,}\S/.test(p)
            || /^[~.]?\/[^\s/]/.test(p)
            || /^(\$ |#!|sudo |cd |git |npm |yay |pacman |pkill |kill |grep |rg |curl |wget |ssh |scp |rm |ls |cat |sed |awk |chmod |systemctl |qs |hyprctl )/i.test(p)
            || / (\|\||&&|\||>>|2>&1) /.test(p)
            || /\w\([^)]*\)/.test(p)
            || /[{};]\s*$/.test(p)
    }

    readonly property string kind:
        colorHex !== "" ? "color" : (clip_ ? clip_.kind : "text")
    readonly property var kindData: Theme.clipKind(kind)
    readonly property color hue: kindData.hue

    readonly property bool first: idx === 0
    readonly property bool keyed: idx < Theme.clipboardKeyed
    Rectangle {
        id: body
        anchors.fill: parent
        radius: 10
        color: hov.hovered ? Theme.surfaceSunk : Theme.surfaceRecess
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    Rectangle {
        id: keycap
        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
        width: 28; height: 28; radius: 8
        color: root.first ? Theme.accent
             : root.keyed ? Theme.withAlpha(Theme.accent, 0.16)
             : Theme.palette.bg4

        Text {
            anchors.centerIn: parent
            text: root.keyed ? (root.idx + 1) : root.kindData.glyph
            color: root.first ? Theme.accentText : root.keyed ? Theme.accent : Theme.text
            opacity: root.keyed ? 1 : 0.45
            font.family: root.keyed ? Theme.fontText : Theme.iconFont
            font.pixelSize: 13
            font.weight: Font.Bold
        }
    }

    Rectangle {
        id: swatch
        visible: root.colorHex !== ""
        anchors { left: keycap.right; leftMargin: 12; verticalCenter: parent.verticalCenter }
        width: 30; height: 30; radius: 8
        color: root.colorHex === "" ? "transparent" : root.colorHex
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.16)
    }

    Item {
        anchors {
            left: swatch.visible ? swatch.right : keycap.right
            leftMargin: 12
            right: parent.right; rightMargin: 14
            verticalCenter: parent.verticalCenter
        }
        height: 36

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            spacing: 1
            visible: root.url !== null
            Text {
                width: parent.width
                text: root.url ? root.url.host : ""
                color: root.hue
                font.family: Theme.fontText; font.pixelSize: 14; font.weight: Font.Medium
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                visible: root.url && root.url.path !== ""
                text: root.url ? root.url.path : ""
                color: Theme.text; opacity: 0.42
                font.family: Theme.fontMono; font.pixelSize: 11
                elide: Text.ElideMiddle
            }
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            visible: root.binary !== null
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.binary ? root.binary.type : ""
                color: root.hue
                font.family: Theme.fontMono; font.pixelSize: 13; font.weight: Font.Bold
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.binary
                    ? (root.binary.dim !== "" ? root.binary.dim + "   " + root.binary.size
                                              : root.binary.size)
                    : ""
                color: Theme.text; opacity: 0.46
                font.family: Theme.fontMono; font.pixelSize: 12
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.colorHex !== ""
            text: root.colorHex.toUpperCase()
            color: root.hue
            font.family: Theme.fontMono; font.pixelSize: 14; font.weight: Font.Bold
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            visible: root.url === null && root.binary === null && root.colorHex === ""
            text: root.preview
            color: Theme.text
            opacity: 0.92 - root.depth * 0.22
            font.family: root.codeish ? Theme.fontMono : Theme.fontText
            font.pixelSize: root.codeish ? 12 : 13.5
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }

    HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: root.taken() }
}
