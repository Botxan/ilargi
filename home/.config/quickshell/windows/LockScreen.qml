import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import Quickshell.Io
import QtQuick
import QtQuick.Shapes
import "../theme"
import "../state"
import "../services"
import "../components" as C

Scope {
    id: root

    property string phase: "idle"
    property bool preview: false
    property real shut: 0

    property bool checking: false
    property int failures: 0
    property string message: ""
    property bool messageIsError: false
    property bool leaving: false

    readonly property bool engaged: phase !== "idle"

    function lock(asPreview) {
        if (phase === "locked" || phase === "closing") return
        openAnim.stop()
        preview = !!asPreview
        Popups.closeAll()
        checking = false; message = ""; leaving = false
        phase = "closing"
        closeAnim.from = shut
        closeAnim.start()
    }

    function lockNow() {
        if (phase === "locked" && !preview) return
        closeAnim.stop(); openAnim.stop(); releaseTimer.stop()
        if (preview) previewWin.visible = false
        preview = false
        Popups.closeAll()
        checking = false; message = ""; leaving = false
        shut = 1
        engage()
    }

    function engage() {
        phase = "locked"
        if (preview) previewWin.visible = true
        else sessionLock.locked = true
    }

    function unlockNow() {
        leaving = true
        releaseTimer.restart()
    }
    Timer {
        id: releaseTimer
        interval: 160
        onTriggered: {
            if (root.preview) previewWin.visible = false
            else sessionLock.locked = false
            root.phase = "opening"
            openAnim.from = root.shut
            openAnim.start()
        }
    }

    NumberAnimation {
        id: closeAnim
        target: root; property: "shut"; to: 1
        duration: 460; easing.type: Easing.InOutCubic
        onFinished: root.engage()
    }
    NumberAnimation {
        id: openAnim
        target: root; property: "shut"; to: 0
        duration: 520; easing.type: Theme.animCurve
        onFinished: { root.phase = "idle"; root.leaving = false; root.message = "" }
    }

    property string pending: ""
    function submit(pw) {
        if (checking || phase !== "locked") return
        pending = pw
        checking = true
        message = ""
        if (!pam.start()) {
            checking = false
            message = "Could not start the check"
            messageIsError = true
        }
    }

    PamContext {
        id: pam
        config: "login"
        onResponseRequiredChanged: {
            if (!responseRequired) return
            respond(root.pending)
            root.pending = ""
        }
        onPamMessage: {
            if (!responseRequired && message !== "") {
                root.message = message
                root.messageIsError = messageIsError
            }
        }
        onCompleted: result => {
            root.checking = false
            root.pending = ""
            if (result === PamResult.Success) {
                root.message = ""
                root.unlockNow()
            } else {
                if (root.message === "" || !root.messageIsError) {
                    root.message = result === PamResult.MaxTries
                        ? "Too many attempts" : "Wrong password"
                    root.messageIsError = true
                }
                root.failures++
                clearMsg.restart()
            }
        }
        onError: err => {
            root.checking = false
            root.pending = ""
            root.message = "PAM error (" + err + ")"
            root.messageIsError = true
            root.failures++
            clearMsg.restart()
        }
    }
    Timer { id: clearMsg; interval: 4000; onTriggered: if (!root.checking) root.message = "" }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: curtain
            required property var modelData
            screen: modelData
            readonly property bool hasBar: modelData.name === DisplayService.primaryName

            visible: root.engaged
            color: "transparent"
            anchors { top: true; left: true; right: true; bottom: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell-lock"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            MouseArea { anchors.fill: parent; hoverEnabled: true }

            Shape {
                id: sheet
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                readonly property real w: curtain.width
                readonly property real h: curtain.height
                readonly property real s: root.shut
                readonly property real e0: curtain.hasBar ? Theme.borderWidth : 0
                readonly property real hl: e0 + (w / 2 - e0) * s
                readonly property real hr: w - hl
                readonly property real ht: e0 + (h / 2 - e0) * s
                readonly property real hb: h - ht
                readonly property real hw: Math.max(0, hr - hl)
                readonly property real hh: Math.max(0, hb - ht)
                readonly property real rad: Math.min(Theme.cornerRadius * (curtain.hasBar ? 1 : Math.min(1, s * 6)),
                                                     hw / 2, hh / 2)

                function hole() {
                    if (hw < 0.5 || hh < 0.5) return ""
                    const r = rad, x0 = hl, y0 = ht, x1 = hr, y1 = hb
                    return "M" + (x0 + r) + " " + y0
                         + "L" + (x1 - r) + " " + y0
                         + "A" + r + " " + r + " 0 0 1 " + x1 + " " + (y0 + r)
                         + "L" + x1 + " " + (y1 - r)
                         + "A" + r + " " + r + " 0 0 1 " + (x1 - r) + " " + y1
                         + "L" + (x0 + r) + " " + y1
                         + "A" + r + " " + r + " 0 0 1 " + x0 + " " + (y1 - r)
                         + "L" + x0 + " " + (y0 + r)
                         + "A" + r + " " + r + " 0 0 1 " + (x0 + r) + " " + y0 + "Z"
                }

                ShapePath {
                    fillColor: Theme.ground
                    strokeColor: "transparent"
                    strokeWidth: 0
                    fillRule: ShapePath.OddEvenFill
                    PathSvg {
                        path: "M0 0L" + sheet.w + " 0L" + sheet.w + " " + sheet.h
                              + "L0 " + sheet.h + "Z" + sheet.hole()
                    }
                }
            }
        }
    }

    WlSessionLock {
        id: sessionLock
        locked: false

        WlSessionLockSurface {
            id: lockSurface
            color: Theme.ground
            readonly property bool isPrimary: screen && screen.name === DisplayService.primaryName

            C.LockFace {
                id: lockFace
                anchors.fill: parent
                primary: lockSurface.isPrimary
                checking: root.checking
                failures: root.failures
                message: root.message
                messageIsError: root.messageIsError
                leaving: root.leaving
                onSubmitted: pw => root.submit(pw)
                Component.onCompleted: grabKeys()
            }
        }
    }

    PanelWindow {
        id: previewWin
        visible: false
        screen: DisplayService.primaryScreen
        color: Theme.ground
        anchors { top: true; left: true; right: true; bottom: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-lock"
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Loader {
            anchors.fill: parent
            active: previewWin.visible
            sourceComponent: C.LockFace {
                primary: true
                checking: root.checking
                failures: root.failures
                message: root.message
                messageIsError: root.messageIsError
                leaving: root.leaving
                onSubmitted: pw => root.submit(pw)
                onEscapedEmpty: root.unlockNow()
                Component.onCompleted: grabKeys()
            }
        }
        Timer { running: previewWin.visible; interval: 90000; onTriggered: root.unlockNow() }
    }

    IpcHandler {
        target: "lock"
        function lock() { root.lock(false) }
        function preview() { root.lock(true) }
        function now() { root.lockNow() }
        function cancel() { if (root.preview && root.phase === "locked") root.unlockNow() }
        function testfail() {
            if (!root.preview || root.phase !== "locked") return
            root.message = "Wrong password"; root.messageIsError = true
            root.failures++; clearMsg.restart()
        }
        function status(): string {
            return root.phase + (root.preview ? " (preview)" : "")
                 + " shut=" + root.shut.toFixed(2) + " failures=" + root.failures
                 + " msg=" + root.message
        }
    }
}
