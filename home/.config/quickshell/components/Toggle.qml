import QtQuick
import "../theme"

Rectangle {
    id: sw
    property bool on: false
    property color hue: Theme.accent
    signal flipped()

    width: 36; height: 20; radius: 10
    opacity: enabled ? 1 : 0.4
    color: on ? hue : Theme.shade(Theme.surfaceSunk, 0.22)
    border.width: 1
    border.color: on ? hue : Qt.rgba(0, 0, 0, 0.30)
    Behavior on color { ColorAnimation { duration: 180 } }

    Rectangle {
        y: 3
        x: sw.on ? sw.width - width - 3 : 3
        width: 14; height: 14; radius: 7
        color: sw.on ? Theme.ground : Theme.text
        opacity: sw.on ? 1 : 0.55
        Behavior on x {
            enabled: !Theme.reducedMotion
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
    }
    HoverHandler { cursorShape: sw.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor }
    TapHandler { enabled: sw.enabled; onTapped: sw.flipped() }
}
