import QtQuick
import "../components"
import "../theme"
import "../services"

Item {
    id: root

    property color tint: Theme.accent
    property real reveal: 1

    readonly property int chrome: 12 + 9 + 16 + 12 + 9
    readonly property real lapsWanted:
        Math.min(root.height * 0.56, 200 + StopwatchService.laps.length * 46)
    readonly property real faceH: Math.max(250, root.height - chrome - lapsWanted)

    Column {
        id: topPart
        anchors { left: parent.left; right: parent.right; top: parent.top }
        spacing: 0

        SectionHeader {
            width: parent.width
            label: "Stopwatch"
            tint: root.tint
            opacity: Theme.phase(root.reveal, 0, 0.16)

            Text {
                text: StopwatchService.running ? "Running"
                    : (StopwatchService.idle ? "Ready" : "Stopped")
                color: StopwatchService.running ? root.tint : Theme.text
                opacity: StopwatchService.running ? 0.85 : 0.32
                font.family: Theme.fontText
                font.pixelSize: Theme.fsSection
                font.letterSpacing: Theme.trSection
            }
        }

        Item { width: 1; height: 9 }

        Rectangle {
            id: face
            width: parent.width
            height: root.faceH
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

            Canvas {
                id: sweep
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Math.max(16, (face.height - width - 54) / 2)
                width: Math.max(150, Math.min(face.width - 36, face.height - 128))
                height: width

                readonly property real frac: (StopwatchService.elapsed % 60) / 60
                readonly property int  mins: Math.floor(StopwatchService.elapsed / 60)
                readonly property real appear: Theme.phase(root.reveal, 0.16, 0.44)
                onFracChanged:  requestPaint()
                onMinsChanged:  requestPaint()
                onAppearChanged: requestPaint()
                onWidthChanged: requestPaint()

                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const cx = width / 2, cy = height / 2
                    const TAU = Math.PI * 2
                    const TOP = -Math.PI / 2
                    const sw = TAU * appear
                    if (sw <= 0.001) return

                    const LW = Math.max(5, width * 0.026)
                    const r  = cx - 10 - LW / 2

                    ctx.beginPath()
                    ctx.lineWidth = LW
                    ctx.strokeStyle = Theme.palette.bg4
                    ctx.arc(cx, cy, r, TOP, TOP + sw)
                    ctx.stroke()

                    ctx.beginPath()
                    ctx.lineWidth = 1
                    ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.09)
                    ctx.arc(cx, cy, r + LW / 2 + 1, TOP, TOP + sw)
                    ctx.stroke()

                    ctx.lineWidth = 1
                    for (var i = 0; i < 60; i += 5) {
                        const a = TOP + i / 60 * TAU
                        if (a - TOP > sw) continue
                        const big = i % 15 === 0
                        const r0 = r + LW / 2 + 3
                        ctx.beginPath()
                        ctx.strokeStyle = Qt.rgba(1, 1, 1, big ? 0.22 : 0.10)
                        ctx.moveTo(cx + Math.cos(a) * r0, cy + Math.sin(a) * r0)
                        ctx.lineTo(cx + Math.cos(a) * (r0 + (big ? 7 : 4)),
                                   cy + Math.sin(a) * (r0 + (big ? 7 : 4)))
                        ctx.stroke()
                    }

                    if (appear <= 0.99) return

                    const pitch = Math.max(6, LW * 1.5)
                    const maxRings = Math.max(0, Math.floor((r - width * 0.22) / pitch))
                    const shown = Math.min(mins, maxRings)
                    for (var k = 0; k < shown; k++) {
                        const rr = r - pitch * (k + 1)
                        const age = k / Math.max(1, maxRings)
                        ctx.beginPath()
                        ctx.lineWidth = Math.max(2, LW * 0.52)
                        ctx.strokeStyle = Theme.withAlpha(root.tint, 0.62 - age * 0.42)
                        ctx.arc(cx, cy, rr, 0, TAU)
                        ctx.stroke()
                    }
                    if (mins > maxRings && maxRings > 0) {
                        ctx.beginPath()
                        ctx.lineWidth = 1
                        ctx.strokeStyle = Theme.withAlpha(root.tint, 0.30)
                        ctx.setLineDash ? 0 : 0
                        ctx.arc(cx, cy, r - pitch * (maxRings + 1), 0, TAU)
                        ctx.stroke()
                    }

                    if (StopwatchService.running || StopwatchService.elapsed > 0) {
                        const a = TOP + frac * TAU
                        ctx.beginPath()
                        ctx.lineCap = "round"
                        ctx.lineWidth = LW
                        ctx.strokeStyle = root.tint
                        ctx.arc(cx, cy, r, TOP, a)
                        ctx.stroke()

                        ctx.beginPath()
                        ctx.fillStyle = Theme.atLum(root.tint, 0.95)
                        ctx.arc(cx + Math.cos(a) * r, cy + Math.sin(a) * r,
                                LW * 0.62, 0, TAU)
                        ctx.fill()
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 1
                    opacity: Theme.phase(root.reveal, 0.36, 0.3)
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: StopwatchService.format(StopwatchService.elapsed, true)
                        color: StopwatchService.running ? root.tint : Theme.text
                        opacity: StopwatchService.idle ? 0.28 : 1
                        font.family: Theme.fontText
                        font.features: Theme.tabularNums
                        font.pixelSize: 31
                        font.weight: Font.Bold
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: StopwatchService.laps.length > 0
                            ? StopwatchService.laps.length + (StopwatchService.laps.length === 1 ? " LAP" : " LAPS")
                            : "Elapsed"
                        color: Theme.text; opacity: 0.3
                        font.family: Theme.fontText
                        font.pixelSize: Theme.fsSection
                        font.letterSpacing: Theme.trSection
                    }
                }
            }

            Row {
                id: controls
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: sweep.bottom
                anchors.topMargin: 22
                spacing: 9
                opacity: Theme.phase(root.reveal, 0.46, 0.3)

                Repeater {
                    model: [{ act: "lap" }, { act: "toggle" }, { act: "reset" }]
                    delegate: Rectangle {
                        id: btn
                        required property var modelData
                        readonly property bool primary: modelData.act === "toggle"
                        readonly property bool live:
                            modelData.act === "lap" ? StopwatchService.running
                          : modelData.act === "reset" ? !StopwatchService.idle : true

                        width: primary ? 104 : 76
                        height: 32
                        radius: 9
                        enabled: live
                        opacity: live ? 1 : 0.34
                        color: primary
                            ? (bHov.hovered ? Theme.withAlpha(root.tint, 0.30) : Theme.withAlpha(root.tint, 0.20))
                            : (bHov.hovered ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.04))
                        border.width: 1
                        border.color: primary ? Theme.withAlpha(root.tint, 0.45) : Qt.rgba(1, 1, 1, 0.09)
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on opacity { NumberAnimation { duration: 150 } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: btn.modelData.act === "lap" ? "󰈻"
                                    : btn.modelData.act === "reset" ? "󰑐"
                                    : (StopwatchService.running ? "󰏤" : "󰐊")
                                color: btn.primary ? root.tint : Theme.text
                                opacity: btn.primary ? 1 : 0.6
                                font.family: Theme.iconFont
                                font.pixelSize: 12
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: btn.modelData.act === "lap" ? "Lap"
                                    : btn.modelData.act === "reset" ? "Reset"
                                    : (StopwatchService.running ? "Pause" : "Start")
                                color: btn.primary ? root.tint : Theme.text
                                opacity: btn.primary ? 1 : 0.65
                                font.family: Theme.fontText
                                font.pixelSize: 11
                            }
                        }
                        HoverHandler { id: bHov; cursorShape: Qt.PointingHandCursor; enabled: btn.live }
                        TapHandler {
                            enabled: btn.live
                            onTapped: {
                                if (btn.modelData.act === "lap") StopwatchService.lap()
                                else if (btn.modelData.act === "reset") StopwatchService.reset()
                                else StopwatchService.toggle()
                            }
                        }
                    }
                }
            }
        }
    }

    SectionHeader {
            id: lapsHeader
            anchors { left: parent.left; right: parent.right; top: topPart.bottom; topMargin: 16 }
            label: "Laps"
            tint: root.tint
            opacity: Theme.phase(root.reveal, 0.54, 0.16)

            Text {
                visible: StopwatchService.laps.length >= 2
                text: "Fastest / slowest marked"
                color: Theme.text; opacity: 0.24
                font.family: Theme.fontText
                font.pixelSize: Theme.fsSection
                font.letterSpacing: Theme.trSection
            }
    }

    Rectangle {
            id: lapCard
            anchors { left: parent.left; right: parent.right
                      top: lapsHeader.bottom; topMargin: 9; bottom: parent.bottom }
            radius: 12
            color: Theme.surfaceRecess
            border.width: 1
            border.color: Theme.grooveDark
            clip: true
            opacity: Theme.phase(root.reveal, 0.6, 0.4)

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

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 26
                visible: StopwatchService.laps.length === 0
                text: "No laps yet"
                color: Theme.text; opacity: 0.24
                font.family: Theme.fontText
                font.pixelSize: Theme.fsSection
                font.letterSpacing: Theme.trSection
            }

            ListView {
                anchors.fill: parent
                anchors.margins: 6
                visible: StopwatchService.laps.length > 0
                model: StopwatchService.laps
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                spacing: 0

                delegate: Item {
                    required property var modelData
                    width: ListView.view.width
                    height: 30

                    readonly property bool best:  modelData.n === StopwatchService.bestLap
                    readonly property bool worst: modelData.n === StopwatchService.worstLap

                    Text {
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: ("0" + parent.modelData.n).slice(-2)
                        color: Theme.text; opacity: 0.34
                        font.family: Theme.iconFont
                        font.features: Theme.tabularNums
                        font.pixelSize: Theme.fsSection
                        font.letterSpacing: Theme.trSection
                    }
                    Text {
                        anchors.centerIn: parent
                        text: StopwatchService.format(parent.modelData.split, true)
                        color: parent.best ? Theme.statusActive
                             : parent.worst ? Theme.statusNotice : Theme.text
                        opacity: parent.best || parent.worst ? 0.95 : 0.75
                        font.family: Theme.fontText
                        font.features: Theme.tabularNums
                        font.pixelSize: 13
                        font.weight: parent.best || parent.worst ? Font.Bold : Font.Normal
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: StopwatchService.format(parent.modelData.at, false)
                        color: Theme.text; opacity: 0.3
                        font.family: Theme.iconFont
                        font.features: Theme.tabularNums
                        font.pixelSize: 11
                    }
                    Rule {
                        anchors { bottom: parent.bottom; left: parent.left; right: parent.right
                                  leftMargin: 8; rightMargin: 8 }
                        visible: parent.modelData.n !== 1
                        tint: Theme.grooveDark; fade: 0.2
                    }
                }
            }
    }
}
