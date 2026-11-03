import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "../shapes"
import "../theme"
import "../state"
import "../services"
import "../components"

Item {
    id: root
    readonly property bool open: Popups.almanacOpen
    readonly property real panelW: sizerWidth - Theme.borderWidth
    readonly property real panelH: openHeight - fh * 2
    visible: open || hold.running
    onOpenChanged: if (!open) hold.restart()
    Timer {
        id: hold
        interval: Theme.animTransition + 40
        onTriggered: if (!Popups.almanacOpen) { Popups.almanacRoom = "day" }
    }

    readonly property int fw: Theme.borderWidth + Theme.cornerRadius
    readonly property int fh: Theme.borderWidth + Theme.cornerRadius

    readonly property real screenH: DisplayService.primaryScreen ? DisplayService.primaryScreen.height : 1080

    readonly property real openHeight: Math.round(screenH * 0.80) + fh * 2
    readonly property int  panelWidth:
        Math.max(Theme.almanacWidth, BarGeometry.rightMinPanelWidth)
    readonly property int  sizerWidth: panelWidth + fw

    readonly property int padL: 24
    readonly property int padR: fw + 12

    IpcHandler {
        target: "almanac-toggle"
        function toggle() {
            var next = !Popups.almanacOpen
            Popups.closeAll()
            Popups.almanacOpen = next
        }
        function room(name: string) {
            if (!Popups.almanacOpen) { Popups.closeAll(); Popups.almanacOpen = true }
            Popups.almanacRoom = name
        }
    }

    property real reveal: 0

    property color activeHue: Theme.almanacHue(Popups.almanacRoom)
    Behavior on activeHue {
        enabled: !Theme.reducedMotion
        ColorAnimation { duration: 380; easing.type: Easing.OutCubic }
    }

    SequentialAnimation {
        id: revealIn
        PauseAnimation { duration: Theme.almanacRevealDelay }
        NumberAnimation {
            target: root; property: "reveal"
            from: 0; to: 1
            duration: Theme.almanacReveal
            easing.type: Theme.animCurve
        }
    }
    NumberAnimation {
        id: revealOut
        target: root; property: "reveal"
        to: 0; duration: Theme.almanacCloseReveal
    }

    Connections {
        target: Popups
        function onAlmanacOpenChanged() {
            if (Popups.almanacOpen) {
                CalendarService.refresh()
                stage.leaving = ""
                stage.shown = Popups.almanacRoom
                stage.slide = 1
                root.reveal = 0
                revealOut.stop()
                revealIn.restart()
                if (Theme.reducedMotion) { revealIn.stop(); root.reveal = 1 }
            } else {
                revealIn.stop()
                revealOut.restart()
            }
        }
        function onAlmanacRoomChanged() {
            stage.moveTo(Popups.almanacRoom)
        }
    }

    Item {
        id: sizer
        x: 0
        y: -root.fh
        width: root.sizerWidth
        height: root.openHeight
        clip: true

        Item {
            id: clockHead
            anchors { left: parent.left; right: parent.right; top: parent.top
                      leftMargin: root.padL; rightMargin: root.padR; topMargin: root.fh + 16 }
            height: 92
            opacity: Theme.phase(root.reveal, 0, 0.3)
            property date now: new Date()
            Timer { interval: 1000; repeat: true; running: root.visible; triggeredOnStart: true
                    onTriggered: clockHead.now = new Date() }
            Row {
                id: clockRow
                anchors.horizontalCenter: parent.horizontalCenter
                y: 0
                spacing: 14
                Text { text: Qt.formatTime(clockHead.now, "hh"); color: Theme.text
                       font.family: Theme.fontText; font.pixelSize: 52; font.weight: Font.Bold
                       font.features: Theme.tabularNums }
                Text { text: ":"; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter
                       anchors.verticalCenterOffset: -3
                       font.family: Theme.fontText; font.pixelSize: 48; font.weight: Font.Bold }
                Text { text: Qt.formatTime(clockHead.now, "mm"); color: Theme.text
                       font.family: Theme.fontText; font.pixelSize: 52; font.weight: Font.Bold
                       font.features: Theme.tabularNums }
            }
            Text {
                anchors { horizontalCenter: parent.horizontalCenter; top: clockRow.bottom; topMargin: 2 }
                text: Qt.formatDate(clockHead.now, "dddd d MMMM")
                color: Theme.text
                font.family: Theme.fontText; font.pixelSize: 14; font.weight: Font.Medium
            }
        }

        Rectangle {
            anchors { left: parent.left; right: parent.right; top: rail.top; bottom: parent.bottom
                      leftMargin: root.padL - 12; rightMargin: root.padR - 12
                      topMargin: -12; bottomMargin: root.fh + 12 }
            radius: 16
            color: Theme.surfaceWell
            opacity: Theme.phase(root.reveal, 0, 0.3)
        }

        Rectangle {
            id: rail
            anchors {
                left: parent.left; right: parent.right; top: parent.top
                leftMargin: root.padL
                rightMargin: root.padR
                topMargin: root.fh + 16 + clockHead.height + 26
            }
            height: 48
            radius: 11
            color: Theme.surfaceRecess
            border.width: 0
            opacity: Theme.phase(root.reveal, 0.04, 0.3)

            Rule {
                anchors { bottom: parent.bottom; bottomMargin: 1; left: parent.left; right: parent.right
                          leftMargin: 6; rightMargin: 6 }
                tint: Theme.grooveLight; fade: 0.12
            }

            readonly property int segN: Theme.almanacRooms.length
            readonly property real segW: (width - 8 - 3 * (segN - 1)) / segN

            Rectangle {
                id: pip
                y: 4
                x: 4 + Math.max(0, rail.indexOfRoom()) * (rail.segW + 3)
                width: rail.segW
                height: parent.height - 8
                radius: 8
                color: Theme.withAlpha(root.activeHue, 0.20)
                border.width: 0
                Behavior on x {
                    enabled: !Theme.reducedMotion
                    NumberAnimation { duration: Theme.animTransition; easing.type: Theme.animCurve }
                }
            }

            function indexOfRoom() {
                var r = Theme.almanacRooms
                for (var i = 0; i < r.length; i++) if (r[i].key === Popups.almanacRoom) return i
                return 0
            }

            Row {
                x: 4
                y: 4
                height: parent.height - 8
                spacing: 3

                Repeater {
                    model: Theme.almanacRooms
                    delegate: Item {
                        id: seg
                        required property var modelData
                        readonly property bool sel: Popups.almanacRoom === modelData.key
                        readonly property color hue: Theme.almanacHue(modelData.key)
                        width: rail.segW
                        height: parent.height

                        Column {
                            anchors.centerIn: parent
                            spacing: 2
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: seg.modelData.glyph
                                color: seg.hue
                                opacity: seg.sel ? 1 : (segHov.hovered ? 0.78 : 0.50)
                                font.family: Theme.iconFont
                                font.pixelSize: 15
                                Behavior on opacity { NumberAnimation { duration: 140 } }
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: seg.modelData.label
                                color: seg.sel ? seg.hue : Theme.text
                                opacity: seg.sel ? 1 : (segHov.hovered ? 0.75 : 0.55)
                                font.family: Theme.fontText
                                font.pixelSize: 11; font.weight: Font.Medium
                                font.letterSpacing: Theme.trSection
                                Behavior on opacity { NumberAnimation { duration: 140 } }
                            }
                        }
                        HoverHandler { id: segHov; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: Popups.almanacRoom = seg.modelData.key }
                    }
                }
            }
        }

        Item {
            id: stage
            anchors {
                left: parent.left; right: parent.right; top: rail.bottom; bottom: parent.bottom
                leftMargin: root.padL
                rightMargin: root.padR
                topMargin: 18
                bottomMargin: root.fh + 24
            }
            clip: true

            property string shown: ""
            property string leaving: ""
            property int dir: 1
            property real slide: 1

            Component.onCompleted: stage.shown = Popups.almanacRoom

            function indexOf(key) {
                var r = Theme.almanacRooms
                for (var i = 0; i < r.length; i++) if (r[i].key === key) return i
                return 0
            }
            function moveTo(key) {
                if (key === stage.shown) return
                if (!Popups.almanacOpen || !root.visible
                        || Theme.reducedMotion) {
                    stage.leaving = ""
                    stage.shown = key
                    stage.slide = 1
                    return
                }
                stage.dir = indexOf(key) > indexOf(stage.shown) ? 1 : -1
                stage.leaving = stage.shown
                stage.shown = key
                stage.slide = 0
                slideAnim.restart()
            }
            function offsetFor(key) {
                if (stage.leaving === key) return -stage.dir * stage.width * stage.slide
                if (stage.shown === key)   return  stage.dir * stage.width * (1 - stage.slide)
                return 0
            }

            NumberAnimation {
                id: slideAnim
                target: stage; property: "slide"
                from: 0; to: 1
                duration: Theme.almanacRoomSlide
                easing.type: Easing.InOutCubic
                onFinished: stage.leaving = ""
            }

            AlmanacDayRoom {
                width: stage.width; height: stage.height
                x: stage.offsetFor("day")
                visible: stage.shown === "day" || stage.leaving === "day"
                tint: Theme.almanacHue("day")
                reveal: root.reveal
            }
            AlmanacTimerRoom {
                width: stage.width; height: stage.height
                x: stage.offsetFor("timer")
                visible: stage.shown === "timer" || stage.leaving === "timer"
                tint: Theme.almanacHue("timer")
                reveal: root.reveal
            }
            AlmanacStopwatchRoom {
                width: stage.width; height: stage.height
                x: stage.offsetFor("watch")
                visible: stage.shown === "watch" || stage.leaving === "watch"
                tint: Theme.almanacHue("watch")
                reveal: root.reveal
            }
            AlmanacAlarmRoom {
                width: stage.width; height: stage.height
                x: stage.offsetFor("alarm")
                visible: stage.shown === "alarm" || stage.leaving === "alarm"
                tint: Theme.almanacHue("alarm")
                reveal: root.reveal
            }
            AlmanacTasksRoom {
                width: stage.width; height: stage.height
                x: stage.offsetFor("tasks")
                visible: stage.shown === "tasks" || stage.leaving === "tasks"
                tint: Theme.almanacHue("tasks")
                reveal: root.reveal
            }
        }

    }
}
