import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Polkit
import Quickshell.Io
import QtQuick
import "../theme"
import "../state"
import "../services"
import "../components" as C

Scope {
    id: root

    PolkitAgent { id: agent }

    readonly property var flow: agent.flow
    property bool preview: false
    readonly property bool wanted: preview || (agent.isActive && flow !== null)

    property bool checking: false
    property int failures: 0
    property string error: ""

    readonly property string message: preview
        ? "Authentication is required to mount «USB» (/dev/sda1)"
        : (flow ? flow.message : "")
    readonly property string userName: {
        if (preview || !flow) return Quickshell.env("USER")
        const id = flow.selectedIdentity
        if (!id) return Quickshell.env("USER")
        return id.displayName || id.name || id.userName || String(id) || Quickshell.env("USER")
    }
    readonly property bool echo: !preview && flow ? flow.responseVisible : false
    readonly property string prompt: {
        const p = (!preview && flow) ? flow.inputPrompt : ""
        if (p === "" || /^password\s*:?\s*$/i.test(p)) return "Password"
        return p.replace(/:\s*$/, "")
    }

    function submit(text) {
        if (checking || text.length === 0) return
        if (preview) return
        if (!flow || !flow.isResponseRequired) return
        checking = true
        error = ""
        flow.submit(text)
    }
    function cancel() {
        if (preview) { preview = false; return }
        if (flow) flow.cancelAuthenticationRequest()
    }

    Connections {
        target: root.flow
        ignoreUnknownSignals: true
        function onAuthenticationFailed() {
            root.checking = false
            root.error = root.flow && root.flow.supplementaryIsError && root.flow.supplementaryMessage !== ""
                ? root.flow.supplementaryMessage : "Wrong password"
            root.failures++
        }
        function onAuthenticationSucceeded() { root.checking = false; root.error = "" }
        function onAuthenticationRequestCancelled() { root.checking = false }
        function onIsResponseRequiredChanged() { if (root.flow.isResponseRequired) root.checking = false }
        function onSupplementaryMessageChanged() {
            if (root.flow.supplementaryIsError && root.flow.supplementaryMessage !== "")
                root.error = root.flow.supplementaryMessage
        }
    }

    onWantedChanged: {
        if (wanted) {
            Popups.closeAll()
            checking = false; error = ""
            win.visible = true
            showAnim.restart()
        } else {
            hideAnim.restart()
        }
    }

    property real shown: 0
    NumberAnimation {
        id: showAnim
        target: root; property: "shown"; to: 1
        duration: Theme.animTransition; easing.type: Theme.animCurve
        onStarted: hideAnim.stop()
    }
    NumberAnimation {
        id: hideAnim
        target: root; property: "shown"; to: 0
        duration: 160; easing.type: Easing.InCubic
        onStarted: showAnim.stop()
        onFinished: { win.visible = false; root.failures = 0; root.error = "" }
    }

    PanelWindow {
        id: win
        visible: false
        screen: DisplayService.primaryScreen
        color: "transparent"
        anchors { top: true; left: true; right: true; bottom: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-polkit"
        WlrLayershell.keyboardFocus: root.wanted ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Rectangle {
            anchors.fill: parent
            color: Theme.withAlpha(Theme.palette.darker, 0.62)
            opacity: root.shown
            MouseArea { anchors.fill: parent; hoverEnabled: true }
        }

        Item {
            id: card
            width: 440
            height: body.implicitHeight + 48
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: shake
            opacity: root.shown
            scale: 0.94 + 0.06 * root.shown

            property real shake: 0
            property real errorMix: 0
            SequentialAnimation {
                id: failAnim
                ParallelAnimation {
                    NumberAnimation { target: card; property: "errorMix"; to: 1; duration: 90 }
                    SequentialAnimation {
                        NumberAnimation { target: card; property: "shake"; to: -12; duration: 50 }
                        NumberAnimation { target: card; property: "shake"; to: 9;   duration: 70 }
                        NumberAnimation { target: card; property: "shake"; to: -5;  duration: 60 }
                        NumberAnimation { target: card; property: "shake"; to: 0;   duration: 60 }
                    }
                }
                PauseAnimation { duration: 500 }
                NumberAnimation { target: card; property: "errorMix"; to: 0; duration: 400 }
            }
            Connections {
                target: root
                function onFailuresChanged() { if (root.failures > 0) { field.text = ""; failAnim.restart() } }
            }

            Rectangle {
                anchors.fill: parent
                radius: 16
                color: Theme.surfaceWell
            }

            Column {
                id: body
                x: 24; y: 24
                width: parent.width - 48
                spacing: 0

                Row {
                    spacing: 14
                    width: parent.width
                    Rectangle {
                        width: 44; height: 44; radius: 22
                        color: Theme.withAlpha(Theme.accent, 0.16)
                        Text {
                            anchors.centerIn: parent
                            text: "󰌾"
                            color: Theme.accent
                            font.family: Theme.iconFont; font.pixelSize: 21
                        }
                    }
                    Column {
                        width: parent.width - 58
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3
                        Text {
                            text: "Authentication required"
                            color: Theme.text
                            font.family: Theme.fontText; font.pixelSize: 18; font.weight: Font.Bold
                        }
                        Text {
                            width: parent.width
                            text: root.message
                            color: Theme.text; opacity: 0.62
                            wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight
                            font.family: Theme.fontText; font.pixelSize: 13
                        }
                    }
                }

                Item { width: 1; height: 20 }

                Row {
                    spacing: 8
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰀄"
                        color: Theme.text; opacity: 0.5
                        font.family: Theme.iconFont; font.pixelSize: 15
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.userName
                        color: Theme.text; opacity: 0.8
                        font.family: Theme.fontText; font.pixelSize: 13; font.weight: Font.Medium
                    }
                }

                Item { width: 1; height: 10 }

                Rectangle {
                    id: well
                    width: parent.width
                    height: 48
                    radius: 11
                    color: Qt.tint(Theme.surfaceRecess, Qt.rgba(0.875, 0.357, 0.38, 0.30 * card.errorMix))
                    border.width: field.activeFocus && !root.checking ? 1 : 0
                    border.color: Theme.withAlpha(Theme.accent, 0.55)

                    TextInput {
                        id: field
                        anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                        verticalAlignment: TextInput.AlignVCenter
                        opacity: root.echo ? 1 : 0
                        color: Theme.text
                        font.family: Theme.fontText; font.pixelSize: 14
                        echoMode: root.echo ? TextInput.Normal : TextInput.Password
                        enabled: !root.checking
                        focus: true
                        onAccepted: root.submit(text)
                        Keys.onEscapePressed: {
                            if (text.length > 0) text = ""
                            else root.cancel()
                        }
                    }
                    C.PasswordDots {
                        anchors.centerIn: parent
                        visible: !root.echo
                        count: field.text.length
                        checking: root.checking
                        fit: 22
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: field.text.length === 0
                        text: root.prompt
                        color: Theme.text; opacity: 0.38
                        font.family: Theme.fontText; font.pixelSize: 14; font.letterSpacing: 0.3
                    }
                }

                Item { width: 1; height: 8 }

                Text {
                    width: parent.width
                    height: 18
                    text: root.error
                    opacity: root.error === "" ? 0 : 1
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                    color: Theme.palette.red
                    elide: Text.ElideRight
                    font.family: Theme.fontText; font.pixelSize: 12; font.weight: Font.Medium
                }

                Item { width: 1; height: 10 }

                Row {
                    anchors.right: parent.right
                    spacing: 10
                    Rectangle {
                        width: 112; height: 40; radius: 10
                        color: cancelHov.hovered ? Theme.surfaceSunk : Theme.surfaceRecess
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                            anchors.centerIn: parent
                            text: "Cancel"
                            color: Theme.text
                            font.family: Theme.fontText; font.pixelSize: 13; font.weight: Font.Medium
                        }
                        HoverHandler { id: cancelHov; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: root.cancel() }
                    }
                    Rectangle {
                        width: 132; height: 40; radius: 10
                        readonly property bool ready: field.text.length > 0 && !root.checking
                        color: okHov.hovered && ready ? Theme.palette.blueBright : Theme.accent
                        opacity: ready || root.checking ? 1 : 0.45
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                        Text {
                            anchors.centerIn: parent
                            text: root.checking ? "Checking…" : "Authenticate"
                            color: Theme.accentText
                            font.family: Theme.fontText; font.pixelSize: 13; font.weight: Font.Bold
                        }
                        HoverHandler { id: okHov; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: root.submit(field.text) }
                    }
                }
            }

            Connections {
                target: root
                function onWantedChanged() { if (root.wanted) { field.text = ""; field.forceActiveFocus() } }
            }
        }
    }

    IpcHandler {
        target: "polkit"
        function preview() { root.preview = true }
        function cancel() { root.cancel() }
        function testfail() {
            if (!root.preview) return
            root.error = "Wrong password"; root.failures++
        }
        function status(): string {
            return "registered=" + agent.isRegistered + " active=" + agent.isActive
                 + " preview=" + root.preview + " shown=" + root.shown.toFixed(2)
                 + " failures=" + root.failures
        }
    }
}
