import Quickshell
import QtQuick
import Quickshell.Wayland
import "../theme"
import "../state"
import "../services"

PanelWindow {
    id: root
    screen: DisplayService.primaryScreen

    readonly property var group: Popups.winMenuGroup
    readonly property var wins: group ? group.windows : []
    readonly property int rowH: 32
    readonly property int popupWidth: 230
    readonly property int popupHeight: root.windowVisible
        ? headerRow.height + divider.height + wins.length * rowH + 14
        : 0

    readonly property real clampedX: Math.max(4, Math.min(Popups.winMenuX, (screen ? screen.width : 1920) - popupWidth - 4))
    readonly property real clampedY: Math.max(4, Math.min(Popups.winMenuY, (screen ? screen.height : 1080) - popupHeight - 4))

    anchors { left: true; top: true }
    margins { left: clampedX; top: clampedY }

    implicitWidth: popupWidth
    implicitHeight: popupHeight

    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    property bool windowVisible: false
    visible: windowVisible

    Connections {
        target: Popups
        function onWinMenuOpenChanged() {
            if (Popups.winMenuOpen) { closeTimer.stop(); root.windowVisible = true }
            else closeTimer.restart()
        }
    }
    Timer {
        id: closeTimer
        interval: 80
        onTriggered: { if (!Popups.winMenuOpen) root.windowVisible = false }
    }

    Item {
        id: clipper
        width:  Popups.winMenuOpen ? root.popupWidth  : Popups.winMenuIconSize
        height: Popups.winMenuOpen ? root.popupHeight : Popups.winMenuIconSize
        clip: true
        Behavior on width  { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }

    Rectangle {
        width: root.popupWidth
        height: root.popupHeight
        radius: Theme.cornerRadius
        color: Theme.ground
        border.color: Theme.grooveDark
        border.width: 1
        clip: true
        opacity: Popups.winMenuOpen ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 70 } }

        Row {
            id: headerRow
            anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 10; rightMargin: 6; topMargin: 6 }
            height: 26
            Text {
                font.family: Theme.fontText
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - closeAllBtn.width
                text: root.group ? root.group.appId : ""
                font.pixelSize: 11
                font.weight: Font.Bold
                color: Qt.rgba(1, 1, 1, 0.45)
                elide: Text.ElideRight
            }
            Rectangle {
                id: closeAllBtn
                visible: root.wins.length > 1
                width: 20; height: 20; radius: 5
                anchors.verticalCenter: parent.verticalCenter
                color: closeAllHov.hovered ? Qt.rgba(248/255, 113/255, 113/255, 0.18) : "transparent"
                Behavior on color { ColorAnimation { duration: 100 } }
                Text {
                    anchors.centerIn: parent
                    text: "󰅗"
                    font.family: Theme.iconFont
                    font.pixelSize: 11
                    color: closeAllHov.hovered ? "#df5b61" : Qt.rgba(1, 1, 1, 0.35)
                }
                HoverHandler { id: closeAllHov; cursorShape: Qt.PointingHandCursor }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        for (var i = 0; i < root.wins.length; i++) root.wins[i].close()
                        Popups.winMenuOpen = false
                    }
                }
            }
        }

        Rectangle {
            id: divider
            anchors { left: parent.left; right: parent.right; top: headerRow.bottom }
            height: 1
            color: Theme.grooveDark
        }

        Column {
            anchors { left: parent.left; right: parent.right; top: divider.bottom; topMargin: 4 }

            Repeater {
                model: root.wins

                delegate: Item {
                    id: winRow
                    required property var modelData
                    width: parent.width
                    height: root.rowH

                    Rectangle {
                        anchors { fill: parent; leftMargin: 4; rightMargin: 4 }
                        radius: 6
                        color: rowHov.hovered ? Qt.rgba(1, 1, 1, 0.07) : "transparent"
                        Behavior on color { ColorAnimation { duration: 90 } }
                    }

                    Rectangle {
                        visible: winRow.modelData.activated
                        width: 4; height: 4; radius: 2
                        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                        color: Theme.accent
                    }

                    Text {
                        font.family: Theme.fontText
                        anchors {
                            left: parent.left; leftMargin: winRow.modelData.activated ? 20 : 12
                            right: closeBtn.left; rightMargin: 4
                            verticalCenter: parent.verticalCenter
                        }
                        text: winRow.modelData.title !== "" ? winRow.modelData.title : "(untitled)"
                        font.pixelSize: 12
                        color: winRow.modelData.activated ? Theme.text : Qt.rgba(1, 1, 1, 0.65)
                        elide: Text.ElideRight
                    }

                    HoverHandler { id: rowHov; cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            winRow.modelData.activate()
                            Popups.winMenuOpen = false
                        }
                    }

                    Rectangle {
                        id: closeBtn
                        width: 20; height: 20; radius: 5
                        anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                        color: closeHov.hovered ? Qt.rgba(248/255, 113/255, 113/255, 0.18) : "transparent"
                        Behavior on color { ColorAnimation { duration: 90 } }
                        Text {
                            font.family: Theme.fontText
                            anchors.centerIn: parent
                            text: "×"
                            font.pixelSize: 13
                            color: closeHov.hovered ? "#df5b61" : Qt.rgba(1, 1, 1, 0.3)
                        }
                        HoverHandler { id: closeHov; cursorShape: Qt.PointingHandCursor }
                        MouseArea { anchors.fill: parent; onClicked: winRow.modelData.close() }
                    }
                }
            }
        }
    }
    }
}
