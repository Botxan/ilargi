import QtQuick
import "../theme"

Item {
    id: root

    property string label: ""
    property color tint: Theme.accent
    default property alias trailing: trail.data

    implicitHeight: 16

    Text {
        id: labelText
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        text: root.label.length ? root.label.charAt(0).toUpperCase() + root.label.slice(1) : ""
        color: Theme.text
        opacity: 0.6
        font.family: Theme.fontText
        font.pixelSize: 12
        font.weight: Font.Medium
    }

    Row {
        id: trail
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
    }
}
