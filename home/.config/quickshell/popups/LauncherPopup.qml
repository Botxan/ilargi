import Quickshell
import Quickshell.Wayland
import QtQuick
import "../shapes"
import "../components"
import "../components/Fuzzy.js" as Fuzzy
import "../theme"
import "../state"
import "../modules/Center"

Item {
    id: root

    readonly property int fw: Theme.borderWidth + Theme.cornerRadius
    readonly property int fh: Theme.borderWidth + Theme.cornerRadius
    readonly property int bodyWidth: 760
    readonly property int bodyHeight: 470
    readonly property color hue: Qt.color("#6791c9")
    readonly property int rowH: 46
    readonly property int pad: 16

    readonly property bool open: Popups.launcherOpen
    readonly property real panelW: bodyWidth
    readonly property real panelH: bodyHeight + fh - Theme.borderWidth
    visible: open || hold.running
    onOpenChanged: if (!open) hold.restart()
    Timer { id: hold; interval: Theme.animTransition + 40 }

    readonly property var kinds: [
        { key: "net",    hue: "#6791c9", cats: ["Network", "WebBrowser", "Email", "Chat", "InstantMessaging"] },
        { key: "dev",    hue: "#6791c9", cats: ["Development", "IDE", "TextEditor", "Security"] },
        { key: "media",  hue: "#6791c9", cats: ["AudioVideo", "Audio", "Video", "Player", "Music"] },
        { key: "gfx",    hue: "#6791c9", cats: ["Graphics", "3DGraphics", "Photography"] },
        { key: "game",   hue: "#6791c9", cats: ["Game"] },
        { key: "office", hue: "#6791c9", cats: ["Office", "Education", "Viewer"] },
        { key: "sys",    hue: "#6791c9", cats: ["System", "Settings", "TerminalEmulator", "FileManager", "Utility", "Monitor"] }
    ]
    function hueFor(entry) {
        var c = entry.categories || []
        for (var k = 0; k < kinds.length; k++)
            for (var i = 0; i < c.length; i++)
                if (kinds[k].cats.indexOf(c[i]) >= 0) return Qt.color(kinds[k].hue)
        return root.hue
    }

    property string query: ""
    property int sel: 0

    readonly property var apps: {
        var out = []
        var v = DesktopEntries.applications.values
        for (var i = 0; i < v.length; i++) if (!v[i].noDisplay) out.push(v[i])
        out.sort(function (a, b) { return a.name.localeCompare(b.name) })
        return out
    }
    readonly property var hits: {
        var q = query, out = []
        for (var i = 0; i < apps.length; i++) {
            var e = apps[i]
            if (q === "") { out.push({ entry: e, score: 0, positions: [] }); continue }
            var m = Fuzzy.score(q, e.name)
            if (!m && e.genericName) {
                var g = Fuzzy.score(q, e.genericName)
                if (g) m = { score: g.score - 6, positions: [] }
            }
            if (m) out.push({ entry: e, score: m.score, positions: m.positions })
        }
        if (q !== "") out.sort(function (a, b) { return b.score - a.score || a.entry.name.localeCompare(b.entry.name) })
        return out
    }
    onHitsChanged: sel = 0

    function launch(i) {
        if (i < 0 || i >= hits.length) return
        hits[i].entry.execute()
        Popups.launcherOpen = false
    }
    function move(d) {
        if (hits.length === 0) return
        sel = Math.max(0, Math.min(hits.length - 1, sel + d))
        grid.positionViewAtIndex(sel, GridView.Contain)
    }

    Connections {
        target: Popups
        function onLauncherOpenChanged() {
            if (!Popups.launcherOpen) return
            field.text = ""
            root.sel = 0
            grid.positionViewAtBeginning()
            field.forceActiveFocus()
            focusTimer.restart()
        }
    }
    Timer { id: focusTimer; interval: 60; onTriggered: field.forceActiveFocus() }

    Item {
        id: sizer
        anchors.fill: parent

        Item {
            id: content
            width: root.bodyWidth
            height: root.bodyHeight
            x: 0
            y: root.fh - Theme.borderWidth
            opacity: root.open ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: root.open ? Theme.animContentIn : Theme.animContentOut }
            }

            Rectangle {
                id: bar
                anchors { left: parent.left; right: parent.right; top: parent.top
                          leftMargin: root.pad; rightMargin: root.pad; topMargin: 14 }
                height: 50
                radius: 14
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.shade(Theme.surfaceSunk, 0.25) }
                    GradientStop { position: 1.0; color: Theme.surfaceSunk }
                }
                border.width: 1
                border.color: Theme.withAlpha(root.hue, 0.30)
                Rectangle {
                    anchors.fill: parent; anchors.margins: 1; radius: 13
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Theme.withAlpha(root.hue, 0.09) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }
                Rule {
                    anchors { bottom: parent.bottom; bottomMargin: 1; left: parent.left; right: parent.right
                              leftMargin: 8; rightMargin: 8 }
                    tint: Theme.grooveLight; fade: 0.12
                }
                Text {
                    id: glyph
                    anchors { left: parent.left; leftMargin: 17; verticalCenter: parent.verticalCenter }
                    text: "󰍉"
                    color: root.hue
                    font.family: Theme.iconFont; font.pixelSize: 17
                }
                Rectangle {
                    id: countChip
                    anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    width: countText.implicitWidth + 14; height: 20; radius: 5
                    color: Qt.rgba(1, 1, 1, 0.03)
                    border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.07)
                    Text {
                        id: countText
                        anchors.centerIn: parent
                        text: root.query === "" ? root.apps.length + " APPS"
                                                : root.hits.length + " / " + root.apps.length
                        color: Theme.text; opacity: 0.4
                        font.family: Theme.fontText
                        font.pixelSize: Theme.fsSection
                        font.letterSpacing: Theme.trSection
                    }
                }
                TextInput {
                    id: field
                    anchors { left: glyph.right; leftMargin: 12; right: countChip.left; rightMargin: 12
                              verticalCenter: parent.verticalCenter }
                    color: Theme.text
                    font.family: Theme.fontText; font.pixelSize: 17; font.weight: Font.Medium
                    selectByMouse: true
                    selectionColor: Theme.withAlpha(root.hue, 0.35)
                    cursorDelegate: Rectangle { width: 2; color: root.hue; radius: 1 }
                    clip: true
                    onTextChanged: root.query = text

                    Keys.onPressed: function (e) {
                        var atEnd = cursorPosition === text.length
                        if (e.key === Qt.Key_Escape) {
                            if (text !== "") text = ""
                            else Popups.launcherOpen = false
                        } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                            root.launch(root.sel)
                        } else if (e.key === Qt.Key_Down) {
                            root.move(2)
                        } else if (e.key === Qt.Key_Up) {
                            root.move(-2)
                        } else if (e.key === Qt.Key_Right && atEnd) {
                            root.move(1)
                        } else if (e.key === Qt.Key_Left && atEnd && root.sel > 0) {
                            root.move(-1)
                        } else if (e.key === Qt.Key_Tab) {
                            root.move(1)
                        } else if (e.key === Qt.Key_Backtab) {
                            root.move(-1)
                        } else if ((e.modifiers & Qt.ControlModifier)
                                   && e.key >= Qt.Key_1 && e.key <= Qt.Key_9) {
                            root.launch(e.key - Qt.Key_1 + 1)
                        } else {
                            return
                        }
                        e.accepted = true
                    }
                }
                Text {
                    anchors { left: field.left; verticalCenter: parent.verticalCenter }
                    visible: field.text === ""
                    text: "Search apps…"
                    color: Theme.text; opacity: 0.28
                    font.family: Theme.fontText; font.pixelSize: 17
                }
            }

            Rectangle {
                id: tray
                anchors { left: parent.left; right: parent.right; top: bar.bottom; bottom: foot.top
                          leftMargin: root.pad; rightMargin: root.pad; topMargin: 12; bottomMargin: 10 }
                radius: 16
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.shade(Theme.surfaceSunk, 0.10) }
                    GradientStop { position: 1.0; color: Theme.shade(Theme.ground, 0.18) }
                }
                border.width: 1
                border.color: Theme.grooveDark
                Rule {
                    anchors { bottom: parent.bottom; bottomMargin: 1; left: parent.left; right: parent.right
                              leftMargin: 10; rightMargin: 10 }
                    tint: Theme.grooveLight; fade: 0.14
                }

                GridView {
                    id: grid
                    anchors.fill: parent
                    anchors.margins: 6
                    clip: true
                    cellWidth: width / 2
                    cellHeight: root.rowH + 4
                    model: root.hits
                    boundsBehavior: Flickable.StopAtBounds
                    currentIndex: root.sel

                    delegate: Item {
                        id: cell
                        required property var modelData
                        required property int index
                        readonly property bool isSel: index === root.sel
                        readonly property color kind: root.hueFor(modelData.entry)
                        width: grid.cellWidth
                        height: grid.cellHeight

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: 11
                            color: cell.isSel ? Theme.withAlpha(cell.kind, 0.14)
                                              : (cHov.hovered ? Qt.rgba(1, 1, 1, 0.03) : "transparent")
                            border.width: 1
                            border.color: cell.isSel ? Theme.withAlpha(cell.kind, 0.34) : "transparent"
                            Behavior on color { ColorAnimation { duration: 110 } }
                            Behavior on border.color { ColorAnimation { duration: 110 } }

                            Rectangle {
                                anchors.fill: parent; anchors.margins: 1; radius: 10
                                visible: cell.isSel
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: Theme.withAlpha(cell.kind, 0.16) }
                                    GradientStop { position: 0.7; color: "transparent" }
                                }
                            }

                            Item {
                                id: icon
                                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                                width: 28; height: 28
                                Rectangle {
                                    anchors.fill: parent
                                    visible: img.status !== Image.Ready
                                    radius: 8
                                    color: Theme.withAlpha(cell.kind, 0.22)
                                    Text {
                                        anchors.centerIn: parent
                                        text: cell.modelData.entry.name.length ? cell.modelData.entry.name[0].toUpperCase() : "?"
                                        color: cell.kind
                                        font.family: Theme.fontText; font.pixelSize: 13; font.weight: Font.Bold
                                    }
                                }
                                Image {
                                    id: img
                                    anchors.fill: parent
                                    source: cell.modelData.entry.icon !== ""
                                        ? Quickshell.iconPath(cell.modelData.entry.icon, true) : ""
                                    sourceSize.width: 56; sourceSize.height: 56
                                    visible: status === Image.Ready
                                    smooth: true; asynchronous: true
                                }
                            }

                            Column {
                                anchors { left: icon.right; leftMargin: 12; right: key.left; rightMargin: 8
                                          verticalCenter: parent.verticalCenter }
                                spacing: 1
                                Text {
                                    width: parent.width
                                    text: Fuzzy.highlightClamped(cell.modelData.entry.name,
                                              cell.modelData.positions, root.hue, 34)
                                    textFormat: Text.RichText
                                    color: Theme.text
                                    opacity: cell.isSel ? 1 : 0.86
                                    font.family: Theme.fontText; font.pixelSize: 14
                                    clip: true
                                }
                                Text {
                                    width: parent.width
                                    text: cell.modelData.entry.genericName || ""
                                    visible: text !== ""
                                    color: Theme.text; opacity: 0.32
                                    font.family: Theme.fontText; font.pixelSize: 11
                                    elide: Text.ElideRight
                                }
                            }

                            Text {
                                id: key
                                anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                                text: cell.index === root.sel ? "↵" : (cell.index > 0 && cell.index < 10 ? "^" + cell.index : "")
                                color: cell.isSel ? cell.kind : Theme.text
                                opacity: cell.isSel ? 0.95 : 0.22
                                font.family: Theme.iconFont; font.pixelSize: 10
                            }
                        }
                        HoverHandler { id: cHov; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: root.launch(cell.index) }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.hits.length === 0
                    text: "Nothing matches “" + root.query + "”"
                    color: Theme.text; opacity: 0.3
                    font.family: Theme.fontText; font.pixelSize: 13
                }
            }

            Row {
                id: foot
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom
                          leftMargin: root.pad + 6; bottomMargin: 12 }
                height: 14
                spacing: 18
                Repeater {
                    model: ["↵  OPEN", "↑↓←→  MOVE", "CTRL 1–9  DIRECT", "ESC  CLOSE"]
                    Text {
                        required property string modelData
                        text: modelData
                        color: Theme.text; opacity: 0.26
                        font.family: Theme.fontText
                        font.pixelSize: Theme.fsSection
                        font.letterSpacing: Theme.trSection
                    }
                }
            }
        }
    }
}
