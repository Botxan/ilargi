import QtQuick
import QtQuick.Effects
import "../theme"
import "../services"

Item {
    id: root

    readonly property var cores: SysStatsService.cores
    readonly property int columns: 4

    function heat(l) {
        const stops = [[0.00,  31,  33,  34],
                       [0.35, 103, 145, 201],
                       [0.68, 222, 143, 120],
                       [1.00, 223,  91,  97]]
        const v = Math.max(0, Math.min(1, l))
        for (let i = 1; i < stops.length; i++) {
            if (v <= stops[i][0] || i === stops.length - 1) {
                const a = stops[i - 1], b = stops[i]
                const f = Math.max(0, Math.min(1, (v - a[0]) / (b[0] - a[0])))
                return Qt.rgba((a[1] + (b[1] - a[1]) * f) / 255,
                               (a[2] + (b[2] - a[2]) * f) / 255,
                               (a[3] + (b[3] - a[3]) * f) / 255, 1)
            }
        }
        return Qt.rgba(0.16, 0.23, 0.33, 1)
    }

    component Die: Grid {
        id: grid
        columns: root.columns
        spacing: 4
        readonly property int rows_: Math.max(1, Math.ceil(root.cores.length / root.columns))

        Repeater {
            model: root.cores
            delegate: Rectangle {
                required property var modelData
                width:  (grid.width  - grid.spacing * (root.columns - 1)) / root.columns
                height: (grid.height - grid.spacing * (grid.rows_ - 1)) / grid.rows_
                radius: 3
                color: root.heat(modelData)
                Behavior on color {
                    enabled: !Theme.reducedMotion
                    ColorAnimation { duration: 700 }
                }
            }
        }
    }

    Item {
        id: bleedHost
        anchors.fill: parent
        layer.enabled: !Theme.reducedMotion
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 1.0
            blurMax: 24
            saturation: 0.25
        }
        Die { anchors.fill: parent }
    }

    Die {
        anchors.fill: parent
        opacity: 0.45
    }
}
