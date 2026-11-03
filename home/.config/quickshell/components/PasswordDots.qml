import QtQuick
import "../theme"

Row {
    id: dots

    property int count: 0
    property bool checking: false
    property int fit: 18
    property int dotSize: 10

    spacing: 9

    Repeater {
        model: Math.min(dots.count, dots.fit)
        delegate: Rectangle {
            width: dots.dotSize; height: dots.dotSize; radius: dots.dotSize / 2
            color: dots.checking ? Theme.accent : Theme.text
            scale: 0
            Component.onCompleted: scale = 1
            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
            Behavior on color { ColorAnimation { duration: 160 } }
            SequentialAnimation on opacity {
                running: dots.checking
                loops: Animation.Infinite
                alwaysRunToEnd: true
                NumberAnimation { to: 0.35; duration: 380; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1;    duration: 380; easing.type: Easing.InOutSine }
            }
        }
    }
}
