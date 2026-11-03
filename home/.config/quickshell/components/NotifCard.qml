import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import "../theme"
import "../services"

Rectangle {
    id: root

    required property var notif
    property bool compact: false
    property real progress: -1
    signal dismissed()

    readonly property bool critical: notif.urgency === NotificationUrgency.Critical
    readonly property color hue: critical ? Theme.palette.red : Theme.accent
    readonly property bool hasImage: notif.image !== "" && bigArt.status !== Image.Error
    readonly property int pad: 12

    implicitHeight: layout.implicitHeight + pad * 2 + (progress >= 0 ? 4 : 0)
    radius: 10
    color: Theme.surfaceRecess
    border.width: critical ? 1 : 0
    border.color: Theme.withAlpha(Theme.palette.red, 0.45)

    HoverHandler { id: hov }

    readonly property real dismissThreshold: width * 0.35
    x: 0
    opacity: 1 - Math.min(1, Math.abs(x) / (width * 0.9))

    MouseArea {
        id: dragArea
        anchors.fill: parent
        drag.target: root
        drag.axis: Drag.XAxis
        drag.minimumX: 0
        drag.maximumX: root.width
        cursorShape: Qt.PointingHandCursor

        onReleased: {
            if (root.x > root.dismissThreshold) flyOut.start()
            else if (root.x > 0) springBack.start()
        }
        onClicked: {
            if (root.notif.actions.length > 0) root.notif.actions[0].invoke()
            root.dismissed()
        }
    }

    NumberAnimation {
        id: springBack
        target: root; property: "x"; to: 0
        duration: Theme.animTransition; easing.type: Theme.animCurve
    }
    SequentialAnimation {
        id: flyOut
        NumberAnimation {
            target: root; property: "x"; to: root.width * 1.05
            duration: 200; easing.type: Easing.OutCubic
        }
        ScriptAction { script: root.dismissed() }
    }

    Column {
        id: layout
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: root.pad }
        spacing: 9

        Item {
            width: parent.width
            height: 18

            Item {
                id: appIcon
                width: 16; height: 16
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    anchors.centerIn: parent
                    visible: art.status !== Image.Ready
                    text: String.fromCodePoint(0xF009A)
                    font.family: Theme.iconFont
                    font.pixelSize: 14
                    color: root.hue
                }
                Image {
                    id: art
                    anchors.fill: parent
                    visible: status === Image.Ready
                    sourceSize: Qt.size(32, 32)
                    source: {
                        var n = root.notif
                        var _dep = DesktopEntries.applications.values.length
                        var e = n.desktopEntry !== "" ? DesktopEntries.heuristicLookup(n.desktopEntry) : null
                        if (e && e.icon !== "") return Quickshell.iconPath(e.icon, true)
                        if (n.appIcon.indexOf("/") === 0) return "file://" + n.appIcon
                        if (n.appIcon.indexOf("file://") === 0) return n.appIcon
                        if (n.appIcon !== "") return Quickshell.iconPath(n.appIcon, true)
                        if (n.appName !== "") {
                            var byName = DesktopEntries.heuristicLookup(n.appName.toLowerCase())
                            if (byName && byName.icon !== "") return Quickshell.iconPath(byName.icon, true)
                        }
                        return ""
                    }
                    smooth: true
                    asynchronous: true
                    fillMode: Image.PreserveAspectFit
                }
            }

            Text {
                anchors { left: appIcon.right; leftMargin: 8; right: age.left; rightMargin: 8
                          verticalCenter: parent.verticalCenter }
                text: root.notif.appName !== "" ? root.notif.appName : "Notification"
                color: root.critical ? Theme.palette.red : Theme.text
                opacity: root.critical ? 1 : 0.55
                font.family: Theme.fontText
                font.pixelSize: 11
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            Text {
                id: age
                anchors { right: closeBtn.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
                text: NotificationService.ageOf(root.notif)
                color: Theme.text
                opacity: 0.35
                font.family: Theme.fontText
                font.pixelSize: 11
            }

            Rectangle {
                id: closeBtn
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: 20; height: 20; radius: 6
                color: closeHov.hovered ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: String.fromCodePoint(0xF0156)
                    font.family: Theme.iconFont
                    font.pixelSize: 13
                    color: closeHov.hovered ? Theme.palette.red : Theme.text
                    opacity: closeHov.hovered ? 1 : (hov.hovered ? 0.6 : 0.3)
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                }
                HoverHandler { id: closeHov; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.dismissed() }
            }
        }

        Row {
            width: parent.width
            spacing: 12

            ClippingRectangle {
                id: bigFrame
                visible: root.hasImage
                width: visible ? 46 : 0
                height: 46
                radius: 8
                color: Qt.rgba(1, 1, 1, 0.04)
                Image {
                    id: bigArt
                    anchors.fill: parent
                    source: root.notif.image
                    sourceSize: Qt.size(92, 92)
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    asynchronous: true
                }
            }

            Column {
                width: parent.width - (bigFrame.visible ? bigFrame.width + parent.spacing : 0)
                spacing: 3
                anchors.verticalCenter: root.hasImage ? parent.verticalCenter : undefined

                Text {
                    width: parent.width
                    text: root.notif.summary
                    color: Theme.text
                    font.family: Theme.fontText
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    visible: text !== ""
                    text: root.notif.body
                    textFormat: Text.StyledText
                    color: Theme.text
                    opacity: 0.6
                    font.family: Theme.fontText
                    font.pixelSize: 12
                    lineHeight: 1.1
                    maximumLineCount: root.compact ? 3 : 4
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                }
            }
        }

        Row {
            id: actionRow
            readonly property int n: Math.max(0, root.notif.actions.length - 1)
            visible: n > 0
            width: parent.width
            spacing: 6

            Repeater {
                model: root.notif.actions
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    visible: index > 0
                    width: visible ? (actionRow.width - actionRow.spacing * (actionRow.n - 1)) / actionRow.n : 0
                    height: visible ? 28 : 0
                    radius: 7
                    color: Qt.rgba(1, 1, 1, actHov.hovered ? 0.08 : 0.04)
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 12
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData.text
                        color: root.hue
                        font.family: Theme.fontText
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }
                    HoverHandler { id: actHov; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: { modelData.invoke(); root.dismissed() } }
                }
            }
        }
    }

    Rectangle {
        visible: root.progress >= 0
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom
                  leftMargin: root.pad; rightMargin: root.pad; bottomMargin: 7 }
        height: 2
        radius: 1
        color: Qt.rgba(1, 1, 1, 0.05)
        Rectangle {
            width: parent.width * Math.max(0, root.progress)
            height: parent.height
            radius: 1
            color: root.hue
            opacity: 0.8
        }
    }
}
