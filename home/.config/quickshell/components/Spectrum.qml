import QtQuick
import "../theme"
import "../services"

Item {
    id: root

    property color tint: Theme.accent
    property real minBar: 0.035
    readonly property bool live: CavaService.available && CavaService.bars.length > 0

    implicitHeight: 60

    Row {
        id: row
        anchors.fill: parent
        spacing: 2
        visible: root.live

        Repeater {
            model: CavaService.barCount

            delegate: Item {
                required property int index
                width: (root.width - row.spacing * (CavaService.barCount - 1)) / CavaService.barCount
                height: root.height

                readonly property real level: {
                    var b = CavaService.bars
                    if (index < b.length) return Math.max(root.minBar, b[index])
                    return root.minBar
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width
                    height: Math.max(2, parent.height * 0.92 * parent.level)
                    radius: width / 2
                    opacity: 0.35 + parent.level * 0.55
                    gradient: Gradient {
                        GradientStop { position: 0.0;  color: "transparent" }
                        GradientStop { position: 0.5;  color: Theme.lift(root.tint, 0.12) }
                        GradientStop { position: 1.0;  color: "transparent" }
                    }

                    Behavior on height {
                        enabled: !Theme.reducedMotion
                        NumberAnimation { duration: 70; easing.type: Easing.OutQuad }
                    }
                }
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: CavaService.checked && !CavaService.available
        text: "install cava for the spectrum  ·  pacman -S cava"
        color: Theme.text
        opacity: 0.28
        font.family: Theme.fontText
        font.pixelSize: 10
    }
}
