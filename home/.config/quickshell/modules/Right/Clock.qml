import QtQuick
import "../../theme"
import "../../state"

Item {
    id: root
    anchors.verticalCenter: parent.verticalCenter
    implicitWidth: line.implicitWidth
    implicitHeight: line.implicitHeight

    property string timeText: ""
    property string dateText: ""

    function refresh() {
        var now = new Date()
        timeText = Qt.formatDateTime(now, "hh:mm")
        dateText = Qt.formatDateTime(now, "ddd d MMM")
    }

    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.refresh() }
    Component.onCompleted: refresh()

    HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
    TapHandler {
        onTapped: {
            var next = !Popups.almanacOpen
            Popups.closeAll()
            Popups.almanacOpen = next
        }
    }

    Row {
        id: line
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.topbarItemGap

        Text {
            id: dateLabel
            font.family: Theme.fontText
            font.features: Theme.tabularNums
            anchors.verticalCenter: parent.verticalCenter
            text: root.dateText
            color: Popups.almanacOpen ? Theme.accent
                 : Theme.withAlpha(Theme.text, hov.hovered ? 0.72 : 0.52)
            Behavior on color { ColorAnimation { duration: 120 } }
            font.pixelSize: 12
            font.weight: Font.Medium
        }
        Text {
            font.family: Theme.fontText
            font.features: Theme.tabularNums
            anchors.verticalCenter: parent.verticalCenter
            text: root.timeText
            color: (Popups.almanacOpen || hov.hovered) ? Theme.accent : Theme.text
            Behavior on color { ColorAnimation { duration: 120 } }
            font.pixelSize: 15
            font.bold: true
        }
    }
}
