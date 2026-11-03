import QtQuick
import "../theme"
import "../shapes"

Item {
    id: face

    property bool primary: true
    property bool checking: false
    property int  failures: 0
    property string message: ""
    property bool messageIsError: false
    property bool leaving: false
    signal submitted(string password)
    signal escapedEmpty()

    opacity: leaving ? 0 : 1
    Behavior on opacity { NumberAnimation { duration: 150 } }
    property real rise: 1
    Component.onCompleted: rise = 0
    Behavior on rise { NumberAnimation { duration: Theme.animTransition; easing.type: Theme.animCurve } }

    function grabKeys() { field.forceActiveFocus() }
    function clear() { field.text = "" }

    property date now: new Date()
    Timer { interval: 1000; repeat: true; running: true; onTriggered: face.now = new Date() }

    Column {
        id: clockCol
        anchors.horizontalCenter: parent.horizontalCenter
        y: face.primary ? Math.round(parent.height * 0.30) + face.rise * 40
                        : Math.round(parent.height / 2 - height / 2) + face.rise * 30
        spacing: face.primary ? 6 : 2

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: face.primary ? 26 : 12
            readonly property int px: face.primary ? 128 : 56
            Text { text: Qt.formatTime(face.now, "hh"); color: Theme.text
                   font.family: Theme.fontText; font.pixelSize: parent.px; font.weight: Font.Bold
                   font.features: Theme.tabularNums }
            Text { text: ":"; color: Theme.accent
                   anchors.verticalCenter: parent.verticalCenter
                   anchors.verticalCenterOffset: -Math.round(parent.px * 0.06)
                   font.family: Theme.fontText; font.pixelSize: Math.round(parent.px * 0.92); font.weight: Font.Bold }
            Text { text: Qt.formatTime(face.now, "mm"); color: Theme.text
                   font.family: Theme.fontText; font.pixelSize: parent.px; font.weight: Font.Bold
                   font.features: Theme.tabularNums }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.locale().toString(face.now, "dddd d MMMM")
            color: Theme.text
            opacity: 0.6
            font.family: Theme.fontText
            font.pixelSize: face.primary ? 20 : 13
            font.weight: Font.Medium
        }
    }

    Item {
        id: entry
        visible: face.primary
        anchors.fill: parent

        TextInput {
            id: field
            opacity: 0
            width: 1; height: 1
            focus: face.primary
            echoMode: TextInput.Password
            enabled: !face.checking && !face.leaving
            onAccepted: if (text.length > 0) face.submitted(text)
            Keys.onEscapePressed: {
                if (text.length > 0) text = ""
                else face.escapedEmpty()
            }
        }

        readonly property int count: field.text.length
        readonly property real depth: face.rise > 0.99 ? 0 : 66

        property real errorMix: 0
        property real shake: 0
        SequentialAnimation {
            id: failAnim
            ParallelAnimation {
                NumberAnimation { target: entry; property: "errorMix"; to: 1; duration: 90 }
                SequentialAnimation {
                    NumberAnimation { target: entry; property: "shake"; to: -14; duration: 50 }
                    NumberAnimation { target: entry; property: "shake"; to: 11;  duration: 70 }
                    NumberAnimation { target: entry; property: "shake"; to: -7;  duration: 60 }
                    NumberAnimation { target: entry; property: "shake"; to: 3;   duration: 50 }
                    NumberAnimation { target: entry; property: "shake"; to: 0;   duration: 50 }
                }
            }
            PauseAnimation { duration: 500 }
            NumberAnimation { target: entry; property: "errorMix"; to: 0; duration: 400 }
        }
        Connections {
            target: face
            function onFailuresChanged() { field.text = ""; failAnim.restart() }
        }

        NotchShape {
            id: notch
            edge: "bottom"
            anchors.bottom: parent.bottom
            x: Math.round(parent.width / 2 - width / 2) + entry.shake
            notchWidth: 360
            notchDepth: Math.max(0.001, entry.depth)
            color: Qt.tint(Theme.surfaceWell, Qt.rgba(0.875, 0.357, 0.38, 0.28 * entry.errorMix))
            Behavior on notchDepth { NumberAnimation { duration: Theme.animTransition; easing.type: Theme.animCurve } }
        }

        PasswordDots {
            id: dots
            anchors.horizontalCenter: notch.horizontalCenter
            anchors.verticalCenter: notch.verticalCenter
            anchors.verticalCenterOffset: 2
            count: entry.count
            checking: face.checking
        }

        Text {
            anchors.centerIn: notch
            anchors.verticalCenterOffset: 2
            visible: entry.count === 0
            opacity: notch.notchDepth > 40 ? 0.45 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.animContentIn } }
            text: "Password"
            color: Theme.text
            font.family: Theme.fontText; font.pixelSize: 15; font.letterSpacing: 0.4
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: notch.top
            anchors.bottomMargin: 16
            text: face.message
            opacity: face.message === "" ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 200 } }
            color: face.messageIsError ? Theme.palette.red : Theme.text
            font.family: Theme.fontText; font.pixelSize: 14; font.weight: Font.Medium
        }
    }
}
