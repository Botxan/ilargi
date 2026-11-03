import QtQuick
import "../theme"

Item {
    id: root

    property color surface: Theme.surfaceRecess
    property int radius: 12
    property color accentTint: "transparent"
    property real accentStrength: 0.10
    property bool hovered: false

    default property alias content: holder.data

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.surface
        border.width: 1
        border.color: root.hovered ? Theme.grooveLight : Theme.grooveDark
        Behavior on border.color { ColorAnimation { duration: 160 } }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: root.radius - 1
            visible: root.accentTint != "transparent"
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.withAlpha(root.accentTint, root.accentStrength) }
                GradientStop { position: 0.55; color: "transparent" }
            }
        }
    }

    Rule {
        anchors.top: parent.top
        anchors.topMargin: 1
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.radius * 0.55
        anchors.rightMargin: root.radius * 0.55
        tint: Theme.grooveDark
        fade: 0.16
    }

    Rule {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 1
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.radius * 0.55
        anchors.rightMargin: root.radius * 0.55
        tint: Theme.grooveLight
        fade: 0.16
    }

    Item {
        id: holder
        anchors.fill: parent
    }
}
