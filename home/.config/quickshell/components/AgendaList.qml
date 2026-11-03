import QtQuick
import "../theme"
import "../services"

Item {
    id: root

    property color tint: Theme.accent
    property real reveal: 1
    property var events: []
    property int maxRows: 6
    property string emptyText: "Nothing left today"
    property string emptyHint: ""
    signal activated(var ev)

    readonly property var rows: events.slice(0, 40)
    readonly property int hiddenBelow: Math.max(0, Math.ceil(
        (flick.contentHeight - flick.contentY - flick.height - 2) / 52))

    implicitHeight: rows.length > 0 ? col.implicitHeight : 74

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        visible: root.rows.length > 0

    Column {
        id: col
        width: flick.width
        spacing: 6

        Repeater {
            model: root.rows
            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index

                readonly property bool isTask: modelData.kind === "task"
                readonly property bool taskDone: isTask && modelData.task.done
                readonly property date startAt: new Date(isTask ? 0 : modelData.start)
                readonly property date endAt:   new Date(isTask ? 0 : modelData.end)
                readonly property bool live:
                    !isTask && !modelData.allDay
                    && startAt.getTime() <= agendaClock.nowMs
                    && endAt.getTime()   >  agendaClock.nowMs

                width: parent.width
                height: 46
                radius: 10
                color: rHov.hovered ? Theme.lift(Theme.surfaceRecess, 0.025) : Theme.surfaceRecess
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                border.width: 1
                border.color: rHov.hovered ? Theme.grooveLight : Theme.grooveDark
                opacity: Theme.phase(root.reveal, index * 0.07, 0.3)
                Behavior on border.color { ColorAnimation { duration: 140 } }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: 9
                    gradient: Gradient {
                        GradientStop { position: 0.30; color: "transparent" }
                        GradientStop {
                            position: 1.0
                            color: "transparent"
                        }
                    }
                }

                Rectangle {
                    x: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 2
                    height: parent.height - 18
                    radius: 1
                    color: row.modelData.color && row.modelData.color !== ""
                        ? row.modelData.color : root.tint
                    opacity: row.live ? 0.95 : 0.5
                }

                Rectangle {
                    visible: row.isTask
                    x: 22
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18; height: 18; radius: 9
                    color: row.taskDone ? root.tint : "transparent"
                    border.width: row.taskDone ? 0 : 1.5
                    border.color: tkHov.hovered ? root.tint : Theme.withAlpha(Theme.text, 0.4)
                    Text { anchors.centerIn: parent; visible: row.taskDone; text: "✓"; color: Theme.accentText; font.pixelSize: 11; font.weight: Font.Bold }
                    HoverHandler { id: tkHov; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: CalendarService.setTaskDone(row.modelData.task, !row.taskDone) }
                }
                Text {
                    id: when
                    visible: !row.isTask
                    x: 20
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.isTask ? "" : row.modelData.allDay
                        ? "All day"
                        : Qt.formatDateTime(row.startAt, "HH:mm")
                    color: row.live ? root.tint : Theme.text
                    opacity: row.live ? 0.95 : 0.5
                    font.family: Theme.fontText
                    font.features: Theme.tabularNums
                    font.pixelSize: row.modelData.allDay ? 11 : 13
                    font.weight: Font.Medium
                }

                Column {
                    x: 74
                    width: parent.width - 116
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text {
                        width: parent.width
                        text: row.modelData.title
                        color: Theme.text
                        opacity: row.taskDone ? 0.4 : (row.live ? 0.98 : 0.85)
                        font.strikeout: row.taskDone
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.WordWrap
                        font.family: Theme.fontText
                        font.pixelSize: 13
                    }
                    Text {
                        width: parent.width
                        visible: text !== ""
                        text: row.isTask ? "Task · " + row.modelData.task.listTitle
                            : (row.modelData.location !== "" ? row.modelData.location : row.modelData.source)
                        color: Theme.text
                        opacity: 0.4
                        elide: Text.ElideRight
                        font.family: Theme.fontText
                        font.pixelSize: 11
                    }
                }

                Row {
                    anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    spacing: 4
                    Text {
                        visible: row.modelData.recurringId !== undefined && row.modelData.recurringId !== ""
                        text: String.fromCodePoint(0xF0456)
                        color: Theme.text; opacity: 0.35
                        font.family: Theme.iconFont; font.pixelSize: 11
                    }
                    Text {
                        visible: row.modelData.reminders !== undefined && row.modelData.reminders.length > 0
                        text: String.fromCodePoint(0xF009A)
                        color: Theme.text; opacity: 0.35
                        font.family: Theme.iconFont; font.pixelSize: 11
                    }
                }

                HoverHandler { id: rHov; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.activated(row.modelData) }
            }
        }
    }
    }

    Item {
        id: empty
        anchors.fill: parent
        visible: root.rows.length === 0
        opacity: Theme.phase(root.reveal, 0.1, 0.3)

        Rectangle {
            anchors.fill: parent
            radius: 10
            color: Theme.surfaceRecess
            border.width: 1
            border.color: Theme.grooveDark

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: 9
                gradient: Gradient {
                    GradientStop { position: 0.45; color: "transparent" }
                    GradientStop { position: 1.0;  color: "transparent" }
                }
            }
            Rule {
                anchors { bottom: parent.bottom; bottomMargin: 1; left: parent.left; right: parent.right
                          leftMargin: 8; rightMargin: 8 }
                tint: Theme.grooveLight; fade: 0.14
            }
        }
        Column {
            anchors.centerIn: parent
            spacing: 5
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.emptyText
                color: Theme.text; opacity: 0.42
                font.family: Theme.fontText; font.pixelSize: 13
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.emptyHint !== ""
                text: root.emptyHint
                color: Theme.text; opacity: 0.26
                font.family: Theme.fontText
                font.pixelSize: Theme.fsSection
                font.letterSpacing: Theme.trSection
            }
        }
    }

    Rectangle {
        anchors { right: parent.right; bottom: parent.bottom; rightMargin: 6; bottomMargin: 6 }
        visible: root.hiddenBelow > 0
        width: moreText.implicitWidth + 16; height: 20; radius: 10
        color: Theme.withAlpha(root.tint, 0.22)
        Text {
            id: moreText
            anchors.centerIn: parent
            text: "+" + root.hiddenBelow + " more"
            color: root.tint
            font.family: Theme.fontText; font.pixelSize: 11; font.weight: Font.Medium
        }
    }

    QtObject {
        id: agendaClock
        property double nowMs: Date.now()
    }
    Timer {
        interval: 30000; repeat: true; running: true
        onTriggered: agendaClock.nowMs = Date.now()
    }
}
