import Quickshell
import Quickshell.Io
import QtQuick
import Quickshell.Wayland
import "../shapes"
import "../components"
import "../theme"
import "../state"
import "../services"

Item {
    id: root
    readonly property bool open: Popups.soundboardOpen
    readonly property int headShift: 18
    readonly property real panelW: popupWidth - fw
    readonly property real panelH: popupHeight - fh - Theme.borderWidth + headShift
    visible: open || hold.running
    onOpenChanged: if (!open) hold.restart()
    Timer { id: hold; interval: Theme.animTransition + 40 }

    readonly property int fw: Theme.borderWidth + Theme.cornerRadius
    readonly property int fh: Theme.borderWidth + Theme.cornerRadius

    readonly property int padLeft:  fw * 2 + Theme.borderWidth
    readonly property int padRight: fw
    readonly property int padTop:   fh + 8
    readonly property int padBot:   fh + 8

    readonly property int popupWidth: Math.max(384, BarGeometry.rightMinPanelWidth)

    readonly property int rowHeight: 50
    readonly property int cardPad:   12
    readonly property int gap:       10
    readonly property int headerH:   12
    readonly property int addH:      26
    readonly property int barH:       8
    readonly property int noteGap:    6
    readonly property int noteH:     13

    readonly property int rowCount: SoundboardService.items.length
    readonly property int contentHeight:
        headerH + gap
        + (rowCount * rowHeight + cardPad) + gap
        + addH + gap
        + headerH + gap
        + barH + noteGap + noteH

    readonly property int webContentHeight: 600
    readonly property int popupHeight: padTop + padBot
        + (page === "web" ? Math.max(contentHeight, webContentHeight) : contentHeight)

    property string page: "list"
    property string webFrom: "list"

    function openWeb(from) {
        root.webFrom = from
        if (from !== "files") root.pendingId = ""
        root.page = "web"
        SoundboardService.refreshFiles()
        if (SoundboardService.webPage === 0 && !SoundboardService.webLoading)
            SoundboardService.webSearch(webSearchInput.text)
        Qt.callLater(function () { webSearchInput.forceActiveFocus() })
    }
    property string pendingId: ""

    IpcHandler {
        target: "soundboard-toggle"
        function toggle() {
            var next = !Popups.soundboardOpen
            Popups.closeAll()
            Popups.soundboardOpen = next
        }
    }

    Connections {
        target: Popups
        function onSoundboardOpenChanged() {
            if (Popups.soundboardOpen) {
                closeTimer.stop()
                {}
                root.page = "list"
                root.pendingId = ""
                SoundboardService.refreshFiles()
                SoundboardService.refreshStatus()
            } else {
                closeTimer.restart()
            }
        }
    }
    Timer {
        id: closeTimer
        interval: Theme.durationBase + 20
        onTriggered: if (!Popups.soundboardOpen) {}
    }

    Item {
        id: sizer
        x: -root.fw
        y: -Theme.borderWidth + root.headShift
        width: root.popupWidth
        height: root.popupHeight

        Keys.onEscapePressed: {
            if (root.page === "list") Popups.soundboardOpen = false
            else if (root.page === "web") root.page = root.webFrom
            else root.page = "list"
        }

        Item {
            id: stack
            anchors {
                fill: parent
                topMargin: root.padTop
                bottomMargin: root.padBot
                leftMargin: root.padLeft
                rightMargin: root.padRight
            }

            opacity: Popups.soundboardOpen ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.durationBase * 0.5 } }

            Column {
                id: listPage
                width: parent.width
                spacing: 10
                visible: opacity > 0
                opacity: root.page === "list" ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 140 } }

                SectionHeader {
                    width: parent.width
                    label: "Keys"

                    Text {
                        visible: !SoundboardService.micReady
                        text: "󰀦 virtual mic is down"
                        color: Theme.statusWarn
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.fsMicro
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Card {
                    width: parent.width
                    implicitHeight: rows.implicitHeight + 12
                    height: implicitHeight
                    surface: Theme.surfaceWell

                    Column {
                        id: rows
                        anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 6 }

                        Repeater {
                            model: SoundboardService.items
                            delegate: KeyRow {
                                width: rows.width
                                entry: modelData
                                lastRow: index === SoundboardService.items.length - 1
                            }
                        }
                    }
                }

                Row {
                    width: parent.width
                    height: root.addH
                    spacing: 8

                    PillButton {
                        glyph: "󰐕"
                        label: "ADD KEY"
                        onActivated: {
                            capture.reset()
                            root.page = "capture"
                            capture.forceActiveFocus()
                        }
                    }
                    PillButton {
                        glyph: "󰝚"
                        label: "MYINSTANTS"
                        onActivated: root.openWeb("list")
                    }
                }

                SectionHeader {
                    width: parent.width
                    label: "Sound volume"

                    Text {
                        text: SoundboardService.masterVolume + "%"
                        color: Theme.text
                        opacity: 0.75
                        font.family: Theme.fontText
                        font.pixelSize: Theme.fsBody
                        font.features: Theme.tabularNums
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Column {
                    width: parent.width
                    spacing: 6

                    VolumeBar {
                        width: parent.width
                        height: 8
                        value: SoundboardService.masterVolume
                        maxValue: 150
                        onChanged: function (v) { SoundboardService.setMaster(v) }
                    }

                    Text {
                        width: parent.width
                        height: root.noteH
                        verticalAlignment: Text.AlignVCenter
                        text: "Sounds only. Your voice is untouched."
                        color: Theme.text
                        opacity: 0.42
                        font.family: Theme.fontText
                        font.pixelSize: Theme.fsMicro
                    }
                }
            }

            Item {
                anchors.fill: parent
                visible: opacity > 0
                opacity: root.page === "files" ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 140 } }

                SectionHeader {
                    id: filesHeader
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    label: "Sound for " + root.pendingLabel
                }

                PopupPage {
                    anchors {
                        left: parent.left; right: parent.right
                        top: filesHeader.bottom; topMargin: 8
                        bottom: filesFoot.top; bottomMargin: 8
                    }
                    padH: 0

                    Repeater {
                        model: SoundboardService.files
                        delegate: FileRow {
                            width: parent.width
                            file: modelData.file
                            name: modelData.name
                            source: modelData.source
                        }
                    }

                    Text {
                        visible: SoundboardService.files.length === 0
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: "No sounds in ~/.local/share/soundboard, "
                              + "Downloads or Music.\n"
                              + "Drop an mp3 there and reopen the panel."
                        color: Theme.text
                        opacity: 0.45
                        font.family: Theme.fontText
                        font.pixelSize: Theme.fsBody
                    }
                }

                Row {
                    id: filesFoot
                    anchors { left: parent.left; bottom: parent.bottom }
                    spacing: 8

                    FlatButton {
                        label: "BACK"
                        onActivated: root.page = "list"
                    }
                    FlatButton {
                        label: "MYINSTANTS"
                        onActivated: root.openWeb("files")
                    }
                    FlatButton {
                        label: "REMOVE SOUND"
                        visible: root.pendingHasFile
                        onActivated: {
                            SoundboardService.setFile(root.pendingId, "")
                            root.page = "list"
                        }
                    }
                }
            }

            Item {
                id: webPage
                anchors.fill: parent
                visible: opacity > 0
                opacity: root.page === "web" ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 140 } }

                SectionHeader {
                    id: webHeader
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    label: root.webFrom === "files" ? "myinstants → " + root.pendingLabel
                                                    : "myinstants"

                    Text {
                        visible: SoundboardService.webItems.length > 0
                        text: SoundboardService.webItems.length
                              + (SoundboardService.webMore ? "+" : "")
                        color: Theme.text
                        opacity: 0.45
                        font.family: Theme.fontText
                        font.pixelSize: Theme.fsMicro
                        font.features: Theme.tabularNums
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Rectangle {
                    id: webSearch
                    anchors { left: parent.left; right: parent.right; top: webHeader.bottom; topMargin: 10 }
                    height: 30
                    radius: 7
                    color: Theme.surfaceWell
                    border.width: 1
                    border.color: webSearchInput.activeFocus ? Theme.withAlpha(Theme.accent, 0.5)
                                                             : Theme.grooveDark
                    Behavior on border.color { ColorAnimation { duration: 140 } }

                    Text {
                        id: webLens
                        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                        text: "󰍉"
                        color: webSearchInput.activeFocus ? Theme.accent : Theme.text
                        opacity: webSearchInput.activeFocus ? 0.9 : 0.45
                        font.family: Theme.iconFont
                        font.pixelSize: 12
                    }

                    Text {
                        anchors { left: webSearchInput.left; verticalCenter: parent.verticalCenter }
                        visible: webSearchInput.text === ""
                        text: "Search sounds…  (empty = most played)"
                        color: Theme.text
                        opacity: 0.3
                        font.family: Theme.fontText
                        font.pixelSize: Theme.fsBody
                    }

                    TextInput {
                        id: webSearchInput
                        anchors {
                            left: webLens.right; leftMargin: 8
                            right: webSpinner.left; rightMargin: 8
                            top: parent.top; bottom: parent.bottom
                        }
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true
                        color: Theme.text
                        selectionColor: Theme.withAlpha(Theme.accent, 0.35)
                        font.family: Theme.fontText
                        font.pixelSize: Theme.fsBody
                        Keys.onReturnPressed: SoundboardService.webSearch(text)
                        Keys.onEnterPressed:  SoundboardService.webSearch(text)
                    }

                    Text {
                        id: webSpinner
                        anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                        text: "󰝲"
                        color: Theme.accent
                        opacity: SoundboardService.webLoading ? 0.9 : 0
                        font.family: Theme.iconFont
                        font.pixelSize: 12
                        Behavior on opacity { NumberAnimation { duration: 140 } }
                        RotationAnimation on rotation {
                            running: SoundboardService.webLoading && webPage.visible
                            from: 0; to: 360; duration: 900
                            loops: Animation.Infinite
                        }
                    }
                }

                Card {
                    anchors {
                        left: parent.left; right: parent.right
                        top: webSearch.bottom; topMargin: 10
                        bottom: webFoot.top; bottomMargin: 10
                    }
                    surface: Theme.surfaceWell

                    PopupPage {
                        anchors.fill: parent
                        padH: 4
                        padV: 6

                        Repeater {
                            model: SoundboardService.webItems
                            delegate: WebRow {
                                width: parent.width
                                item: modelData
                            }
                        }

                        FlatButton {
                            visible: SoundboardService.webMore
                            anchors.horizontalCenter: parent.horizontalCenter
                            label: SoundboardService.webLoading ? "LOADING…" : "LOAD MORE"
                            enabled: !SoundboardService.webLoading
                            onActivated: SoundboardService.webNext()
                        }

                        Text {
                            visible: !SoundboardService.webLoading
                                     && SoundboardService.webItems.length === 0
                            width: parent.width
                            topPadding: 8
                            leftPadding: 8
                            rightPadding: 8
                            wrapMode: Text.WordWrap
                            text: SoundboardService.webError !== ""
                                  ? SoundboardService.webError
                                  : (SoundboardService.webQuery !== ""
                                     ? "Nothing for «" + SoundboardService.webQuery + "»."
                                     : "")
                            color: SoundboardService.webError !== "" ? Theme.statusWarn : Theme.text
                            opacity: SoundboardService.webError !== "" ? 0.9 : 0.45
                            font.family: Theme.fontText
                            font.pixelSize: Theme.fsBody
                        }
                    }
                }

                Row {
                    id: webFoot
                    anchors { left: parent.left; bottom: parent.bottom }
                    spacing: 8

                    FlatButton {
                        label: "BACK"
                        onActivated: root.page = root.webFrom
                    }
                    FlatButton {
                        label: "STOP"
                        visible: SoundboardService.hearing !== ""
                        onActivated: SoundboardService.stopAll()
                    }
                }

                Text {
                    anchors { right: parent.right; verticalCenter: webFoot.verticalCenter }
                    text: "Listen only plays in your headphones"
                    color: Theme.text
                    opacity: 0.38
                    font.family: Theme.fontText
                    font.pixelSize: Theme.fsMicro
                }
            }

            FocusScope {
                id: capture
                anchors.fill: parent
                visible: opacity > 0
                opacity: root.page === "capture" ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 140 } }

                property string spec: ""
                property string pretty: ""
                property bool taken: false

                function reset() { spec = ""; pretty = ""; taken = false }

                Keys.onPressed: function (event) {
                    event.accepted = true
                    if (event.key === Qt.Key_Escape) { root.page = "list"; return }

                    if (event.key === Qt.Key_Super_L || event.key === Qt.Key_Super_R
                        || event.key === Qt.Key_Control || event.key === Qt.Key_Shift
                        || event.key === Qt.Key_Alt || event.key === Qt.Key_AltGr
                        || event.key === Qt.Key_Meta) return

                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (capture.spec !== "" && !capture.taken) {
                            SoundboardService.addKey(capture.spec, capture.pretty)
                            root.page = "list"
                        }
                        return
                    }

                    var mods = []
                    if (event.modifiers & Qt.MetaModifier)    mods.push("SUPER")
                    if (event.modifiers & Qt.ControlModifier) mods.push("CTRL")
                    if (event.modifiers & Qt.AltModifier)     mods.push("ALT")
                    if (event.modifiers & Qt.ShiftModifier)   mods.push("SHIFT")

                    var code = "code:" + event.nativeScanCode
                    var prefix = mods.length ? mods.join(" + ") + " + " : ""
                    capture.spec = prefix + code

                    var t = event.text
                    var human = (t && t.length === 1 && t.charCodeAt(0) >= 33)
                                    ? t.toUpperCase() : code
                    capture.pretty = prefix + human
                    capture.taken = SoundboardService.keyTaken(capture.spec)
                }

                Column {
                    anchors.centerIn: parent
                    width: parent.width
                    spacing: 12

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "󰌌"
                        color: Theme.accent
                        opacity: 0.8
                        font.family: Theme.iconFont
                        font.pixelSize: 30
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: capture.spec === "" ? "Press the combination" : capture.pretty
                        color: capture.taken ? Theme.statusWarn : Theme.text
                        font.family: Theme.fontText
                        font.pixelSize: Theme.fsTitle
                    }

                    Text {
                        visible: capture.spec !== ""
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: capture.spec
                        color: Theme.text
                        opacity: 0.4
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fsMicro
                        font.letterSpacing: 0.6
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width - 20
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        color: Theme.text
                        opacity: 0.45
                        font.family: Theme.fontText
                        font.pixelSize: Theme.fsMicro
                        text: capture.taken
                                ? "Another pad key already uses that combination."
                                : (capture.spec === ""
                                    ? "If nothing shows up when you press it, Hyprland already owns that combination."
                                    : "Enter saves it, Esc cancels.")
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 8

                        FlatButton {
                            label: "CANCEL"
                            onActivated: root.page = "list"
                        }
                        FlatButton {
                            label: "SAVE"
                            enabled: capture.spec !== "" && !capture.taken
                            onActivated: {
                                SoundboardService.addKey(capture.spec, capture.pretty)
                                root.page = "list"
                            }
                        }
                    }
                }
            }
        }
    }

    readonly property var pendingEntry: {
        var v = SoundboardService.items
        for (var i = 0; i < v.length; i++) if (v[i].id === root.pendingId) return v[i]
        return null
    }
    readonly property string pendingLabel: pendingEntry ? pendingEntry.label : ""
    readonly property bool pendingHasFile: pendingEntry ? (pendingEntry.file || "") !== "" : false

    component KeyRow: Item {
        id: krow
        property var entry
        property bool lastRow: false

        readonly property bool hasFile: (entry.file || "") !== ""
        readonly property bool playingThis: SoundboardService.playing === entry.id

        implicitHeight: root.rowHeight
        height: root.rowHeight

        HoverHandler { id: rowHov }

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: 4
            anchors.rightMargin: 4
            radius: 6
            color: rowHov.hovered ? Theme.withAlpha(Theme.accent, 0.07)
                 : krow.playingThis ? Theme.withAlpha(Theme.accent, 0.05) : "transparent"
            Behavior on color { ColorAnimation { duration: 140 } }
        }

        Rectangle {
            id: chip
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(30, chipText.implicitWidth + 12)
            height: 20
            radius: 5
            color: Theme.surfaceSunk
            border.width: 1
            border.color: Theme.grooveDark

            Text {
                id: chipText
                anchors.centerIn: parent
                text: krow.entry.label
                color: krow.hasFile ? Theme.accent : Theme.text
                opacity: krow.hasFile ? 0.95 : 0.55
                font.family: Theme.fontText
                font.pixelSize: Theme.fsSection
                font.letterSpacing: Theme.trSection
            }
        }

        Text {
            id: nameText
            anchors {
                left: chip.right; leftMargin: 12
                right: actions.left; rightMargin: 10
                verticalCenter: parent.verticalCenter
                verticalCenterOffset: krow.hasFile ? -8 : 0
            }
            elide: Text.ElideRight
            text: krow.hasFile ? krow.entry.file.slice(krow.entry.file.lastIndexOf("/") + 1)
                               : "no sound"
            color: Theme.text
            opacity: krow.hasFile ? 0.85 : 0.38
            font.family: Theme.fontText
            font.pixelSize: Theme.fsBody
        }

        Row {
            id: actions
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            IconButton {
                glyph: krow.playingThis ? "󰓛" : "󰐊"
                enabled: krow.hasFile
                tip: krow.playingThis ? "Stop" : "Test"
                onActivated: SoundboardService.preview(krow.entry.id)
            }
            IconButton {
                glyph: "󰅖"
                visible: krow.entry.fixed !== true
                tip: "Remove key"
                onActivated: SoundboardService.remove(krow.entry.id)
            }
        }

        MouseArea {
            anchors { left: parent.left; right: actions.left; top: parent.top; bottom: parent.bottom }
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.pendingId = krow.entry.id
                SoundboardService.refreshFiles()
                root.page = "files"
            }
        }

        Item {
            id: vol
            visible: krow.hasFile
            anchors {
                left: nameText.left
                right: nameText.right
                verticalCenter: parent.verticalCenter
                verticalCenterOffset: 9
            }
            height: 12

            property real draft: -1
            readonly property real shown: draft >= 0 ? draft : (krow.entry.volume === undefined ? 100 : krow.entry.volume)

            VolumeBar {
                anchors { left: parent.left; right: volPct.left; rightMargin: 8; top: parent.top; bottom: parent.bottom }
                trackHeight: 4
                value: vol.shown
                maxValue: 200
                onChanged: function (v) { vol.draft = v }
                onCommitted: function (v) {
                    vol.draft = -1
                    SoundboardService.setVolume(krow.entry.id, v)
                }
            }

            Text {
                id: volPct
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                horizontalAlignment: Text.AlignRight
                text: Math.round(vol.shown) + "%"
                color: vol.shown > 100 ? Qt.rgba(1, 0.67, 0.25, 1) : Theme.text
                opacity: pctHov.hovered ? 1 : 0.6
                font.family: Theme.fontText
                font.pixelSize: Theme.fsMicro
                font.features: Theme.tabularNums

                HoverHandler { id: pctHov }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: SoundboardService.setVolume(krow.entry.id, 100)
                }
            }
        }

        Rule {
            visible: !krow.lastRow
            groove: true
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            fade: 0.10
        }
    }

    component FileRow: Item {
        id: frow
        property string file: ""
        property string name: ""
        property string source: ""
        readonly property bool current: root.pendingEntry
                                        && root.pendingEntry.file === frow.file

        implicitHeight: 30
        height: 30

        HoverHandler { id: fHov }

        Rectangle {
            anchors.fill: parent
            radius: 6
            color: fHov.hovered ? Theme.withAlpha(Theme.accent, 0.12)
                                : (frow.current ? Theme.withAlpha(Theme.accent, 0.06) : "transparent")
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: frow.current ? "󰓃" : "󰝰"
            color: frow.current ? Theme.accent : Theme.text
            opacity: frow.current ? 1 : 0.4
            font.family: Theme.iconFont
            font.pixelSize: 12
        }

        Text {
            anchors {
                left: parent.left; leftMargin: 30
                right: originTag.visible ? originTag.left : parent.right
                rightMargin: 10
                verticalCenter: parent.verticalCenter
            }
            elide: Text.ElideRight
            text: frow.name
            color: frow.current ? Theme.accent : Theme.text
            opacity: frow.current ? 1 : 0.8
            font.family: Theme.fontText
            font.pixelSize: Theme.fsBody
        }

        Text {
            id: originTag
            visible: frow.source !== "" && frow.source !== "soundboard"
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: frow.source === "music" ? "MUSIC" : "DOWNLOADS"
            color: Theme.text
            opacity: 0.38
            font.family: Theme.fontText
            font.pixelSize: Theme.fsMicro
            font.letterSpacing: 1
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                SoundboardService.setFile(root.pendingId, frow.file)
                root.page = "list"
            }
        }
    }

    component WebRow: Item {
        id: wrow
        property var item

        readonly property bool owned:       SoundboardService.hasOwnFile(item.file)
        readonly property bool busy:        SoundboardService.downloading[item.url] === true
        readonly property bool hearingThis: SoundboardService.hearing === item.url
        readonly property bool forKey:      root.webFrom === "files" && root.pendingId !== ""
        readonly property bool current:     forKey && root.pendingEntry
                                            && root.pendingEntry.file === item.file

        property bool useWhenReady: false
        onOwnedChanged: if (owned && useWhenReady) use()

        function use() {
            useWhenReady = false
            SoundboardService.setFile(root.pendingId, item.file)
            root.page = "list"
        }

        implicitHeight: 34
        height: 34

        HoverHandler { id: wHov }

        Rectangle {
            anchors.fill: parent
            radius: 6
            color: wHov.hovered ? Theme.withAlpha(Theme.accent, 0.10)
                                : (wrow.hearingThis ? Theme.withAlpha(Theme.accent, 0.06) : "transparent")
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        IconButton {
            id: hearBtn
            anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
            glyph: wrow.hearingThis ? "󰓛" : "󰐊"
            tip: wrow.hearingThis ? "Stop" : "Listen"
            onActivated: wrow.hearingThis ? SoundboardService.stopAll()
                                          : SoundboardService.hear(wrow.item.url)
        }

        Text {
            anchors {
                left: hearBtn.right; leftMargin: 8
                right: wActions.left; rightMargin: 8
                verticalCenter: parent.verticalCenter
            }
            elide: Text.ElideRight
            text: wrow.item.name
            color: wrow.current || wrow.hearingThis ? Theme.accent : Theme.text
            opacity: wrow.owned || wrow.hearingThis ? 0.95 : 0.78
            font.family: Theme.fontText
            font.pixelSize: Theme.fsBody
        }

        Row {
            id: wActions
            anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
            spacing: 6

            Text {
                visible: wrow.owned && !wrow.forKey
                anchors.verticalCenter: parent.verticalCenter
                width: 22
                horizontalAlignment: Text.AlignHCenter
                text: "󰄬"
                color: Theme.accent
                opacity: 0.85
                font.family: Theme.iconFont
                font.pixelSize: 12
            }

            Text {
                visible: wrow.busy
                anchors.verticalCenter: parent.verticalCenter
                width: 22
                horizontalAlignment: Text.AlignHCenter
                text: "󰝲"
                color: Theme.accent
                font.family: Theme.iconFont
                font.pixelSize: 12
                RotationAnimation on rotation {
                    running: wrow.busy
                    from: 0; to: 360; duration: 900
                    loops: Animation.Infinite
                }
            }

            IconButton {
                visible: !wrow.owned && !wrow.busy
                glyph: "󰇚"
                tip: "Download"
                onActivated: SoundboardService.download(wrow.item.url)
            }

            FlatButton {
                visible: wrow.forKey
                enabled: !wrow.current
                label: wrow.current ? "SET" : "USE"
                onActivated: {
                    if (wrow.owned) wrow.use()
                    else {
                        wrow.useWhenReady = true
                        SoundboardService.download(wrow.item.url)
                    }
                }
            }
        }
    }

    component PillButton: Rectangle {
        id: pb
        property string glyph: ""
        property string label: ""
        signal activated()

        width: pbRow.implicitWidth + 20
        height: parent.height
        radius: 7
        color: pbHov.hovered ? Theme.withAlpha(Theme.accent, 0.14) : Theme.surfaceWell
        border.width: 1
        border.color: pbHov.hovered ? Theme.withAlpha(Theme.accent, 0.45) : Theme.grooveDark
        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on border.color { ColorAnimation { duration: 140 } }

        HoverHandler { id: pbHov }

        Row {
            id: pbRow
            anchors.centerIn: parent
            spacing: 7

            Text {
                text: pb.glyph
                color: pbHov.hovered ? Theme.accent : Theme.text
                opacity: pbHov.hovered ? 1 : 0.7
                font.family: Theme.iconFont
                font.pixelSize: 12
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: pb.label
                color: pbHov.hovered ? Theme.accent : Theme.text
                opacity: pbHov.hovered ? 1 : 0.7
                font.family: Theme.fontText
                font.pixelSize: Theme.fsSection
                font.letterSpacing: Theme.trSection
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: pb.activated()
        }
    }

    component IconButton: Item {
        id: ib
        property string glyph: ""
        property string tip: ""
        signal activated()

        implicitWidth: 22
        implicitHeight: 22
        width: 22
        height: 22
        opacity: enabled ? 1 : 0.3

        HoverHandler { id: ibHov; enabled: ib.enabled }

        Rectangle {
            anchors.fill: parent
            radius: 5
            color: ibHov.hovered ? Theme.withAlpha(Theme.accent, 0.18) : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        Text {
            anchors.centerIn: parent
            text: ib.glyph
            color: ibHov.hovered ? Theme.accent : Theme.text
            opacity: ibHov.hovered ? 1 : 0.6
            font.family: Theme.iconFont
            font.pixelSize: 12
        }

        MouseArea {
            anchors.fill: parent
            enabled: ib.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: ib.activated()
        }
    }

    component FlatButton: Item {
        id: fb
        property string label: ""
        signal activated()

        implicitWidth: fbText.implicitWidth + 20
        implicitHeight: 24
        width: implicitWidth
        height: 24
        opacity: enabled ? 1 : 0.35

        HoverHandler { id: fbHov; enabled: fb.enabled }

        Rectangle {
            anchors.fill: parent
            radius: 6
            color: fbHov.hovered ? Theme.withAlpha(Theme.accent, 0.14) : Theme.surfaceWell
            border.width: 1
            border.color: fbHov.hovered ? Theme.withAlpha(Theme.accent, 0.45) : Theme.grooveDark
            Behavior on color { ColorAnimation { duration: 140 } }
            Behavior on border.color { ColorAnimation { duration: 140 } }
        }

        Text {
            id: fbText
            anchors.centerIn: parent
            text: fb.label
            color: fbHov.hovered ? Theme.accent : Theme.text
            opacity: fbHov.hovered ? 1 : 0.7
            font.family: Theme.fontText
            font.pixelSize: Theme.fsSection
            font.letterSpacing: Theme.trSection
        }

        MouseArea {
            anchors.fill: parent
            enabled: fb.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: fb.activated()
        }
    }

    component VolumeBar: Item {
        id: bar
        implicitWidth: 100
        implicitHeight: 8
        property real value: 0
        property real maxValue: 150
        property real trackHeight: height
        signal changed(real v)
        signal committed(real v)

        readonly property real frac: maxValue > 0 ? Math.min(1, value / maxValue) : 0
        readonly property real unityFrac: maxValue > 0 ? Math.min(1, 100 / maxValue) : 1
        readonly property bool boosted: value > 100

        property real pulse: 0
        onValueChanged: pulseAnim.restart()
        SequentialAnimation {
            id: pulseAnim
            NumberAnimation { target: bar; property: "pulse"; to: 1; duration: 60;  easing.type: Easing.OutQuad }
            NumberAnimation { target: bar; property: "pulse"; to: 0; duration: 280; easing.type: Easing.OutQuad }
        }

        Rectangle {
            id: track
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
            height: bar.trackHeight
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.08)

            Rectangle {
                id: fill
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                width: Math.max(height, track.width * bar.frac)
                radius: height / 2
                color: bar.boosted ? Qt.rgba(1, 0.67, 0.25, 1) : Theme.accent
                Behavior on width { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 140 } }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "white"
                    opacity: bar.pulse * 0.30
                }
            }

            Rectangle {
                x: track.width * bar.unityFrac - width / 2
                width: 2
                height: parent.height
                color: Qt.rgba(0, 0, 0, 0.35)
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            function calc(mx) { return Math.max(0, Math.min(bar.maxValue, (mx / width) * bar.maxValue)) }
            onPressed: bar.changed(calc(mouseX))
            onPositionChanged: if (pressed) bar.changed(calc(mouseX))
            onReleased: bar.committed(calc(mouseX))
        }
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: function (event) {
                var delta = event.angleDelta.y > 0 ? 5 : -5
                var v = Math.max(0, Math.min(bar.maxValue, bar.value + delta))
                bar.changed(v)
                bar.committed(v)
            }
        }
    }
}
