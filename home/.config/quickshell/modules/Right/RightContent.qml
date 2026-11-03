import QtQuick
import "../../theme"
import "../../components"

Item {
    id: root
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        Network {}
        Item { width: Theme.topbarItemGap; height: 1 }
        VPN {}
        Item { width: Theme.topbarItemGap; height: 1 }
        Audio {}
        Item { width: Theme.topbarItemGap; height: 1 }
        Soundboard {}
        Item { width: Theme.topbarItemGap; height: 1; visible: bluetooth.visible || battery.visible }
        Bluetooth { id: bluetooth }
        Item { width: Theme.topbarItemGap; height: 1; visible: bluetooth.visible && battery.visible }
        Battery { id: battery }

        Item { width: Theme.topbarDividerGap; height: 1 }
        Rule {
            vertical: true
            groove: true
            width: 1
            height: 16
            anchors.verticalCenter: parent.verticalCenter
        }
        Item { width: Theme.topbarDividerGap; height: 1 }
        Clock {}
    }
}
