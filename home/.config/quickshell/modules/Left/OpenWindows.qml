import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../../theme"
import "../../state"

Item {
    id: root

    anchors.verticalCenter: parent.verticalCenter

    readonly property int naturalIconSize: 24
    readonly property int minIconSize:     16
    readonly property int iconSpacing:     6
    readonly property int maxWidth:        320

    readonly property var groups: {
        var byId = {}
        var order = []
        var list = ToplevelManager.toplevels.values
        for (var i = 0; i < list.length; i++) {
            var t = list[i]
            var id = t.appId !== "" ? t.appId : "?"
            if (!byId[id]) { byId[id] = []; order.push(id) }
            byId[id].push(t)
        }
        var result = []
        for (var j = 0; j < order.length; j++) {
            var wins = byId[order[j]]
            var primary = wins[0]
            for (var k = 0; k < wins.length; k++) if (wins[k].activated) { primary = wins[k]; break }
            result.push({ appId: order[j], windows: wins, primary: primary })
        }
        return result
    }

    readonly property int count: groups.length
    readonly property real naturalWidth: count > 0 ? count * naturalIconSize + (count - 1) * iconSpacing : 0
    readonly property real iconSize: {
        if (count === 0) return naturalIconSize
        if (naturalWidth <= maxWidth) return naturalIconSize
        var fitted = (maxWidth - (count - 1) * iconSpacing) / count
        return Math.max(minIconSize, fitted)
    }
    readonly property real contentWidth: count > 0 ? count * iconSize + (count - 1) * iconSpacing : 0

    visible: count > 0
    implicitWidth: visible ? Math.min(contentWidth, maxWidth) : 0
    implicitHeight: naturalIconSize

    function iconSourceFor(appId) {
        var _dep = DesktopEntries.applications.values.length
        var entry = DesktopEntries.heuristicLookup(appId)
        var name = (entry && entry.icon !== "") ? entry.icon : "application-x-executable"
        return Quickshell.iconPath(name, "application-x-executable")
    }

    function openMenu(group, anchorItem) {
        var pos = anchorItem.mapToItem(null, 0, anchorItem.height + 6)
        Popups.closeAll()
        Popups.winMenuGroup = group
        Popups.winMenuIconSize = anchorItem.width
        Popups.winMenuX = pos.x
        Popups.winMenuY = pos.y
        Popups.winMenuOpen = true
    }

    Flickable {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: root.naturalIconSize
        contentWidth: row.width
        contentHeight: height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Row {
            id: row
            spacing: root.iconSpacing
            height: root.naturalIconSize

            Repeater {
                model: root.groups

                delegate: Rectangle {
                    id: iconBtn
                    required property var modelData
                    width: root.iconSize
                    height: root.iconSize
                    anchors.verticalCenter: parent.verticalCenter
                    radius: Math.max(4, width * 0.28)
                    color: iconHov.hovered ? Qt.rgba(1, 1, 1, 0.10) : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Image {
                        id: iconImg
                        width: parent.width - 4
                        height: width
                        anchors.centerIn: parent
                        source: root.iconSourceFor(iconBtn.modelData.appId)
                        sourceSize.width: Math.ceil(width * iconImg.dpr)
                        sourceSize.height: Math.ceil(height * iconImg.dpr)
                        readonly property real dpr: Window.window ? Window.window.devicePixelRatio : 1
                        smooth: true
                        mipmap: true
                        asynchronous: true
                        visible: false
                    }
                    MultiEffect {
                        anchors.fill: iconImg
                        source: iconImg
                        saturation: -1.0
                        colorization: 0.78
                        colorizationColor: Theme.text
                        opacity: iconBtn.modelData.primary.activated ? 1.0
                               : (iconHov.hovered ? 0.88 : 0.58)
                        Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
                    }

                    Rectangle {
                        visible: iconBtn.modelData.primary.activated
                        width: 4; height: 4; radius: 2
                        color: Theme.accent
                        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: -5 }
                    }

                    Rectangle {
                        visible: iconBtn.modelData.windows.length > 1
                        width: 12; height: 12; radius: 6
                        color: Theme.ground
                        border.color: Qt.rgba(1, 1, 1, 0.18); border.width: 1
                        anchors { right: parent.right; top: parent.top; rightMargin: -3; topMargin: -3 }
                        Text {
                            font.family: Theme.fontText
                            anchors.centerIn: parent
                            text: iconBtn.modelData.windows.length
                            font.pixelSize: 8
                            font.weight: Font.Bold
                            color: Theme.accent
                        }
                    }

                    HoverHandler { id: iconHov; cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: (mouse) => {
                            if (mouse.button === Qt.LeftButton) {
                                const w = iconBtn.modelData.primary
                                Popups.closeThen(() => w.activate())
                            } else {
                                root.openMenu(iconBtn.modelData, iconBtn)
                            }
                        }
                    }
                }
            }
        }
    }
}
