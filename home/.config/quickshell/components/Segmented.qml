import QtQuick
import "../theme"

Rectangle {
    id: seg
    property var options: []
    property string current: ""
    property real segWidth: 56
    property color hue: Theme.accent
    signal picked(string key)

    width: segRow.width + 6
    height: 26
    radius: 8
    color: Theme.shade(Theme.surfaceSunk, 0.18)
    border.width: 1
    border.color: Qt.rgba(0, 0, 0, 0.30)
    opacity: enabled ? 1 : 0.4

    readonly property int currentIndex: {
        for (var i = 0; i < options.length; i++)
            if (options[i].key === current) return i
        return -1
    }

    Rectangle {
        visible: seg.currentIndex >= 0
        y: 3
        x: 3 + Math.max(0, seg.currentIndex) * (seg.segWidth + segRow.spacing)
        width: seg.segWidth
        height: parent.height - 6
        radius: 6
        color: seg.hue
        Behavior on x {
            enabled: !Theme.reducedMotion
            NumberAnimation { duration: Theme.animTransition; easing.type: Theme.animCurve }
        }
    }

    Row {
        id: segRow
        x: 3; y: 3
        height: parent.height - 6
        spacing: 3

        Repeater {
            model: seg.options
            delegate: Item {
                id: segItem
                required property var modelData
                readonly property bool sel: seg.current === modelData.key
                width: seg.segWidth
                height: segRow.height

                Text {
                    anchors.centerIn: parent
                    text: segItem.modelData.label
                    color: segItem.sel ? Theme.ground : Theme.text
                    opacity: segItem.sel ? 1 : (segHov.hovered ? 0.8 : 0.5)
                    font.family: Theme.fontText
                    font.pixelSize: 11
                    font.weight: segItem.sel ? Font.Medium : Font.Normal
                    Behavior on opacity { NumberAnimation { duration: 140 } }
                }
                HoverHandler { id: segHov; cursorShape: seg.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor }
                TapHandler { enabled: seg.enabled; onTapped: seg.picked(segItem.modelData.key) }
            }
        }
    }
}
