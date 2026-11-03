import QtQuick
import Quickshell
import Quickshell.Wayland
import "../theme"
import "../services"

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win
        required property var modelData
        screen: modelData
        visible: DisplayService.identifying || fade.opacity > 0.01
        implicitWidth: 220
        implicitHeight: 220
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-identify"
        mask: Region {}

        readonly property var mon: DisplayService.monitors.find(m => m.name === win.modelData.name)
        readonly property int number: {
            var on = DisplayService.monitors.filter(m => !m.disabled && m.mirrorOf === "none")
                .sort((a, b) => a.x - b.x || a.y - b.y)
            return on.findIndex(m => m.name === win.modelData.name) + 1
        }
        readonly property bool isPrimary: win.modelData.name === DisplayService.primaryName

        Rectangle {
            id: fade
            anchors.fill: parent
            radius: 28
            color: Theme.ground
            border.width: 2
            border.color: win.isPrimary ? Theme.palette.blue : Qt.rgba(1, 1, 1, 0.08)
            opacity: DisplayService.identifying ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.animTransition; easing.type: Theme.animCurve } }

            Column {
                anchors.centerIn: parent
                spacing: 4
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: win.number > 0 ? win.number : "–"
                    color: win.isPrimary ? Theme.palette.blue : Theme.text
                    font.family: Theme.fontText
                    font.pixelSize: 96
                    font.weight: Font.Bold
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: win.mon ? DisplayService.shortName(win.mon) : win.modelData.name
                    color: Theme.text; opacity: 0.7
                    font.family: Theme.fontText; font.pixelSize: 13; font.weight: Font.Medium
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: win.modelData.name + (win.isPrimary ? " · principal" : "")
                    color: Theme.text; opacity: 0.4
                    font.family: Theme.fontMono; font.pixelSize: 10
                }
            }
        }
    }
}
