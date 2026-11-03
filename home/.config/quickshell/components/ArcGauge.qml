import QtQuick
import "../theme"

Item {
    id: root

    property real value: 0
    property real peak: 0
    property color tint: Theme.accent
    property string label: ""
    property string sub: ""
    property string readout: ""

    implicitWidth: 86
    implicitHeight: 104

    readonly property real ringSize: 66
    readonly property real strokeW: 5

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: Theme.shade(Theme.surfaceWell, 0.25)
        border.width: 1
        border.color: Theme.grooveDark

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 11
            gradient: Gradient {
                GradientStop { position: 0.35; color: "transparent" }
                GradientStop { position: 1.0;  color: "transparent" }
            }
        }
    }
    Rule {
        anchors { top: parent.top; topMargin: 1; left: parent.left; right: parent.right
                  leftMargin: 7; rightMargin: 7 }
        tint: Theme.grooveDark; fade: 0.16
    }
    Rule {
        anchors { bottom: parent.bottom; bottomMargin: 1; left: parent.left; right: parent.right
                  leftMargin: 7; rightMargin: 7 }
        tint: Theme.grooveLight; fade: 0.16
    }

    Canvas {
        id: cv
        width: root.ringSize; height: root.ringSize
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 11

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const c = width / 2
            const r = c - root.strokeW / 2
            const start = -Math.PI / 2

            ctx.beginPath()
            ctx.arc(c, c, r, 0, Math.PI * 2)
            ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.09)
            ctx.lineWidth = root.strokeW
            ctx.stroke()

            const v = Math.max(0, Math.min(1, root.value))
            if (v > 0.001) {
                ctx.beginPath()
                ctx.arc(c, c, r, start, start + v * Math.PI * 2)
                ctx.strokeStyle = root.tint
                ctx.lineWidth = root.strokeW
                ctx.lineCap = "round"
                ctx.stroke()
            }

            const p = Math.max(0, Math.min(1, root.peak))
            if (p > v + 0.03) {
                const a = start + p * Math.PI * 2
                ctx.beginPath()
                ctx.moveTo(c + Math.cos(a) * (r - root.strokeW), c + Math.sin(a) * (r - root.strokeW))
                ctx.lineTo(c + Math.cos(a) * (r + root.strokeW * 0.9), c + Math.sin(a) * (r + root.strokeW * 0.9))
                ctx.strokeStyle = "#de8f78"
                ctx.lineWidth = 2
                ctx.lineCap = "round"
                ctx.stroke()
            }
        }
        onWidthChanged: requestPaint()
    }

    onValueChanged: cv.requestPaint()
    onPeakChanged:  cv.requestPaint()
    onTintChanged:  cv.requestPaint()

    Text {
        anchors.horizontalCenter: cv.horizontalCenter
        y: cv.y + root.ringSize / 2 - height / 2
        text: root.readout
        color: Theme.text
        font.family: Theme.iconFont
        font.pixelSize: 15
    }

    Column {
        anchors { bottom: parent.bottom; bottomMargin: 8
                  horizontalCenter: parent.horizontalCenter }
        spacing: 1
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.label
            color: Theme.text; opacity: 0.42
            font.family: Theme.iconFont; font.pixelSize: 9
            font.letterSpacing: 0.6
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.sub
            visible: text !== ""
            color: Theme.text; opacity: 0.28
            font.family: Theme.iconFont; font.pixelSize: 9
        }
    }
}
