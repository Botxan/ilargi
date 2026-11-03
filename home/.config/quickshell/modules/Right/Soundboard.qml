import QtQuick
import "../../theme"
import "../../state"
import "../../services"

Item {
    id: root

    anchors.verticalCenter: parent.verticalCenter
    implicitWidth: glyph.implicitWidth
    implicitHeight: glyph.implicitHeight

    readonly property int mapped: {
        var n = 0
        var v = SoundboardService.items
        for (var i = 0; i < v.length; i++)
            if ((v[i].file || "") !== "") n++
        return n
    }

    readonly property bool live: SoundboardService.playing !== ""
    readonly property color iconColor: {
        if (hov.hovered || root.live) return Theme.accent
        if (!SoundboardService.micReady) return Theme.statusWarn
        return root.mapped > 0 ? Theme.statusActive : Theme.statusStandby
    }

    HoverHandler { id: hov }

    Text {
        id: glyph
        anchors.centerIn: parent
        text: "󰓃"
        color: root.iconColor
        font.family: Theme.iconFont
        font.pixelSize: Theme.trayIconSoundboard
        Behavior on color { ColorAnimation { duration: 120 } }

        SequentialAnimation on opacity {
            running: root.live && !hov.hovered
            loops: Animation.Infinite
            NumberAnimation { to: 0.45; duration: 520; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0;  duration: 520; easing.type: Easing.InOutSine }
            onRunningChanged: if (!running) glyph.opacity = 1
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: function (mouse) {
            if (mouse.button === Qt.RightButton) {
                SoundboardService.stopAll()
            } else {
                var next = !Popups.soundboardOpen
                Popups.closeAll()
                Popups.soundboardOpen = next
            }
        }
    }
}
