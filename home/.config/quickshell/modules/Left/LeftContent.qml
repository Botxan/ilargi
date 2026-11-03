import QtQuick
import ".."
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

        WorkspaceRow { id: workspaces }

        Item { width: openWindows.count > 0 ? Theme.topbarDividerGap : 0; height: 1 }
        Rule {
            visible: openWindows.count > 0
            vertical: true
            groove: true
            width: 1
            height: 16
            anchors.verticalCenter: parent.verticalCenter
        }
        Item { width: openWindows.count > 0 ? Theme.topbarDividerGap : 0; height: 1 }

        OpenWindows { id: openWindows }
    }
}
