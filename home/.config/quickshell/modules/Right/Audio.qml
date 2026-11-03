import QtQuick
import Quickshell.Services.Pipewire
import "../../theme"
import "../../state"

Item {
    id: root

    property bool showPercentage: false

    anchors.verticalCenter: parent.verticalCenter
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    readonly property var sink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: root.sink ? [root.sink] : [] }

    readonly property string icon: {
        if (!sink?.ready) return "󰕾"
        if (sink.audio.muted) return "󰝟"
        if (sink.audio.volume > 0.6) return "󰕾"
        if (sink.audio.volume > 0.2) return "󰖀"
        return "󰕿"
    }

    readonly property int pct: sink?.ready ? Math.round(sink.audio.volume * 100) : 0

    readonly property color iconColor: {
        if (hov.hovered) return Theme.accent
        if (!sink?.ready) return Theme.statusIdle
        return sink.audio.muted ? Theme.statusStandby : Theme.statusActive
    }

    HoverHandler { id: hov }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: pctWrapper.show ? 3 : 0

        Text {
            text: root.icon
            color: root.iconColor
            font.family: Theme.iconFont
            font.pixelSize: Theme.trayIconAudio
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 120 } }
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

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                if (root.sink?.ready) root.sink.audio.muted = !root.sink.audio.muted
            } else {
                var next = !Popups.audioOpen
                Popups.closeAll()
                Popups.audioOpen = next
            }
        }
    }
}
