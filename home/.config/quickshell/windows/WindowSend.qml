import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Io
import QtQuick
import "../theme"
import "../services"

Scope {
    id: root

    readonly property int slideMs: 400

    property string target: ""
    property var win: null
    property var toplevel: null
    property string screenName: ""
    property int dir: 1
    property real gx: 0; property real gy: 0
    property real gw: 0; property real gh: 0
    property bool sliding: false
    property real slide: 0

    function send(t) {
        if (sliding) { slideAnim.complete() }
        target = t
        query.running = true
    }

    function norm(a) { return String(a).replace(/^0x/, "").toLowerCase() }

    function wsMonitorX(name) {
        const ws = Hyprland.workspaces.values
        for (let i = 0; i < ws.length; i++) {
            const w = ws[i]
            if ((name.startsWith("name:") && w.name === name.slice(5)) || String(w.id) === name)
                return w.monitor ? w.monitor.x : null
        }
        if (!name.startsWith("name:")) {
            const ms = Hyprland.monitors.values
            for (let j = 0; j < ms.length; j++)
                if (ms[j].name === DisplayService.primaryName) return ms[j].x
        }
        return null
    }

    function moveNow() {
        if (!win) return
        Hyprland.dispatch("hl.dsp.window.move({ workspace = " + (/^\d+$/.test(target) ? target : '"' + target + '"')
                          + ", follow = false, window = \"address:" + win.address + "\" })")
    }

    Process {
        id: query
        command: ["hyprctl", "-j", "activewindow"]
        stdout: StdioCollector {
            onStreamFinished: {
                let w = null
                try { w = JSON.parse(text) } catch (e) { w = null }
                if (!w || !w.address) { root.win = null; return }
                root.win = w
                root.begin()
            }
        }
    }

    function begin() {
        const w = win
        const cur = w.workspace || {}
        if (String(cur.id) === target || ("name:" + cur.name) === target) return

        const mons = Hyprland.monitors.values
        let mon = null
        for (let i = 0; i < mons.length; i++) if (mons[i].id === w.monitor) mon = mons[i]
        const tx = wsMonitorX(target)
        if (mon && tx !== null && tx !== mon.x) dir = tx > mon.x ? 1 : -1
        else if (/^\d+$/.test(target) && cur.id > 0) dir = Number(target) > cur.id ? 1 : -1
        else dir = 1

        if (!mon || w.fullscreen > 0) { moveNow(); return }

        screenName = mon.name
        gx = w.at[0] - mon.x; gy = w.at[1] - mon.y
        gw = w.size[0]; gh = w.size[1]

        const tl = Hyprland.toplevels.values
        captured = false
        toplevel = null
        for (let k = 0; k < tl.length; k++)
            if (norm(tl[k].address) === norm(w.address)) toplevel = tl[k]
        if (!toplevel || !toplevel.wayland) { moveNow(); return }

        waitCapture.tries = 0
        waitCapture.start()
    }
    property bool captured: false

    Timer {
        id: waitCapture
        property int tries: 0
        interval: 16; repeat: true
        onTriggered: {
            tries++
            if (root.captured || tries > 9) {
                stop()
                if (root.captured) {
                    root.slide = 0
                    root.sliding = true
                    root.moveNow()
                    slideAnim.restart()
                } else {
                    root.moveNow()
                }
            }
        }
    }

    NumberAnimation {
        id: slideAnim
        target: root; property: "slide"; from: 0; to: 1
        duration: root.slideMs
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.23, 1, 0.32, 1, 1, 1]
        onFinished: { root.sliding = false; root.toplevel = null; root.captured = false }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: ghostWin
            required property var modelData
            screen: modelData
            readonly property bool mine: root.screenName === modelData.name && root.toplevel !== null
            readonly property bool framed: modelData.name === DisplayService.primaryName

            visible: true
            color: "transparent"
            anchors { top: true; left: true; right: true; bottom: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "quickshell-send"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            mask: Region {}

            ClippingRectangle {
                x: ghostWin.framed ? Theme.borderWidth : 0
                y: ghostWin.framed ? Theme.borderWidth : 0
                width: parent.width - 2 * x
                height: parent.height - 2 * y
                radius: ghostWin.framed ? Theme.cornerRadius : 0
                color: "transparent"
                visible: ghostWin.mine && root.sliding

                Item {
                    x: root.gx - parent.x + root.dir * root.slide * ghostWin.width
                    y: root.gy - parent.y
                    width: root.gw; height: root.gh

                    Rectangle {
                        x: -2; y: -2
                        width: parent.width + 4; height: parent.height + 4
                        radius: 14
                        color: Theme.accent
                    }
                    ClippingRectangle {
                        anchors.fill: parent
                        radius: 12
                        color: Theme.ground
                        ScreencopyView {
                            id: copy
                            anchors.fill: parent
                            live: false
                            captureSource: ghostWin.mine ? root.toplevel.wayland : null
                            onHasContentChanged: if (hasContent && ghostWin.mine) root.captured = true
                        }
                    }
                }
            }
        }
    }

    Instantiator {
        model: ["1", "2", "3", "4", "5", "6", "7", "8"]
        delegate: GlobalShortcut {
            required property string modelData
            appid: "quickshell"
            name: "send-" + modelData
            description: "Send the active window to desktop " + modelData
            onPressed: root.send(modelData)
        }
    }
    Instantiator {
        model: ["aux-l", "aux-r", "aux-x"]
        delegate: GlobalShortcut {
            required property string modelData
            appid: "quickshell"
            name: "send-" + modelData
            description: "Send the active window to " + modelData
            onPressed: root.send("name:" + modelData)
        }
    }

    IpcHandler {
        target: "send"
        function to(ws: string): void { root.send(ws) }
        function status(): string {
            return "sliding=" + root.sliding + " dir=" + root.dir + " target=" + root.target
                 + " rect=" + root.gx + "," + root.gy + " " + root.gw + "x" + root.gh
        }
    }
}
