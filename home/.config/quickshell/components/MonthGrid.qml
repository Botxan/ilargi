import QtQuick
import "../theme"
import "../services"

Item {
    id: root

    property date shown: new Date()
    property date today: new Date()
    property date selected: new Date()
    property color tint: Theme.accent
    property real reveal: 1

    signal daySelected(date day)
    signal dayActivated(date day)
    signal todayRequested()
    signal jumpRequested()
    readonly property int titleH: 40

    readonly property int year: shown.getFullYear()
    readonly property int month: shown.getMonth()
    readonly property int firstCol: (new Date(year, month, 1).getDay() + 6) % 7
    readonly property int daysIn: new Date(year, month + 1, 0).getDate()
    readonly property bool showingToday:
        month === today.getMonth() && year === today.getFullYear()

    readonly property real cellW: Math.floor((width - 16) / 7)
    readonly property int rows: Math.ceil((firstCol + daysIn) / 7)
    readonly property real cellH: 34

    implicitHeight: titleH + 4 + dowRow.height + 6 + 12 + rows * cellH + 12

    function shift(months) {
        var d = new Date(shown)
        d.setDate(1)
        d.setMonth(d.getMonth() + months)
        shown = d
    }

    WheelHandler { onWheel: function (e) { root.shift(e.angleDelta.y > 0 ? -1 : 1) } }

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: Theme.surfaceRecess
        border.width: 0

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 11
            gradient: Gradient {
                GradientStop { position: 0.30; color: "transparent" }
                GradientStop { position: 1.0;  color: "transparent" }
            }
        }
    }

    Item {
        id: title
        width: parent.width
        height: root.titleH
        Text {
            anchors.centerIn: parent
            text: Qt.formatDate(root.shown, "MMMM yyyy")
            color: root.tint
            font.family: Theme.fontText; font.pixelSize: 16; font.weight: Font.Bold
            HoverHandler { cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: root.jumpRequested() }
        }
        Rectangle {
            visible: !root.showingToday
            anchors.verticalCenter: parent.verticalCenter
            x: parent.width - 18 - 26 - 4 - width
            width: 26; height: 26; radius: 13
            color: tHov.hovered ? Theme.withAlpha(root.tint, 0.18) : "transparent"
            Text {
                anchors.centerIn: parent
                text: String.fromCodePoint(0xF00F6)
                color: root.tint
                font.family: Theme.iconFont; font.pixelSize: 14
            }
            HoverHandler { id: tHov; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: { root.shown = new Date(); root.todayRequested() } }
        }
        Repeater {
            model: [{ d: -1, g: "󰅁" }, { d: 1, g: "󰅂" }]
            delegate: Rectangle {
                id: arrow
                required property var modelData
                anchors.verticalCenter: parent.verticalCenter
                x: modelData.d < 0 ? 18 : parent.width - width - 18
                width: 26; height: 26; radius: 13
                color: aHov.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: arrow.modelData.g
                    color: Theme.text
                    opacity: aHov.hovered ? 1 : 0.7
                    font.family: Theme.iconFont; font.pixelSize: 15
                }
                HoverHandler { id: aHov; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.shift(arrow.modelData.d) }
            }
        }
    }

    Row {
        id: dowRow
        x: 8
        y: root.titleH + 4
        height: 14
        Repeater {
            model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
            delegate: Item {
                required property var modelData
                required property int index
                width: root.cellW
                height: 14
                opacity: Theme.phase(root.reveal, 0, 0.18)
                Text {
                    anchors.centerIn: parent
                    text: parent.modelData
                    color: Theme.text
                    opacity: 0.9
                    font.family: Theme.fontText
                    font.pixelSize: 12
                    font.weight: Font.Bold
                }
            }
        }
    }

    Grid {
        x: 8
        y: dowRow.y + dowRow.height + 12
        columns: 7

        Repeater {
            model: root.firstCol + root.daysIn
            delegate: Item {
                id: cell
                required property int index
                readonly property int day: index - root.firstCol + 1
                readonly property int col: index % 7
                readonly property int row: Math.floor(index / 7)
                readonly property bool real: day > 0
                readonly property date when: new Date(root.year, root.month, Math.max(1, day))
                readonly property bool isToday:
                    real && day === root.today.getDate() && root.showingToday
                readonly property bool isSelected:
                    real && !isToday && day === root.selected.getDate()
                    && root.month === root.selected.getMonth() && root.year === root.selected.getFullYear()
                readonly property var events: real ? CalendarService.on(when).concat(CalendarService.tasksOn(when)) : []

                width: root.cellW
                height: root.cellH

                opacity: Theme.phase(root.reveal, 0.10 + row * 0.055, 0.26)

                Rectangle {
                    anchors.centerIn: parent
                    visible: cell.isToday
                    width: 30; height: 30; radius: 15
                    color: root.tint
                    border.width: 0
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: 8
                        gradient: Gradient {
                            GradientStop { position: 0.25; color: "transparent" }
                            GradientStop { position: 1.0;  color: "transparent" }
                        }
                    }
                    Rule {
                        anchors { bottom: parent.bottom; bottomMargin: 1
                                  left: parent.left; right: parent.right
                                  leftMargin: 6; rightMargin: 6 }
                        tint: Theme.grooveLight; fade: 0.2
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 30; height: 30; radius: 15
                    opacity: cell.isSelected ? 1 : 0
                    scale: cell.isSelected ? 1 : 0.8
                    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                    Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutQuart } }
                    color: Theme.withAlpha(root.tint, 0.16)
                    border.width: 1.5
                    border.color: root.tint
                }

                Rectangle {
                    anchors.centerIn: parent
                    visible: dHov.hovered && cell.real && !cell.isToday && !cell.isSelected
                    width: 30; height: 30; radius: 15
                    color: Qt.rgba(1, 1, 1, 0.06)
                }

                Text {
                    id: num
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: cell.events.length > 0 ? -3 : 0
                    visible: cell.real
                    text: cell.real ? cell.day : ""
                    color: cell.isToday ? Theme.accentText : (cell.isSelected ? root.tint : Theme.text)
                    opacity: cell.isToday || cell.isSelected ? 1 : 0.85
                    font.family: Theme.fontText
                    font.features: Theme.tabularNums
                    font.pixelSize: 13
                    font.weight: cell.isToday || cell.isSelected ? Font.Bold : Font.Normal
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: num.bottom
                    anchors.topMargin: 2
                    spacing: 3
                    visible: cell.events.length > 0
                    Repeater {
                        model: Math.min(3, cell.events.length)
                        delegate: Rectangle {
                            width: 3; height: 3; radius: 2
                            color: root.tint
                            opacity: cell.isToday ? 0.95 : 0.6
                        }
                    }
                }

                HoverHandler { id: dHov; enabled: cell.real; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    enabled: cell.real
                    onTapped: root.daySelected(cell.when)
                    onDoubleTapped: root.dayActivated(cell.when)
                }
            }
        }
    }
}
