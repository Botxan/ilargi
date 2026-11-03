import QtQuick
import QtQuick.Effects
import "../shapes"
import "../theme"

Item {
    id: root

    required property var room
    property bool open: false
    default property alias content: holder.data

    anchors.fill: parent
    visible: reveal > 0.001

    readonly property bool leftSide: room.corner === "tl" || room.corner === "bl"
    readonly property bool topSide:  room.corner === "tl" || room.corner === "tr"

    readonly property real ox: leftSide ? Theme.dialCx : width - Theme.dialCx
    readonly property real oy: topSide  ? Theme.dialCy : height - Theme.dialCy

    property real reveal: 0
    onOpenChanged: reveal = open ? 1 : 0

    Behavior on reveal {
        enabled: !Theme.reducedMotion
        SequentialAnimation {
            PauseAnimation { duration: root.open ? 120 : 0 }
            NumberAnimation {
                duration: root.open ? 470 : 340
                easing.type: root.open ? Easing.OutExpo : Easing.InOutQuad
            }
        }
    }

    Item {
        id: washSource
        anchors.fill: parent
        visible: false
        layer.enabled: true

        Item {
            x: root.ox
            y: root.oy
            width: 0
            height: 0
            scale: root.reveal

        }
    }

    Rectangle {
        id: washMask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        color: "white"
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius:  Theme.cornerRadius
        bottomRightRadius: Theme.cornerRadius
    }

    MultiEffect {
        anchors.fill: parent
        visible: root.visible
        source: washSource
        maskEnabled: true
        maskSource: washMask
    }

    Item {
        id: holder
        anchors.fill: parent
        anchors.leftMargin:   Theme.plateGutterX
        anchors.rightMargin:  Theme.plateGutterX
        anchors.topMargin:    Theme.plateGutterY
        anchors.bottomMargin: Theme.plateGutterY

        opacity: root.open ? 1 : 0
        transform: Translate {
            x: root.open ? 0 : (root.leftSide ? -22 : 22)
            y: root.open ? 0 : (root.topSide ? -16 : 16)
            Behavior on x {
                enabled: !Theme.reducedMotion
                NumberAnimation { duration: 540; easing.type: Easing.OutExpo }
            }
            Behavior on y {
                enabled: !Theme.reducedMotion
                NumberAnimation { duration: 540; easing.type: Easing.OutExpo }
            }
        }

        Behavior on opacity {
            enabled: !Theme.reducedMotion
            SequentialAnimation {
                PauseAnimation { duration: root.open ? 210 : 0 }
                NumberAnimation { duration: root.open ? 320 : 160 }
            }
        }
    }
}
