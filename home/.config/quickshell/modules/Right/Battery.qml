import QtQuick
import Quickshell.Services.UPower
import "../../theme"
import "../../state"

Item {
    id: root

    property bool showPercentage: false

    readonly property var bat: UPower.displayDevice
    visible: bat.ready && bat.isLaptopBattery

    anchors.verticalCenter: parent.verticalCenter
    implicitWidth: statusRow.implicitWidth
    implicitHeight: statusRow.implicitHeight

    readonly property real pct: bat.ready ? Math.round(bat.percentage * 100) : 0
    readonly property bool charging: bat.ready
        ? (bat.state === UPowerDeviceState.Charging ||
           bat.state === UPowerDeviceState.PendingCharge ||
           bat.state === UPowerDeviceState.FullyCharged)
        : false
    readonly property bool full: bat.ready ? bat.state === UPowerDeviceState.FullyCharged : false

    function staticIcon(p) {
        if (p > 90) return "󰁹"
        if (p > 80) return "󰂂"
        if (p > 70) return "󰂁"
        if (p > 60) return "󰂀"
        if (p > 50) return "󰁿"
        if (p > 40) return "󰁾"
        if (p > 30) return "󰁽"
        if (p > 20) return "󰁼"
        if (p > 10) return "󰁻"
        return "󰁺"
    }

    readonly property var chargeFrames: ["󰢜", "󰂆", "󰂇", "󰂈", "󰂉", "󰂊", "󰂋", "󰂅"]
    property int chargeFrame: 0
    Timer {
        interval: 650
        running: root.charging && !root.full
        repeat: true
        onTriggered: root.chargeFrame = (root.chargeFrame + 1) % root.chargeFrames.length
    }

    readonly property string icon: {
        if (full) return "󰂄"
        if (charging) return chargeFrames[chargeFrame % chargeFrames.length]
        return staticIcon(pct)
    }

    readonly property color iconColor: {
        if (hov.hovered) return Theme.accent
        if (charging || full) return Theme.statusActive
        if (pct <= 7)  return Theme.statusAlert
        if (pct <= 15) return Theme.statusWarn
        if (pct <= 30) return Theme.statusNotice
        return Theme.statusActive
    }

    Row {
        id: statusRow
        spacing: pctWrapper.show ? 4 : 0
        anchors.centerIn: parent

        Text {
            id: iconText
            text: root.icon
            color: root.iconColor
            font.family: Theme.iconFont
            font.pixelSize: Theme.trayIconBattery
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 150 } }

            SequentialAnimation on opacity {
                id: pulseAnim
                running: root.pct <= 10 && !root.charging
                loops: Animation.Infinite
                NumberAnimation { to: 0.2; duration: 600; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
            }
            Connections {
                target: pulseAnim
                function onRunningChanged() { if (!pulseAnim.running) iconText.opacity = 1.0 }
            }
        }

        Item {
            id: pctWrapper
            property bool show: root.showPercentage
            implicitWidth: show ? pctText.implicitWidth + 2 : 0
            implicitHeight: pctText.implicitHeight
            clip: true
            anchors.verticalCenter: parent.verticalCenter
            Behavior on implicitWidth { NumberAnimation { duration: Theme.durationBase; easing.type: Easing.InOutCubic } }

            Text {
                font.family: Theme.fontText
                id: pctText
                text: root.pct + "%"
                color: hov.hovered ? Theme.accent : Theme.text
                font.pixelSize: 12
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: 120 } }
            }
        }
    }

    HoverHandler { id: hov }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            var next = !Popups.batteryOpen
            Popups.closeAll()
            Popups.batteryOpen = next
        }
    }
}
