import QtQuick
import "../theme"

Item {
    id: root

    property var    model:       []
    property string currentPage: ""
    property string orientation: "horizontal"
    property bool   showDivider: true

    signal pageChanged(string key)

    property string defaultPage: model.length > 0 ? model[0].key : ""
    function reset() { pageChanged(defaultPage) }

    implicitWidth:  orientation === "vertical"   ? 40 : 0
    implicitHeight: orientation === "horizontal" ? 48 : 0

    property bool scrollBusy: false
    Timer { id: scrollCooldown; interval: 300; onTriggered: root.scrollBusy = false }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: function(event) {
            if (root.scrollBusy) return
            root.scrollBusy = true
            scrollCooldown.restart()
            var keys = root.model.map(function(m) { return m.key })
            var idx  = keys.indexOf(root.currentPage)
            idx = event.angleDelta.y < 0 ? (idx + 1) % keys.length : (idx - 1 + keys.length) % keys.length
            root.pageChanged(keys[idx])
        }
    }

    Row {
        id: hRow
        anchors.fill: parent
        visible: root.orientation === "horizontal"

        Repeater {
            model: root.orientation === "horizontal" ? root.model : []

            delegate: Item {
                id: hTab
                required property var modelData
                readonly property bool isActive: root.currentPage === modelData.key

                width:  hRow.width / root.model.length
                height: hRow.height

                Rectangle {
                    id: pillBg
                    anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
                    width:  hIcon.implicitWidth + hLabel.implicitWidth + 24
                    height: 32
                    radius: height / 2
                    color: hTab.isActive
                        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                        : (hHov.hovered ? Qt.rgba(1, 1, 1, 0.07) : "transparent")
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                Row {
                    anchors { top: pillBg.top; horizontalCenter: parent.horizontalCenter; topMargin: (pillBg.height - height) / 2 }
                    spacing: 6

                    Text {
                        id: hIcon
                        text: hTab.modelData.icon
                        font.family: Theme.iconFont
                        font.pixelSize: 14
                        anchors.verticalCenter: parent.verticalCenter
                        color: hTab.isActive ? Theme.accent : (hHov.hovered ? Qt.rgba(1, 1, 1, 0.75) : Qt.rgba(1, 1, 1, 0.4))
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    Text {
                        font.family: Theme.fontText
                        id: hLabel
                        visible: hTab.modelData.label !== undefined
                        text: hTab.modelData.label ?? ""
                        font.pixelSize: 12
                        font.weight: hTab.isActive ? Font.Medium : Font.Normal
                        anchors.verticalCenter: parent.verticalCenter
                        color: hTab.isActive ? Theme.accent : (hHov.hovered ? Qt.rgba(1, 1, 1, 0.75) : Qt.rgba(1, 1, 1, 0.4))
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                }

                HoverHandler { id: hHov; cursorShape: Qt.PointingHandCursor }
                MouseArea { anchors.fill: parent; onClicked: root.pageChanged(hTab.modelData.key) }
            }
        }
    }

    Rectangle {
        visible: root.orientation === "horizontal" && root.showDivider
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        height: 1
        color: Qt.rgba(1, 1, 1, 0.07)
    }

    Column {
        id: vCol
        anchors.centerIn: parent
        visible: root.orientation === "vertical"
        width: root.width

        readonly property int tabH: 48
        spacing: root.model.length > 1
            ? (root.height - root.model.length * tabH) / (root.model.length - 1)
            : 0

        Repeater {
            model: root.orientation === "vertical" ? root.model : []

            delegate: Rectangle {
                id: vTab
                required property var modelData
                readonly property bool isActive: root.currentPage === modelData.key

                width: vCol.width
                height: vCol.tabH
                radius: Theme.cornerRadius

                color: vTab.isActive ? Theme.accent : (vHov.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: vTab.modelData.icon
                    font.family: Theme.iconFont
                    font.pixelSize: 16
                    color: vTab.isActive ? Theme.ground : Theme.text
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                HoverHandler { id: vHov; cursorShape: Qt.PointingHandCursor }
                MouseArea { anchors.fill: parent; onClicked: root.pageChanged(vTab.modelData.key) }
            }
        }
    }
}
