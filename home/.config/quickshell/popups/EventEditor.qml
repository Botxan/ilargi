import QtQuick
import "../components"
import "../theme"
import "../services"

FocusScope {
    id: editor

    property color tint: Theme.accent
    property bool open: false
    signal closed()

    property var ev: null
    readonly property bool isNew: ev === null
    readonly property bool isSeries: !isNew && ev.recurringId !== ""
    readonly property bool readOnly: !isNew && ev.writable === false
    property date day: new Date()
    property date lastDay: new Date()
    property bool allDay: false
    property int startM: 600
    property int endM: 660
    property string freq: "none"
    property string ends: "never"
    property int count: 10
    property date until: new Date()
    property bool repeatTouched: false
    property bool remDefault: true
    property var rems: []
    property string calId: ""
    property string ask: ""
    property bool confirmDelete: false
    property string picking: ""
    function pickDate(which) {
        picking = which
        picker.title = which === "day" ? "Date" : which === "last" ? "Last day" : "Repeat until"
        picker.open(which === "day" ? day : which === "last" ? lastDay : until)
    }
    function datePicked(d) {
        if (picking === "day") {
            var span = Math.round((lastDay - day) / 86400000)
            day = d
            lastDay = addDays(d, span)
            if (until < d) until = addDays(d, 30)
        } else if (picking === "last") {
            lastDay = d < day ? day : d
        } else if (picking === "until") {
            until = d < day ? day : d
            ends = "until"; repeatTouched = true
        }
        picking = ""
        titleIn.forceActiveFocus()
    }

    readonly property var cal: CalendarService.calendarById(calId)
    readonly property var calDefault: cal ? cal.defaultReminders : []

    function addDays(d, n) { return new Date(d.getFullYear(), d.getMonth(), d.getDate() + n) }
    function hhmm(m) { m = ((m % 1440) + 1440) % 1440; return ("0" + Math.floor(m / 60)).slice(-2) + ":" + ("0" + (m % 60)).slice(-2) }
    function toMin(s) { var d = new Date(s); return d.getHours() * 60 + d.getMinutes() }
    function lengthText() {
        var n = endM - startM; if (n <= 0) n += 1440
        var h = Math.floor(n / 60), m = n % 60
        return h === 0 ? m + " min" : (m === 0 ? h + " h" : h + " h " + m)
    }
    function remLabel(m) {
        if (allDay) {
            if (m === 0) return "At 00:00"
            var d = Math.ceil(m / 1440), t = d * 1440 - m
            return (d === 1 ? "Day before" : d === 7 ? "Week before" : d + " days before") + " · " + hhmm(t)
        }
        if (m === 0) return "At start"
        if (m < 60) return m + " min"
        if (m < 1440) return Math.floor(m / 60) + " h" + (m % 60 ? " " + (m % 60) : "")
        return Math.floor(m / 1440) + " d" + (m % 1440 ? " " + Math.floor((m % 1440) / 60) + " h" : "")
    }
    readonly property var remChoices: {
        var base = allDay ? [900, 2340, 9540] : [0, 5, 10, 30, 60, 1440]
        var all = base.concat(rems).concat(allDay ? [] : calDefault)
        var seen = ({}), out = []
        for (var i = 0; i < all.length; i++) if (!seen[all[i]]) { seen[all[i]] = 1; out.push(all[i]) }
        return out.sort(function (a, b) { return a - b })
    }

    function reset() {
        ask = ""; confirmDelete = false; repeatTouched = false; picking = ""
        ends = "never"; count = 10
    }

    function openNew(d) {
        reset()
        ev = null
        day = d; lastDay = d
        var now = new Date()
        var sameDay = d.toDateString() === now.toDateString()
        startM = sameDay ? Math.min((now.getHours() + 1) * 60, 23 * 60) : 600
        endM = startM + 60
        allDay = false
        freq = "none"; until = addDays(d, 30)
        remDefault = true; rems = []
        calId = CalendarService.primaryCalendar ? CalendarService.primaryCalendar.id : "primary"
        titleIn.text = ""; placeIn.text = ""; notesIn.text = ""
        open = true
        titleIn.forceActiveFocus()
    }

    function openEdit(e) {
        reset()
        ev = e
        var s = new Date(e.start), en = new Date(e.end)
        day = new Date(s.getFullYear(), s.getMonth(), s.getDate())
        allDay = e.allDay
        lastDay = e.allDay ? addDays(new Date(en.getFullYear(), en.getMonth(), en.getDate()), -1) : day
        startM = e.allDay ? 600 : toMin(e.start)
        endM = e.allDay ? 660 : toMin(e.end)
        var r = e.repeat
        freq = r ? r.freq : "none"
        if (r && r.count) { ends = "count"; count = r.count }
        else if (r && r.until) { ends = "until"; var p = r.until.split("-"); until = new Date(+p[0], +p[1] - 1, +p[2]) }
        else until = addDays(day, 30)
        remDefault = e.remindersDefault === true
        rems = (e.reminders || []).slice()
        calId = e.calendar
        titleIn.text = e.title; placeIn.text = e.location || ""; notesIn.text = e.description || ""
        open = true
        titleIn.forceActiveFocus()
    }

    function close() { open = false; ask = ""; closed() }

    function payload(scope) {
        var rep = null
        if (isNew || repeatTouched || (!isSeries && freq !== "none"))
            rep = freq === "custom" ? null : {
                freq: freq,
                count: ends === "count" ? count : 0,
                until: ends === "until" ? CalendarService.key(until) : ""
            }
        return {
            calendar: calId, origCalendar: isNew ? calId : ev.calendar,
            id: isNew ? "" : ev.id, recurringId: isNew ? "" : ev.recurringId,
            scope: scope,
            title: titleIn.text.trim(), location: placeIn.text.trim(), description: notesIn.text,
            allDay: allDay, date: CalendarService.key(day), endDate: CalendarService.key(lastDay),
            start: hhmm(startM), end: hhmm(endM),
            origStart: isNew ? "" : ev.start,
            repeat: rep,
            reminders: remDefault ? null : rems
        }
    }
    function save() {
        if (readOnly || titleIn.text.trim() === "") return
        if (isSeries && !repeatTouched && ask === "") { ask = "save"; return }
        CalendarService.saveEvent(payload(isSeries ? (repeatTouched ? "all" : ask === "all" ? "all" : "this") : "this"))
        close()
    }
    function saveScoped(scope) {
        CalendarService.saveEvent(payload(scope))
        close()
    }
    function remove() {
        if (isNew || readOnly) return
        if (isSeries) { ask = "delete"; return }
        if (!confirmDelete) { confirmDelete = true; return }
        CalendarService.deleteEvent(ev, false)
        close()
    }
    function removeScoped(all) {
        CalendarService.deleteEvent(ev, all)
        close()
    }

    Keys.onEscapePressed: function (e) {
        if (picking !== "") { picking = ""; titleIn.forceActiveFocus() }
        else if (ask !== "") ask = ""; else close()
        e.accepted = true
    }
    Keys.onPressed: function (e) {
        if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && (e.modifiers & Qt.ControlModifier)) {
            save(); e.accepted = true
        }
    }

    visible: opacity > 0.01
    enabled: open
    opacity: open ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: editor.open ? Theme.animContentIn : Theme.animContentOut } }
    transform: Translate {
        y: editor.open ? 0 : 14
        Behavior on y { NumberAnimation { duration: Theme.animTransition; easing.type: Theme.animCurve } }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.surfaceWell
        TapHandler {}
        WheelHandler {}
    }

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
            font.features: Theme.tabularNums
        }
        HoverHandler { id: chipHov; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: chip.clicked() }
    }

    component Stepper: Rectangle {
        id: st
        property string text
        property string label: ""
        signal step(int d)
        signal activated()
        width: 150; height: 34; radius: 10
        color: Theme.surfaceSunk
        Text {
            visible: st.label !== ""
            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
            text: st.label
            color: Theme.text; opacity: 0.4
            font.family: Theme.fontText; font.pixelSize: 10
        }
        Rectangle {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: st.label !== "" ? 8 : 0
            width: stVal.implicitWidth + 16; height: 26; radius: 8
            color: stHov.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
            HoverHandler { id: stHov; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: st.activated() }
        }
        Text {
            id: stVal
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: st.label !== "" ? 8 : 0
            text: st.text
            color: Theme.text
            font.family: Theme.fontText; font.pixelSize: 13; font.weight: Font.Medium
            font.features: Theme.tabularNums
        }
        Repeater {
            model: [-1, 1]
            delegate: Rectangle {
                required property int modelData
                anchors.verticalCenter: parent.verticalCenter
                x: modelData < 0 ? 3 : st.width - width - 3
                visible: st.label === "" || modelData > 0
                width: 26; height: 28; radius: 8
                color: arrHov.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: parent.modelData < 0 ? "‹" : "›"
                    color: Theme.text; opacity: 0.7
                    font.family: Theme.fontText; font.pixelSize: 16
                }
                HoverHandler { id: arrHov; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: st.step(parent.modelData) }
            }
        }
        WheelHandler { onWheel: function (e) { st.step(e.angleDelta.y > 0 ? 1 : -1) } }
    }

    component TimeField: Rectangle {
        id: tf
        property int mins: 0
        property string label: ""
        property string note: ""
        property alias input: tin
        signal edited(int m)
        function fmt(m) { m = ((m % 1440) + 1440) % 1440; return ("0" + Math.floor(m / 60)).slice(-2) + ":" + ("0" + (m % 60)).slice(-2) }
        function parse(s) {
            s = s.trim()
            var h, mm
            if (s.indexOf(":") >= 0) { var p = s.split(":"); h = parseInt(p[0]); mm = parseInt(p[1] || "0") }
            else if (s.length <= 2) { h = parseInt(s); mm = 0 }
            else { h = parseInt(s.slice(0, s.length - 2)); mm = parseInt(s.slice(-2)) }
            if (isNaN(h) || isNaN(mm) || h > 23 || mm > 59 || h < 0 || mm < 0) return -1
            return h * 60 + mm
        }
        width: 104; height: 34; radius: 10
        color: Theme.surfaceSunk
        border.width: tin.activeFocus ? 1 : 0
        border.color: Theme.withAlpha(Theme.accent, 0.6)
        onMinsChanged: if (!tin.activeFocus) tin.text = fmt(mins)
        Component.onCompleted: tin.text = fmt(mins)
        Text {
            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
            text: tf.label
            color: Theme.text; opacity: 0.4
            font.family: Theme.fontText; font.pixelSize: 10
        }
        TextInput {
            id: tin
            anchors { right: parent.right; rightMargin: tf.note !== "" ? 26 : 10; verticalCenter: parent.verticalCenter }
            width: 44
            horizontalAlignment: TextInput.AlignRight
            color: Theme.text
            selectionColor: Theme.withAlpha(Theme.accent, 0.4)
            font.family: Theme.fontText; font.pixelSize: 14; font.weight: Font.Medium
            font.features: Theme.tabularNums
            maximumLength: 5
            validator: RegularExpressionValidator { regularExpression: /[0-9:]{0,5}/ }
            onActiveFocusChanged: {
                if (activeFocus) selectAll()
                else { var m = tf.parse(text); if (m >= 0 && m !== tf.mins) tf.edited(m); text = tf.fmt(tf.mins) }
            }
            onAccepted: { var m = tf.parse(text); if (m >= 0) tf.edited(m); text = tf.fmt(tf.mins); selectAll() }
        }
        Text {
            visible: tf.note !== ""
            anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
            text: tf.note
            color: Theme.accent
            font.family: Theme.fontText; font.pixelSize: 9; font.weight: Font.Bold
        }
        WheelHandler { onWheel: function (e) { tf.edited(tf.mins + (e.angleDelta.y > 0 ? 15 : -15)) } }
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
            Text {
                text: card.glyph
                color: Theme.accent; opacity: 0.85
                font.family: Theme.iconFont; font.pixelSize: 12
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: card.label
                color: Theme.text; opacity: 0.55
                font.family: Theme.fontText; font.pixelSize: 11; font.weight: Font.Medium
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        Column {
            id: inner
            x: 12; y: card.label !== "" ? 34 : 12
            width: card.width - 24
            spacing: 10
        }
    }

    Item {
        id: head
        enabled: editor.picking === "" && editor.ask === ""
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
            text: editor.isNew ? "New event" : (editor.readOnly ? "Event" : "Edit event")
            color: Theme.text
            font.family: Theme.fontText; font.pixelSize: 15; font.weight: Font.Bold
        }
        Rectangle {
            visible: !editor.isNew && editor.ev && editor.ev.link !== ""
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            width: gRow.implicitWidth + 20; height: 26; radius: 13
            color: gHov.hovered ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)
            Row {
                id: gRow
                anchors.centerIn: parent
                spacing: 5
                Text {
                    text: "Google"
                    color: Theme.text; opacity: 0.6
                    font.family: Theme.fontText; font.pixelSize: 11; font.weight: Font.Medium
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: String.fromCodePoint(0xF03CC)
                    color: Theme.text; opacity: 0.6
                    font.family: Theme.iconFont; font.pixelSize: 11
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            HoverHandler { id: gHov; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: { Qt.openUrlExternally(editor.ev.link); editor.close() } }
        }
    }

    Flickable {
        id: flick
        enabled: editor.picking === "" && editor.ask === ""
        anchors { left: parent.left; right: parent.right; top: head.bottom; topMargin: 12
                  bottom: foot.top; bottomMargin: 12 }
        contentWidth: width
        contentHeight: body.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: body
            width: flick.width
            spacing: 10
            enabled: !editor.readOnly

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
                    maximumLength: 200
                    readOnly: editor.readOnly
                    onAccepted: editor.save()
                    KeyNavigation.tab: fromF.input
                }
                Text {
                    anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                    visible: titleIn.text === ""
                    text: "Title"
                    color: Theme.text; opacity: 0.3
                    font.family: Theme.fontText; font.pixelSize: 16
                }
            }

            Card {
                label: "When"; glyph: String.fromCodePoint(0xF0954)
                Item {
                    width: parent.width; height: 34
                    Stepper {
                        id: dayStep
                        width: parent.width - allDayChip.width - 8
                        text: Qt.formatDate(editor.day, "ddd d MMMM yyyy")
                        onActivated: editor.pickDate("day")
                        onStep: function (d) {
                            var span = Math.round((editor.lastDay - editor.day) / 86400000)
                            editor.day = editor.addDays(editor.day, d)
                            editor.lastDay = editor.addDays(editor.day, span)
                        }
                    }
                    Chip {
                        id: allDayChip
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        height: 34; radius: 10
                        text: "All day"; on: editor.allDay
                        onClicked: {
                            editor.allDay = !editor.allDay
                            if (!editor.remDefault) editor.rems = []
                        }
                    }
                }
                Row {
                    visible: !editor.allDay
                    spacing: 8
                    TimeField {
                        id: fromF
                        label: "From"
                        mins: editor.startM
                        onEdited: function (m) {
                            var len = editor.endM - editor.startM; if (len <= 0) len += 1440
                            m = Math.max(0, Math.min(1439, m))
                            editor.startM = m
                            editor.endM = (m + len) % 1440
                        }
                    }
                    TimeField {
                        id: toF
                        label: "To"
                        mins: editor.endM
                        note: editor.endM <= editor.startM ? "+1" : ""
                        onEdited: function (m) { editor.endM = ((m % 1440) + 1440) % 1440 }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: editor.lengthText()
                        color: Theme.text; opacity: 0.4
                        font.family: Theme.fontText; font.pixelSize: 11
                    }
                }
                Stepper {
                    visible: editor.allDay
                    width: parent.width
                    label: "Until"
                    text: editor.lastDay.getTime() === editor.day.getTime() ? "Same day"
                        : Qt.formatDate(editor.lastDay, "ddd d MMMM")
                            + "  ·  " + (Math.round((editor.lastDay - editor.day) / 86400000) + 1) + " days"
                    onActivated: editor.pickDate("last")
                    onStep: function (d) {
                        var n = editor.addDays(editor.lastDay, d)
                        if (n >= editor.day) editor.lastDay = n
                    }
                }
            }

            Card {
                label: editor.isSeries ? "Repeat · changing it applies to every occurrence" : "Repeat"
                glyph: String.fromCodePoint(0xF0456)
                Flow {
                    width: parent.width
                    spacing: 6
                    Repeater {
                        model: [
                            { k: "none", l: "Never" }, { k: "DAILY", l: "Daily" },
                            { k: "WEEKDAYS", l: "Weekdays" }, { k: "WEEKLY", l: "Weekly · " + Qt.formatDate(editor.day, "ddd") },
                            { k: "MONTHLY", l: "Monthly · " + editor.day.getDate() }, { k: "YEARLY", l: "Yearly" }
                        ]
                        delegate: Chip {
                            required property var modelData
                            text: modelData.l
                            on: editor.freq === modelData.k
                            onClicked: { editor.freq = modelData.k; editor.repeatTouched = true }
                        }
                    }
                    Chip {
                        visible: editor.freq === "custom"
                        text: "Custom (kept)"; on: true
                    }
                }
                Flow {
                    visible: editor.freq !== "none" && editor.freq !== "custom"
                    width: parent.width
                    spacing: 6
                    Text {
                        height: 28; verticalAlignment: Text.AlignVCenter
                        text: "Ends"
                        color: Theme.text; opacity: 0.4
                        font.family: Theme.fontText; font.pixelSize: 11
                    }
                    Chip { text: "Never"; on: editor.ends === "never"; onClicked: { editor.ends = "never"; editor.repeatTouched = true } }
                    Chip {
                        text: editor.ends === "count" ? editor.count + " times" : "After…"
                        on: editor.ends === "count"
                        onClicked: { editor.ends = "count"; editor.repeatTouched = true }
                        WheelHandler {
                            enabled: editor.ends === "count"
                            onWheel: function (e) { editor.count = Math.max(2, Math.min(365, editor.count + (e.angleDelta.y > 0 ? 1 : -1))); editor.repeatTouched = true }
                        }
                    }
                    Chip {
                        text: editor.ends === "until" ? "Until " + Qt.formatDate(editor.until, "d MMM yyyy") : "Until…"
                        on: editor.ends === "until"
                        onClicked: editor.pickDate("until")
                        WheelHandler {
                            enabled: editor.ends === "until"
                            onWheel: function (e) {
                                var n = editor.addDays(editor.until, e.angleDelta.y > 0 ? 7 : -7)
                                if (n >= editor.day) editor.until = n
                                editor.repeatTouched = true
                            }
                        }
                    }
                }
                Text {
                    visible: editor.freq !== "none" && editor.ends !== "never" && editor.freq !== "custom"
                    text: editor.ends === "count" ? "Scroll on the chip to change it" : "Click the date to change it"
                    color: Theme.text; opacity: 0.3
                    font.family: Theme.fontText; font.pixelSize: 10
                }
            }

            Card {
                label: "Reminders · on this desktop and on your phone"
                glyph: String.fromCodePoint(0xF009A)
                Flow {
                    width: parent.width
                    spacing: 6
                    Chip {
                        text: "Default" + (!editor.allDay && editor.calDefault.length
                              ? " · " + editor.calDefault.map(function (m) { return editor.remLabel(m) }).join(", ") : "")
                        on: editor.remDefault
                        onClicked: { editor.remDefault = true; editor.rems = editor.allDay ? [] : editor.calDefault.slice() }
                    }
                    Repeater {
                        model: editor.remChoices
                        delegate: Chip {
                            required property int modelData
                            text: editor.remLabel(modelData)
                            on: !editor.remDefault && editor.rems.indexOf(modelData) >= 0
                            onClicked: {
                                var r = editor.remDefault ? [] : editor.rems.slice()
                                var i = r.indexOf(modelData)
                                if (i >= 0) r.splice(i, 1); else if (r.length < 5) r.push(modelData)
                                editor.remDefault = false
                                editor.rems = r.sort(function (a, b) { return a - b })
                            }
                        }
                    }
                    Chip {
                        text: "None"
                        on: !editor.remDefault && editor.rems.length === 0
                        onClicked: { editor.remDefault = false; editor.rems = [] }
                    }
                }
            }

            Card {
                Row {
                    width: parent.width
                    spacing: 10
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: String.fromCodePoint(0xF034E)
                        color: editor.tint; opacity: 0.85
                        font.family: Theme.iconFont; font.pixelSize: 14
                    }
                    Item {
                        width: parent.width - 24; height: 24
                        TextInput {
                            id: placeIn
                            anchors.fill: parent
                            verticalAlignment: TextInput.AlignVCenter
                            color: Theme.text
                            selectionColor: Theme.withAlpha(editor.tint, 0.4)
                            font.family: Theme.fontText; font.pixelSize: 13
                            clip: true
                            readOnly: editor.readOnly
                            onAccepted: editor.save()
                            KeyNavigation.tab: notesIn
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: placeIn.text === ""
                            text: "Location"
                            color: Theme.text; opacity: 0.3
                            font.family: Theme.fontText; font.pixelSize: 13
                        }
                    }
                }
                Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.05) }
                Row {
                    width: parent.width
                    spacing: 10
                    Text {
                        text: String.fromCodePoint(0xF09ED)
                        color: editor.tint; opacity: 0.85
                        font.family: Theme.iconFont; font.pixelSize: 14
                    }
                    Item {
                        width: parent.width - 24
                        height: Math.max(54, notesIn.contentHeight + 4)
                        TextEdit {
                            id: notesIn
                            anchors.fill: parent
                            color: Theme.text
                            selectionColor: Theme.withAlpha(editor.tint, 0.4)
                            font.family: Theme.fontText; font.pixelSize: 13
                            wrapMode: TextEdit.Wrap
                            readOnly: editor.readOnly
                            textFormat: TextEdit.PlainText
                            KeyNavigation.tab: titleIn
                        }
                        Text {
                            visible: notesIn.text === ""
                            text: "Notes"
                            color: Theme.text; opacity: 0.3
                            font.family: Theme.fontText; font.pixelSize: 13
                        }
                    }
                }
            }

            Card {
                visible: CalendarService.writableCalendars.length > 1 && !(editor.isSeries)
                label: "Calendar"; glyph: String.fromCodePoint(0xF00ED)
                Flow {
                    width: parent.width
                    spacing: 6
                    Repeater {
                        model: CalendarService.writableCalendars
                        delegate: Chip {
                            required property var modelData
                            text: modelData.name
                            on: editor.calId === modelData.id
                            onClicked: editor.calId = modelData.id
                        }
                    }
                }
            }

            Text {
                visible: editor.readOnly
                width: parent.width
                wrapMode: Text.WordWrap
                text: "This calendar is read-only."
                color: Theme.text; opacity: 0.4
                font.family: Theme.fontText; font.pixelSize: 11
            }
        }
    }

    Item {
        id: foot
        enabled: editor.picking === "" && editor.ask === ""
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 38

        Rectangle {
            visible: !editor.isNew && !editor.readOnly
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            width: delRow.implicitWidth + 22; height: 36; radius: 10
            color: editor.confirmDelete ? Theme.statusAlert
                 : (delHov.hovered ? Theme.withAlpha(Theme.statusAlert, 0.18) : Qt.rgba(1, 1, 1, 0.04))
            Behavior on color { ColorAnimation { duration: Theme.animColor } }
            Row {
                id: delRow
                anchors.centerIn: parent
                spacing: 6
                Text {
                    text: String.fromCodePoint(0xF01B4)
                    color: editor.confirmDelete ? Theme.accentText : Theme.statusAlert
                    font.family: Theme.iconFont; font.pixelSize: 13
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: editor.confirmDelete ? "Sure?" : "Delete"
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
                Text { anchors.centerIn: parent; text: editor.readOnly ? "Close" : "Cancel"; color: Theme.text; opacity: 0.7
                       font.family: Theme.fontText; font.pixelSize: 12; font.weight: Font.Medium }
                HoverHandler { id: cHov; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: editor.close() }
            }
            Rectangle {
                visible: !editor.readOnly
                width: 80; height: 36; radius: 10
                readonly property bool ok: titleIn.text.trim() !== ""
                color: ok ? editor.tint : Qt.rgba(1, 1, 1, 0.04)
                Behavior on color { ColorAnimation { duration: Theme.animColor } }
                Text { anchors.centerIn: parent; text: "Save"
                       color: parent.ok ? Theme.accentText : Theme.withAlpha(Theme.text, 0.35)
                       font.family: Theme.fontText; font.pixelSize: 12; font.weight: Font.Bold }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: editor.save() }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.withAlpha(Theme.surfaceWell, 0.82)
        visible: opacity > 0.01
        opacity: editor.picking !== "" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.animContentIn } }
        id: pickDim
        TapHandler {
            onTapped: function (ev) {
                var p = picker.mapFromItem(pickDim, ev.position.x, ev.position.y)
                if (p.x < 0 || p.y < 0 || p.x > picker.width || p.y > picker.height) {
                    editor.picking = ""; titleIn.forceActiveFocus()
                }
            }
        }
        WheelHandler {}

        DatePicker {
            id: picker
            anchors.centerIn: parent
            width: parent.width - 16
            height: implicitHeight
            tint: editor.tint
            focus: editor.picking !== ""
            onPicked: function (d) { editor.datePicked(d) }
            onCancelled: { editor.picking = ""; titleIn.forceActiveFocus() }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.withAlpha(Theme.surfaceWell, 0.82)
        visible: opacity > 0.01
        opacity: editor.ask !== "" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.animContentIn } }
        id: askDim
        TapHandler {
            onTapped: function (ev) {
                var p = askCard.mapFromItem(askDim, ev.position.x, ev.position.y)
                if (p.x < 0 || p.y < 0 || p.x > askCard.width || p.y > askCard.height) editor.ask = ""
            }
        }

        Rectangle {
            id: askCard
            anchors.centerIn: parent
            width: parent.width - 24
            height: askCol.implicitHeight + 32
            radius: 14
            color: Theme.surfaceSunk
            TapHandler {}
            Column {
                id: askCol
                x: 16; y: 16
                width: parent.width - 32
                spacing: 12
                Text {
                    text: editor.ask === "delete" ? "Delete a repeating event" : "Save a repeating event"
                    color: Theme.text
                    font.family: Theme.fontText; font.pixelSize: 14; font.weight: Font.Bold
                }
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: editor.ask === "delete"
                        ? "Only " + Qt.formatDate(editor.day, "ddd d MMM") + ", or every occurrence?"
                        : "Change only " + Qt.formatDate(editor.day, "ddd d MMM") + ", or every occurrence?"
                    color: Theme.text; opacity: 0.6
                    font.family: Theme.fontText; font.pixelSize: 12
                }
                Row {
                    anchors.right: parent.right
                    spacing: 8
                    Repeater {
                        model: [{ k: "this", l: "Only this one" }, { k: "all", l: "All events" }]
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool danger: editor.ask === "delete"
                            width: aText.implicitWidth + 24; height: 34; radius: 10
                            color: modelData.k === "all"
                                ? (danger ? Theme.statusAlert : editor.tint)
                                : (aHov.hovered ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05))
                            Text {
                                id: aText
                                anchors.centerIn: parent
                                text: parent.modelData.l
                                color: parent.modelData.k === "all" ? Theme.accentText : Theme.text
                                font.family: Theme.fontText; font.pixelSize: 12; font.weight: Font.Medium
                            }
                            HoverHandler { id: aHov; cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                onTapped: editor.ask === "delete"
                                    ? editor.removeScoped(parent.modelData.k === "all")
                                    : editor.saveScoped(parent.modelData.k)
                            }
                        }
                    }
                }
            }
        }
    }
}
