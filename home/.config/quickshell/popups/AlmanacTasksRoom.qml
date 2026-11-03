import QtQuick
import "../components"
import "../theme"
import "../services"

Item {
    id: root
    property color tint: Theme.accent
    property real reveal: 1

    property var addDue: null
    property string listFilter: ""
    property bool showDone: false
    property bool pickingAdd: false
    readonly property bool covered: taskSheet.open || pickingAdd

    function today0() { var t = new Date(); return new Date(t.getFullYear(), t.getMonth(), t.getDate()) }
    function dayOf(s) { var p = s.split("-"); return new Date(+p[0], +p[1] - 1, +p[2]) }
    function shortDue(d) {
        if (!d) return "No date"
        var n = Math.round((d - today0()) / 86400000)
        if (n === 0) return "Today"
        if (n === 1) return "Tomorrow"
        return Qt.formatDate(d, d.getFullYear() === new Date().getFullYear() ? "ddd d MMM" : "d MMM yyyy")
    }
    function commit() {
        var t = field.text.trim()
        if (t === "") return
        var list = listFilter !== "" ? listFilter
                 : (CalendarService.taskLists.length ? CalendarService.taskLists[0].id : "@default")
        CalendarService.saveTask({ list: list, id: "", title: t, notes: "",
                                   due: addDue ? CalendarService.key(addDue) : "", parent: "" })
        field.text = ""
        addDue = null
    }

    function groupOf(t) {
        if (!t.due) return "nodate"
        var n = Math.round((dayOf(t.due) - today0()) / 86400000)
        return n < 0 ? "overdue" : n === 0 ? "today" : n === 1 ? "tomorrow" : n <= 7 ? "week" : "later"
    }
    readonly property var groupNames: ({ overdue: "Overdue", today: "Today", tomorrow: "Tomorrow",
                                         week: "This week", later: "Later", nodate: "No date" })
    readonly property var rows: {
        var v = CalendarService.tasks, tops = [], kids = ({})
        for (var i = 0; i < v.length; i++) {
            var t = v[i]
            if (listFilter !== "" && t.list !== listFilter) continue
            if (t.parent) { (kids[t.parent] = kids[t.parent] || []).push(t) }
            else tops.push(t)
        }
        for (var k in kids) kids[k].sort(function (a, b) { return a.position < b.position ? -1 : 1 })
        var groups = { overdue: [], today: [], tomorrow: [], week: [], later: [], nodate: [] }, done = []
        for (var j = 0; j < tops.length; j++) {
            if (tops[j].done) done.push(tops[j]); else groups[groupOf(tops[j])].push(tops[j])
        }
        var out = []
        function push(t) {
            var ks = kids[t.id] || []
            var nd = 0; for (var q = 0; q < ks.length; q++) if (ks[q].done) nd++
            out.push({ kind: "task", t: t, depth: 0, nsub: ks.length, nsubDone: nd })
            for (var s = 0; s < ks.length; s++) out.push({ kind: "task", t: ks[s], depth: 1, nsub: 0, nsubDone: 0 })
        }
        var order = ["overdue", "today", "tomorrow", "week", "later", "nodate"]
        for (var g = 0; g < order.length; g++) {
            var arr = groups[order[g]]
            if (!arr.length) continue
            arr.sort(function (a, b) { return (a.due || "9") < (b.due || "9") ? -1 : (a.due === b.due ? (a.position < b.position ? -1 : 1) : 1) })
            out.push({ kind: "head", key: order[g], label: groupNames[order[g]], n: arr.length })
            for (var m = 0; m < arr.length; m++) push(arr[m])
        }
        if (done.length) {
            out.push({ kind: "head", key: "done", label: "Completed", n: done.length })
            if (showDone) for (var d = 0; d < done.length; d++) push(done[d])
        }
        return out
    }
    readonly property int openCount: {
        var n = 0, v = CalendarService.tasks
        for (var i = 0; i < v.length; i++) if (!v[i].done && !v[i].parent && (listFilter === "" || v[i].list === listFilter)) n++
        return n
    }

    SectionHeader {
        id: head
        anchors { left: parent.left; right: parent.right; top: parent.top }
        label: "Tasks"
        tint: root.tint
        opacity: Theme.phase(root.reveal, 0, 0.2)
        Text {
            text: CalendarService.writing ? "Syncing…"
                : (CalendarService.lastError !== "" ? "Sync failed"
                : root.openCount + " open")
            color: CalendarService.lastError !== "" ? Theme.statusAlert : Theme.text
            opacity: CalendarService.lastError !== "" ? 0.9 : 0.4
            font.family: Theme.fontText; font.pixelSize: Theme.fsSection
        }
    }

    Flow {
        id: lists
        anchors { left: parent.left; right: parent.right; top: head.bottom; topMargin: CalendarService.taskLists.length > 1 ? 8 : 0 }
        height: CalendarService.taskLists.length > 1 ? implicitHeight : 0
        visible: CalendarService.taskLists.length > 1
        enabled: !root.covered
        spacing: 6
        Repeater {
            model: [{ id: "", title: "All" }].concat(CalendarService.taskLists)
            delegate: Rectangle {
                required property var modelData
                readonly property bool on: root.listFilter === modelData.id
                width: lt.implicitWidth + 20; height: 26; radius: 13
                color: on ? Theme.withAlpha(root.tint, 0.22) : (lh.hovered ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04))
                Text { id: lt; anchors.centerIn: parent; text: parent.modelData.title; color: parent.on ? root.tint : Theme.text; opacity: parent.on ? 1 : 0.65; font.family: Theme.fontText; font.pixelSize: 11; font.weight: Font.Medium }
                HoverHandler { id: lh; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.listFilter = parent.modelData.id }
            }
        }
    }

    Rectangle {
        id: addCard
        anchors { left: parent.left; right: parent.right; top: lists.bottom; topMargin: 10 }
        height: 48
        radius: 12
        enabled: !root.covered
        color: Theme.surfaceRecess
        border.width: field.activeFocus ? 1 : 0
        border.color: Theme.withAlpha(root.tint, 0.45)
        opacity: Theme.phase(root.reveal, 0.05, 0.25)

        Rectangle {
            id: plus
            anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
            width: 32; height: 32; radius: 16
            color: field.text.trim() !== "" ? root.tint : Theme.withAlpha(Theme.text, 0.06)
            Behavior on color { ColorAnimation { duration: Theme.animColor } }
            Text {
                anchors.centerIn: parent
                text: "+"
                color: field.text.trim() !== "" ? Theme.accentText : Theme.withAlpha(Theme.text, 0.5)
                font.family: Theme.fontText; font.pixelSize: 18; font.weight: Font.Bold
            }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: root.commit() }
        }

        Rectangle {
            id: dueChip
            anchors { right: plus.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
            width: dueRow.implicitWidth + 20; height: 28; radius: 14
            color: root.addDue ? Theme.withAlpha(root.tint, 0.20)
                 : (chipHov.hovered ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04))
            Behavior on color { ColorAnimation { duration: Theme.animColor } }
            Row {
                id: dueRow
                anchors.centerIn: parent
                spacing: 5
                Text {
                    text: String.fromCodePoint(0xF00ED)
                    color: root.addDue ? root.tint : Theme.text
                    opacity: root.addDue ? 1 : 0.55
                    font.family: Theme.iconFont; font.pixelSize: 11
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: root.shortDue(root.addDue)
                    color: root.addDue ? root.tint : Theme.text
                    opacity: root.addDue ? 1 : 0.55
                    font.family: Theme.fontText; font.pixelSize: 11; font.weight: Font.Medium
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            HoverHandler { id: chipHov; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: { root.pickingAdd = true; addPicker.open(root.addDue ? root.addDue : new Date()) } }
        }

        TextInput {
            id: field
            anchors { left: parent.left; leftMargin: 14; right: dueChip.left; rightMargin: 10
                      verticalCenter: parent.verticalCenter }
            color: Theme.text
            selectionColor: Theme.withAlpha(root.tint, 0.4)
            font.family: Theme.fontText; font.pixelSize: 13
            clip: true
            maximumLength: 1024
            onAccepted: root.commit()
            Keys.onEscapePressed: function (e) {
                if (text !== "") { text = ""; e.accepted = true } else e.accepted = false
            }
        }
        Text {
            anchors { left: field.left; verticalCenter: parent.verticalCenter }
            visible: field.text === ""
            text: "New task"
            color: Theme.text; opacity: 0.3
            font.family: Theme.fontText; font.pixelSize: 13
        }
    }

    Flickable {
        id: flick
        anchors { left: parent.left; right: parent.right; top: addCard.bottom; bottom: parent.bottom; topMargin: 6 }
        contentWidth: width
        contentHeight: col.implicitHeight + 8
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        enabled: !root.covered
        opacity: Theme.phase(root.reveal, 0.1, 0.3)

        Column {
            id: col
            width: flick.width
            spacing: 6

            Repeater {
                model: root.rows
                delegate: Item {
                    id: rowItem
                    required property var modelData
                    readonly property bool isHead: modelData.kind === "head"
                    width: col.width
                    height: isHead ? 30 : (task.height)

                    Item {
                        visible: rowItem.isHead
                        anchors.fill: parent
                        Row {
                            anchors { left: parent.left; leftMargin: 2; bottom: parent.bottom; bottomMargin: 4 }
                            spacing: 6
                            Text {
                                text: rowItem.modelData.label || ""
                                color: rowItem.modelData.key === "overdue" ? Theme.statusAlert
                                     : rowItem.modelData.key === "today" ? root.tint : Theme.text
                                opacity: rowItem.modelData.key === "overdue" || rowItem.modelData.key === "today" ? 0.95 : 0.55
                                font.family: Theme.fontText; font.pixelSize: 12; font.weight: Font.Bold
                            }
                            Text {
                                text: rowItem.modelData.n !== undefined ? rowItem.modelData.n : ""
                                color: Theme.text; opacity: 0.3
                                font.family: Theme.fontText; font.pixelSize: 12
                            }
                            Text {
                                visible: rowItem.modelData.key === "done"
                                text: String.fromCodePoint(root.showDone ? 0xF0143 : 0xF0140)
                                color: Theme.text; opacity: 0.45
                                font.family: Theme.iconFont; font.pixelSize: 12
                            }
                        }
                        HoverHandler { enabled: rowItem.isHead && rowItem.modelData.key === "done"; cursorShape: Qt.PointingHandCursor }
                        TapHandler { enabled: rowItem.isHead && rowItem.modelData.key === "done"; onTapped: root.showDone = !root.showDone }
                    }

                    Rectangle {
                        id: task
                        visible: !rowItem.isHead
                        readonly property var t: rowItem.isHead ? null : rowItem.modelData.t
                        readonly property int depth: rowItem.isHead ? 0 : rowItem.modelData.depth
                        readonly property bool done: t ? t.done : false
                        readonly property bool overdue: t && !done && t.due !== "" && root.dayOf(t.due) < root.today0()
                        readonly property string dueText: {
                            if (!t || !t.due || depth > 0) return ""
                            var g = root.groupOf(t)
                            if (g === "today" || g === "tomorrow") return ""
                            return root.shortDue(root.dayOf(t.due))
                        }
                        readonly property string meta: {
                            if (!t) return ""
                            var bits = []
                            if (dueText !== "") bits.push(dueText)
                            if (rowItem.modelData.nsub) bits.push(rowItem.modelData.nsubDone + "/" + rowItem.modelData.nsub + " subtasks")
                            return bits.join("  ·  ")
                        }
                        x: depth * 26
                        width: parent.width - x
                        height: depth > 0 ? 38 : (meta !== "" || (t && t.notes) ? 54 : 44)
                        radius: depth > 0 ? 10 : 12
                        color: rowHov.hovered ? Theme.lift(Theme.surfaceRecess, 0.025) : Theme.surfaceRecess
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                        Rectangle {
                            id: check
                            anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                            width: task.depth ? 16 : 20; height: width; radius: width / 2
                            color: task.done ? root.tint : "transparent"
                            border.width: task.done ? 0 : 1.5
                            border.color: checkHov.hovered ? root.tint
                                        : task.overdue ? Theme.withAlpha(Theme.statusAlert, 0.7) : Theme.withAlpha(Theme.text, 0.35)
                            Behavior on color { ColorAnimation { duration: Theme.animColor } }
                            Text {
                                anchors.centerIn: parent
                                visible: task.done
                                text: "✓"
                                color: Theme.accentText
                                font.pixelSize: task.depth ? 10 : 12; font.weight: Font.Bold
                            }
                            HoverHandler { id: checkHov; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: CalendarService.setTaskDone(task.t, !task.done) }
                        }

                        Column {
                            anchors { left: check.right; leftMargin: 12; right: del.left; rightMargin: 8
                                      verticalCenter: parent.verticalCenter }
                            spacing: 3
                            Row {
                                width: parent.width
                                spacing: 6
                                Text {
                                    width: Math.min(implicitWidth, parent.width - (noteMark.visible ? 20 : 0))
                                    text: task.t ? task.t.title : ""
                                    color: Theme.text
                                    opacity: task.done ? 0.4 : 0.92
                                    font.family: Theme.fontText; font.pixelSize: task.depth ? 12 : 13
                                    font.strikeout: task.done
                                    elide: Text.ElideRight
                                }
                                Text {
                                    id: noteMark
                                    visible: task.t !== null && task.t.notes !== ""
                                    text: String.fromCodePoint(0xF09ED)
                                    color: Theme.text; opacity: 0.35
                                    font.family: Theme.iconFont; font.pixelSize: 11
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            Text {
                                visible: task.meta !== ""
                                text: task.meta
                                color: task.overdue ? Theme.statusAlert : Theme.text
                                opacity: task.overdue ? 0.9 : 0.45
                                font.family: Theme.fontText; font.pixelSize: 11
                            }
                        }

                        Rectangle {
                            id: del
                            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                            width: 26; height: 26; radius: 13
                            opacity: rowHov.hovered ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                            color: delHov.hovered ? Theme.withAlpha(Theme.statusAlert, 0.18) : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: "󰅖"
                                color: delHov.hovered ? Theme.statusAlert : Theme.withAlpha(Theme.text, 0.5)
                                font.family: Theme.iconFont; font.pixelSize: 13
                            }
                            HoverHandler { id: delHov; cursorShape: Qt.PointingHandCursor }
                            TapHandler { enabled: rowHov.hovered; onTapped: CalendarService.deleteTask(task.t) }
                        }

                        HoverHandler { id: rowHov; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: taskSheet.openTask(task.t) }
                    }
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 30
            visible: root.rows.length === 0
            text: CalendarService.configured ? "No tasks — add one above" : "Google is not connected"
            color: Theme.text; opacity: 0.35
            font.family: Theme.fontText; font.pixelSize: 13
        }
    }

    Rectangle {
        id: addDim
        anchors.fill: parent
        z: 40
        color: Theme.withAlpha(Theme.surfaceWell, 0.82)
        visible: opacity > 0.01
        opacity: root.pickingAdd ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.animContentIn } }
        TapHandler {
            onTapped: function (ev) {
                var p = addPicker.mapFromItem(addDim, ev.position.x, ev.position.y)
                if (p.x < 0 || p.y < 0 || p.x > addPicker.width || p.y > addPicker.height) { root.pickingAdd = false; field.forceActiveFocus() }
            }
        }
        WheelHandler {}
        DatePicker {
            id: addPicker
            anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
            width: parent.width
            height: implicitHeight
            tint: root.tint
            title: "Due"
            quick: true
            allowClear: true
            focus: root.pickingAdd
            onPicked: function (d) { root.addDue = d; root.pickingAdd = false; field.forceActiveFocus() }
            onCleared: { root.addDue = null; root.pickingAdd = false; field.forceActiveFocus() }
            onCancelled: { root.pickingAdd = false; field.forceActiveFocus() }
        }
    }

    TaskEditor {
        id: taskSheet
        anchors.fill: parent
        z: 50
        tint: root.tint
    }
}
