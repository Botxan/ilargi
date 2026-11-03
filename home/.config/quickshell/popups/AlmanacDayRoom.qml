import QtQuick
import "../components"
import "../theme"
import "../services"

Item {
    id: root

    property color tint: Theme.accent
    property real reveal: 1

    property date shown: new Date()
    property date today: new Date()
    property date selected: new Date()

    function startAdd() { editorSheet.openNew(root.selected) }
    function edit(ev) { editorSheet.openEdit(ev) }
    readonly property bool covered: editorSheet.open || taskSheet.open || jumpLayer.shown

    Timer {
        interval: 60000; repeat: true; running: true
        onTriggered: {
            var t = new Date()
            if (t.getDate() !== root.today.getDate()) {
                root.today = t
                if (root.selectedIsToday) root.selected = t
            }
        }
    }

    readonly property bool selectedIsToday:
        selected.getFullYear() === today.getFullYear()
        && selected.getMonth() === today.getMonth()
        && selected.getDate() === today.getDate()

    readonly property var dayEvents: CalendarService.on(selected)

    readonly property var listEvents: {
        if (!selectedIsToday) return dayEvents
        var out = [], now = Date.now()
        for (var i = 0; i < dayEvents.length; i++)
            if (new Date(dayEvents[i].end).getTime() >= now) out.push(dayEvents[i])
        return out
    }

    readonly property var nextEvent: listEvents.length > 0 ? listEvents[0] : null

    readonly property var dayTasks: {
        var k = CalendarService.key(selected), v = CalendarService.tasks, out = []
        for (var i = 0; i < v.length; i++)
            if (v[i].due === k && !v[i].parent) out.push({ kind: "task", task: v[i], title: v[i].title })
        return out
    }

    function untilText() {
        if (!nextEvent) return ""
        var mins = Math.round((new Date(nextEvent.start).getTime() - Date.now()) / 60000)
        if (!root.selectedIsToday && mins < 0) {
            var n = root.dayEvents.length
            return n + (n === 1 ? " event" : " events")
        }
        if (mins <= 0) return "now"
        if (mins >= 2 * 1440) return "in " + Math.round(mins / 1440) + "d"
        var h = Math.floor(mins / 60), m = mins % 60
        return h > 0 ? ("in " + h + "h " + m + "m") : ("in " + m + "m")
    }

    Column {
        id: topPart
        enabled: !root.covered
        anchors { left: parent.left; right: parent.right; top: parent.top }
        spacing: 0

        MonthGrid {
            id: month
            width: parent.width
            tint: root.tint
            today: root.today
            selected: root.selected
            reveal: Theme.phase(root.reveal, 0, 0.50)
            onDaySelected: function (d) { root.selected = d }
            onDayActivated: function (d) { root.selected = d; root.startAdd() }
            onTodayRequested: root.selected = new Date()
            onJumpRequested: { jumpLayer.shown = true; jumpPicker.open(root.selected) }
        }

        Item { width: 1; height: 16 }

        SectionHeader {
            width: parent.width
            label: root.selectedIsToday ? "The day" : Qt.formatDate(root.selected, "ddd d MMM")
            tint: root.tint
            opacity: Theme.phase(root.reveal, 0.28, 0.16)

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    var e = root.dayEvents.length, t = root.dayTasks.length, bits = []
                    if (e) bits.push(e + (e === 1 ? " event" : " events"))
                    if (t) bits.push(t + (t === 1 ? " task" : " tasks"))
                    return bits.length ? bits.join(" · ") : "Clear"
                }
                color: Theme.text
                opacity: 0.32
                font.family: Theme.fontText
                font.pixelSize: Theme.fsSection
            }
            Rectangle {
                visible: CalendarService.configured
                width: addEvText.implicitWidth + 18; height: 20; radius: 10
                color: addEvHov.hovered ? Theme.withAlpha(root.tint, 0.16) : Qt.rgba(1, 1, 1, 0.05)
                Behavior on color { ColorAnimation { duration: Theme.animColor } }
                Text {
                    id: addEvText
                    anchors.centerIn: parent
                    text: "+ Event"
                    color: root.tint
                    font.family: Theme.fontText; font.pixelSize: 11; font.weight: Font.Medium
                }
                HoverHandler { id: addEvHov; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.startAdd() }
            }
        }

        Item { width: 1; height: 4 }

        Item {
            width: parent.width
            height: 196

            DayDial {
                id: dial
                anchors.centerIn: parent
                width: 188; height: 188
                tint: root.tint
                events: root.dayEvents
                reveal: Theme.phase(root.reveal, 0.26, 0.56)
            }

            Column {
                anchors.centerIn: dial
                spacing: 2
                opacity: Theme.phase(root.reveal, 0.72, 0.28)

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.nextEvent ? root.untilText() : "free"
                    color: root.nextEvent ? Theme.groundText : Theme.text
                    opacity: root.nextEvent ? 1 : 0.35
                    font.family: Theme.fontText
                    font.features: Theme.tabularNums
                    font.pixelSize: 24
                    font.weight: Font.Bold
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 150
                    horizontalAlignment: Text.AlignHCenter
                    text: root.nextEvent ? root.nextEvent.title
                        : (root.selectedIsToday ? "Rest of the day" : "Nothing scheduled")
                    color: root.nextEvent ? root.tint : Theme.text
                    opacity: root.nextEvent ? 0.8 : 0.4
                    elide: Text.ElideRight
                    font.family: Theme.fontText
                    font.pixelSize: 11
                }
            }
        }
    }

    SectionHeader {
        id: listHeader
        enabled: !root.covered
        anchors { left: parent.left; right: parent.right; top: topPart.bottom; topMargin: 6 }
        label: root.selectedIsToday ? "Up next" : "Schedule"
        tint: root.tint
        opacity: Theme.phase(root.reveal, 0.6, 0.16)

            Text {
                text: CalendarService.configured
                    ? (CalendarService.healthy ? "Synced" : "Sync failed")
                    : "No calendar"
                color: CalendarService.configured && !CalendarService.healthy
                    ? Theme.statusWarn : Theme.text
                opacity: CalendarService.configured && !CalendarService.healthy ? 0.8 : 0.28
                font.family: Theme.fontText
                font.pixelSize: Theme.fsSection
                font.letterSpacing: Theme.trSection

                HoverHandler { id: syncHov; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: CalendarService.refresh() }
            }
        }

    Item {
        id: listArea
        enabled: !root.covered
        anchors { left: parent.left; right: parent.right
                  top: listHeader.bottom; topMargin: 9; bottom: parent.bottom }

        AgendaList {
            anchors.fill: parent
            tint: root.tint
            events: root.listEvents.concat(root.dayTasks)
            onActivated: function (ev) { if (ev.kind === "task") taskSheet.openTask(ev.task); else root.edit(ev) }
            maxRows: Math.max(1, Math.floor((listArea.height + 6) / 52))
            reveal: Theme.phase(root.reveal, 0.62, 0.38)
            emptyText: CalendarService.configured
                ? (root.selectedIsToday ? "Nothing left today" : "Nothing scheduled")
                : "No calendar connected"
            emptyHint: CalendarService.configured ? "" : "Calendar not set up"
        }
    }

    EventEditor {
        id: editorSheet
        anchors.fill: parent
        z: 50
        tint: root.tint
    }

    Rectangle {
        id: jumpLayer
        property bool shown: false
        anchors.fill: parent
        z: 40
        color: Theme.withAlpha(Theme.surfaceWell, 0.82)
        visible: opacity > 0.01
        opacity: shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.animContentIn } }
        TapHandler {
            onTapped: function (ev) {
                var p = jumpPicker.mapFromItem(jumpLayer, ev.position.x, ev.position.y)
                if (p.x < 0 || p.y < 0 || p.x > jumpPicker.width || p.y > jumpPicker.height) jumpLayer.shown = false
            }
        }
        WheelHandler {}
        DatePicker {
            id: jumpPicker
            anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
            width: parent.width
            height: implicitHeight
            tint: root.tint
            title: "Go to"
            focus: jumpLayer.shown
            onPicked: function (d) { month.shown = d; root.selected = d; jumpLayer.shown = false }
            onCancelled: jumpLayer.shown = false
        }
    }

    TaskEditor {
        id: taskSheet
        anchors.fill: parent
        z: 50
        tint: root.tint
    }
}
