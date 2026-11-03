import QtQuick
import Quickshell
import "../components"
import "../theme"
import "../services"

Item {
    id: root

    readonly property color hue: Qt.color("#6791c9")

    property var draft: null
    property string savedJson: ""
    property string selected: ""
    readonly property bool dirty: draft !== null && JSON.stringify(draft) !== savedJson

    function load() {
        var p = DisplayService.currentProfile
            ? DisplayService.clone(DisplayService.currentProfile) : DisplayService.snapshot()
        var live = DisplayService.snapshot()
        for (var d in live.outputs) if (!p.outputs[d]) p.outputs[d] = live.outputs[d]
        for (var d2 in p.outputs) if (!live.outputs[d2]) delete p.outputs[d2]
        if (!p.outputs[p.primary]) p.primary = live.primary
        draft = p
        savedJson = JSON.stringify(p)
        if (!p.outputs[selected])
            selected = DisplayService.newcomer !== "" && p.outputs[DisplayService.newcomer]
                ? DisplayService.newcomer : p.primary
    }
    function edit(fn) {
        var d = DisplayService.clone(draft)
        fn(d)
        draft = d
    }

    Component.onCompleted: {
        load()
        keys.forceActiveFocus()
    }
    Component.onDestruction: DisplayService.newcomer = ""
    Connections {
        target: DisplayService
        function onRefreshed() { if (!root.dirty && !DisplayService.confirmPending) root.load() }
    }

    function out(desc) { return draft ? draft.outputs[desc] : null }
    function sizeOf(desc) {
        var o = out(desc)
        return o ? DisplayService.logicalSize(desc, o) : { w: 1, h: 1 }
    }
    function placed(desc) {
        var o = out(desc)
        return !!o && !o.disabled && (!o.mirror || o.mirror === "none")
    }
    readonly property var placedDescs: draft ? Object.keys(draft.outputs).filter(placed) : []
    readonly property var unplacedDescs: draft ? Object.keys(draft.outputs).filter(d => !placed(d)) : []
    function monitorOf(desc) { return DisplayService.monitors.find(m => m.desc === desc) || null }
    function labelOf(desc) {
        var m = monitorOf(desc)
        return m ? DisplayService.shortName(m) : desc
    }

    readonly property var slots: draft ? DisplayService.slotsFor(draft) : ({})

    readonly property var order: placedDescs.slice().sort((a, b) => out(a).x - out(b).x || out(a).y - out(b).y)

    function snap(desc, x, y) {
        var me = sizeOf(desc)
        var others = placedDescs.filter(d => d !== desc)
        if (others.length === 0) return { x: 0, y: 0, edge: null }
        var thr = 28 / Math.max(0.0001, canvas.k)
        var best = null

        function overlaps(cx, cy) {
            return others.some(function (d) {
                var o = out(d), s = sizeOf(d)
                return cx < o.x + s.w && cx + me.w > o.x && cy < o.y + s.h && cy + me.h > o.y
            })
        }
        function align(v, lo, hi, lines) {
            v = Math.max(lo, Math.min(hi, v))
            for (var i = 0; i < lines.length; i++)
                if (Math.abs(v - lines[i]) < thr && lines[i] >= lo && lines[i] <= hi) return lines[i]
            return v
        }
        function consider(cx, cy, edge) {
            cx = Math.round(cx); cy = Math.round(cy)
            if (overlaps(cx, cy)) return
            var dist = Math.hypot(cx - x, cy - y)
            if (!best || dist < best.dist) best = { x: cx, y: cy, edge: edge, dist: dist }
        }

        others.forEach(function (d) {
            var o = out(d), s = sizeOf(d)
            var minOv = Math.min(64, me.h, s.h)
            var yy = align(y, o.y - me.h + minOv, o.y + s.h - minOv,
                           [o.y, o.y + s.h - me.h, o.y + (s.h - me.h) / 2])
            var y0 = Math.max(o.y, yy), y1 = Math.min(o.y + s.h, yy + me.h)
            consider(o.x + s.w, yy, { vertical: true, at: o.x + s.w, from: y0, to: y1 })
            consider(o.x - me.w, yy, { vertical: true, at: o.x, from: y0, to: y1 })
            var minOvX = Math.min(64, me.w, s.w)
            var xx = align(x, o.x - me.w + minOvX, o.x + s.w - minOvX,
                           [o.x, o.x + s.w - me.w, o.x + (s.w - me.w) / 2])
            var x0 = Math.max(o.x, xx), x1 = Math.min(o.x + s.w, xx + me.w)
            consider(xx, o.y + s.h, { vertical: false, at: o.y + s.h, from: x0, to: x1 })
            consider(xx, o.y - me.h, { vertical: false, at: o.y, from: x0, to: x1 })
        })
        return best || { x: x, y: y, edge: null }
    }

    function normalise(d) {
        var keys = Object.keys(d.outputs).filter(k => {
            var o = d.outputs[k]; return !o.disabled && (!o.mirror || o.mirror === "none")
        })
        if (keys.length === 0) return
        var mx = Math.min.apply(null, keys.map(k => d.outputs[k].x))
        var my = Math.min.apply(null, keys.map(k => d.outputs[k].y))
        keys.forEach(k => { d.outputs[k].x -= mx; d.outputs[k].y -= my })
    }

    function place(desc, x, y, keepKeys) {
        var s = snap(desc, x, y)
        edit(function (d) {
            d.outputs[desc].x = s.x
            d.outputs[desc].y = s.y
            if (!keepKeys) d.slots = null
            normalise(d)
        })
    }
    function resettle(desc) {
        if (!placed(desc)) return
        var o = out(desc)
        place(desc, o.x, o.y, true)
    }

    readonly property bool unsaved: DisplayService.currentProfile === null
    function applyDraft() {
        if (!dirty && !unsaved) return
        var p = draft
        savedJson = JSON.stringify(p)
        DisplayService.apply(p)
    }

    function makePrimary(desc) {
        if (!placed(desc)) return
        edit(function (d) { d.primary = desc; d.slots = null })
    }

    function swapKey(desc) {
        var cur = slots
        var secs = Object.keys(cur)
        if (secs.length < 2) return
        var i = secs.indexOf(desc)
        var other = secs[(i + 1) % secs.length]
        var ns = {}
        secs.forEach(s => ns[s] = cur[s])
        ns[desc] = cur[other]
        ns[other] = cur[desc]
        edit(function (d) { d.slots = ns })
    }

    function setField(desc, key, value) {
        edit(function (d) { d.outputs[desc][key] = value })
        if (key === "mode" || key === "scale" || key === "transform") resettle(desc)
        if (key === "disabled" && !value) resettle(desc)
        if ((key === "disabled" && value) || (key === "mirror" && value !== "none")) {
            if (draft.primary === desc) {
                var next = placedDescs.find(x => x !== desc)
                if (next) makePrimary(next)
            }
        }
    }

    function resolutionsOf(desc) {
        var m = monitorOf(desc)
        if (!m) return []
        var seen = {}, list = []
        m.modes.forEach(function (t) {
            var r = t.split("@")[0]
            if (!seen[r]) { seen[r] = true; list.push(r) }
        })
        return list.sort(function (a, b) {
            var pa = a.split("x"), pb = b.split("x")
            return pb[0] * pb[1] - pa[0] * pa[1]
        })
    }
    function ratesOf(desc, res) {
        var m = monitorOf(desc)
        if (!m) return []
        var rates = m.modes.filter(t => t.split("@")[0] === res).map(t => t.split("@")[1])
        var out = []
        rates.sort((a, b) => b - a).forEach(function (r) {
            if (!out.some(o => Math.abs(o - r) < 0.2)) out.push(r)
        })
        return out.slice(0, 5)
    }
    function resOf(desc) { var o = out(desc); return o ? o.mode.split("@")[0] : "" }
    function rateOf(desc) { var o = out(desc); return o ? o.mode.split("@")[1] : "" }

    Item {
        id: keys
        focus: true
        Keys.onPressed: function (e) {
            var i = root.order.indexOf(root.selected)
            if (e.key === Qt.Key_Left || e.key === Qt.Key_Right) {
                var dir = e.key === Qt.Key_Left ? -1 : 1
                if (e.modifiers & Qt.ShiftModifier) {
                    var o = root.out(root.selected), s = root.sizeOf(root.selected)
                    root.place(root.selected, o.x + dir * (s.w * 0.75 + 40), o.y)
                } else if (root.order.length > 0) {
                    root.selected = root.order[(Math.max(0, i) + dir + root.order.length) % root.order.length]
                }
                e.accepted = true
            } else if ((e.key === Qt.Key_Up || e.key === Qt.Key_Down) && (e.modifiers & Qt.ShiftModifier)) {
                var o2 = root.out(root.selected), s2 = root.sizeOf(root.selected)
                root.place(root.selected, o2.x, o2.y + (e.key === Qt.Key_Up ? -1 : 1) * (s2.h * 0.75 + 40))
                e.accepted = true
            } else if (e.key === Qt.Key_P) {
                root.makePrimary(root.selected); e.accepted = true
            } else if (e.key === Qt.Key_I) {
                DisplayService.identify(); e.accepted = true
            } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                if (DisplayService.confirmPending) DisplayService.confirm()
                else root.applyDraft()
                e.accepted = true
            } else if (e.key === Qt.Key_Escape) {
                if (DisplayService.confirmPending) { DisplayService.revert(); e.accepted = true }
                else if (root.dirty) { root.load(); e.accepted = true }
                else e.accepted = false
            }
        }
    }

    component Keycap: Rectangle {
        id: kc
        property string label: ""
        property bool clickable: false
        signal clicked()
        width: Math.max(20, kcText.implicitWidth + 12)
        height: 20
        radius: 5
        color: kcHov.hovered && clickable ? Theme.lift(Theme.palette.grey, 0.08) : Theme.palette.grey
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 2; radius: 5
            color: Theme.palette.black
            opacity: 0.6
        }
        Text {
            id: kcText
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -1
            text: kc.label
            color: Theme.text
            font.family: kc.label.length === 1 ? Theme.fontText : Theme.fontMono
            font.pixelSize: kc.label === "º" ? 15 : 11
            font.weight: Font.Medium
        }
        HoverHandler { id: kcHov; cursorShape: kc.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor }
        TapHandler { enabled: kc.clickable; onTapped: kc.clicked() }
    }

    component Button_: Rectangle {
        id: btn
        property string label: ""
        property string glyph: ""
        property bool primary: false
        property color tint: root.hue
        signal clicked()
        width: btnRow.implicitWidth + 24
        height: 28
        radius: 8
        opacity: enabled ? 1 : 0.35
        color: primary ? (bHov.hovered ? Theme.lift(tint, 0.08) : tint)
                       : (bHov.hovered ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04))
        Behavior on color { ColorAnimation { duration: 140 } }
        Row {
            id: btnRow
            anchors.centerIn: parent
            spacing: 6
            Text {
                visible: btn.glyph !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: btn.glyph
                color: btn.primary ? Theme.ground : btn.tint
                font.family: Theme.iconFont; font.pixelSize: 13
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: btn.label
                color: btn.primary ? Theme.ground : Theme.text
                opacity: btn.primary ? 1 : 0.85
                font.family: Theme.fontText; font.pixelSize: 12
                font.weight: btn.primary ? Font.Medium : Font.Normal
            }
        }
        HoverHandler { id: bHov; cursorShape: btn.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor }
        TapHandler { enabled: btn.enabled; onTapped: btn.clicked() }
    }

    component Chip: Rectangle {
        id: chip
        property string glyph: ""
        property string label: ""
        property color tint: Theme.text
        width: chipRow.implicitWidth + 16
        height: 22
        radius: 11
        color: Theme.withAlpha(tint, 0.12)
        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 5
            Text {
                visible: chip.glyph !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: chip.glyph; color: chip.tint
                font.family: Theme.iconFont; font.pixelSize: 11
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.label; color: chip.tint
                font.family: Theme.fontText; font.pixelSize: 11
            }
        }
    }

    component Setting: Item {
        property string name: ""
        default property alias control: ctl.data
        width: parent ? parent.width : 0
        height: 32
        Text {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            text: parent.name
            color: Theme.text; opacity: 0.55
            font.family: Theme.fontText; font.pixelSize: 12
        }
        Item {
            id: ctl
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            width: childrenRect.width; height: childrenRect.height
        }
    }

    component Drop: Rectangle {
        id: drop
        property var items: []
        property string current: ""
        signal picked(string key)
        width: 128; height: 26; radius: 8
        color: dHov.hovered || (dropLayer.owner === drop) ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.045)
        Text {
            anchors { left: parent.left; leftMargin: 10; right: chev.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
            text: { var it = drop.items.find(i => i.key === drop.current); return it ? it.label : drop.current }
            color: Theme.text; opacity: 0.88
            elide: Text.ElideRight
            font.family: Theme.fontText; font.pixelSize: 12
        }
        Text {
            id: chev
            anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
            text: String.fromCodePoint(0xF0140)
            color: Theme.text; opacity: 0.45
            font.family: Theme.iconFont; font.pixelSize: 12
        }
        HoverHandler { id: dHov; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: dropLayer.toggle(drop) }
    }

    Column {
        anchors.fill: parent
        spacing: 10

        SectionHeader {
            width: parent.width
            label: "Displays"
            tint: root.hue

            Chip {
                visible: DisplayService.primaryIsFallback
                glyph: String.fromCodePoint(0xF04D2)
                label: "Temporary primary"
                tint: Theme.palette.yellow
            }
            Chip {
                readonly property var ps: root.draft && root.out(root.draft.primary) ? root.sizeOf(root.draft.primary) : null
                visible: ps !== null && ps.h < 900
                glyph: String.fromCodePoint(0xF0026)
                label: "Small primary · try scale 1.25"
                tint: Theme.palette.yellow
            }
            Rectangle {
                width: nameInput.contentWidth + 22
                height: 22; radius: 11
                color: nameInput.activeFocus ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)
                TextInput {
                    id: nameInput
                    anchors.centerIn: parent
                    width: Math.max(40, contentWidth)
                    text: root.draft ? root.draft.name : ""
                    color: Theme.text
                    font.family: Theme.fontText; font.pixelSize: 11
                    selectByMouse: true
                    onEditingFinished: {
                        if (root.draft && text.trim() !== "" && text !== root.draft.name)
                            root.edit(function (d) { d.name = nameInput.text.trim() })
                        keys.forceActiveFocus()
                    }
                }
            }
            Button_ {
                height: 22
                glyph: String.fromCodePoint(0xF0379)
                label: "Identify"
                onClicked: DisplayService.identify()
            }
        }

        Rectangle {
            id: canvas
            width: parent.width
            height: 224
            radius: 12
            color: Theme.surfaceRecess

            readonly property real pad: 22
            readonly property var bbox: {
                var ds = root.placedDescs
                if (ds.length === 0) return { x: 0, y: 0, w: 1920, h: 1080 }
                var x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9
                ds.forEach(function (d) {
                    var o = root.out(d), s = root.sizeOf(d)
                    x0 = Math.min(x0, o.x); y0 = Math.min(y0, o.y)
                    x1 = Math.max(x1, o.x + s.w); y1 = Math.max(y1, o.y + s.h)
                })
                return { x: x0, y: y0, w: x1 - x0, h: y1 - y0 }
            }
            readonly property real liveK: Math.min((width - 2 * pad) / bbox.w, (height - 2 * pad - 8) / bbox.h)
            property real frozenK: 0.1
            property var frozenBox: ({ x: 0, y: 0, w: 1, h: 1 })
            property bool frozen: false
            readonly property real k: frozen ? frozenK : liveK
            readonly property var box: frozen ? frozenBox : bbox
            readonly property real ox: (width - box.w * k) / 2
            readonly property real oy: (height - box.h * k) / 2
            function toX(lx) { return ox + (lx - box.x) * k }
            function toY(ly) { return oy + (ly - box.y) * k }

            property string dragDesc: ""
            property var preview: null

            Grid {
                anchors.centerIn: parent
                columns: Math.max(1, Math.floor((canvas.width - 24) / 16))
                rows: Math.max(1, Math.floor((canvas.height - 24) / 16))
                spacing: 14
                opacity: 0.5
                Repeater {
                    model: parent.columns * parent.rows
                    Rectangle { width: 2; height: 2; radius: 1; color: Qt.rgba(1, 1, 1, 0.05) }
                }
            }

            Rectangle {
                visible: canvas.dragDesc !== "" && canvas.preview !== null
                readonly property var s: canvas.dragDesc !== "" ? root.sizeOf(canvas.dragDesc) : { w: 0, h: 0 }
                x: canvas.preview ? canvas.toX(canvas.preview.x) : 0
                y: canvas.preview ? canvas.toY(canvas.preview.y) : 0
                width: s.w * canvas.k
                height: s.h * canvas.k
                radius: 8
                color: Theme.withAlpha(root.hue, 0.08)
                border.width: 1
                border.color: Theme.withAlpha(root.hue, 0.5)
            }
            Rectangle {
                readonly property var e: canvas.preview ? canvas.preview.edge : null
                visible: canvas.dragDesc !== "" && e !== null
                x: e ? (e.vertical ? canvas.toX(e.at) - 1 : canvas.toX(e.from)) : 0
                y: e ? (e.vertical ? canvas.toY(e.from) : canvas.toY(e.at) - 1) : 0
                width: e ? (e.vertical ? 2 : (e.to - e.from) * canvas.k) : 0
                height: e ? (e.vertical ? (e.to - e.from) * canvas.k : 2) : 0
                radius: 1
                color: root.hue
            }

            Repeater {
                model: root.placedDescs
                delegate: Rectangle {
                    id: tile
                    required property string modelData
                    readonly property string desc: modelData
                    readonly property var o: root.out(desc) || ({ x: 0, y: 0, mode: "0x0@0", scale: 1 })
                    readonly property var sz: root.sizeOf(desc)
                    readonly property var mon: root.monitorOf(desc)
                    readonly property bool isPrimary: root.draft && root.draft.primary === desc
                    readonly property bool isSel: root.selected === desc
                    readonly property bool isNew: DisplayService.newcomer === desc
                    readonly property string slot: root.slots[desc] || ""
                    readonly property bool dragging: canvas.dragDesc === desc

                    property real dragLX: 0
                    property real dragLY: 0

                    x: dragging ? canvas.toX(dragLX) : canvas.toX(o.x)
                    y: dragging ? canvas.toY(dragLY) : canvas.toY(o.y)
                    width: sz.w * canvas.k
                    height: sz.h * canvas.k
                    z: dragging ? 10 : (isSel ? 2 : 1)
                    radius: 8
                    color: area.containsMouse || dragging ? Theme.lift(Theme.palette.bg4, 0.04) : Theme.palette.bg4
                    border.width: isSel || isPrimary ? 1.5 : 1
                    border.color: isSel ? root.hue
                                 : isPrimary ? Theme.withAlpha(root.hue, 0.45)
                                 : Qt.rgba(1, 1, 1, 0.07)
                    opacity: dragging ? 0.92 : 1
                    Behavior on x { enabled: !tile.dragging && !Theme.reducedMotion; NumberAnimation { duration: Theme.animTransition; easing.type: Theme.animCurve } }
                    Behavior on y { enabled: !tile.dragging && !Theme.reducedMotion; NumberAnimation { duration: Theme.animTransition; easing.type: Theme.animCurve } }
                    Behavior on width { enabled: !Theme.reducedMotion; NumberAnimation { duration: Theme.animTransition; easing.type: Theme.animCurve } }
                    Behavior on height { enabled: !Theme.reducedMotion; NumberAnimation { duration: Theme.animTransition; easing.type: Theme.animCurve } }
                    Behavior on border.color { ColorAnimation { duration: 160 } }

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -4
                        radius: 11
                        color: "transparent"
                        border.width: 2
                        border.color: Theme.palette.green
                        visible: tile.isNew
                        SequentialAnimation on opacity {
                            running: tile.isNew && Theme.ambientMotion
                            loops: Animation.Infinite
                            NumberAnimation { from: 0.15; to: 0.8; duration: 900; easing.type: Easing.InOutSine }
                            NumberAnimation { from: 0.8; to: 0.15; duration: 900; easing.type: Easing.InOutSine }
                        }
                    }

                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: tile.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        property point start
                        property real sx: 0
                        property real sy: 0
                        property bool moved: false
                        onPressed: function (m) {
                            root.selected = tile.desc
                            if (tile.isNew) DisplayService.newcomer = ""
                            keys.forceActiveFocus()
                            start = mapToItem(canvas, m.x, m.y)
                            sx = tile.o.x; sy = tile.o.y
                            moved = false
                        }
                        onPositionChanged: function (m) {
                            if (!pressed) return
                            var p = mapToItem(canvas, m.x, m.y)
                            p = Qt.point(Math.max(0, Math.min(canvas.width, p.x)),
                                         Math.max(0, Math.min(canvas.height, p.y)))
                            if (!moved && Math.hypot(p.x - start.x, p.y - start.y) < 4) return
                            if (!moved) {
                                moved = true
                                canvas.frozenK = canvas.liveK
                                canvas.frozenBox = canvas.bbox
                                canvas.frozen = true
                                canvas.dragDesc = tile.desc
                            }
                            tile.dragLX = sx + (p.x - start.x) / canvas.k
                            tile.dragLY = sy + (p.y - start.y) / canvas.k
                            canvas.preview = root.snap(tile.desc, tile.dragLX, tile.dragLY)
                        }
                        onReleased: {
                            if (moved) {
                                var t = canvas.preview
                                root.place(tile.desc, t ? t.x : tile.dragLX, t ? t.y : tile.dragLY)
                            }
                            canvas.dragDesc = ""
                            canvas.preview = null
                            canvas.frozen = false
                        }
                    }

                    Text {
                        id: star
                        anchors { left: parent.left; top: parent.top; margins: 6 }
                        text: String.fromCodePoint(tile.isPrimary ? 0xF04CE : 0xF04D2)
                        color: tile.isPrimary ? root.hue : Theme.text
                        opacity: tile.isPrimary ? 1 : (starHov.hovered ? 0.9 : (area.containsMouse ? 0.35 : 0))
                        Behavior on opacity { NumberAnimation { duration: 140 } }
                        font.family: Theme.iconFont
                        font.pixelSize: 13
                        HoverHandler { id: starHov; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: { root.makePrimary(tile.desc); root.selected = tile.desc } }
                    }

                    Rectangle {
                        anchors { right: parent.right; top: parent.top; margins: 5 }
                        width: 18; height: 18; radius: 9
                        color: root.hue
                        opacity: DisplayService.identifying ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 160 } }
                        Text {
                            anchors.centerIn: parent
                            text: root.order.indexOf(tile.desc) + 1
                            color: Theme.ground
                            font.family: Theme.fontText; font.pixelSize: 11; font.weight: Font.Bold
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -6
                        spacing: 2
                        width: parent.width - 14
                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: tile.mon ? DisplayService.shortName(tile.mon) : tile.desc
                            color: Theme.text; opacity: 0.9
                            wrapMode: Text.WrapAnywhere
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            font.family: Theme.fontText; font.pixelSize: 11; font.weight: Font.Medium
                        }
                        Text {
                            width: parent.width
                            visible: tile.height > 70
                            horizontalAlignment: Text.AlignHCenter
                            text: tile.o.mode.split("@")[0].replace("x", "×") + " · "
                                  + Math.round(+tile.o.mode.split("@")[1]) + " Hz"
                                  + (tile.o.scale !== 1 ? " · " + tile.o.scale + "×" : "")
                            color: Theme.text; opacity: 0.45
                            elide: Text.ElideRight
                            font.family: Theme.fontMono; font.pixelSize: 9
                        }
                    }

                    Row {
                        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 6 }
                        spacing: 4
                        Keycap {
                            visible: tile.isPrimary
                            label: "1–8"
                        }
                        Keycap {
                            visible: !tile.isPrimary && tile.slot !== ""
                            label: DisplayService.auxKeys[tile.slot] || ""
                            clickable: Object.keys(root.slots).length > 1
                            onClicked: root.swapKey(tile.desc)
                        }
                    }
                }
            }

            Row {
                anchors { left: parent.left; bottom: parent.bottom; margins: 8 }
                spacing: 6
                Repeater {
                    model: root.unplacedDescs
                    delegate: Rectangle {
                        id: offChip
                        required property string modelData
                        readonly property var o: root.out(modelData)
                        width: offRow.implicitWidth + 16; height: 22; radius: 11
                        color: root.selected === modelData ? Theme.withAlpha(root.hue, 0.2) : Qt.rgba(1, 1, 1, 0.05)
                        Row {
                            id: offRow
                            anchors.centerIn: parent
                            spacing: 5
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: String.fromCodePoint(offChip.o.disabled ? 0xF0379 : 0xF0E67)
                                color: Theme.text; opacity: 0.5
                                font.family: Theme.iconFont; font.pixelSize: 11
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.labelOf(offChip.modelData)
                                      + (offChip.o.disabled ? " · off" : " · mirror of " + root.labelOf(offChip.o.mirror))
                                color: Theme.text; opacity: 0.6
                                font.family: Theme.fontText; font.pixelSize: 11
                            }
                        }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: root.selected = offChip.modelData }
                    }
                }
            }
        }

        Rectangle {
            id: card
            width: parent.width
            height: 148
            radius: 12
            color: Theme.surfaceRecess
            readonly property string d: root.selected
            readonly property var o: root.out(d)
            readonly property bool isPrimary: root.draft !== null && root.draft.primary === d

            Item {
                id: cardHead
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14; bottomMargin: 0 }
                height: 22
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.labelOf(card.d)
                        color: Theme.text
                        font.family: Theme.fontText; font.pixelSize: 13; font.weight: Font.Medium
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        readonly property var m: root.monitorOf(card.d)
                        text: m ? m.name : ""
                        color: Theme.text; opacity: 0.4
                        font.family: Theme.fontMono; font.pixelSize: 10
                    }
                }
                Chip {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    visible: card.isPrimary
                    glyph: String.fromCodePoint(0xF04CE)
                    label: "Primary · bar and desktops 1–8"
                    tint: root.hue
                }
                Button_ {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    visible: !card.isPrimary
                    enabled: root.placed(card.d)
                    height: 22
                    glyph: String.fromCodePoint(0xF04D2)
                    label: "Make primary"
                    onClicked: root.makePrimary(card.d)
                }
            }

            Row {
                anchors { left: parent.left; right: parent.right; top: cardHead.bottom; topMargin: 8
                          leftMargin: 14; rightMargin: 14 }
                spacing: 24
                readonly property real colW: (width - spacing) / 2

                Column {
                    width: parent.colW
                    Setting {
                        name: "Resolution"
                        Drop {
                            items: root.resolutionsOf(card.d).map(r => ({ key: r, label: r.replace("x", " × ") }))
                            current: root.resOf(card.d)
                            onPicked: function (k) {
                                var rates = root.ratesOf(card.d, k)
                                root.setField(card.d, "mode", k + "@" + (rates.length ? rates[0] : "60.00"))
                            }
                        }
                    }
                    Setting {
                        name: "Refresh"
                        Segmented {
                            hue: root.hue
                            segWidth: 38
                            options: root.ratesOf(card.d, root.resOf(card.d)).map(r => ({ key: r, label: String(Math.round(+r)) }))
                            current: {
                                var cur = +root.rateOf(card.d)
                                var opts = root.ratesOf(card.d, root.resOf(card.d))
                                var hit = opts.find(r => Math.abs(r - cur) < 0.2)
                                return hit || ""
                            }
                            onPicked: function (k) { root.setField(card.d, "mode", root.resOf(card.d) + "@" + k) }
                        }
                    }
                    Setting {
                        name: "Scale"
                        Segmented {
                            hue: root.hue
                            segWidth: 38
                            options: [{ key: "1", label: "1" }, { key: "1.25", label: "1.25" },
                                      { key: "1.5", label: "1.5" }, { key: "2", label: "2" }]
                            current: card.o ? String(card.o.scale) : ""
                            onPicked: function (k) { root.setField(card.d, "scale", +k) }
                        }
                    }
                }
                Column {
                    width: parent.colW
                    Setting {
                        name: "Rotation"
                        Segmented {
                            hue: root.hue
                            segWidth: 38
                            options: [{ key: "0", label: "0°" }, { key: "1", label: "90°" },
                                      { key: "2", label: "180°" }, { key: "3", label: "270°" }]
                            current: card.o ? String(card.o.transform % 4) : ""
                            onPicked: function (k) { root.setField(card.d, "transform", +k) }
                        }
                    }
                    Setting {
                        name: "Adaptive · VRR"
                        Row {
                            spacing: 10
                            Toggle {
                                hue: root.hue
                                on: card.o ? !card.o.disabled : false
                                enabled: !(card.o && !card.o.disabled && root.placedDescs.length <= 1)
                                onFlipped: root.setField(card.d, "disabled", !card.o.disabled)
                            }
                            Toggle {
                                hue: root.hue
                                on: card.o ? !!card.o.vrr : false
                                enabled: card.o ? !card.o.disabled : false
                                onFlipped: root.setField(card.d, "vrr", !card.o.vrr)
                            }
                        }
                    }
                    Setting {
                        name: "Mirror of"
                        Drop {
                            items: [{ key: "none", label: "None" }].concat(
                                root.placedDescs.filter(x => x !== card.d).map(x => ({ key: x, label: root.labelOf(x) })))
                            current: card.o ? (card.o.mirror || "none") : "none"
                            onPicked: function (k) {
                                root.setField(card.d, "mirror", k)
                                if (k === "none") root.resettle(card.d)
                            }
                        }
                    }
                }
            }
        }

        Item {
            width: parent.width
            height: 30

            Item {
                anchors.fill: parent
                visible: !DisplayService.confirmPending
                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    width: parent.width - actions.width - 16
                    elide: Text.ElideRight
                    text: root.dirty ? "Unapplied changes · Enter applies · Esc discards"
                          : root.unsaved ? "New displays · Save remembers this layout"
                          : "Drag to place · ★ primary · click a key to swap"
                    color: root.dirty || root.unsaved ? Theme.palette.yellow : Theme.text
                    opacity: root.dirty || root.unsaved ? 0.9 : 0.4
                    font.family: Theme.fontText; font.pixelSize: 11
                }
                Row {
                    id: actions
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: 8
                    Button_ {
                        label: "Discard"
                        enabled: root.dirty
                        onClicked: root.load()
                    }
                    Button_ {
                        primary: true
                        glyph: String.fromCodePoint(0xF012C)
                        label: root.dirty || !root.unsaved ? "Apply" : "Save"
                        enabled: root.dirty || root.unsaved
                        onClicked: root.applyDraft()
                    }
                }
            }

            Item {
                anchors.fill: parent
                visible: DisplayService.confirmPending
                Text {
                    id: askText
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    text: "Keep this configuration?  "
                          + Math.ceil(DisplayService.confirmLeft * DisplayService.confirmSeconds) + " s"
                    color: Theme.text
                    font.family: Theme.fontText; font.pixelSize: 12; font.weight: Font.Medium
                }
                Rectangle {
                    anchors { left: askText.right; leftMargin: 12; right: keepRow.left; rightMargin: 14
                              verticalCenter: parent.verticalCenter }
                    height: 4; radius: 2
                    color: Qt.rgba(1, 1, 1, 0.06)
                    Rectangle {
                        width: parent.width * DisplayService.confirmLeft
                        height: parent.height; radius: 2
                        color: Theme.palette.yellow
                    }
                }
                Row {
                    id: keepRow
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: 8
                    Button_ { label: "Revert"; onClicked: DisplayService.revert() }
                    Button_ { primary: true; label: "Keep"; onClicked: DisplayService.confirm() }
                }
            }
        }
    }

    Item {
        id: dropLayer
        anchors.fill: parent
        z: 100
        property var owner: null
        visible: owner !== null

        function toggle(d) { owner = (owner === d) ? null : d }

        MouseArea { anchors.fill: parent; onPressed: dropLayer.owner = null }

        Rectangle {
            id: list
            readonly property var p: dropLayer.owner ? dropLayer.owner.mapToItem(dropLayer, 0, 0) : Qt.point(0, 0)
            readonly property int rows: dropLayer.owner ? Math.min(8, dropLayer.owner.items.length) : 0
            x: p.x
            width: dropLayer.owner ? Math.max(dropLayer.owner.width, 150) : 0
            height: rows * 26 + 8
            y: Math.max(0, p.y - height - 4)
            radius: 10
            color: Theme.palette.bg3
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.06)

            ListView {
                anchors.fill: parent
                anchors.margins: 4
                clip: true
                model: dropLayer.owner ? dropLayer.owner.items : []
                boundsBehavior: Flickable.StopAtBounds
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    readonly property bool cur: dropLayer.owner && dropLayer.owner.current === modelData.key
                    width: ListView.view.width
                    height: 26
                    radius: 6
                    color: rHov.hovered ? Qt.rgba(1, 1, 1, 0.07) : "transparent"
                    Text {
                        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                        text: row.modelData.label
                        color: row.cur ? root.hue : Theme.text
                        opacity: row.cur ? 1 : 0.85
                        font.family: Theme.fontText; font.pixelSize: 12
                    }
                    HoverHandler { id: rHov; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: {
                            var o = dropLayer.owner
                            dropLayer.owner = null
                            if (o) o.picked(row.modelData.key)
                        }
                    }
                }
            }
        }
    }
}
