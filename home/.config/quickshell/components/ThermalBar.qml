import QtQuick
import "../theme"

Item {
    id: root

    property string name: ""
    property var value: undefined
    property real floorC: 30
    property real ceilC: 95
    property real warnC: 75
    property real critC: 88

    readonly property real frac: value === undefined ? 0
        : Math.max(0, Math.min(1, (value - floorC) / (ceilC - floorC)))
    readonly property color c: value === undefined ? Theme.text
        : (value >= critC ? Qt.color("#df5b61")
          : (value >= warnC ? Qt.color("#de8f78") : Qt.color("#78b892")))

    implicitHeight: 34

    Column {
        anchors.fill: parent
        spacing: 7

        Item {
            width: parent.width
            height: 11

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: root.name
                color: Theme.text
                opacity: 0.45
                font.family: Theme.fontText
                font.pixelSize: Theme.fsSection
                font.letterSpacing: Theme.trSection
            }
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: root.value === undefined ? "--" : Math.round(root.value) + "°"
                color: root.c
                font.family: Theme.iconFont
                font.pixelSize: 12
                Behavior on color { ColorAnimation { duration: 500 } }
            }
        }

        Rectangle {
            id: trackRect
            width: parent.width
            height: 5
            radius: 2.5
            color: Theme.shade(Theme.surfaceSunk, 0.30)
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.25)

            Rectangle {
                width: Math.max(parent.height, (parent.width - 2) * root.frac)
                height: parent.height - 2
                y: 1
                x: 1
                radius: height / 2
                color: root.c
                Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 500 } }
            }

            Rectangle {
                x: Math.round(trackRect.width * (root.warnC - root.floorC) / (root.ceilC - root.floorC))
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: parent.height + 5
                color: Qt.rgba(1, 1, 1, 0.25)
            }
        }
    }
}
