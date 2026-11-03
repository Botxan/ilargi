import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "../shapes"
import "../components"
import "../modules/Center"
import "../services"
import "../theme"
import "../state"

Item {
    id: root

    readonly property int fw: Theme.borderWidth + Theme.cornerRadius
    readonly property int fh: Theme.borderWidth + Theme.cornerRadius
    readonly property int bodyWidth:  Theme.aperturePanelWidth
    readonly property int bodyHeight: Theme.aperturePanelHeight

    readonly property bool open: Popups.apertureOpen
    readonly property real panelW: bodyWidth
    readonly property real panelH: bodyHeight
    visible: open || hold.running
    onOpenChanged: if (!open) hold.restart()
    Timer {
        id: hold
        interval: Theme.animTransition + 40
        onTriggered: if (!Popups.apertureOpen) Popups.apertureRoom = ""
    }

    IpcHandler {
        target: "aperture-toggle"
        function toggle() {
            var next = !Popups.apertureOpen
            Popups.closeAll()
            Popups.apertureOpen = next
        }
        function dnd() { Theme.set("dnd", !Theme.dnd) }
        function launcher() {
            var next = !Popups.launcherOpen
            Popups.closeAll()
            Popups.launcherOpen = next
        }
        function room(name: string) {
            if (!Popups.apertureOpen) { Popups.closeAll(); Popups.apertureOpen = true }
            Popups.apertureRoom = (Popups.apertureRoom === name) ? "" : name
        }
    }

    Timer {
        id: focusTimer
        interval: 60
        onTriggered: sizer.forceActiveFocus()
    }
    Connections {
        target: Popups
        function onApertureOpenChanged() { if (Popups.apertureOpen) focusTimer.restart() }
    }

    Item {
        id: sizer
        focus: true
        x: -root.fw
        y: Theme.borderWidth - root.fh
        width: root.bodyWidth + root.fw * 2
        height: root.bodyHeight + root.fh

        Item {
            id: body
            anchors.fill: parent
            anchors.leftMargin: root.fw
            anchors.rightMargin: root.fw
            anchors.topMargin: root.fh
            clip: true
            opacity: root.open ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: root.open ? Theme.animContentIn : Theme.animContentOut }
            }

            Rectangle {
                anchors.fill: parent
                topLeftRadius: 0
                topRightRadius: 0
                bottomLeftRadius: Theme.cornerRadius
                bottomRightRadius: Theme.cornerRadius
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.lift(Theme.ground, 0.023) }
                    GradientStop { position: 0.55; color: Theme.ground }
                    GradientStop { position: 1.0; color: Theme.shade(Theme.ground, 0.10) }
                }
            }

            Item {
                anchors.fill: parent
                opacity: 0.5
                visible: Theme.causticsEnabled && Theme.ambientMotion

            }

            ChassisPlate {
                id: plate
                x: Theme.chassisRail
                y: Theme.plateInsetTop
                width:  body.width - Theme.chassisRail * 2
                height: body.height - Theme.plateInsetTop - Theme.plateInsetBottom
                fillTop:    Theme.withAlpha(Theme.shade(Theme.surfaceWell, 0.24), 0.95)
                fillBottom: Theme.withAlpha(Theme.surfaceWell, 0.93)
                scoopGlow: root.activeHue
                scoopGlowStrength: 0
                Behavior on scoopGlowStrength { NumberAnimation { duration: 300 } }
            }

            Repeater {
                model: 2
                delegate: Item {
                    required property int index
                    readonly property real cx: index === 0
                        ? Theme.dialCx : body.width - Theme.dialCx - 1
                    x: cx - 6
                    y: Theme.dialCy + Theme.apertureDialSize / 2 + 12
                    width: 13
                    height: body.height - 2 * (Theme.dialCy + Theme.apertureDialSize / 2 + 12)

                    Rule {
                        x: 6
                        width: 1
                        height: parent.height
                        vertical: true
                        tint: Qt.rgba(1, 1, 1, 0.06)
                        fade: 0.10
                    }
                    Repeater {
                        model: 3
                        delegate: Rectangle {
                            required property int index
                            x: index === 1 ? 2 : 4
                            y: Math.round(parent.height * (0.32 + index * 0.18))
                            width: index === 1 ? 9 : 5
                            height: 1
                            color: Qt.rgba(1, 1, 1, index === 1 ? 0.12 : 0.07)
                        }
                    }
                }
            }

            Item {
                id: floor
                anchors.fill: parent
                anchors.leftMargin:   Theme.plateGutterX
                anchors.rightMargin:  Theme.plateGutterX
                anchors.topMargin:    Theme.plateGutterY
                anchors.bottomMargin: Theme.plateGutterY

                opacity: Popups.apertureRoom === "" ? 1 : 0
                scale:   Popups.apertureRoom === "" ? 1 : 0.985
                visible: opacity > 0.01
                Behavior on opacity {
                    SequentialAnimation {
                        PauseAnimation { duration: Popups.apertureRoom === "" ? 170 : 0 }
                        NumberAnimation { duration: Popups.apertureRoom === "" ? 260 : 160 }
                    }
                }
                Behavior on scale { NumberAnimation { duration: 420; easing.type: Easing.OutExpo } }

                SectionHeader {
                    id: feedHead
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    label: NotificationService.count > 0
                        ? "Feed · " + NotificationService.count
                        : "Feed"
                    tint: Theme.accent

                    Row {
                        spacing: 7

                        Rectangle {
                            width: dndText.implicitWidth + 18
                            height: 18
                            radius: 5
                            color: Theme.dnd ? Theme.withAlpha(Theme.accent, 0.18)
                                             : (dndHov.hovered ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.035))
                            border.width: 1
                            border.color: Theme.dnd ? Theme.withAlpha(Theme.accent, 0.45) : Qt.rgba(1,1,1,0.08)
                            Behavior on color { ColorAnimation { duration: 180 } }

                            Text {
                                id: dndText
                                anchors.centerIn: parent
                                text: Theme.dnd ? "COPPERCLOUD ON" : "COPPERCLOUD"
                                color: Theme.dnd ? Theme.accent : Theme.text
                                opacity: Theme.dnd ? 1 : 0.45
                                font.family: Theme.fontText
                                font.pixelSize: Theme.fsSection
                                font.letterSpacing: Theme.trSection
                            }
                            HoverHandler { id: dndHov; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: Theme.set("dnd", !Theme.dnd) }
                        }

                        Rectangle {
                            visible: NotificationService.count > 0
                            width: clearText.implicitWidth + 18
                            height: 18
                            radius: 5
                            color: clearHov.hovered ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.035)
                            border.width: 1
                            border.color: Qt.rgba(1,1,1,0.08)
                            Behavior on color { ColorAnimation { duration: 180 } }

                            Text {
                                id: clearText
                                anchors.centerIn: parent
                                text: "CLEAR ALL"
                                color: Theme.text
                                opacity: 0.45
                                font.family: Theme.fontText
                                font.pixelSize: Theme.fsSection
                                font.letterSpacing: Theme.trSection
                            }
                            HoverHandler { id: clearHov; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: NotificationService.clearAll() }
                        }
                    }
                }

                ListView {
                    id: feedList
                    anchors { left: parent.left; right: parent.right
                              top: feedHead.bottom; bottom: parent.bottom
                              topMargin: 11 }
                    clip: true
                    spacing: 7
                    model: NotificationService.all
                    boundsBehavior: Flickable.StopAtBounds

                    remove: Transition {
                        ParallelAnimation {
                            NumberAnimation { property: "opacity"; to: 0; duration: 160 }
                            NumberAnimation { property: "x"; to: feedList.width * 0.4; duration: 200; easing.type: Easing.OutCubic }
                        }
                    }
                    removeDisplaced: Transition {
                        NumberAnimation { properties: "x,y"; duration: 260; easing.type: Easing.OutCubic }
                    }
                    displaced: Transition {
                        NumberAnimation { properties: "x,y"; duration: 260; easing.type: Easing.OutCubic }
                    }
                    add: Transition {
                        ParallelAnimation {
                            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 }
                            NumberAnimation { property: "y"; from: -14; duration: 300; easing.type: Easing.OutCubic }
                        }
                    }

                    delegate: NotifCard {
                        required property var modelData
                        width: feedList.width
                        notif: modelData
                        onDismissed: NotificationService.dismiss(modelData)
                    }
                }

                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 28
                    visible: NotificationService.count > 0
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: Theme.surfaceWell }
                    }
                }

                Item {
                    anchors.centerIn: parent
                    width: 240
                    height: 150
                    visible: NotificationService.count === 0

                    Item {
                        id: emptyMark
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        width: 66
                        height: 66

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: "transparent"
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.07)
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            width: 46; height: 46; radius: 23
                            color: Qt.rgba(1, 1, 1, 0.022)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.05)
                        }
                        Text {
                            anchors.centerIn: parent
                            text: Theme.dnd ? "󰂛" : "󰂚"
                            font.family: Theme.iconFont
                            font.pixelSize: 21
                            color: Theme.accent
                            opacity: 0.42
                        }
                    }

                    Column {
                        anchors { top: emptyMark.bottom; topMargin: 16
                                  left: parent.left; right: parent.right }
                        spacing: 7

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Theme.dnd ? "COPPERCLOUD IS UP" : "NOTHING WAITING"
                            color: Theme.text
                            opacity: 0.42
                            font.family: Theme.fontText
                            font.pixelSize: Theme.fsSection
                            font.letterSpacing: Theme.trSection
                        }
                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            text: Theme.dnd
                                ? "Toasts are suppressed. Anything that arrives still lands here."
                                : "Notifications collect here and stay until you clear them."
                            color: Theme.text
                            opacity: 0.24
                            font.family: Theme.fontText
                            font.pixelSize: 10
                        }
                    }
                }
            }

            Repeater {
                model: Theme.apertureRooms
                delegate: ApertureRoom {
                    id: roomItem
                    required property var modelData
                    room: modelData
                    open: Popups.apertureOpen && Popups.apertureRoom === modelData.key

                    Loader {
                        anchors.fill: parent
                        active: roomItem.open
                        sourceComponent: {
                            switch (roomItem.modelData.key) {
                            case "media":  return mediaRoom
                            case "vitals": return vitalsRoom
                            case "capture": return captureRoom
                            case "displays": return displaysRoom
                            default:       return stubRoom
                            }
                        }

                        readonly property var roomData: roomItem.modelData
                    }
                }
            }

            Repeater {
                model: Theme.apertureRooms
                delegate: Item {
                    id: dialBtn
                    required property var modelData

                    readonly property bool leftSide: modelData.corner === "tl" || modelData.corner === "bl"
                    readonly property bool topSide:  modelData.corner === "tl" || modelData.corner === "tr"
                    readonly property bool selected: Popups.apertureRoom === modelData.key
                    readonly property real cx: leftSide ? Theme.dialCx : body.width - Theme.dialCx
                    readonly property real cy: topSide  ? Theme.dialCy : body.height - Theme.dialCy

                    width: Theme.apertureDialSize
                    height: Theme.apertureDialSize
                    x: cx - width / 2
                    y: cy - height / 2

                    opacity: (Popups.apertureRoom !== "" && !selected) ? 0.5 : 1
                    Behavior on opacity { NumberAnimation { duration: 260 } }

                    scale: btnHov.hovered ? 1.07 : 1
                    Behavior on scale {
                        NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2.4 }
                    }

                    Rectangle {
                        id: face
                        anchors.fill: parent
                        radius: width / 2
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Theme.lift(Theme.ground, 0.085) }
                            GradientStop { position: 1.0; color: Theme.shade(Theme.ground, 0.16) }
                        }
                        border.width: 1
                        border.color: btnHov.hovered
                            ? Theme.withAlpha(dialBtn.modelData.hue, 0.55)
                            : Theme.withAlpha(dialBtn.modelData.hue, 0.26)
                        Behavior on border.color { ColorAnimation { duration: 180 } }
                    }

                    Rectangle {
                        id: litFace
                        anchors.fill: parent
                        radius: width / 2
                        opacity: dialBtn.selected ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 260 } }
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Theme.lift(dialBtn.modelData.hue, 0.22) }
                            GradientStop { position: 1.0; color: Theme.shade(dialBtn.modelData.hue, 0.14) }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: width / 2
                        color: "transparent"
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, dialBtn.selected ? 0.18 : 0.055)
                        Behavior on border.color { ColorAnimation { duration: 260 } }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 0
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: dialBtn.modelData.glyph
                            font.family: Theme.iconFont
                            font.pixelSize: 17
                            color: dialBtn.selected ? Theme.shade(dialBtn.modelData.hue, 0.72)
                                                    : dialBtn.modelData.hue
                            Behavior on color { ColorAnimation { duration: 240 } }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: dialBtn.modelData.label.toUpperCase()
                            font.family: Theme.iconFont
                            font.pixelSize: 8
                            font.letterSpacing: 0.7
                            color: dialBtn.selected ? Theme.shade(dialBtn.modelData.hue, 0.72)
                                                    : dialBtn.modelData.hue
                            opacity: dialBtn.selected ? 0.75 : 0.62
                            Behavior on color { ColorAnimation { duration: 240 } }
                        }
                    }

                    Rectangle {
                        id: ring
                        anchors.centerIn: parent
                        width: parent.width + 10; height: width
                        radius: width / 2
                        color: "transparent"
                        border.width: 1
                        border.color: dialBtn.modelData.hue
                        opacity: 0
                        scale: 0.8
                    }
                    SequentialAnimation {
                        id: ringFire
                        ScriptAction { script: { ring.opacity = 0.9; ring.scale = 0.8 } }
                        ParallelAnimation {
                            NumberAnimation { target: ring; property: "scale"; to: 1.9; duration: 560; easing.type: Easing.OutExpo }
                            NumberAnimation { target: ring; property: "opacity"; to: 0; duration: 560; easing.type: Easing.OutQuad }
                        }
                    }
                    onSelectedChanged: if (selected && !Theme.reducedMotion) ringFire.restart()

                    Rectangle {
                        id: tip
                        x: dialBtn.leftSide ? parent.width + 10 : -width - 10
                        y: (parent.height - height) / 2
                        width: tipText.implicitWidth + 16
                        height: 20
                        radius: 6
                        color: Theme.withAlpha(Theme.shade(Theme.ground, 0.45), 0.94)
                        border.width: 1
                        border.color: Theme.withAlpha(dialBtn.modelData.hue, 0.35)
                        opacity: btnHov.hovered ? 1 : 0
                        visible: opacity > 0.01
                        Behavior on opacity { NumberAnimation { duration: 160 } }

                        Text {
                            id: tipText
                            anchors.centerIn: parent
                            text: dialBtn.selected ? "Back to feed" : dialBtn.modelData.label
                            color: dialBtn.modelData.hue
                            font.family: Theme.fontText
                            font.pixelSize: 10
                        }
                    }

                    HoverHandler { id: btnHov; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: Popups.apertureRoom =
                            (Popups.apertureRoom === dialBtn.modelData.key) ? "" : dialBtn.modelData.key
                    }
                }
            }
}

        Keys.onEscapePressed: {
            if (Popups.apertureRoom !== "") Popups.apertureRoom = ""
            else Popups.apertureOpen = false
        }
    }

    Component {
        id: stubRoom
        Column {
            spacing: 10
            Text {
                text: roomData.label
                color: roomData.hue
                font.family: Theme.iconFont
                font.pixelSize: 17
                font.weight: Font.DemiBold
            }
            Text {
                text: "Room chassis only — content lands in a later step."
                color: Theme.text
                opacity: 0.4
                font.family: Theme.fontText
                font.pixelSize: 12
            }
        }
    }

    Component {
        id: mediaRoom

        Item {
            id: media
            readonly property color hue: Qt.color("#6791c9")

            Column {
                anchors.centerIn: parent
                spacing: 7
                visible: !MediaService.hasPlayer
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "NO PLAYER"
                    color: media.hue; opacity: 0.55
                    font.family: Theme.fontText
                    font.pixelSize: Theme.fsSection
                    font.letterSpacing: Theme.trSection
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Anything speaking MPRIS shows up here — browser tabs included."
                    color: Theme.text; opacity: 0.28
                    font.family: Theme.fontText
                    font.pixelSize: 11
                }
            }

            Column {
                anchors.fill: parent
                spacing: 0
                visible: MediaService.hasPlayer

                SectionHeader {
                    width: parent.width
                    label: "Now playing"
                    tint: media.hue

                    Repeater {
                        model: MediaService.players.length > 1 ? MediaService.players : []
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool sel: MediaService.active === modelData
                            width: chipText.implicitWidth + 16
                            height: 16
                            radius: 4
                            color: sel ? Theme.withAlpha(media.hue, 0.16) : Qt.rgba(1, 1, 1, 0.04)
                            border.width: 1
                            border.color: sel ? Theme.withAlpha(media.hue, 0.42) : Qt.rgba(1, 1, 1, 0.08)
                            Behavior on color { ColorAnimation { duration: 160 } }

                            Text {
                                id: chipText
                                anchors.centerIn: parent
                                text: (modelData.identity !== "" ? modelData.identity : modelData.dbusName).toUpperCase()
                                color: sel ? media.hue : Theme.text
                                opacity: sel ? 0.95 : 0.42
                                font.family: Theme.iconFont
                                font.pixelSize: 8
                                font.letterSpacing: 0.9
                            }
                            HoverHandler { id: cHov; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: MediaService.pinnedId = modelData.dbusName }
                        }
                    }
                }

                Item { width: 1; height: 9 }

                Row {
                    width: parent.width
                    height: 186
                    spacing: 18

                    Item {
                        width: 186
                        height: 186

                        Rectangle {
                            id: artBox
                            anchors.fill: parent
                            radius: 14
                            color: Theme.surfaceSunk
                            border.width: 1
                            border.color: Theme.grooveDark
                            clip: true

                            Image {
                                id: art
                                anchors.fill: parent
                                source: MediaService.artUrl
                                visible: status === Image.Ready
                                fillMode: Image.PreserveAspectCrop
                                smooth: true
                                asynchronous: true
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: art.status !== Image.Ready
                                text: "󰝚"
                                font.family: Theme.iconFont
                                font.pixelSize: 42
                                color: media.hue
                                opacity: 0.3
                            }
                        }
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 1
                            radius: 13
                            color: "transparent"
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.09)
                        }
                    }

                    Item {
                        width: parent.width - 186 - parent.spacing
                        height: parent.height

                        Column {
                            id: meta
                            anchors { left: parent.left; right: parent.right; top: parent.top }
                            spacing: 4

                            Text {
                                width: parent.width
                                text: MediaService.title !== "" ? MediaService.title : "Unknown track"
                                color: Theme.text
                                font.family: Theme.fontText
                                font.pixelSize: 20
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                maximumLineCount: 2
                                wrapMode: Text.WordWrap
                            }
                            Text {
                                width: parent.width
                                text: MediaService.artist
                                visible: text !== ""
                                color: media.hue
                                opacity: 0.8
                                font.family: Theme.iconFont
                                font.pixelSize: 13
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                text: MediaService.album
                                visible: text !== ""
                                color: Theme.text
                                opacity: 0.3
                                font.family: Theme.iconFont
                                font.pixelSize: 11
                                elide: Text.ElideRight
                            }
                        }

                        Column {
                            id: scrubBlock
                            anchors { left: parent.left; right: parent.right; bottom: transport.top
                                      bottomMargin: 16 }
                            spacing: 6

                            Item {
                                width: parent.width
                                height: 14

                                Rectangle {
                                    id: track
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width
                                    height: scrubHov.hovered || scrubDrag.active ? 6 : 4
                                    radius: height / 2
                                    color: Theme.shade(Theme.surfaceSunk, 0.35)
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.10)
                                    Behavior on height { NumberAnimation { duration: 140 } }

                                    Rectangle {
                                        x: 1; y: 1
                                        width: Math.max(0, (parent.width - 2) * MediaService.progress)
                                        height: parent.height - 2
                                        radius: height / 2
                                        gradient: Gradient {
                                            orientation: Gradient.Horizontal
                                            GradientStop { position: 0.0; color: Theme.withAlpha(media.hue, 0.55) }
                                            GradientStop { position: 1.0; color: media.hue }
                                        }
                                    }
                                    Rectangle {
                                        x: parent.width * MediaService.progress - width / 2
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: scrubHov.hovered || scrubDrag.active ? 12 : 0
                                        height: width; radius: width / 2
                                        color: media.hue
                                        border.width: 2
                                        border.color: Theme.shade(Theme.ground, 0.4)
                                        Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
                                    }
                                }

                                HoverHandler {
                                    id: scrubHov
                                    cursorShape: MediaService.active && MediaService.active.canSeek
                                        ? Qt.PointingHandCursor : Qt.ArrowCursor
                                }
                                DragHandler {
                                    id: scrubDrag
                                    target: null
                                    xAxis.enabled: true
                                    yAxis.enabled: false
                                    onCentroidChanged: if (active)
                                        MediaService.seekFraction(centroid.position.x / width)
                                }
                                TapHandler {
                                    onTapped: function (pt) {
                                        MediaService.seekFraction(pt.position.x / width)
                                    }
                                }
                            }

                            Item {
                                width: parent.width
                                height: 12
                                Text {
                                    anchors.left: parent.left
                                    text: MediaService.fmt(MediaService.pos)
                                    color: Theme.text; opacity: 0.45
                                    font.family: Theme.iconFont; font.pixelSize: 10
                                }
                                Text {
                                    anchors.right: parent.right
                                    text: MediaService.fmt(MediaService.length)
                                    color: Theme.text; opacity: 0.45
                                    font.family: Theme.iconFont; font.pixelSize: 10
                                }
                            }
                        }

                        Row {
                            id: transport
                            anchors { left: parent.left; bottom: parent.bottom }
                            spacing: 12

                            Repeater {
                                model: [
                                    { g: "󰒮", act: "previous", big: false },
                                    { g: "󰐊", act: "toggle",   big: true  },
                                    { g: "󰒭", act: "next",     big: false }
                                ]
                                delegate: Item {
                                    id: tBtn
                                    required property var modelData
                                    readonly property bool big: modelData.big
                                    width: big ? 44 : 34
                                    height: width

                                    scale: tHov.hovered ? 1.09 : 1
                                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: width / 2
                                        gradient: Gradient {
                                            GradientStop {
                                                position: 0.0
                                                color: tBtn.big ? Theme.lift(media.hue, 0.20)
                                                                : Theme.lift(Theme.ground, 0.085)
                                            }
                                            GradientStop {
                                                position: 1.0
                                                color: tBtn.big ? Theme.shade(media.hue, 0.14)
                                                                : Theme.shade(Theme.ground, 0.16)
                                            }
                                        }
                                        border.width: 1
                                        border.color: tBtn.big ? "transparent"
                                            : (tHov.hovered ? Theme.withAlpha(media.hue, 0.5)
                                                            : Qt.rgba(1, 1, 1, 0.10))
                                        Behavior on border.color { ColorAnimation { duration: 160 } }

                                        Rectangle {
                                            anchors.fill: parent
                                            anchors.margins: 1
                                            radius: width / 2
                                            color: "transparent"
                                            border.width: 1
                                            border.color: Qt.rgba(1, 1, 1, tBtn.big ? 0.20 : 0.05)
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: tBtn.modelData.act === "toggle"
                                            ? (MediaService.playing ? "󰏤" : "󰐊")
                                            : tBtn.modelData.g
                                        font.family: Theme.fontText
                                        font.pixelSize: tBtn.big ? 17 : 13
                                        color: tBtn.big ? Theme.shade(media.hue, 0.72) : Theme.text
                                        opacity: tBtn.big ? 1 : 0.78
                                    }

                                    HoverHandler { id: tHov; cursorShape: Qt.PointingHandCursor }
                                    TapHandler {
                                        onTapped: {
                                            if (tBtn.modelData.act === "toggle") MediaService.toggle()
                                            else if (tBtn.modelData.act === "next") MediaService.next()
                                            else MediaService.previous()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Item { width: 1; height: 18 }

                SectionHeader {
                    width: parent.width
                    label: "Spectrum"
                    tint: media.hue

                    Text {
                        text: CavaService.available ? "CAVA · 42 BANDS" : "UNAVAILABLE"
                        color: Theme.text
                        opacity: 0.3
                        font.family: Theme.fontText
                        font.pixelSize: Theme.fsSection
                        font.letterSpacing: Theme.trSection
                    }
                }

                Item { width: 1; height: 9 }

                Rectangle {
                    width: parent.width
                    height: 176
                    radius: 12
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Theme.shade(Theme.surfaceSunk, 0.10) }
                        GradientStop { position: 1.0; color: Theme.surfaceSunk }
                    }
                    border.width: 1
                    border.color: Theme.grooveDark
                    clip: true

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

                    Rule {
                        anchors { left: parent.left; right: parent.right
                                  verticalCenter: parent.verticalCenter
                                  leftMargin: 16; rightMargin: 16 }
                        tint: Theme.withAlpha(media.hue, 0.16)
                        fade: 0.08
                    }

                    Repeater {
                        model: 5
                        delegate: Rule {
                            required property int index
                            x: 16 + (parent.width - 32) * (index + 1) / 6
                            y: 18
                            width: 1
                            height: parent.height - 36
                            vertical: true
                            tint: Qt.rgba(1, 1, 1, 0.035)
                            fade: 0.22
                        }
                    }

                    Spectrum {
                        anchors { fill: parent; leftMargin: 16; rightMargin: 16
                                  topMargin: 14; bottomMargin: 14 }
                        tint: media.hue
                    }
                }
            }

            Component.onCompleted:  CavaService.wanted = true
            Component.onDestruction: CavaService.wanted = false
        }
    }

    Component {
        id: vitalsRoom

        Item {
            id: vitals
            readonly property color hue: Qt.color("#6791c9")
            readonly property var t: SysStatsService.temps

            function tempColor(v, warn, crit) {
                if (v === undefined) return Theme.text
                if (v >= crit) return Qt.color("#df5b61")
                if (v >= warn) return Qt.color("#de8f78")
                return Qt.color("#78b892")
            }

            Column {
                anchors.fill: parent
                spacing: 0
                visible: SysStatsService.haveSample

                SectionHeader {
                    width: parent.width
                    label: "Timeline"
                    tint: vitals.hue

                    Rectangle {
                        width: liveText.implicitWidth + 14
                        height: 15
                        radius: 4
                        color: Theme.withAlpha(vitals.hue, 0.12)
                        border.width: 1
                        border.color: Theme.withAlpha(vitals.hue, 0.28)
                        Text {
                            id: liveText
                            anchors.centerIn: parent
                            text: "60 SECONDS"
                            color: vitals.hue
                            opacity: 0.85
                            font.family: Theme.iconFont
                            font.pixelSize: 8
                            font.letterSpacing: 1.1
                        }
                    }
                }

                Item { width: 1; height: 9 }

                Scope {
                    width: parent.width
                    height: 162
                    tint: vitals.hue
                }

                Item { width: 1; height: 16 }

                SectionHeader {
                    width: parent.width
                    label: "Silicon"
                    tint: vitals.hue

                    Text {
                        text: SysStatsService.gpu ? SysStatsService.gpu.name : ""
                        color: Theme.text; opacity: 0.3
                        font.family: Theme.iconFont
                        font.pixelSize: 9
                        font.letterSpacing: 0.5
                    }
                }

                Item { width: 1; height: 9 }

                Row {
                    id: instruments
                    width: parent.width
                    height: 130
                    spacing: 10

                    readonly property real gaugeW: (width - 170 - spacing * 3) / 3

                    Rectangle {
                        id: dieBox
                        width: 170
                        height: parent.height
                        radius: 12
                        color: Theme.surfaceRecess
                        border.width: 1
                        border.color: (vitals.t.pkg !== undefined && vitals.t.pkg >= 90)
                            ? Theme.withAlpha("#df5b61", 0.6)
                            : Theme.grooveDark
                        Behavior on border.color { ColorAnimation { duration: 400 } }

                        Rule {
                            anchors { top: parent.top; topMargin: 1; left: parent.left; right: parent.right
                                      leftMargin: 7; rightMargin: 7 }
                            tint: Theme.grooveDark; fade: 0.16
                        }
                        Rule {
                            anchors { bottom: parent.bottom; bottomMargin: 1; left: parent.left; right: parent.right
                                      leftMargin: 7; rightMargin: 7 }
                            tint: Theme.grooveLight; fade: 0.16
                        }

                        CpuDie {
                            anchors { fill: parent; margins: 11; bottomMargin: 30 }
                        }

                        Rule {
                            groove: true
                            anchors { left: parent.left; right: parent.right
                                      bottom: parent.bottom; bottomMargin: 26
                                      leftMargin: 11; rightMargin: 11 }
                        }

                        Item {
                            anchors { left: parent.left; right: parent.right
                                      bottom: parent.bottom
                                      leftMargin: 11; rightMargin: 11; bottomMargin: 8 }
                            height: 14
                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: "CPU · " + SysStatsService.cores.length + "C"
                                color: Theme.text; opacity: 0.45
                                font.family: Theme.fontText
                                font.pixelSize: Theme.fsSection
                                font.letterSpacing: Theme.trSection
                            }
                            Text {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: vitals.t.pkg !== undefined ? vitals.t.pkg + "°C" : "--"
                                color: vitals.tempColor(vitals.t.pkg, 80, 90)
                                font.family: Theme.iconFont; font.pixelSize: 12
                            }
                        }
                    }

                    ArcGauge {
                        height: parent.height
                        width: instruments.gaugeW
                        tint: vitals.hue
                        value: SysStatsService.gpu ? SysStatsService.gpu.util / 100 : 0
                        peak: SysStatsService.peakOf(SysStatsService.histGpu)
                        readout: SysStatsService.gpu ? SysStatsService.gpu.util + "%" : "--"
                        label: "GPU"
                        sub: SysStatsService.gpu
                            ? SysStatsService.gpu.temp + "°C · "
                              + Math.round(SysStatsService.gpu.memUsed / 1024 * 10) / 10 + "G"
                            : "no GPU data"
                    }
                    ArcGauge {
                        height: parent.height
                        width: instruments.gaugeW
                        tint: vitals.hue
                        value: SysStatsService.memFrac
                        peak: SysStatsService.peakOf(SysStatsService.histMem)
                        readout: Math.round(SysStatsService.memFrac * 100) + "%"
                        label: "MEMORY"
                        sub: SysStatsService.memUsedGb + " / " + SysStatsService.memTotalGb + "G"
                    }
                    ArcGauge {
                        height: parent.height
                        width: instruments.gaugeW
                        tint: vitals.hue
                        value: SysStatsService.netScale > 0
                            ? (SysStatsService.netRx + SysStatsService.netTx) / SysStatsService.netScale : 0
                        peak: 0
                        readout: (SysStatsService.netRx + SysStatsService.netTx).toFixed(1)
                        label: "NETWORK"
                        sub: "MB/s · up " + SysStatsService.fmtUptime(SysStatsService.uptime)
                    }
                }

                Item { width: 1; height: 16 }

                SectionHeader {
                    width: parent.width
                    label: "Thermal"
                    tint: vitals.hue

                    Text {
                        text: SysStatsService.peripherals.length > 0 ? "PERIPHERALS" : ""
                        color: Theme.text; opacity: 0.32
                        font.family: Theme.fontText
                        font.pixelSize: Theme.fsSection
                        font.letterSpacing: Theme.trSection
                    }
                }

                Item { width: 1; height: 9 }

                Row {
                    id: thermoRow
                    width: parent.width
                    height: 64
                    spacing: 10

                    readonly property int nPeriph: SysStatsService.peripherals.length
                    readonly property real periphWidth: nPeriph > 0 ? width * 0.5 : 0
                    readonly property real thermalWidth:
                        nPeriph > 0 ? width - periphWidth - spacing : width

                    Rectangle {
                        width: thermoRow.thermalWidth
                        height: parent.height
                        radius: 12
                        color: Theme.surfaceRecess
                        border.width: 1
                        border.color: Theme.grooveDark

                        Rule {
                            anchors { top: parent.top; topMargin: 1; left: parent.left; right: parent.right
                                      leftMargin: 7; rightMargin: 7 }
                            tint: Theme.grooveDark; fade: 0.16
                        }

                        Row {
                            id: thermals
                            anchors { fill: parent; leftMargin: 13; rightMargin: 13
                                      topMargin: 12; bottomMargin: 12 }
                            spacing: 14

                            readonly property var chans: {
                                var out = []
                                if (vitals.t.pkg !== undefined)
                                    out.push({ n: "CPU", v: vitals.t.pkg, warn: 80, crit: 90, ceil: 100 })
                                if (SysStatsService.gpu)
                                    out.push({ n: "GPU", v: SysStatsService.gpu.temp, warn: 78, crit: 87, ceil: 95 })
                                if (vitals.t.nvme !== undefined)
                                    out.push({ n: "NVME", v: vitals.t.nvme, warn: 60, crit: 72, ceil: 80 })
                                if (vitals.t.acpi !== undefined)
                                    out.push({ n: "BOARD", v: vitals.t.acpi, warn: 65, crit: 78, ceil: 90 })
                                return out
                            }

                            Repeater {
                                model: thermals.chans
                                delegate: ThermalBar {
                                    required property var modelData
                                    width: (thermals.width - thermals.spacing * (thermals.chans.length - 1))
                                           / Math.max(1, thermals.chans.length)
                                    height: thermals.height
                                    name: modelData.n
                                    value: modelData.v
                                    warnC: modelData.warn
                                    critC: modelData.crit
                                    ceilC: modelData.ceil
                                }
                            }
                        }
                    }

                    Row {
                        height: parent.height
                        spacing: 10
                        visible: thermoRow.nPeriph > 0

                        Repeater {
                            model: SysStatsService.peripherals
                            delegate: Rectangle {
                                id: periph
                                required property var modelData
                                readonly property color pc: modelData.pct <= 20 ? Qt.color("#df5b61")
                                    : (modelData.pct <= 40 ? Qt.color("#de8f78") : Qt.color("#78b892"))
                                width: (thermoRow.periphWidth - 10 * (thermoRow.nPeriph - 1))
                                       / Math.max(1, thermoRow.nPeriph)
                                height: thermoRow.height
                                radius: 12
                                color: Theme.surfaceRecess
                                border.width: 1
                                border.color: modelData.pct <= 20
                                    ? Theme.withAlpha("#df5b61", 0.45) : Theme.grooveDark

                                Rule {
                                    anchors { top: parent.top; topMargin: 1; left: parent.left; right: parent.right
                                              leftMargin: 7; rightMargin: 7 }
                                    tint: Theme.grooveDark; fade: 0.16
                                }

                                Row {
                                    anchors { fill: parent; leftMargin: 13; rightMargin: 13 }
                                    spacing: 10

                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 5; height: 26; radius: 2.5
                                        color: Theme.shade(Theme.surfaceSunk, 0.25)
                                        Rectangle {
                                            anchors.bottom: parent.bottom
                                            width: parent.width
                                            height: Math.max(3, parent.height * periph.modelData.pct / 100)
                                            radius: parent.radius
                                            color: periph.pc
                                            Behavior on height { NumberAnimation { duration: 500 } }
                                        }
                                    }

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - 5 - 10 - pctText.width - 10
                                        spacing: 2
                                        Text {
                                            width: parent.width
                                            text: periph.modelData.name
                                            color: Theme.text; opacity: 0.78
                                            font.family: Theme.iconFont; font.pixelSize: 10
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            text: periph.modelData.status.toUpperCase()
                                            color: Theme.text; opacity: 0.3
                                            font.family: Theme.fontText
                                            font.pixelSize: Theme.fsSection
                                            font.letterSpacing: Theme.trSection
                                        }
                                    }

                                    Text {
                                        id: pctText
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: periph.modelData.pct + "%"
                                        color: periph.pc
                                        font.family: Theme.iconFont; font.pixelSize: 14
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 7
                visible: !SysStatsService.haveSample
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "SAMPLING"
                    color: vitals.hue; opacity: 0.6
                    font.family: Theme.fontText
                    font.pixelSize: Theme.fsSection
                    font.letterSpacing: Theme.trSection
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "first frame lands within a second"
                    color: Theme.text; opacity: 0.28
                    font.family: Theme.fontText; font.pixelSize: 11
                }
            }
        }
    }

    Component {
        id: captureRoom
        CaptureRoom { onRequestClose: Popups.apertureOpen = false }
    }

    Component { id: displaysRoom; DisplaysRoom {} }

    property color activeHue: {
        var r = Theme.apertureRoomFor(Popups.apertureRoom)
        return r ? Qt.color(r.hue) : BarGeometry.centerHue
    }
    Behavior on activeHue { ColorAnimation { duration: 240 } }
}
