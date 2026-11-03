pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"
import Quickshell.Hyprland
import "../state"

Singleton {
    id: root

    readonly property string storePath: Paths.state + "/displays.json"
    readonly property string luaPath: Paths.state + "/displays.lua"
    readonly property var auxSlots: ["aux-l", "aux-r", "aux-x"]
    readonly property var auxKeys: ({ "aux-l": "º", "aux-r": "0", "aux-x": "9" })

    property var monitors: []
    property bool ready: false
    signal refreshed()

    property string primaryDesc: ""
    property string lastPrimaryName: ""

    readonly property var primaryMonitor: {
        var on = monitors.filter(m => !m.disabled && m.mirrorOf === "none")
        return on.find(m => m.desc === primaryDesc) || fallbackPrimary(on) || null
    }
    readonly property string primaryName: primaryMonitor ? primaryMonitor.name : lastPrimaryName
    readonly property var primaryScreen:
        Quickshell.screens.find(s => s.name === primaryName) || Quickshell.screens[0]
    readonly property bool primaryIsFallback: primaryMonitor !== null && primaryMonitor.desc !== primaryDesc

    function fallbackPrimary(list) {
        var best = null
        for (var i = 0; i < list.length; i++) {
            var m = list[i]
            if (!best || m.lw * m.lh > best.lw * best.lh
                || (m.lw * m.lh === best.lw * best.lh && m.x < best.x)) best = m
        }
        return best
    }

    property var store: ({ profiles: {} })

    FileView {
        id: storeFile
        path: root.storePath
        blockLoading: true
        printErrors: false
        onLoaded: root.loadStore()
    }
    function loadStore() {
        var t = storeFile.text()
        var s = null
        try { s = JSON.parse(t) } catch (e) {}
        if (!s || typeof s !== "object") s = {}
        if (!s.profiles) s.profiles = {}
        store = s
        if (s.lastPrimaryName) lastPrimaryName = s.lastPrimaryName
    }
    function saveStore() {
        store.lastPrimaryName = primaryName
        storeFile.setText(JSON.stringify(store, null, 2) + "\n")
    }

    FileView { id: luaFile; path: root.luaPath; printErrors: false }

    // XWayland games open on the X11 primary output; keep it on ours.
    onPrimaryNameChanged: if (primaryName !== "") xPrimary.running = true
    readonly property Process xPrimary: Process {
        command: ["sh", "-c", "command -v xrandr >/dev/null || exit 0; for i in $(seq 20); do xrandr --output \"$1\" --primary 2>/dev/null && exit; sleep 1; done", "sh", root.primaryName]
    }

    Process {
        id: reader
        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                var raw
                try { raw = JSON.parse(text) } catch (e) { return }
                root.monitors = raw.map(root.normalise)
                    .sort((a, b) => a.x - b.x || a.y - b.y)
                root.ready = true
                root.refreshed()
            }
        }
    }
    function refresh() { reader.running = false; reader.running = true }

    function normalise(m) {
        var rot = (m.transform % 2) === 1
        var s = m.scale > 0 ? m.scale : 1
        return {
            id: m.id, name: m.name, desc: m.description || m.name, make: m.make, model: m.model,
            w: m.width, h: m.height, hz: m.refreshRate,
            x: m.x, y: m.y, scale: s, transform: m.transform,
            disabled: m.disabled, vrr: !!m.vrr, mirrorOf: m.mirrorOf || "none",
            internal: m.name.indexOf("eDP") === 0,
            modes: (m.availableModes || []).map(t => t.replace(/Hz$/, "")),
            lw: Math.round((rot ? m.height : m.width) / s),
            lh: Math.round((rot ? m.width : m.height) / s)
        }
    }

    function liveMirror(m) {
        if (m.mirrorOf === "none") return "none"
        var src = monitors.find(o => String(o.id) === m.mirrorOf || o.name === m.mirrorOf)
        return src ? src.desc : "none"
    }
    function modeString(m) { return m.w + "x" + m.h + "@" + Number(m.hz).toFixed(2) }
    readonly property var makeNames: ({ "BNQ": "BenQ", "Sharp Corporation": "Sharp", "GSM": "LG",
                                        "SAM": "Samsung", "DEL": "Dell", "ACR": "Acer", "AUS": "ASUS",
                                        "HWP": "HP", "LEN": "Lenovo", "PHL": "Philips", "VSC": "ViewSonic" })
    function shortName(m) {
        if (m.internal) return "Laptop"
        var make = makeNames[m.make] || m.make || ""
        var model = m.model || ""
        if (make !== "" && model.toLowerCase().indexOf(make.toLowerCase()) === 0) make = ""
        var t = (make + " " + model).trim()
        return t !== "" ? t : m.name
    }

    function keyOf(list) { return list.map(m => m.desc).sort().join(" | ") }
    readonly property string currentKey: keyOf(monitors)
    readonly property var currentProfile: store.profiles[currentKey] || null

    function snapshot() {
        var outs = {}
        monitors.forEach(function (m) {
            var mir = liveMirror(m)
            outs[m.desc] = {
                mode: modeString(m), x: m.x, y: m.y, scale: m.scale,
                transform: m.transform, vrr: m.vrr, disabled: m.disabled, mirror: mir
            }
        })
        var p = {
            name: currentProfile ? currentProfile.name : defaultName(),
            primary: primaryMonitor ? primaryMonitor.desc : "",
            slots: currentProfile && currentProfile.slots ? currentProfile.slots : liveSlots(),
            outputs: outs
        }
        return p
    }
    function defaultName() {
        var ext = monitors.filter(m => !m.internal).length
        if (ext === 0) return "Laptop only"
        return monitors.length + " displays"
    }
    function clone(o) { return JSON.parse(JSON.stringify(o)) }

    function logicalSize(desc, o) {
        var p = /(\d+)x(\d+)/.exec(o.mode) || [0, 1920, 1080]
        var w = +p[1], h = +p[2]
        var rot = (o.transform % 2) === 1
        var s = o.scale > 0 ? o.scale : 1
        return { w: Math.round((rot ? h : w) / s), h: Math.round((rot ? w : h) / s) }
    }

    function slotsFor(p) {
        var prim = p.outputs[p.primary]
        if (!prim) return {}
        var ps = logicalSize(p.primary, prim)
        var pcx = prim.x + ps.w / 2
        var secs = Object.keys(p.outputs).filter(function (d) {
            var o = p.outputs[d]
            return d !== p.primary && !o.disabled && (!o.mirror || o.mirror === "none")
        }).map(function (d) {
            var o = p.outputs[d], s = logicalSize(d, o)
            return { desc: d, cx: o.x + s.w / 2 }
        }).sort((a, b) => a.cx - b.cx)

        if (p.slots) {
            var ok = secs.every(s => !!p.slots[s.desc])
            if (ok && secs.length > 0) {
                var r = {}
                secs.forEach(s => r[s.desc] = p.slots[s.desc])
                return r
            }
        }
        var out = {}
        if (secs.length === 1) {
            out[secs[0].desc] = secs[0].cx < pcx ? "aux-l" : "aux-r"
        } else if (secs.length >= 2) {
            out[secs[0].desc] = "aux-l"
            out[secs[secs.length - 1].desc] = "aux-r"
            if (secs.length >= 3) out[secs[1].desc] = "aux-x"
        }
        return out
    }

    function portOf(desc) {
        var m = monitors.find(x => x.desc === desc)
        return m ? m.name : ""
    }
    function lq(s) { return "\"" + String(s).replace(/\\/g, "\\\\").replace(/"/g, "\\\"") + "\"" }

    function monitorRule(port, o) {
        if (o.disabled) return "hl.monitor({ output = " + lq(port) + ", disabled = true })"
        var mir = (o.mirror && o.mirror !== "none") ? portOf(o.mirror) : ""
        return "hl.monitor({ output = " + lq(port)
            + ", mode = " + lq(o.mode)
            + ", position = " + lq(Math.round(o.x) + "x" + Math.round(o.y))
            + ", scale = " + lq(String(+Number(o.scale).toFixed(4)))
            + ", transform = " + (o.transform | 0)
            + ", vrr = " + (o.vrr ? 1 : 0)
            + ", mirror = " + lq(mir)
            + ", disabled = false })"
    }

    function workspaceRules(p, slots) {
        var P = portOf(p.primary)
        var l = []
        for (var i = 1; i <= 8; i++)
            l.push("hl.workspace_rule({ workspace = \"" + i + "\", monitor = " + lq(P)
                   + ", default = " + (i === 1) + " })")
        for (var d in slots)
            l.push("hl.workspace_rule({ workspace = \"name:" + slots[d] + "\", monitor = "
                   + lq(portOf(d)) + ", default = true })")
        return l
    }

    function workspaceMoves(p, slots) {
        var P = portOf(p.primary)
        var cmds = []
        Hyprland.workspaces.values.forEach(function (w) {
            var on = w.monitor ? w.monitor.name : ""
            if (w.id >= 1 && w.id <= 8 && on !== P)
                cmds.push("hl.dispatch(hl.dsp.workspace.move({ workspace = \"" + w.id + "\", monitor = " + lq(P) + " }))")
        })
        for (var d in slots) {
            var w2 = Hyprland.workspaces.values.find(w => w.name === slots[d])
            if (w2 && w2.monitor && w2.monitor.name !== portOf(d))
                cmds.push("hl.dispatch(hl.dsp.workspace.move({ workspace = \"name:" + slots[d]
                          + "\", monitor = " + lq(portOf(d)) + " }))")
        }
        return cmds
    }

    function workspaceFixups(p, slots) {
        var cmds = [], shows = [], hidden = []
        var wss = Hyprland.workspaces.values
        var have = {}
        wss.forEach(w => have[w.name] = w)
        for (var d in slots) {
            var slot = slots[d], port = portOf(d)
            var mon = Hyprland.monitors.values.find(m => m.name === port)
            var act = mon && mon.activeWorkspace
            if (!act) continue
            var stray = (act.id > 8 || act.id < 0) && root.auxSlots.indexOf(act.name) < 0
            if (!have[slot]) {
                if (stray) {
                    cmds.push("hl.dispatch(hl.dsp.workspace.rename({ workspace = "
                              + lq(act.id > 0 ? String(act.id) : "name:" + act.name) + ", name = " + lq(slot) + " }))")
                    have[slot] = true
                }
            } else if (act.name !== slot && (stray || root.auxSlots.indexOf(act.name) >= 0)) {
                shows.push("name:" + slot)
                hidden.push(act.id > 0 ? String(act.id) : "name:" + act.name)
            }
        }
        var P = portOf(p.primary)
        var pm = Hyprland.monitors.values.find(m => m.name === P)
        var pa = pm && pm.activeWorkspace
        if (pa && !(pa.id >= 1 && pa.id <= 8)) {
            hidden.push(pa.id > 0 ? String(pa.id) : "name:" + pa.name)
            var ones = wss.filter(w => w.id >= 1 && w.id <= 8 && w.monitor && w.monitor.name === P)
                          .sort((a, b) => a.id - b.id)
            shows.push(ones.length ? String(ones[0].id) : "1")
        }
        if (shows.length > 0) {
            var back = Hyprland.focusedWorkspace
            var backName = back ? (back.id > 0 ? String(back.id) : "name:" + back.name) : ""
            cmds.unshift("local __c = hl.get_cursor_pos()")
            shows.forEach(w => cmds.push("hl.dispatch(hl.dsp.focus({ workspace = " + lq(w) + " }))"))
            if (backName !== "" && shows.indexOf(backName) < 0 && hidden.indexOf(backName) < 0)
                cmds.push("hl.dispatch(hl.dsp.focus({ workspace = " + lq(backName) + " }))")
            cmds.push("hl.dispatch(hl.dsp.cursor.move({ x = __c.x, y = __c.y }))")
        }
        return cmds
    }

    function stableSlots(p, prev) {
        var pos = slotsFor(p)
        if (!prev) return pos
        var out = {}, used = {}
        for (var d in pos)
            if (prev[d] && !used[prev[d]]) { out[d] = prev[d]; used[prev[d]] = true }
        for (var d2 in pos) {
            if (out[d2]) continue
            var want = pos[d2]
            if (used[want]) want = auxSlots.find(s => !used[s]) || ""
            if (want !== "") { out[d2] = want; used[want] = true }
        }
        return out
    }
    property var lastSlots: null

    function liveSlots() {
        var out = {}, n = 0
        Hyprland.workspaces.values.forEach(function (w) {
            if (auxSlots.indexOf(w.name) < 0 || !w.monitor) return
            var m = monitors.find(x => x.name === w.monitor.name)
            if (m && m.desc !== primaryDesc) { out[m.desc] = w.name; n++ }
        })
        return n > 0 ? out : null
    }

    function generatedFile(p, slots) {
        var l = [
            "-- GENERATED by Quickshell's Displays room (services/DisplayService.qml).",
            "-- Edit the layout from the room; hand edits are overwritten on the next apply.",
            "-- Profile: " + p.name,
            "",
            "-- Anything not listed below still turns on, beside the others.",
            "hl.monitor({ output = \"\", mode = \"preferred\", position = \"auto\", scale = \"auto\" })",
            ""
        ]
        Object.keys(p.outputs).forEach(function (d) {
            var port = portOf(d)
            if (port === "") return
            l.push("-- " + d)
            l.push(monitorRule(port, p.outputs[d]))
        })
        l.push("")
        l.push("-- Desktops 1–8 live on the primary; aux-l/aux-r/aux-x are SUPER+º/0/9.")
        l = l.concat(workspaceRules(p, slots))
        return l.join("\n") + "\n"
    }

    function risky(p) {
        return monitors.some(function (m) {
            var o = p.outputs[m.desc]
            if (!o) return false
            return o.mode !== modeString(m) || Math.abs(o.scale - m.scale) > 0.001
                || o.transform !== m.transform || !!o.disabled !== !!m.disabled
                || (o.mirror || "none") !== liveMirror(m)
        })
    }

    property bool dryRun: false
    property string lastLua: ""
    property string lastFile: ""

    property var previous: null
    property bool confirmPending: false
    property int confirmSeconds: 15
    property real confirmLeft: 0
    property bool suppressEvents: false

    NumberAnimation {
        id: confirmAnim
        target: root; property: "confirmLeft"
        from: 1; to: 0
        duration: root.confirmSeconds * 1000
        onFinished: if (root.confirmPending) root.revert()
    }

    function apply(p, opts) {
        opts = opts || {}
        var slots = slotsFor(p)
        var needConfirm = opts.confirm !== false && risky(p)
        if (!opts.isRevert) previous = snapshot()

        var lua = []
        monitors.forEach(function (m) {
            var o = p.outputs[m.desc]
            if (!o) return
            if (!!o.disabled !== !!m.disabled || (o.mirror || "none") !== root.liveMirror(m))
                root.expected[m.name] = Date.now()
            var same = !o.disabled && !m.disabled && o.mode === modeString(m)
                && Math.round(o.x) === m.x && Math.round(o.y) === m.y
                && Math.abs(o.scale - m.scale) < 0.001 && o.transform === m.transform
                && !!o.vrr === m.vrr && (o.mirror || "none") === liveMirror(m)
            if (o.disabled && m.disabled) same = true
            if (!same) lua.push(monitorRule(m.name, o))
        })
        lua = lua.concat(workspaceRules(p, slots))
        lua = lua.concat(workspaceMoves(p, slots))
        lastSlots = slots
        pendingSlots = slots
        pendingProfile = p

        primaryDesc = p.primary
        suppressEvents = true
        suppressTimer.restart()
        lastLua = lua.join("\n")
        lastFile = generatedFile(p, slots)
        if (dryRun) {
            console.log("displays dry run — eval:\n" + lastLua + "\n— file:\n" + lastFile)
        } else {
            evalProc.exec(["hyprctl", "eval", lastLua])
            luaFile.setText(lastFile)
        }

        if (opts.save !== false) {
            var saved = clone(p)
            saved.slots = slots
            var st = clone(store)
            st.profiles[keyOf(monitors)] = saved
            store = st
            if (!dryRun) saveStore()
        }
        if (needConfirm) {
            confirmPending = true
            confirmAnim.restart()
        } else {
            confirmPending = false
            confirmAnim.stop()
        }
        renameTimer.restart()
    }
    property var pendingSlots: null
    property var pendingProfile: null
    Timer {
        id: renameTimer
        interval: 350
        onTriggered: {
            var r = root.pendingSlots ? root.workspaceFixups(root.pendingProfile, root.pendingSlots) : []
            if (r.length > 0) {
                if (root.dryRun) console.log("displays dry run — renames:\n" + r.join("\n"))
                else renameProc.exec(["hyprctl", "eval", r.join("\n")])
            }
            root.suppressEvents = true
            suppressTimer.restart()
            settleTimer.restart()
        }
    }
    Process { id: renameProc }
    function confirm() { confirmPending = false; confirmAnim.stop() }
    function revert() {
        confirmPending = false
        confirmAnim.stop()
        if (previous) apply(previous, { isRevert: true, confirm: false })
    }

    Process {
        id: evalProc
        stdout: StdioCollector { onStreamFinished: if (text.trim() !== "ok") console.warn("displays eval:", text) }
    }
    Timer { id: settleTimer; interval: 450; onTriggered: root.refresh() }
    Timer { id: suppressTimer; interval: 2500; onTriggered: root.suppressEvents = false }

    property string newcomer: ""

    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            if (ev.name !== "monitoraddedv2" && ev.name !== "monitorremovedv2") return
            var port = ev.data.split(",")[1] || ""
            var t = root.expected[port]
            if (t && Date.now() - t < 5000) { delete root.expected[port]; return }
            root.plugAdded = ev.name === "monitoraddedv2"
            root.plugName = port
            plugTimer.restart()
        }
    }
    property var expected: ({})
    property bool plugAdded: false
    property string plugName: ""
    Timer {
        id: plugTimer
        interval: 700
        onTriggered: { root.pendingPlug = true; root.refresh() }
    }
    property bool pendingPlug: false
    onRefreshed: {
        if (!pendingPlug) return
        pendingPlug = false
        var prof = store.profiles[currentKey]
        console.log("displays: " + (plugAdded ? "plugged " : "unplugged ") + plugName
                    + (prof ? " — profile «" + prof.name + "»" : " — no profile, opening the room"))
        if (prof) {
            apply(clone(prof), { save: false, confirm: false })
            notify("Profile «" + prof.name + "» applied")
        } else {
            var draft = snapshot()
            if (!monitors.some(m => m.desc === draft.primary)) draft.primary = primaryMonitor ? primaryMonitor.desc : ""
            draft.slots = stableSlots(draft, liveSlots())
            apply(draft, { save: false, confirm: false })
            var nm = monitors.find(m => m.name === plugName)
            newcomer = plugAdded && nm ? nm.desc : ""
            openTimer.restart()
        }
    }

    Timer { id: openTimer; interval: 900; onTriggered: root.openRoom() }
    function openRoom() {
        Popups.closeAll()
        Popups.apertureOpen = true
        Popups.apertureRoom = "displays"
    }

    Process {
        id: notifier
        stdout: StdioCollector { onStreamFinished: if (text.trim() === "adjust") root.openRoom() }
    }
    function notify(msg) {
        notifier.exec(["notify-send", "-a", "Displays",
                       "--action=adjust=Adjust", msg, "Layout saved for these displays"])
    }

    property bool identifying: false
    Timer { id: identifyTimer; interval: 2200; onTriggered: root.identifying = false }
    function identify() { identifying = true; identifyTimer.restart() }

    IpcHandler {
        target: "displays"
        function open() { root.openRoom() }
        function status(): string {
            return JSON.stringify({ primary: root.primaryName, key: root.currentKey,
                                    slots: root.liveSlots() })
        }
        function primary(name: string) {
            var m = root.monitors.find(x => x.name === name)
            if (!m) return
            var p = root.currentProfile ? root.clone(root.currentProfile) : root.snapshot()
            p.primary = m.desc
            p.slots = null
            root.apply(p, { confirm: false })
        }
        function apply() { root.apply(root.currentProfile ? root.clone(root.currentProfile) : root.snapshot()) }
        function confirm() { root.confirm() }
        function dryrun(on: bool) { root.dryRun = on }
        function revert() { root.revert() }
        function identify() { root.identify() }
    }

    Component.onCompleted: {
        loadStore()
        refresh()
    }
    onReadyChanged: {
        if (!ready) return
        var p = currentProfile
        if (p) lastSlots = slotsFor(p)
        primaryDesc = p ? p.primary : (monitors.find(m => m.name === lastPrimaryName) || {}).desc || ""
    }
}
