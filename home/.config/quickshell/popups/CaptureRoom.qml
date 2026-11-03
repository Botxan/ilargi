import QtQuick
import Quickshell
import "../components"
import "../theme"
import "../services"
import "../state"

Item {
    id: root
    readonly property color hue: Qt.color("#6791c9")
    readonly property color live: Theme.statusLive
    readonly property string scripts: Paths.scripts + "/"

    signal requestClose()

    Component.onCompleted: RecorderService.refreshRecent()

    function afterClose(cmd) {
        root.requestClose()
        Quickshell.execDetached(["hyprctl", "dispatch", "exec", "sleep 0.32; " + cmd])
    }

    component Tile: Rectangle {
        id: tile
        property string glyph: ""
        property string label: ""
        property string sub: ""
        property color tint: root.hue
        property bool big: true
        signal activated()

        radius: 12
        color: tHov.hovered ? Theme.lift(Theme.surfaceRecess, 0.03) : Theme.surfaceRecess
        border.width: 1
        border.color: tHov.hovered ? Theme.withAlpha(tint, 0.45) : Theme.grooveDark
        Behavior on border.color { ColorAnimation { duration: 140 } }
        Behavior on color { ColorAnimation { duration: 140 } }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 11
            opacity: tHov.hovered ? 1 : 0.55
            Behavior on opacity { NumberAnimation { duration: 160 } }
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: Theme.withAlpha(tile.tint, 0.10) }
            }
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: 12
            spacing: tile.big ? 8 : 3
            Text {
                text: tile.glyph
                color: tile.tint
                font.family: Theme.iconFont
                font.pixelSize: tile.big ? 24 : 16
                visible: tile.big
            }
            Text {
                text: tile.label
                color: Theme.text; opacity: 0.92
                font.family: Theme.fontText; font.pixelSize: 14; font.weight: Font.DemiBold
            }
            Text {
                width: parent.width
                text: tile.sub
                visible: text !== ""
                color: Theme.text; opacity: 0.38
                font.family: Theme.iconFont; font.pixelSize: 10
                elide: Text.ElideRight
            }
        }
        HoverHandler { id: tHov; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: tile.activated() }
    }

    SectionHeader {
        id: head
        anchors { left: parent.left; right: parent.right; top: parent.top }
        label: "Capture"
        tint: root.hue
        Text {
            text: RecorderService.recording ? "● REC " + RecorderService.display() : "PRINT · SUPER+PRINT"
            color: RecorderService.recording ? root.live : Theme.text
            opacity: RecorderService.recording ? 0.95 : 0.35
            font.family: Theme.fontText
            font.pixelSize: Theme.fsSection
            font.letterSpacing: Theme.trSection
        }
    }

    Item {
        id: cols
        anchors { left: parent.left; right: parent.right; top: head.bottom; bottom: parent.bottom; topMargin: 16 }
        readonly property real colW: (width - 16) / 2

        Item {
            id: recCol
            width: cols.colW
            height: parent.height

            Column {
                anchors.fill: parent
                spacing: 10
                visible: !RecorderService.recording

                Row {
                    width: parent.width
                    spacing: 10
                    Tile {
                        width: (parent.width - 10) / 2; height: 118
                        glyph: "󰹑"; label: "Screen"
                        sub: "Whole monitor"
                        tint: root.live
                        onActivated: root.afterClose(root.scripts + "record-screen.sh")
                    }
                    Tile {
                        width: (parent.width - 10) / 2; height: 118
                        glyph: "󰩭"; label: "Region"
                        sub: "Drag a rectangle"
                        tint: root.live
                        onActivated: root.afterClose(root.scripts + "record-region.sh")
                    }
                }

                Rectangle {
                    width: parent.width; height: 46; radius: 10
                    color: Theme.surfaceRecess
                    border.width: 1; border.color: aHov.hovered ? Theme.grooveLight : Theme.grooveDark
                    Text {
                        id: aGlyph
                        anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                        text: RecorderService.withAudio ? "󰕾" : "󰖁"
                        color: root.hue; opacity: 0.75
                        font.family: Theme.iconFont; font.pixelSize: 15
                    }
                    Column {
                        anchors { left: aGlyph.right; leftMargin: 11; verticalCenter: parent.verticalCenter }
                        spacing: 2
                        Text { text: "System audio"; color: Theme.text; opacity: 0.88
                               font.family: Theme.iconFont; font.pixelSize: 12 }
                        Text { text: RecorderService.withAudio ? "What you hear goes in" : "Silent video"
                               color: Theme.text; opacity: 0.32
                               font.family: Theme.iconFont; font.pixelSize: 9 }
                    }
                    Rectangle {
                        id: sw
                        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        width: 40; height: 22; radius: 11
                        color: RecorderService.withAudio ? Theme.withAlpha(root.hue, 0.85) : Theme.shade(Theme.surfaceSunk, 0.22)
                        border.width: 1
                        border.color: RecorderService.withAudio ? Theme.withAlpha(root.hue, 0.9) : Qt.rgba(0, 0, 0, 0.30)
                        Behavior on color { ColorAnimation { duration: 180 } }
                        Rectangle {
                            y: 3; x: RecorderService.withAudio ? sw.width - width - 3 : 3
                            width: 16; height: 16; radius: 8
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Theme.lift(Theme.ground, 0.30) }
                                GradientStop { position: 1.0; color: Theme.ground }
                            }
                            Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                        }
                    }
                    HoverHandler { id: aHov; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: RecorderService.withAudio = !RecorderService.withAudio }
                }

                Text {
                    width: parent.width
                    text: "Stops with the same key that started it, or from here."
                    wrapMode: Text.WordWrap
                    color: Theme.text; opacity: 0.28
                    font.family: Theme.fontText; font.pixelSize: 11
                }
            }

            Rectangle {
                anchors.fill: parent
                visible: RecorderService.recording
                radius: 14
                color: Theme.surfaceRecess
                border.width: 1; border.color: Theme.withAlpha(root.live, 0.30)
                Rectangle {
                    anchors.fill: parent; anchors.margins: 1; radius: 13
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: Theme.withAlpha(root.live, 0.10) }
                    }
                }
                Column {
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
                    spacing: 6
                    Row {
                        spacing: 10
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 12; height: 12; radius: 6
                            color: root.live
                            SequentialAnimation on opacity {
                                running: RecorderService.recording && !Theme.reducedMotion
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.3; duration: 700; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
                            }
                        }
                        Text {
                            text: RecorderService.display()
                            color: Theme.text
                            font.family: Theme.fontMono; font.pixelSize: 38; font.weight: Font.DemiBold
                        }
                    }
                    Text {
                        text: RecorderService.scope + "  ·  " + RecorderService.detail
                              + (RecorderService.withAudio ? "  ·  audio" : "")
                        color: Theme.text; opacity: 0.45
                        font.family: Theme.iconFont; font.pixelSize: 11
                    }
                }
                Tile {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 14 }
                    height: 58
                    big: false
                    label: "󰓛  Stop and save"
                    sub: "SUPER+PRINT does the same"
                    tint: root.live
                    onActivated: RecorderService.stop()
                }
            }
        }

        Column {
            x: cols.colW + 16
            width: cols.colW
            height: parent.height
            spacing: 10

            Tile {
                width: parent.width; height: 74
                big: false
                label: "󰄀  Screenshot"
                sub: "Opens the editor with the crop tool · PRINT"
                onActivated: root.afterClose(root.scripts + "screenshot.sh")
            }

            Item {
                width: parent.width; height: 14
                SectionHeader {
                    anchors.fill: parent
                    label: "Recent"
                    tint: root.hue
                    Text {
                        text: "FOLDER ↗"
                        color: root.hue; opacity: fHov.hovered ? 1 : 0.6
                        font.family: Theme.fontText
                        font.pixelSize: Theme.fsSection
                        font.letterSpacing: Theme.trSection
                        HoverHandler { id: fHov; cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: {
                                Quickshell.execDetached(["xdg-open", RecorderService.videoDir])
                                root.requestClose()
                            }
                        }
                    }
                }
            }

            Repeater {
                model: RecorderService.recent
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: parent.width; height: 34; radius: 8
                    color: rHov.hovered ? Qt.rgba(1, 1, 1, 0.045) : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Text {
                        id: rg
                        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                        text: "󰈫"
                        color: root.hue; opacity: index === 0 ? 0.9 : 0.5
                        font.family: Theme.iconFont; font.pixelSize: 13
                    }
                    Text {
                        anchors { left: rg.right; leftMargin: 10; right: meta.left; rightMargin: 10
                                  verticalCenter: parent.verticalCenter }
                        text: modelData.name
                        elide: Text.ElideMiddle
                        color: Theme.text; opacity: 0.8
                        font.family: Theme.iconFont; font.pixelSize: 11
                    }
                    Text {
                        id: meta
                        anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                        text: modelData.when + "  ·  " + modelData.size
                        color: Theme.text; opacity: 0.32
                        font.family: Theme.iconFont; font.pixelSize: 10
                    }
                    HoverHandler { id: rHov; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: {
                            Quickshell.execDetached(["xdg-open", modelData.file])
                            root.requestClose()
                        }
                    }
                }
            }

            Text {
                visible: RecorderService.recent.length === 0
                text: "Nothing recorded yet"
                color: Theme.text; opacity: 0.3
                font.family: Theme.fontText; font.pixelSize: 12
            }
        }
    }
}
