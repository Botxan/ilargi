import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../shapes"
import "../state"
import "../services"
import "../theme"

PanelWindow {
    id: root
    screen: DisplayService.primaryScreen

    readonly property int panelWidth:  980
    readonly property int panelHeight: 420
    readonly property int r: Theme.cornerRadius
    readonly property bool open: Popups.wallpaperOpen

    anchors { left: true; right: true; bottom: true }
    implicitHeight: panelHeight + r + Theme.borderWidth + 4
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: true

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-wallpaper"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Item { id: noInput; width: 0; height: 0 }
    mask: Region { item: root.open ? notchArea : noInput }

    IpcHandler {
        target: "wallpaper-toggle"
        function toggle() {
            var next = !Popups.wallpaperOpen
            Popups.closeAll()
            Popups.wallpaperOpen = next
        }
    }

    property real notchWidth: open ? panelWidth + 2 * r : 0.001
    property real notchDepth: open ? panelHeight + r : 0.001
    Behavior on notchWidth { NumberAnimation { duration: Theme.animTransition; easing.type: Theme.animCurve } }
    Behavior on notchDepth { NumberAnimation { duration: Theme.animTransition; easing.type: Theme.animCurve } }

    NotchShape {
        edge: "bottom"
        notchWidth: root.notchWidth
        notchDepth: root.notchDepth
        flare: root.r
        radius: root.r
        x: Math.round(root.width / 2 - root.notchWidth / 2 - root.r)
        y: root.height - Theme.borderWidth - height
        visible: root.notchDepth > 0.5
    }

    Item {
        id: notchArea
        width: root.notchWidth
        height: root.notchDepth
        x: root.width / 2 - width / 2
        y: root.height - Theme.borderWidth - height
        clip: true

        MouseArea { anchors.fill: parent }

        Item {
            id: content
            focus: true
            anchors {
                bottom: parent.bottom
                bottomMargin: 8
                horizontalCenter: parent.horizontalCenter
            }
            width: root.panelWidth - 32
            height: root.panelHeight - 24

            property string searchQuery: ""
            property bool folderMode: false

            readonly property var filtered: {
                var q = searchQuery.toLowerCase()
                if (q === "") return WallpaperService.wallpapers
                return WallpaperService.wallpapers.filter(function (p) {
                    return p.split("/").pop().toLowerCase().indexOf(q) !== -1
                })
            }
            readonly property bool applyActive: WallpaperService.previewWall !== ""

            function step(d) {
                var walls = filtered
                if (!walls || walls.length === 0) return
                var idx = walls.indexOf(WallpaperService.previewWall)
                if (d > 0) idx = (idx < 0 || idx >= walls.length - 1) ? 0 : idx + 1
                else       idx = (idx <= 0) ? walls.length - 1 : idx - 1
                WallpaperService.previewWall = walls[idx]
                wallList.positionViewAtIndex(idx, ListView.Center)
            }
            function applyTarget(path) {
                WallpaperService.apply(path)
                Popups.wallpaperOpen = false
            }

            opacity: root.open ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: root.open ? Theme.animContentIn : Theme.animContentOut }
            }
            transform: Translate {
                y: root.open ? 0 : 40
                Behavior on y { NumberAnimation { duration: Theme.animTransition; easing.type: Theme.animCurve } }
            }

            ListView {
                id: wallList
                property int targetCenterIndex: -1
                onWidthChanged: if (root.open && targetCenterIndex !== -1 && count > targetCenterIndex)
                                    positionViewAtIndex(targetCenterIndex, ListView.Center)
                anchors { top: parent.top; left: parent.left; right: parent.right
                          bottom: divider.top; bottomMargin: 8 }
                orientation: ListView.Horizontal
                spacing: 14
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: false
                cacheBuffer: 400
                ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded; height: 6 }
                model: content.filtered

                Text {
                    anchors.centerIn: parent
                    visible: wallList.count === 0
                    text: "No wallpapers found in " + WallpaperService.wallpaperDir
                    color: Theme.withAlpha(Theme.text, 0.25)
                    font.family: Theme.fontText; font.pixelSize: 13
                }

                delegate: Item {
                    id: card
                    required property string modelData
                    required property int index
                    readonly property bool isPreview: WallpaperService.previewWall === modelData
                    readonly property bool isCurrent: WallpaperService.currentWall === modelData
                    readonly property int labelH: 30

                    width: isPreview ? 156 : 130
                    height: isPreview ? wallList.height : wallList.height - 14
                    Behavior on width { NumberAnimation { duration: Theme.animColor; easing.type: Theme.animCurve } }

                    Item {
                        id: cardContent
                        anchors.fill: parent
                        visible: false

                        Image {
                            id: img
                            anchors { left: parent.left; right: parent.right; top: parent.top }
                            height: parent.height - card.labelH
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            mipmap: true
                            readonly property string rawUrl: "file://" + card.modelData
                            readonly property string thumbUrl: "file://" + WallpaperService.thumbnail(card.modelData)
                            source: thumbUrl
                            onStatusChanged: if (status === Image.Error && source.toString() === thumbUrl) source = rawUrl
                            Connections {
                                target: WallpaperService
                                function onThumbnailsUpdated() { if (img.source.toString() !== img.thumbUrl) img.source = img.thumbUrl }
                            }
                        }

                        Rectangle {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                            height: card.labelH
                            color: card.isPreview ? Theme.withAlpha(Theme.accent, 0.22) : Theme.withAlpha(Theme.text, 0.09)
                            Text {
                                anchors.centerIn: parent
                                width: parent.width - 10
                                text: card.modelData.split("/").pop().replace(/\.[^/.]+$/, "")
                                color: card.isPreview ? Theme.accent : Theme.withAlpha(Theme.text, 0.65)
                                font.family: Theme.fontText
                                font.pixelSize: 10
                                font.weight: card.isPreview ? Font.Medium : Font.Normal
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }

                    Rectangle {
                        id: cardMask
                        anchors.fill: parent
                        radius: 10
                        visible: false
                        layer.enabled: true
                    }
                    MultiEffect {
                        source: cardContent
                        anchors.fill: parent
                        maskEnabled: true
                        maskSource: cardMask
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1.0
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: "transparent"
                        border.width: card.isPreview ? 2 : 1
                        border.color: card.isPreview ? Theme.accent
                            : card.isCurrent ? Theme.withAlpha(Theme.accent, 0.45)
                            : Theme.withAlpha(Theme.text, 0.15)
                        Behavior on border.color { ColorAnimation { duration: Theme.animColor } }
                        Behavior on border.width { NumberAnimation { duration: Theme.animColor } }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (card.isPreview) content.applyTarget(card.modelData)
                            else WallpaperService.previewWall = card.modelData
                        }
                    }
                }
            }

            MouseArea {
                anchors { top: parent.top; left: parent.left; right: parent.right
                          bottom: divider.top; bottomMargin: 8 }
                z: wallList.z + 1
                acceptedButtons: Qt.NoButton
                onWheel: function (wheel) {
                    wallList.contentX = Math.max(0, Math.min(wallList.contentWidth - wallList.width,
                                                             wallList.contentX - wheel.angleDelta.y))
                }
            }

            Rectangle {
                id: divider
                anchors { bottom: utilBar.top; bottomMargin: 8; left: parent.left; right: parent.right }
                height: 1
                color: Theme.withAlpha(Theme.text, 0.07)
            }

            Item {
                id: utilBar
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 32

                component BarButton: Rectangle {
                    id: bb
                    property bool lit: false
                    signal clicked()
                    height: 32
                    radius: 8
                    color: bbMa.containsMouse ? Theme.withAlpha(Theme.accent, 0.14)
                         : (lit ? Theme.withAlpha(Theme.accent, 0.18) : Theme.withAlpha(Theme.text, 0.04))
                    border.width: 1
                    border.color: (lit || bbMa.containsMouse) ? Theme.withAlpha(Theme.accent, 0.4) : Theme.withAlpha(Theme.text, 0.09)
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
                    readonly property bool hot: lit || bbMa.containsMouse
                    MouseArea {
                        id: bbMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: bb.clicked()
                    }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 8

                    BarButton {
                        id: folderBtn
                        width: 32
                        lit: content.folderMode
                        Text {
                            anchors.centerIn: parent
                            text: "󰉋"
                            font.family: Theme.iconFont; font.pixelSize: 15
                            color: folderBtn.hot ? Theme.accent : Theme.withAlpha(Theme.text, 0.5)
                        }
                        onClicked: {
                            content.folderMode = !content.folderMode
                            if (content.folderMode) {
                                dirInput.text = WallpaperService.wallpaperDir
                                dirInput.forceActiveFocus()
                                dirInput.selectAll()
                            } else searchInput.forceActiveFocus()
                        }
                    }

                    Rectangle {
                        id: filterBox
                        width: 300; height: 32; radius: 8
                        color: fbMa.containsMouse ? Theme.withAlpha(Theme.text, 0.08) : Theme.withAlpha(Theme.text, 0.06)
                        border.width: 1
                        border.color: (searchInput.activeFocus || dirInput.activeFocus) ? Theme.withAlpha(Theme.accent, 0.5)
                                    : (fbMa.containsMouse ? Theme.withAlpha(Theme.text, 0.15) : Theme.withAlpha(Theme.text, 0.1))
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
                        MouseArea { id: fbMa; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }

                        Item {
                            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                            visible: !content.folderMode
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: searchInput.text === ""
                                text: "Search wallpapers…"
                                color: (searchInput.activeFocus || fbMa.containsMouse) ? Theme.withAlpha(Theme.accent, 0.7) : Theme.withAlpha(Theme.text, 0.28)
                                font.family: Theme.fontText; font.pixelSize: 12
                            }
                            TextInput {
                                id: searchInput
                                anchors.fill: parent
                                verticalAlignment: TextInput.AlignVCenter
                                color: Theme.text
                                font.family: Theme.fontText; font.pixelSize: 12
                                selectionColor: Theme.withAlpha(Theme.accent, 0.35)
                                clip: true
                                onTextChanged: content.searchQuery = text
                                Keys.onReturnPressed: {
                                    var walls = content.filtered
                                    if (!walls || walls.length === 0) return
                                    var t = walls.indexOf(WallpaperService.previewWall) >= 0 ? WallpaperService.previewWall : walls[0]
                                    content.applyTarget(t)
                                }
                                Keys.onLeftPressed: content.step(-1)
                                Keys.onRightPressed: content.step(1)
                                Keys.onEscapePressed: function (event) {
                                    event.accepted = true
                                    if (searchInput.text !== "") {
                                        var target = WallpaperService.previewWall !== "" ? WallpaperService.previewWall : WallpaperService.currentWall
                                        var idx = Math.max(0, WallpaperService.wallpapers.indexOf(target))
                                        searchInput.text = ""
                                        wallList.forceLayout()
                                        wallList.positionViewAtIndex(idx, ListView.Center)
                                    } else Popups.wallpaperOpen = false
                                }
                            }
                        }
                        Item {
                            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                            visible: content.folderMode
                            Text {
                                id: pathLbl
                                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                text: "Path: "
                                color: dirInput.activeFocus ? Theme.accent : Theme.withAlpha(Theme.accent, 0.7)
                                font.family: Theme.fontText; font.pixelSize: 11
                            }
                            TextInput {
                                id: dirInput
                                anchors { left: pathLbl.right; right: parent.right; top: parent.top; bottom: parent.bottom }
                                verticalAlignment: TextInput.AlignVCenter
                                color: Theme.text
                                font.family: Theme.fontMono; font.pixelSize: 12
                                selectionColor: Theme.withAlpha(Theme.accent, 0.35)
                                clip: true
                                Keys.onReturnPressed: {
                                    if (dirInput.text.trim() === "") return
                                    WallpaperService.wallpaperDir = dirInput.text.trim().replace(/^~/, Quickshell.env("HOME"))
                                    WallpaperService.refresh()
                                    content.folderMode = false
                                    searchInput.forceActiveFocus()
                                }
                                Keys.onEscapePressed: function (event) {
                                    event.accepted = true
                                    content.folderMode = false
                                    searchInput.forceActiveFocus()
                                }
                            }
                        }
                    }

                }

                Rectangle {
                    id: applyBtn
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    readonly property bool active: content.applyActive
                    width: active ? 90 : 0
                    height: 32; radius: 8
                    opacity: active ? 1 : 0
                    clip: true
                    color: applyMa.containsMouse ? Theme.withAlpha(Theme.accent, 0.28) : Theme.withAlpha(Theme.accent, 0.18)
                    border.width: 1
                    border.color: applyMa.containsMouse ? Theme.accent : Theme.withAlpha(Theme.accent, 0.4)
                    Behavior on width { NumberAnimation { duration: 200; easing.type: Theme.animCurve } }
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    Text {
                        anchors.centerIn: parent
                        text: WallpaperService.applying ? "…" : "Apply"
                        color: Theme.accent
                        font.family: Theme.fontText; font.pixelSize: 12; font.weight: Font.Medium
                    }
                    MouseArea {
                        id: applyMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: applyBtn.active && !WallpaperService.applying
                        onClicked: content.applyTarget(WallpaperService.previewWall !== ""
                                                       ? WallpaperService.previewWall : WallpaperService.currentWall)
                    }
                }
            }

        }
    }

    Connections {
        target: Popups
        function onWallpaperOpenChanged() {
            if (!Popups.wallpaperOpen) return
            WallpaperService.refresh()
            var idx = WallpaperService.wallpapers.indexOf(WallpaperService.currentWall)
            WallpaperService.previewWall = idx !== -1 ? WallpaperService.currentWall : ""
            wallList.targetCenterIndex = idx
            content.folderMode = false
            searchInput.text = ""
            if (idx !== -1 && wallList.width > 0) wallList.positionViewAtIndex(idx, ListView.Center)
            searchInput.forceActiveFocus()
            focusTimer.restart()
        }
    }
    Timer { id: focusTimer; interval: 60; onTriggered: if (root.open) searchInput.forceActiveFocus() }
}
