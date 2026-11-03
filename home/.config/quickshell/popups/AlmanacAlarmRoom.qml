import QtQuick
import "../components"
import "../theme"
import "../services"

Item {
    id: root

    property color tint: Theme.accent
    property real reveal: 1

    readonly property int chrome: 12 + 9 + 16 + 12 + 9
    readonly property real listWanted:
        Math.min(root.height * 0.52, 190 + AlarmService.alarms.length * 62)
    readonly property real composerH:
        Math.max(184, Math.min(430, root.height - chrome - listWanted))
    readonly property real grow: Theme.phase(composerH, 184, 246)
    readonly property real groupH:
        (66 + grow * 44) + (12 + grow * 18) + (26 + grow * 10) + (12 + grow * 20) + 38
    readonly property real groupTop: Math.max(16, (composerH - groupH) / 2)

    property int  nh: 7
    property int  nm: 30
    property var  newDays: []
    property string newLabel: ""

    function bump(unit, dir) {
        if (unit === "h") nh = (nh + dir + 24) % 24
        else nm = (nm + dir + 60) % 60
    }
    function toggleDay(d) {
        var next = []
        var had = false
        for (var i = 0; i < newDays.length; i++) {
            if (newDays[i] === d) { had = true; continue }
            next.push(newDays[i])
        }
        if (!had) next.push(d)
        next.sort(function (a, b) { return a - b })
        newDays = next
    }
    function daysLabel(days) {
        if (!days || days.length === 0) return "Once"
        if (days.length === 7) return "Every day"
        if (days.length === 5 && days.indexOf(5) < 0 && days.indexOf(6) < 0) return "Weekdays"
        if (days.length === 2 && days.indexOf(5) >= 0 && days.indexOf(6) >= 0) return "Weekends"
        var names = ["MO", "TU", "WE", "TH", "FR", "SA", "SU"]
        var out = []
        for (var i = 0; i < days.length; i++) out.push(names[days[i]])
        return out.join(" ")
    }

    Column {
        id: topPart
        anchors { left: parent.left; right: parent.right; top: parent.top }
        spacing: 0

        SectionHeader {
            width: parent.width
            label: "New alarm"
            tint: root.tint
            opacity: Theme.phase(root.reveal, 0, 0.16)

            Text {
                text: AlarmService.next
                    ? "Next in " + AlarmService.untilText(AlarmService.next.at)
                    : "None armed"
                color: AlarmService.next ? root.tint : Theme.text
                opacity: AlarmService.next ? 0.8 : 0.3
                font.family: Theme.fontText
                font.pixelSize: Theme.fsSection
                font.letterSpacing: Theme.trSection
            }
        }

        Item { width: 1; height: 9 }

        Rectangle {
            id: composer
            width: parent.width
            height: root.composerH
            radius: 12
            color: Theme.surfaceRecess
            border.width: 1
            border.color: Theme.grooveDark
            opacity: Theme.phase(root.reveal, 0.06, 0.3)

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: 11
                gradient: Gradient {
                    GradientStop { position: 0.35; color: "transparent" }
                    GradientStop { position: 1.0;  color: "transparent" }
                }
            }

            Row {
                id: clockRow
                anchors { top: parent.top
                          topMargin: root.groupTop
                          horizontalCenter: parent.horizontalCenter }
                spacing: 6

                Repeater {
                    model: [{ key: "h" }, { key: "m" }]
                    delegate: Rectangle {
                        id: well
                        required property var modelData
                        readonly property int value: modelData.key === "h" ? root.nh : root.nm
                        width: 86 + root.grow * 44
                        height: 66 + root.grow * 44
                        radius: 10 + root.grow * 4
                        color: Theme.shade(Theme.surfaceSunk, 0.18)
                        border.width: 1
                        border.color: wHov.hovered ? Theme.grooveLight : Theme.grooveDark
                        Behavior on border.color { ColorAnimation { duration: 140 } }

                        Text {
                            anchors.centerIn: parent
                            text: ("0" + well.value).slice(-2)
                            color: Theme.text
                            opacity: 0.95
                            font.family: Theme.fontText
                            font.features: Theme.tabularNums
                            font.pixelSize: 34 + root.grow * 24
                            font.weight: Font.Bold
                        }
                        Text {
                            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 2 }
                            text: "󰅃"
                            color: root.tint; opacity: wHov.hovered ? 0.5 : 0
                            font.family: Theme.iconFont; font.pixelSize: 10
                            Behavior on opacity { NumberAnimation { duration: 120 } }
                        }
                        Text {
                            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 2 }
                            text: "󰅀"
                            color: root.tint; opacity: wHov.hovered ? 0.5 : 0
                            font.family: Theme.iconFont; font.pixelSize: 10
                            Behavior on opacity { NumberAnimation { duration: 120 } }
                        }

                        HoverHandler { id: wHov; cursorShape: Qt.PointingHandCursor }
                        MouseArea {
                            anchors.fill: parent
                            onWheel: function (w) { root.bump(well.modelData.key, w.angleDelta.y > 0 ? 1 : -1) }
                            onClicked: function (m) { root.bump(well.modelData.key, m.y < height / 2 ? 1 : -1) }
                        }
                    }
                }
            }

            Text {
                anchors { verticalCenter: clockRow.verticalCenter; horizontalCenter: clockRow.horizontalCenter }
                text: ":"
                color: Theme.text; opacity: 0.4
                font.family: Theme.fontText
                font.pixelSize: 26 + root.grow * 16
                font.weight: Font.Bold
            }

            Row {
                id: dayRow
                anchors { top: clockRow.bottom
                          topMargin: 12 + root.grow * 18
                          horizontalCenter: parent.horizontalCenter }
                spacing: 5

                Repeater {
                    model: [
                        { d: 0, l: "M" }, { d: 1, l: "T" }, { d: 2, l: "W" }, { d: 3, l: "T" },
                        { d: 4, l: "F" }, { d: 5, l: "S" }, { d: 6, l: "S" }
                    ]
                    delegate: Rectangle {
                        id: chip
                        required property var modelData
                        readonly property bool on: root.newDays.indexOf(modelData.d) >= 0
                        width: 30 + root.grow * 12
                        height: 26 + root.grow * 10
                        radius: 7 + root.grow * 2
                        color: on ? Theme.withAlpha(root.tint, 0.22)
                             : (cHov.hovered ? Qt.rgba(1, 1, 1, 0.07) : Theme.shade(Theme.surfaceSunk, 0.10))
                        border.width: 1
                        border.color: on ? Theme.withAlpha(root.tint, 0.5) : Theme.grooveDark
                        Behavior on color { ColorAnimation { duration: 130 } }

                        Text {
                            anchors.centerIn: parent
                            text: chip.modelData.l
                            color: chip.on ? root.tint : Theme.text
                            opacity: chip.on ? 1 : 0.42
                            font.family: Theme.iconFont
                            font.pixelSize: 11 + root.grow * 3
                        }
                        HoverHandler { id: cHov; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: root.toggleDay(chip.modelData.d) }
                    }
                }
            }

            Row {
                anchors { top: dayRow.bottom
                          topMargin: 12 + root.grow * 20
                          left: parent.left; leftMargin: 14
                          right: parent.right; rightMargin: 14 }
                spacing: 10

                Rectangle {
                    width: parent.width - 88 - parent.spacing
                    height: 38
                    radius: 9
                    color: Theme.shade(Theme.surfaceSunk, 0.18)
                    border.width: 1
                    border.color: field.activeFocus ? Theme.withAlpha(root.tint, 0.45) : Theme.grooveDark
                    Behavior on border.color { ColorAnimation { duration: 140 } }

                    TextInput {
                        id: field
                        anchors.fill: parent
                        anchors.leftMargin: 11
                        anchors.rightMargin: 11
                        verticalAlignment: TextInput.AlignVCenter
                        text: root.newLabel
                        onTextChanged: root.newLabel = text
                        color: Theme.text
                        selectionColor: Theme.withAlpha(root.tint, 0.4)
                        font.family: Theme.fontText
                        font.pixelSize: 13
                        maximumLength: 28
                        clip: true
                        onAccepted: addBtn.commit()
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 11
                        visible: field.text === ""
                        text: "Label"
                        color: Theme.text; opacity: 0.26
                        font.family: Theme.fontText; font.pixelSize: 13
                    }
                }

                Rectangle {
                    id: addBtn
                    width: 88; height: 38; radius: 9
                    color: aHov.hovered ? Theme.withAlpha(root.tint, 0.32) : Theme.withAlpha(root.tint, 0.20)
                    border.width: 1
                    border.color: Theme.withAlpha(root.tint, 0.45)
                    Behavior on color { ColorAnimation { duration: 150 } }

                    function commit() {
                        AlarmService.add(root.nh, root.nm, root.newLabel, root.newDays)
                        root.newLabel = ""
                        field.text = ""
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰐕"
                            color: root.tint
                            font.family: Theme.iconFont; font.pixelSize: 14
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.daysLabel(root.newDays) === "Once" ? "Once" : "Add"
                            color: root.tint; opacity: 0.9
                            font.family: Theme.fontText
                            font.pixelSize: Theme.fsSection
                            font.letterSpacing: Theme.trSection
                        }
                    }
                    HoverHandler { id: aHov; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: addBtn.commit() }
                }
            }
        }
    }

    SectionHeader {
        id: listHeader
        anchors { left: parent.left; right: parent.right; top: topPart.bottom; topMargin: 16 }
        label: "Armed"
        tint: root.tint
        opacity: Theme.phase(root.reveal, 0.5, 0.16)

        Text {
            text: AlarmService.alarms.length === 0 ? "Empty"
                : AlarmService.alarms.length + (AlarmService.alarms.length === 1 ? " ALARM" : " ALARMS")
            color: Theme.text; opacity: 0.3
            font.family: Theme.fontText
            font.pixelSize: Theme.fsSection
            font.letterSpacing: Theme.trSection
        }
    }

    Rectangle {
        anchors { left: parent.left; right: parent.right
                  top: listHeader.bottom; topMargin: 9; bottom: parent.bottom }
        radius: 12
        color: Theme.surfaceRecess
        border.width: 1
        border.color: Theme.grooveDark
        clip: true
        opacity: Theme.phase(root.reveal, 0.56, 0.44)

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 11
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

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 30
            width: parent.width - 24
            spacing: 5
            visible: AlarmService.alarms.length === 0
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "No alarms set"
                color: Theme.text; opacity: 0.4
                font.family: Theme.fontText; font.pixelSize: 13
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: "They ring through this shell's own notifications"
                color: Theme.text; opacity: 0.22
                font.family: Theme.fontText
                font.pixelSize: Theme.fsSection
                font.letterSpacing: Theme.trSection
            }
        }

        ListView {
            anchors.fill: parent
            anchors.margins: 6
            visible: AlarmService.alarms.length > 0
            model: AlarmService.alarms
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: alarmRow
                required property var modelData
                width: ListView.view.width
                height: 52

                Text {
                    id: hhmm
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: ("0" + alarmRow.modelData.h).slice(-2) + ":" + ("0" + alarmRow.modelData.m).slice(-2)
                    color: alarmRow.modelData.enabled ? Theme.text : Theme.text
                    opacity: alarmRow.modelData.enabled ? 0.95 : 0.34
                    font.family: Theme.fontText
                    font.features: Theme.tabularNums
                    font.pixelSize: 20
                    font.weight: Font.Bold
                }

                Column {
                    anchors { left: hhmm.right; leftMargin: 12; verticalCenter: parent.verticalCenter
                              right: sw.left; rightMargin: 10 }
                    spacing: 2
                    Text {
                        width: parent.width
                        text: alarmRow.modelData.label
                        color: Theme.text
                        opacity: alarmRow.modelData.enabled ? 0.8 : 0.3
                        elide: Text.ElideRight
                        font.family: Theme.fontText; font.pixelSize: 12
                    }
                    Text {
                        width: parent.width
                        text: root.daysLabel(alarmRow.modelData.days)
                        color: alarmRow.modelData.enabled ? root.tint : Theme.text
                        opacity: alarmRow.modelData.enabled ? 0.62 : 0.22
                        elide: Text.ElideRight
                        font.family: Theme.fontText
                        font.pixelSize: Theme.fsSection
                        font.letterSpacing: Theme.trSection
                    }
                }

                Text {
                    id: del
                    anchors { right: sw.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    text: "󰆴"
                    color: Theme.statusAlert
                    opacity: rowHov.hovered ? (delHov.hovered ? 1 : 0.55) : 0
                    font.family: Theme.iconFont; font.pixelSize: 14
                    Behavior on opacity { NumberAnimation { duration: 130 } }
                    HoverHandler { id: delHov; cursorShape: Qt.PointingHandCursor }
                    TapHandler { enabled: rowHov.hovered; onTapped: AlarmService.remove(alarmRow.modelData.id) }
                }

                Rectangle {
                    id: sw
                    anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    width: 38; height: 20; radius: 10
                    color: alarmRow.modelData.enabled
                        ? Theme.withAlpha(root.tint, 0.24) : Theme.shade(Theme.surfaceSunk, 0.16)
                    border.width: 1
                    border.color: alarmRow.modelData.enabled
                        ? Theme.withAlpha(root.tint, 0.45) : Theme.grooveDark
                    Behavior on color { ColorAnimation { duration: 160 } }

                    Rectangle {
                        y: 3
                        x: alarmRow.modelData.enabled ? parent.width - width - 3 : 3
                        width: 14; height: 14; radius: 7
                        color: alarmRow.modelData.enabled ? root.tint : Theme.withAlpha(Theme.text, 0.42)
                        Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.InOutCubic } }
                        Behavior on color { ColorAnimation { duration: 160 } }
                    }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: AlarmService.setEnabled(alarmRow.modelData.id, !alarmRow.modelData.enabled)
                    }
                }

                Rule {
                    anchors { bottom: parent.bottom; left: parent.left; right: parent.right
                              leftMargin: 10; rightMargin: 10 }
                    tint: Theme.grooveDark; fade: 0.2
                }
                HoverHandler { id: rowHov }
            }
        }
    }
}
