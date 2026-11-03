import QtQuick
import "../theme"

Rectangle {
    id: root

    property bool vertical: false
    property bool groove: false
    property color tint: Theme.grooveDark
    property real fade: 0.12

    implicitHeight: vertical ? 40 : 1
    implicitWidth:  vertical ? 1 : 40
    color: "transparent"
    antialiasing: false
    visible: root.groove
             || !(Qt.colorEqual(root.tint, Theme.grooveLight) || Qt.colorEqual(root.tint, Theme.grooveDark))

    gradient: Gradient {
        orientation: root.vertical ? Gradient.Vertical : Gradient.Horizontal
        GradientStop { position: 0.0;            color: "transparent" }
        GradientStop { position: root.fade;      color: root.tint }
        GradientStop { position: 1.0 - root.fade; color: root.tint }
        GradientStop { position: 1.0;            color: "transparent" }
    }

    Rectangle {
        visible: root.groove
        width:  root.vertical ? 1 : root.width
        height: root.vertical ? root.height : 1
        x: root.vertical ? root.width : 0
        y: root.vertical ? 0 : root.height
        color: "transparent"
        antialiasing: false
        gradient: Gradient {
            orientation: root.vertical ? Gradient.Vertical : Gradient.Horizontal
            GradientStop { position: 0.0;             color: "transparent" }
            GradientStop { position: root.fade;       color: Theme.grooveLight }
            GradientStop { position: 1.0 - root.fade; color: Theme.grooveLight }
            GradientStop { position: 1.0;             color: "transparent" }
        }
    }
}
