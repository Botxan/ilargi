import QtQuick
import "../theme"

FocusScope {
    id: root

    property date value: new Date()
    property color tint: Theme.accent
    property string title: "Pick a date"
    signal picked(date d)
    signal cancelled()
    signal cleared()
    property bool allowClear: false
    property bool quick: false

    property int viewYear: value.getFullYear()
    property int viewMonth: value.getMonth()
    readonly property date today: new Date()

    function open(d) {
        value = d
        viewYear = d.getFullYear(); viewMonth = d.getMonth()
        field.text = ""
        field.forceActiveFocus()
    }
    function pick(d) { value = d; picked(d) }
    function shiftMonth(n) {
        var d = new Date(viewYear, viewMonth + n, 1)
        viewYear = d.getFullYear(); viewMonth = d.getMonth()
    }

    readonly property var monthWords: [
        ["jan"], ["feb"], ["mar"], ["apr"], ["may"], ["jun"],
        ["jul"], ["aug"], ["sep"], ["oct"], ["nov"], ["dec"]]
    readonly property var dayWords: [
        ["mon"], ["tue"], ["wed"], ["thu"], ["fri"], ["sat"], ["sun"]]
    function monthOf(w) {
        w = w.toLowerCase()
        for (var i = 0; i < 12; i++)
            for (var j = 0; j < monthWords[i].length; j++)
                if (w.indexOf(monthWords[i][j]) === 0) return i
        return -1
    }
    function parse(s) {
        s = s.trim().toLowerCase()
        if (s === "") return null
        var t = new Date(today.getFullYear(), today.getMonth(), today.getDate())
        if (s === "today") return t
        if (s === "tomorrow") return new Date(t.getFullYear(), t.getMonth(), t.getDate() + 1)
        var rel = s.match(/^\+\s*(\d+)\s*([dwmy]?)/)
        if (rel) {
            var n = parseInt(rel[1]), u = rel[2]
            if (u === "w") return new Date(t.getFullYear(), t.getMonth(), t.getDate() + 7 * n)
            if (u === "m") return new Date(t.getFullYear(), t.getMonth() + n, t.getDate())
            if (u === "y") return new Date(t.getFullYear() + n, t.getMonth(), t.getDate())
            return new Date(t.getFullYear(), t.getMonth(), t.getDate() + n)
        }
        if (/^[a-z]+$/.test(s) && s.length >= 3 && monthOf(s) < 0) {
            for (var w = 0; w < 7; w++)
                for (var k = 0; k < dayWords[w].length; k++)
                    if (s.indexOf(dayWords[w][k]) === 0) {
                        var cur = (t.getDay() + 6) % 7
                        var ahead = (w - cur + 7) % 7 || 7
                        return new Date(t.getFullYear(), t.getMonth(), t.getDate() + ahead)
                    }
        }
        var parts = s.split(/[\/\-\.\s,]+/).filter(function (x) { return x !== "" && x !== "of" })
        var y = -1, m = -1, d = -1
        if (parts.length >= 1 && /^\d{4}$/.test(parts[0])) {
            y = parseInt(parts[0]); m = parseInt(parts[1]) - 1; d = parseInt(parts[2] || "1")
        } else {
            d = parseInt(parts[0])
            if (parts.length >= 2) m = /^\d+$/.test(parts[1]) ? parseInt(parts[1]) - 1 : monthOf(parts[1])
            else m = -2
            if (parts.length >= 3) { y = parseInt(parts[2]); if (y < 100) y += 2000 }
        }
        if (isNaN(d) || d < 1 || d > 31) return null
        if (m === -2) {
            var c = new Date(t.getFullYear(), t.getMonth(), d)
            if (c < t) c = new Date(t.getFullYear(), t.getMonth() + 1, d)
            return c.getDate() === d ? c : null
        }
        if (isNaN(m) || m < 0 || m > 11) return null
        if (y < 0) {
            y = t.getFullYear()
            if (new Date(y, m, d) < t) y += 1
        }
        if (isNaN(y) || y < 1970 || y > 2200) return null
        var r = new Date(y, m, d)
        return r.getMonth() === m ? r : null
    }
    readonly property var parsed: parse(field.text)

    Keys.onEscapePressed: function (e) { root.cancelled(); e.accepted = true }

    implicitWidth: 320
    implicitHeight: col.implicitHeight + 28

    Rectangle {
        anchors.fill: parent
        radius: 14
        color: Theme.surfaceSunk
        TapHandler {}
    }

    Column {
        id: col
        x: 14; y: 14
        width: parent.width - 28
        spacing: 10

        Text {
            text: root.title
            color: Theme.text
            font.family: Theme.fontText; font.pixelSize: 14; font.weight: Font.Bold
        }

        Flow {
            visible: root.quick || root.allowClear
            width: parent.width
            spacing: 6
            Repeater {
                model: {
                    var t = new Date(root.today.getFullYear(), root.today.getMonth(), root.today.getDate())
                    var out = []
                    if (root.allowClear) out.push({ l: "No date", d: null })
                    if (root.quick) {
                        out.push({ l: "Today", d: t })
                        out.push({ l: "Tomorrow", d: new Date(t.getFullYear(), t.getMonth(), t.getDate() + 1) })
                        var ahead = (7 - (t.getDay() + 6) % 7) || 7
                        out.push({ l: "Next week", d: new Date(t.getFullYear(), t.getMonth(), t.getDate() + ahead) })
                        out.push({ l: "In a month", d: new Date(t.getFullYear(), t.getMonth() + 1, t.getDate()) })
                    }
                    return out
                }
                delegate: Rectangle {
                    required property var modelData
                    width: qText.implicitWidth + 20; height: 28; radius: 14
                    color: qHov.hovered ? Theme.withAlpha(root.tint, 0.18) : Qt.rgba(1, 1, 1, 0.05)
                    Text {
                        id: qText
                        anchors.centerIn: parent
                        text: parent.modelData.l
                        color: parent.modelData.d ? root.tint : Theme.text
                        opacity: parent.modelData.d ? 1 : 0.7
                        font.family: Theme.fontText; font.pixelSize: 12; font.weight: Font.Medium
                    }
                    HoverHandler { id: qHov; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: parent.modelData.d ? root.pick(parent.modelData.d) : root.cleared() }
                }
            }
        }

        Rectangle {
            width: parent.width; height: 38; radius: 10
            color: Theme.surfaceRecess
            border.width: field.activeFocus ? 1 : 0
            border.color: Theme.withAlpha(root.tint, 0.5)
            TextInput {
                id: field
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.text
                selectionColor: Theme.withAlpha(root.tint, 0.4)
                font.family: Theme.fontText; font.pixelSize: 14
                clip: true
                onAccepted: if (root.parsed) root.pick(root.parsed)
                onTextChanged: {
                    var d = root.parse(text)
                    if (d) { root.viewYear = d.getFullYear(); root.viewMonth = d.getMonth() }
                }
            }
            Text {
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                visible: field.text === ""
                text: "15/3/2028 · 15 mar · +3w · friday"
                color: Theme.text; opacity: 0.3
                font.family: Theme.fontText; font.pixelSize: 13
            }
        }
        Text {
            visible: field.text !== ""
            text: root.parsed ? "↵  " + Qt.formatDate(root.parsed, "dddd d MMMM yyyy") : "Not a date I know"
            color: root.parsed ? root.tint : Theme.statusAlert
            opacity: root.parsed ? 1 : 0.8
            font.family: Theme.fontText; font.pixelSize: 12; font.weight: Font.Medium
        }

        Item {
            width: parent.width; height: 30
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Repeater {
                    model: [-1, 0, 1]
                    delegate: Rectangle {
                        required property int modelData
                        width: modelData === 0 ? 64 : 28; height: 28; radius: 8
                        color: modelData !== 0 && yHov.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: parent.modelData === 0 ? root.viewYear : (parent.modelData < 0 ? "‹" : "›")
                            color: parent.modelData === 0 ? root.tint : Theme.text
                            opacity: parent.modelData === 0 ? 1 : 0.7
                            font.family: Theme.fontText
                            font.pixelSize: parent.modelData === 0 ? 16 : 18
                            font.weight: parent.modelData === 0 ? Font.Bold : Font.Normal
                            font.features: Theme.tabularNums
                        }
                        HoverHandler { id: yHov; cursorShape: parent.modelData !== 0 ? Qt.PointingHandCursor : Qt.ArrowCursor }
                        TapHandler { enabled: parent.modelData !== 0; onTapped: root.viewYear += parent.modelData }
                    }
                }
            }
            WheelHandler { onWheel: function (e) { root.viewYear += e.angleDelta.y > 0 ? 1 : -1 } }
            Rectangle {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: tdText.implicitWidth + 20; height: 26; radius: 13
                color: tdHov.hovered ? Theme.withAlpha(root.tint, 0.18) : Qt.rgba(1, 1, 1, 0.05)
                Text {
                    id: tdText
                    anchors.centerIn: parent
                    text: "Today"
                    color: root.tint
                    font.family: Theme.fontText; font.pixelSize: 11; font.weight: Font.Medium
                }
                HoverHandler { id: tdHov; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.pick(new Date(root.today.getFullYear(), root.today.getMonth(), root.today.getDate())) }
            }
        }

        Grid {
            columns: 6
            spacing: 4
            Repeater {
                model: 12
                delegate: Rectangle {
                    required property int index
                    readonly property bool on: root.viewMonth === index
                    width: (col.width - 20) / 6; height: 28; radius: 8
                    color: on ? Theme.withAlpha(root.tint, 0.22) : (mHov.hovered ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.035))
                    Text {
                        anchors.centerIn: parent
                        text: Qt.locale("en_GB").standaloneMonthName(parent.index, Locale.ShortFormat)
                        color: parent.on ? root.tint : Theme.text
                        opacity: parent.on ? 1 : 0.7
                        font.family: Theme.fontText; font.pixelSize: 12; font.weight: Font.Medium
                    }
                    HoverHandler { id: mHov; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.viewMonth = parent.index }
                }
            }
        }

        Item {
            id: days
            width: parent.width
            readonly property int first: (new Date(root.viewYear, root.viewMonth, 1).getDay() + 6) % 7
            readonly property int count: new Date(root.viewYear, root.viewMonth + 1, 0).getDate()
            readonly property real cw: width / 7
            height: 18 + 6 * 30
            Row {
                Repeater {
                    model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                    delegate: Text {
                        required property var modelData
                        width: days.cw; height: 18
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        color: Theme.text; opacity: 0.5
                        font.family: Theme.fontText; font.pixelSize: 11; font.weight: Font.Bold
                    }
                }
            }
            Repeater {
                model: days.first + days.count
                delegate: Item {
                    required property int index
                    readonly property int day: index - days.first + 1
                    readonly property bool isToday: day === root.today.getDate() && root.viewMonth === root.today.getMonth() && root.viewYear === root.today.getFullYear()
                    readonly property bool isValue: day === root.value.getDate() && root.viewMonth === root.value.getMonth() && root.viewYear === root.value.getFullYear()
                    readonly property bool isTyped: root.parsed !== null && day === root.parsed.getDate() && root.viewMonth === root.parsed.getMonth() && root.viewYear === root.parsed.getFullYear()
                    visible: day > 0
                    x: (index % 7) * days.cw
                    y: 18 + Math.floor(index / 7) * 30
                    width: days.cw; height: 30
                    Rectangle {
                        anchors.centerIn: parent
                        width: 28; height: 28; radius: 14
                        color: parent.isToday ? root.tint
                             : (parent.isValue || parent.isTyped) ? Theme.withAlpha(root.tint, 0.18)
                             : (dHov.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                        border.width: (parent.isValue || parent.isTyped) && !parent.isToday ? 1.5 : 0
                        border.color: root.tint
                    }
                    Text {
                        anchors.centerIn: parent
                        text: parent.day
                        color: parent.isToday ? Theme.accentText : ((parent.isValue || parent.isTyped) ? root.tint : Theme.text)
                        font.family: Theme.fontText; font.pixelSize: 12
                        font.weight: parent.isToday || parent.isValue ? Font.Bold : Font.Normal
                        font.features: Theme.tabularNums
                    }
                    HoverHandler { id: dHov; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.pick(new Date(root.viewYear, root.viewMonth, parent.day)) }
                }
            }
            WheelHandler { onWheel: function (e) { root.shiftMonth(e.angleDelta.y > 0 ? -1 : 1) } }
        }
    }
}
