import QtQuick
import "../components"
import "../theme"
import "../services"

FocusScope {
    id: editor

    property color tint: Theme.accent
    property bool open: false
    signal closed()

    property var task: null
    property var due: null
    property string listId: ""
    property bool picking: false
    property bool confirmDelete: false
    readonly property bool isSub: task !== null && task.parent !== ""
    readonly property var live: {
        if (!task) return null
        var v = CalendarService.tasks
        for (var i = 0; i < v.length; i++) if (v[i].id === task.id) return v[i]
        return task
    }
    readonly property var subs: task ? CalendarService.subtasksOf(task.id) : []

    function addDays(d, n) { return new Date(d.getFullYear(), d.getMonth(), d.getDate() + n) }
    function dayOf(s) { if (!s) return null; var p = s.split("-"); return new Date(+p[0], +p[1] - 1, +p[2]) }
    function dueLabel() {
        if (!due) return "No date"
        var t = new Date(); t = new Date(t.getFullYear(), t.getMonth(), t.getDate())
        var n = Math.round((due - t) / 86400000)
        var rel = n === 0 ? "Today" : n === 1 ? "Tomorrow" : n === -1 ? "Yesterday"
                : n < 0 ? (-n) + " days ago" : n < 7 ? "In " + n + " days" : ""
        return Qt.formatDate(due, "ddd d MMMM yyyy") + (rel ? "  ·  " + rel : "")
    }

    function openTask(t) {
        task = t
        due = dayOf(t.due)
        listId = t.list
        picking = false; confirmDelete = false
        titleIn.text = t.title; notesIn.text = t.notes || ""; subIn.text = ""
        open = true
        titleIn.forceActiveFocus()
    }
    function close() { open = false; picking = false; closed() }
    function save() {
        var t = titleIn.text.trim()
        if (t === "") return
        CalendarService.saveTask({
            list: task.list, id: task.id, title: t, notes: notesIn.text,
            due: due ? CalendarService.key(due) : "", toList: listId
        })
        close()
    }
    function remove() {
        if (!confirmDelete) { confirmDelete = true; return }
        CalendarService.deleteTask(task)
        close()
    }
    function addSub() {
        var t = subIn.text.trim()
        if (t === "") return
        CalendarService.saveTask({ list: task.list, id: "", title: t, notes: "", due: "", parent: task.id })
        subIn.text = ""
    }

    Keys.onEscapePressed: function (e) {
        if (picking) { picking = false; titleIn.forceActiveFocus() } else close()
        e.accepted = true
    }
    Keys.onPressed: function (e) {
        if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && (e.modifiers & Qt.ControlModifier)) { save(); e.accepted = true }
    }

    visible: opacity > 0.01
    enabled: open
    opacity: open ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: editor.open ? Theme.animContentIn : Theme.animContentOut } }
    transform: Translate {
        y: editor.open ? 0 : 14
        Behavior on y { NumberAnimation { duration: Theme.animTransition; easing.type: Theme.animCurve } }
    }

    Rectangle { anchors.fill: parent; color: Theme.surfaceWell; TapHandler {} WheelHandler {} }

    component Chip: Rectangle {
        id: chip
        property string text
        property bool on: false
        property color tint: Theme.accent
        signal clicked()
        width: chipText.implicitWidth + 22; height: 28; radius: 14
        color: on ? Theme.withAlpha(tint, 0.22) : (chipHov.hovered ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.045))
        Behavior on color { ColorAnimation { duration: Theme.animColor } }
        Text {
            id: chipText
            anchors.centerIn: parent
            text: chip.text
            color: chip.on ? chip.tint : Theme.text
            opacity: chip.on ? 1 : 0.68
            font.family: Theme.fontText; font.pixelSize: 12; font.weight: Font.Medium
        }
        HoverHandler { id: chipHov; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: chip.clicked() }
    }
    component Card: Rectangle {
        id: card
        default property alias content: inner.data
        property string label: ""
        property string glyph: ""
        width: parent ? parent.width : 0
        height: inner.implicitHeight + 24 + (label !== "" ? 22 : 0)
        radius: 12
        color: Theme.surfaceRecess
        Row {
            visible: card.label !== ""
            x: 12; y: 11
            spacing: 6
            Text { text: card.glyph; color: Theme.accent; opacity: 0.85; font.family: Theme.iconFont; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
            Text { text: card.label; color: Theme.text; opacity: 0.55; font.family: Theme.fontText; font.pixelSize: 11; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
        }
        Column { id: inner; x: 12; y: card.label !== "" ? 34 : 12; width: card.width - 24; spacing: 10 }
    }

    Item {
        id: head
        enabled: !editor.picking
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 34
        Rectangle {
            id: back
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            width: 30; height: 30; radius: 15
            color: backHov.hovered ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)
            Text { anchors.centerIn: parent; text: "‹"; color: Theme.text; font.pixelSize: 18; font.family: Theme.fontText }
            HoverHandler { id: backHov; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: editor.close() }
        }
        Text {
            anchors { left: back.right; leftMargin: 10; verticalCenter: parent.verticalCenter }
            text: editor.isSub ? "Subtask" : "Task"
            color: Theme.text
            font.family: Theme.fontText; font.pixelSize: 15; font.weight: Font.Bold
        }
        Rectangle {
            readonly property bool done: editor.live && editor.live.done
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            width: doneRow.implicitWidth + 20; height: 28; radius: 14
            color: done ? Theme.withAlpha(editor.tint, 0.2)
                        : (dHov.hovered ? Theme.withAlpha(editor.tint, 0.16) : Qt.rgba(1, 1, 1, 0.05))
            Row {
                id: doneRow
                anchors.centerIn: parent
                spacing: 6
                Text { text: "✓"; color: editor.tint; font.pixelSize: 12; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: parent.parent.done ? "Done · reopen" : "Mark done"
                    color: editor.tint
                    font.family: Theme.fontText; font.pixelSize: 11; font.weight: Font.Medium
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            HoverHandler { id: dHov; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: { CalendarService.setTaskDone(editor.live, !parent.done) } }
        }
    }

    Flickable {
        id: flick
        enabled: !editor.picking
        anchors { left: parent.left; right: parent.right; top: head.bottom; topMargin: 12; bottom: foot.top; bottomMargin: 12 }
        contentWidth: width
        contentHeight: body.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: body
            width: flick.width
            spacing: 10

            Rectangle {
                width: parent.width; height: 46; radius: 12
                color: Theme.surfaceRecess
                border.width: titleIn.activeFocus ? 1 : 0
                border.color: Theme.withAlpha(editor.tint, 0.5)
                TextInput {
                    id: titleIn
                    anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text
                    selectionColor: Theme.withAlpha(editor.tint, 0.4)
                    font.family: Theme.fontText; font.pixelSize: 16; font.weight: Font.Medium
                    clip: true
                    maximumLength: 1024
                    onAccepted: editor.save()
                    KeyNavigation.tab: notesIn
                }
                Text {
                    anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                    visible: titleIn.text === ""
                    text: "Title"; color: Theme.text; opacity: 0.3
                    font.family: Theme.fontText; font.pixelSize: 16
                }
            }

            Card {
                label: "Due"; glyph: String.fromCodePoint(0xF00ED)
                Rectangle {
                    width: parent.width; height: 34; radius: 10
                    color: dueHov.hovered ? Theme.lift(Theme.surfaceSunk, 0.03) : Theme.surfaceSunk
                    Text {
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        text: editor.dueLabel()
                        color: editor.due ? Theme.text : Theme.withAlpha(Theme.text, 0.45)
                        font.family: Theme.fontText; font.pixelSize: 13; font.weight: Font.Medium
                    }
                    Text {
                        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        text: "Change"
                        color: editor.tint
                        font.family: Theme.fontText; font.pixelSize: 11; font.weight: Font.Medium
                    }
                    HoverHandler { id: dueHov; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: { editor.picking = true; picker.open(editor.due ? editor.due : new Date()) } }
                }
                Flow {
                    width: parent.width
                    spacing: 6
                    Chip { text: "No date"; on: editor.due === null; onClicked: editor.due = null }
                    Chip {
                        text: "Today"
                        on: editor.due !== null && editor.due.toDateString() === new Date().toDateString()
                        onClicked: { var t = new Date(); editor.due = new Date(t.getFullYear(), t.getMonth(), t.getDate()) }
                    }
                    Chip {
                        text: "Tomorrow"
                        on: editor.due !== null && editor.due.toDateString() === editor.addDays(new Date(), 1).toDateString()
                        onClicked: editor.due = editor.addDays(new Date(new Date().toDateString()), 1)
                    }
                    Chip {
                        text: "+1 week"
                        visible: editor.due !== null
                        onClicked: editor.due = editor.addDays(editor.due, 7)
                    }
                }
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "Google Tasks keeps only the date: no time, reminder or repeat through its API."
                    color: Theme.text; opacity: 0.3
                    font.family: Theme.fontText; font.pixelSize: 10
                }
            }

            Card {
                label: "Notes"; glyph: String.fromCodePoint(0xF09ED)
                Item {
                    width: parent.width
                    height: Math.max(54, notesIn.contentHeight + 4)
                    TextEdit {
                        id: notesIn
                        anchors.fill: parent
                        color: Theme.text
                        selectionColor: Theme.withAlpha(editor.tint, 0.4)
                        font.family: Theme.fontText; font.pixelSize: 13
                        wrapMode: TextEdit.Wrap
                        textFormat: TextEdit.PlainText
                        KeyNavigation.tab: titleIn
                    }
                    Text {
                        visible: notesIn.text === ""
                        text: "Add details"; color: Theme.text; opacity: 0.3
                        font.family: Theme.fontText; font.pixelSize: 13
                    }
                }
            }

            Card {
                visible: !editor.isSub
                label: "Subtasks" + (editor.subs.length ? " · " + editor.subs.filter(function (x) { return x.done }).length + "/" + editor.subs.length : "")
                glyph: String.fromCodePoint(0xF0756)
                Repeater {
                    model: editor.subs
                    delegate: Item {
                        required property var modelData
                        width: parent ? parent.width : 0
                        height: 30
                        Rectangle {
                            id: sc
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                            width: 18; height: 18; radius: 9
                            color: modelData.done ? editor.tint : "transparent"
                            border.width: modelData.done ? 0 : 1.5
                            border.color: scHov.hovered ? editor.tint : Theme.withAlpha(Theme.text, 0.35)
                            Text { anchors.centerIn: parent; visible: modelData.done; text: "✓"; color: Theme.accentText; font.pixelSize: 11; font.weight: Font.Bold }
                            HoverHandler { id: scHov; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: CalendarService.setTaskDone(modelData, !modelData.done) }
                        }
                        Text {
                            anchors { left: sc.right; leftMargin: 10; right: sx.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
                            text: modelData.title
                            color: Theme.text; opacity: modelData.done ? 0.4 : 0.9
                            font.strikeout: modelData.done
                            font.family: Theme.fontText; font.pixelSize: 13
                            elide: Text.ElideRight
                        }
                        Rectangle {
                            id: sx
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            width: 24; height: 24; radius: 12
                            opacity: rowHov.hovered ? 1 : 0
                            color: sxHov.hovered ? Theme.withAlpha(Theme.statusAlert, 0.18) : "transparent"
                            Text { anchors.centerIn: parent; text: "󰅖"; color: sxHov.hovered ? Theme.statusAlert : Theme.withAlpha(Theme.text, 0.5); font.family: Theme.iconFont; font.pixelSize: 12 }
                            HoverHandler { id: sxHov; cursorShape: Qt.PointingHandCursor }
                            TapHandler { enabled: rowHov.hovered; onTapped: CalendarService.deleteTask(modelData) }
                        }
                        HoverHandler { id: rowHov }
                    }
                }
                Item {
                    width: parent.width; height: 30
                    Text {
                        id: plusSub
                        anchors { left: parent.left; leftMargin: 3; verticalCenter: parent.verticalCenter }
                        text: "+"; color: editor.tint
                        font.family: Theme.fontText; font.pixelSize: 16; font.weight: Font.Bold
                    }
                    TextInput {
                        id: subIn
                        anchors { left: parent.left; leftMargin: 28; right: parent.right; verticalCenter: parent.verticalCenter }
                        color: Theme.text
                        selectionColor: Theme.withAlpha(editor.tint, 0.4)
                        font.family: Theme.fontText; font.pixelSize: 13
                        clip: true
                        onAccepted: editor.addSub()
                    }
                    Text {
                        anchors { left: subIn.left; verticalCenter: parent.verticalCenter }
                        visible: subIn.text === ""
                        text: "Add subtask"; color: Theme.text; opacity: 0.3
                        font.family: Theme.fontText; font.pixelSize: 13
                    }
                }
            }

            Card {
                visible: CalendarService.taskLists.length > 1 && !editor.isSub
                label: "List"; glyph: String.fromCodePoint(0xF0279)
                Flow {
                    width: parent.width
                    spacing: 6
                    Repeater {
                        model: CalendarService.taskLists
                        delegate: Chip {
                            required property var modelData
                            text: modelData.title
                            on: editor.listId === modelData.id
                            onClicked: editor.listId = modelData.id
                        }
                    }
                }
            }
        }
    }

    Item {
        id: foot
        enabled: !editor.picking
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 38
        Rectangle {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            width: delRow.implicitWidth + 22; height: 36; radius: 10
            color: editor.confirmDelete ? Theme.statusAlert
                 : (delHov.hovered ? Theme.withAlpha(Theme.statusAlert, 0.18) : Qt.rgba(1, 1, 1, 0.04))
            Behavior on color { ColorAnimation { duration: Theme.animColor } }
            Row {
                id: delRow
                anchors.centerIn: parent
                spacing: 6
                Text { text: String.fromCodePoint(0xF01B4); color: editor.confirmDelete ? Theme.accentText : Theme.statusAlert; font.family: Theme.iconFont; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: editor.confirmDelete ? (editor.subs.length ? "Sure? (and subtasks)" : "Sure?") : "Delete"
                    color: editor.confirmDelete ? Theme.accentText : Theme.statusAlert
                    font.family: Theme.fontText; font.pixelSize: 12; font.weight: Font.Medium
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            HoverHandler { id: delHov; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: editor.remove() }
        }
        Row {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 8
            Rectangle {
                width: 80; height: 36; radius: 10
                color: cHov.hovered ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)
                Text { anchors.centerIn: parent; text: "Cancel"; color: Theme.text; opacity: 0.7; font.family: Theme.fontText; font.pixelSize: 12; font.weight: Font.Medium }
                HoverHandler { id: cHov; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: editor.close() }
            }
            Rectangle {
                width: 80; height: 36; radius: 10
                readonly property bool ok: titleIn.text.trim() !== ""
                color: ok ? editor.tint : Qt.rgba(1, 1, 1, 0.04)
                Text { anchors.centerIn: parent; text: "Save"; color: parent.ok ? Theme.accentText : Theme.withAlpha(Theme.text, 0.35); font.family: Theme.fontText; font.pixelSize: 12; font.weight: Font.Bold }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: editor.save() }
            }
        }
    }

    Rectangle {
        id: pickDim
        anchors.fill: parent
        color: Theme.withAlpha(Theme.surfaceWell, 0.82)
        visible: opacity > 0.01
        opacity: editor.picking ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.animContentIn } }
        TapHandler {
            onTapped: function (ev) {
                var p = picker.mapFromItem(pickDim, ev.position.x, ev.position.y)
                if (p.x < 0 || p.y < 0 || p.x > picker.width || p.y > picker.height) { editor.picking = false; titleIn.forceActiveFocus() }
            }
        }
        WheelHandler {}
        DatePicker {
            id: picker
            anchors.centerIn: parent
            width: parent.width - 16
            height: implicitHeight
            tint: editor.tint
            title: "Due"
            quick: true
            allowClear: true
            focus: editor.picking
            onPicked: function (d) { editor.due = d; editor.picking = false; titleIn.forceActiveFocus() }
            onCleared: { editor.due = null; editor.picking = false; titleIn.forceActiveFocus() }
            onCancelled: { editor.picking = false; titleIn.forceActiveFocus() }
        }
    }
}
