import Quickshell
import Quickshell.Wayland
import QtQuick
import "../services"

PanelWindow {
    id: root
    property string edge: "top"
    property int reserve: 0
    screen: DisplayService.primaryScreen
    anchors {
        top: edge === "top"; bottom: edge === "bottom"
        left: edge === "left" || edge === "top" || edge === "bottom"
        right: edge === "right" || edge === "top" || edge === "bottom"
    }
    implicitWidth: (edge === "left" || edge === "right") ? Math.max(1, reserve) : 0
    implicitHeight: (edge === "top" || edge === "bottom") ? Math.max(1, reserve) : 0
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "quickshell-strut"
    exclusiveZone: reserve
    mask: Region {}
}
