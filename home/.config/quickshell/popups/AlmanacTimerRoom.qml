import QtQuick
import "../components"
import "../shapes"
import "../theme"
import "../services"

Item {
    id: root

    property color tint: Theme.accent
    property real reveal: 1

    property int ch: 0
    property int cm: 5
    property int cs: 0
    readonly property int customTotal: ch * 3600 + cm * 60 + cs

    function fmt(total) {
        var t = Math.max(0, Math.round(total))
        var h = Math.floor(t / 3600), m = Math.floor((t % 3600) / 60), sec = t % 60
        if (h > 0) return h + ":" + ("0" + m).slice(-2) + ":" + ("0" + sec).slice(-2)
        return m + ":" + ("0" + sec).slice(-2)
    }
    readonly property bool armed: TimerService.totalSeconds > 0

    function bump(unit, dir) {
        if (unit === "h") ch = Math.max(0, Math.min(23, ch + dir))
        else if (unit === "m") cm = Math.max(0, Math.min(59, cm + dir))
        else cs = Math.max(0, Math.min(59, cs + dir))
    }

    SectionHeader {
            id: head
            anchors { left: parent.left; right: parent.right; top: parent.top }
            label: "Timer"
            tint: root.tint
            opacity: Theme.phase(root.reveal, 0, 0.16)

            Text {
                text: TimerService.totalSeconds === 0 ? "Idle"
                    : (TimerService.running ? "Running" : "Paused")
                color: TimerService.running ? root.tint : Theme.text
                opacity: TimerService.running ? 0.85 : 0.32
                font.family: Theme.fontText
                font.pixelSize: Theme.fsSection
                font.letterSpacing: Theme.trSection
            }
        }

    Rectangle {
            id: face
            anchors { left: parent.left; right: parent.right
                      top: head.bottom; topMargin: 9
                      bottom: presetsHead.top; bottomMargin: 16 }
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
                    GradientStop {
                        position: 1.0
                        color: "transparent"
                    }
                }
            }
            Rule {
                anchors { bottom: parent.bottom; bottomMargin: 1; left: parent.left; right: parent.right
                          leftMargin: 8; rightMargin: 8 }
                tint: Theme.grooveLight; fade: 0.14
            }

            readonly property real ringSize:
                Math.max(150, Math.min(300, height - 190))

            Canvas {
                id: dialRing
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -26
                width: face.ringSize; height: face.ringSize

                readonly property real prog: TimerService.totalSeconds > 0 ? TimerService.progress : 0
                readonly property real appear: Theme.phase(root.reveal, 0.16, 0.5)
                onProgChanged: requestPaint()
                onAppearChanged: requestPaint()

                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const cx = width / 2, cy = height / 2
                    const LW = Math.max(8, width * 0.05)
                    const r = cx - LW / 2 - 8
                    const TAU = Math.PI * 2
                    const sweep = TAU * appear
                    if (sweep <= 0.001) return

                    ctx.beginPath()
                    ctx.lineWidth = LW
                    ctx.strokeStyle = Theme.palette.bg4
                    ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + sweep)
                    ctx.stroke()

                    ctx.beginPath()
                    ctx.lineWidth = 1
                    ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.09)
                    ctx.arc(cx, cy, r + LW / 2 + 0.5, -Math.PI / 2, -Math.PI / 2 + sweep)
                    ctx.stroke()

                    if (prog > 0) {
                        ctx.beginPath()
                        ctx.lineCap = "round"
                        ctx.lineWidth = LW - 2
                        ctx.strokeStyle = Theme.withAlpha(root.tint, 0.85)
                        ctx.arc(cx, cy, r, -Math.PI / 2,
                                -Math.PI / 2 + Math.min(sweep, TAU * prog))
                        ctx.stroke()
                        ctx.lineCap = "butt"
                    }

                    ctx.lineWidth = 1
                    for (var i = 0; i < 60; i += 5) {
                        const a = -Math.PI / 2 + i / 60 * TAU
                        if (a + Math.PI / 2 > sweep) continue
                        const r0 = r + LW / 2 + 4
                        const major = i % 15 === 0
                        ctx.beginPath()
                        ctx.strokeStyle = Qt.rgba(1, 1, 1, major ? 0.22 : 0.10)
                        ctx.moveTo(cx + Math.cos(a) * r0, cy + Math.sin(a) * r0)
                        ctx.lineTo(cx + Math.cos(a) * (r0 + (major ? 7 : 4)),
                                   cy + Math.sin(a) * (r0 + (major ? 7 : 4)))
                        ctx.stroke()
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 3
                    opacity: Theme.phase(root.reveal, 0.4, 0.3)
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.armed ? TimerService.display() : root.fmt(root.customTotal)
                        color: TimerService.running ? root.tint : Theme.text
                        opacity: root.armed ? 1 : (root.customTotal > 0 ? 0.34 : 0.18)
                        font.family: Theme.fontText
                        font.features: Theme.tabularNums
                        font.pixelSize: Math.round(face.ringSize * 0.22)
                        font.weight: Font.Bold
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.armed
                            ? (TimerService.label !== "" ? TimerService.label
                               : "of " + Math.round(TimerService.totalSeconds / 60) + " min")
                            : (root.customTotal > 0 ? "Ready" : "Pick a preset")
                        color: Theme.text
                        opacity: 0.3
                        font.family: Theme.fontText
                        font.pixelSize: Theme.fsSection
                        font.letterSpacing: Theme.trSection
                    }
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: dialRing.bottom
                anchors.topMargin: 22
                spacing: 10
                visible: root.armed
                opacity: Theme.phase(root.reveal, 0.5, 0.3)

                Repeater {
                    model: [{ act: "toggle" }, { act: "cancel" }]
                    delegate: Rectangle {
                        id: ctlBtn
                        required property var modelData
                        readonly property bool primary: modelData.act === "toggle"
                        width: 108; height: 34; radius: 9
                        color: primary
                            ? (ctlHov.hovered ? Theme.withAlpha(root.tint, 0.30)
                                              : Theme.withAlpha(root.tint, 0.20))
                            : (ctlHov.hovered ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.04))
                        border.width: 1
                        border.color: primary ? Theme.withAlpha(root.tint, 0.45)
                                              : Qt.rgba(1, 1, 1, 0.09)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 7
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: ctlBtn.primary ? (TimerService.running ? "󰏤" : "󰐊") : "󰜺"
                                color: ctlBtn.primary ? root.tint : Theme.text
                                opacity: ctlBtn.primary ? 1 : 0.6
                                font.family: Theme.iconFont
                                font.pixelSize: 12
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: ctlBtn.primary ? (TimerService.running ? "Pause" : "Resume") : "Cancel"
                                color: ctlBtn.primary ? root.tint : Theme.text
                                opacity: ctlBtn.primary ? 1 : 0.65
                                font.family: Theme.fontText
                                font.pixelSize: 11
                            }
                        }
                        HoverHandler { id: ctlHov; cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: {
                                if (ctlBtn.primary) TimerService.toggle()
                                else TimerService.stop()
                            }
                        }
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: dialRing.bottom
                anchors.topMargin: 26
                visible: !root.armed
                width: parent.width - 40
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: "A running timer also shows in the centre island"
                color: Theme.text; opacity: 0.24
                font.family: Theme.fontText
                font.pixelSize: Theme.fsSection
                font.letterSpacing: Theme.trSection
            }
    }

    SectionHeader {
        id: presetsHead
        anchors { left: parent.left; right: parent.right; bottom: presets.top; bottomMargin: 9 }
        label: "Presets"
        tint: root.tint
        opacity: Theme.phase(root.reveal, 0.5, 0.16)
    }

    Grid {
        id: presets
        anchors { left: parent.left; right: parent.right; bottom: customHead.top; bottomMargin: 16 }
        columns: 2
            columnSpacing: 10
            rowSpacing: 10
            readonly property real cellW: (width - columnSpacing) / 2
            opacity: Theme.phase(root.reveal, 0.56, 0.3)

            Repeater {
                model: [
                    { m: 5,  label: "Short",    glyph: "󰅐" },
                    { m: 15, label: "Break",    glyph: "󰅶" },
                    { m: 25, label: "Pomodoro", glyph: "󰔛" },
                    { m: 45, label: "Deep",     glyph: "󰧑" }
                ]
                delegate: Rectangle {
                    id: preset
                    required property var modelData
                    readonly property bool active: TimerService.totalSeconds === modelData.m * 60
                    width: presets.cellW
                    height: 58
                    radius: 12
                    color: active ? Theme.withAlpha(root.tint, 0.16)
                         : (pHov.hovered ? Theme.lift(Theme.surfaceRecess, 0.04) : Theme.surfaceRecess)
                    border.width: 1
                    border.color: active ? Theme.withAlpha(root.tint, 0.45)
                         : (pHov.hovered ? Theme.grooveLight : Theme.grooveDark)
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    Rule {
                        anchors { top: parent.top; topMargin: 1; left: parent.left; right: parent.right
                                  leftMargin: 7; rightMargin: 7 }
                        tint: Theme.grooveDark; fade: 0.16
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 11
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: preset.modelData.glyph
                            color: root.tint
                            opacity: preset.active ? 1 : 0.55
                            font.family: Theme.iconFont
                            font.pixelSize: 17
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Text {
                                text: preset.modelData.m + " min"
                                color: Theme.text; opacity: 0.88
                                font.family: Theme.fontText; font.pixelSize: 13
                            }
                            Text {
                                text: preset.modelData.label
                                color: Theme.text; opacity: 0.3
                                font.family: Theme.fontText
                                font.pixelSize: Theme.fsSection
                                font.letterSpacing: Theme.trSection
                            }
                        }
                    }
                    HoverHandler { id: pHov; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: {
                            root.ch = Math.floor(preset.modelData.m / 60)
                            root.cm = preset.modelData.m % 60
                            root.cs = 0
                            TimerService.start(preset.modelData.m * 60, preset.modelData.label)
                        }
                    }
                }
            }
        }

    SectionHeader {
        id: customHead
        anchors { left: parent.left; right: parent.right; bottom: custom.top; bottomMargin: 9 }
        label: "Custom"
        tint: root.tint
        opacity: Theme.phase(root.reveal, 0.66, 0.16)

            Text {
                text: "Scroll or click above / below"
                color: Theme.text; opacity: 0.24
                font.family: Theme.fontText
                font.pixelSize: Theme.fsSection
                font.letterSpacing: Theme.trSection
            }
        }

    Row {
        id: custom
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 76
            spacing: 10
            opacity: Theme.phase(root.reveal, 0.72, 0.28)
            readonly property real wellW: (width - spacing * 3 - 88) / 3

            Repeater {
                model: [
                    { key: "h", cap: "hrs" },
                    { key: "m", cap: "min" },
                    { key: "s", cap: "sec" }
                ]
                delegate: Rectangle {
                    id: well
                    required property var modelData
                    readonly property int value:
                        modelData.key === "h" ? root.ch
                      : modelData.key === "m" ? root.cm : root.cs

                    width: custom.wellW
                    height: custom.height
                    radius: 12
                    color: Theme.surfaceRecess
                    border.width: 1
                    border.color: wHov.hovered ? Theme.grooveLight : Theme.grooveDark
                    Behavior on border.color { ColorAnimation { duration: 140 } }

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: 11
                        gradient: Gradient {
                            GradientStop { position: 0.35; color: "transparent" }
                            GradientStop { position: 1.0;  color: "transparent" }
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 1
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: ("0" + well.value).slice(-2)
                            color: Theme.text
                            opacity: well.value > 0 ? 0.95 : 0.35
                            font.family: Theme.fontText
                            font.features: Theme.tabularNums
                            font.pixelSize: 28
                            font.weight: Font.Bold
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: well.modelData.cap
                            color: Theme.text; opacity: 0.3
                            font.family: Theme.fontText
                            font.pixelSize: Theme.fsSection
                            font.letterSpacing: Theme.trSection
                        }
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
                        onWheel: function (w) {
                            root.bump(well.modelData.key, w.angleDelta.y > 0 ? 1 : -1)
                        }
                        onClicked: function (m) {
                            root.bump(well.modelData.key, m.y < height / 2 ? 1 : -1)
                        }
                    }
                }
            }

            Rectangle {
                width: 88
                height: custom.height
                radius: 12
                enabled: root.customTotal > 0
                opacity: enabled ? 1 : 0.4
                color: sHov.hovered ? Theme.withAlpha(root.tint, 0.32)
                                    : Theme.withAlpha(root.tint, 0.20)
                border.width: 1
                border.color: Theme.withAlpha(root.tint, 0.45)
                Behavior on color { ColorAnimation { duration: 150 } }

                Column {
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "󰐊"
                        color: root.tint
                        font.family: Theme.iconFont; font.pixelSize: 18
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Start"
                        color: root.tint; opacity: 0.9
                        font.family: Theme.fontText
                        font.pixelSize: Theme.fsSection
                        font.letterSpacing: Theme.trSection
                    }
                }
                HoverHandler { id: sHov; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    onTapped: {
                        if (root.customTotal <= 0) return
                        TimerService.start(root.customTotal, "Custom")
                    }
                }
            }
    }
}
