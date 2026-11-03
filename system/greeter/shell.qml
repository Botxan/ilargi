import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Greetd
import Quickshell.Io
import QtQuick
import "./theme"
import "./components" as C

ShellRoot {
    id: root

    property string user: ""
    property string primaryName: ""
    property var sessionCmd: ["uwsm", "start", "hyprland.desktop"]

    readonly property bool demo: !Greetd.available

    property bool checking: false
    property int failures: 0
    property string message: ""
    property bool messageIsError: false
    property bool leaving: false
    property string pending: ""

    function submit(pw) {
        if (checking || leaving) return
        checking = true
        message = ""
        pending = pw
        if (demo) { demoTimer.restart(); return }
        if (Greetd.state !== GreetdState.Inactive) Greetd.cancelSession()
        Greetd.createSession(user)
    }

    function fail(text) {
        checking = false
        pending = ""
        message = text
        messageIsError = true
        failures++
        clearMsg.restart()
    }

    function succeed() {
        checking = false
        leaving = true
        launchTimer.start()
    }

    Connections {
        target: Greetd
        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (responseRequired) {
                Greetd.respond(root.pending)
                root.pending = ""
            } else if (message !== "") {
                root.message = message
                root.messageIsError = error
            }
        }
        function onAuthFailure(message) {
            root.fail("Wrong password")
            if (Greetd.state !== GreetdState.Inactive) Greetd.cancelSession()
        }
        function onReadyToLaunch() { root.succeed() }
        function onError(error) { root.fail("greetd error: " + error) }
    }

    Timer {
        id: launchTimer
        interval: 260
        onTriggered: {
            if (root.demo) Qt.quit()
            else Greetd.launch(root.sessionCmd, [], true)
        }
    }
    Timer {
        id: demoTimer
        interval: 700
        onTriggered: root.pending === "fail" ? root.fail("Wrong password") : root.succeed()
    }
    Timer { id: clearMsg; interval: 4000; onTriggered: if (!root.checking) root.message = "" }
    Timer { running: root.demo; interval: 60000; onTriggered: Qt.quit() }

    Process { id: power }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            readonly property bool primary: {
                const screens = Quickshell.screens
                const main = screens.find(s => s.name === root.primaryName)
                    || screens.reduce((a, b) => b.width * b.height > a.width * a.height ? b : a)
                return modelData === main
            }

            color: Theme.ground
            anchors { top: true; left: true; right: true; bottom: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "ilargi-greeter"
            WlrLayershell.keyboardFocus: primary ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            C.LockFace {
                id: face
                anchors.fill: parent
                primary: win.primary
                checking: root.checking
                failures: root.failures
                message: root.message
                messageIsError: root.messageIsError
                leaving: root.leaving
                onSubmitted: pw => root.submit(pw)
                onEscapedEmpty: if (root.demo) Qt.quit()
                Component.onCompleted: if (win.primary) grabKeys()
            }

            Row {
                visible: win.primary
                opacity: root.leaving ? 0 : 0.75
                Behavior on opacity { NumberAnimation { duration: 150 } }
                anchors { left: parent.left; bottom: parent.bottom; leftMargin: 32; bottomMargin: 18 }
                spacing: 10
                Rectangle {
                    width: 30; height: 30; radius: 15
                    color: Theme.withAlpha(Theme.accent, 0.16)
                    Text {
                        anchors.centerIn: parent
                        text: "󰀄"
                        color: Theme.accent
                        font.family: Theme.iconFont; font.pixelSize: 15
                    }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        text: root.user
                        color: Theme.text
                        font.family: Theme.fontText; font.pixelSize: 14; font.weight: Font.Bold
                    }
                    Text {
                        text: root.demo ? "Hyprland · preview" : "Hyprland"
                        color: Theme.text; opacity: 0.55
                        font.family: Theme.fontText; font.pixelSize: 11
                    }
                }
            }

            Row {
                visible: win.primary
                opacity: root.leaving ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: 150 } }
                anchors { right: parent.right; bottom: parent.bottom; rightMargin: 28; bottomMargin: 14 }
                spacing: 10
                Repeater {
                    model: [
                        { glyph: "󰜉", tip: "Restart", cmd: ["systemctl", "reboot"] },
                        { glyph: "󰐥", tip: "Power off", cmd: ["systemctl", "poweroff"] }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        width: 38; height: 38; radius: 11
                        color: hov.hovered ? Theme.surfaceRecess : Theme.surfaceWell
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                            anchors.centerIn: parent
                            text: modelData.glyph
                            color: hov.hovered ? (modelData.tip === "Power off" ? Theme.palette.red : Theme.accent) : Theme.text
                            opacity: hov.hovered ? 1 : 0.6
                            font.family: Theme.iconFont; font.pixelSize: 17
                        }
                        HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: {
                                if (root.demo) { root.message = modelData.tip + " (preview)"; root.messageIsError = false; clearMsg.restart(); return }
                                power.command = modelData.cmd
                                power.running = true
                            }
                        }
                    }
                }
            }
        }
    }
}
