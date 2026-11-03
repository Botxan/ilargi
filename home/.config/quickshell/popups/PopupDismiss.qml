import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import "../theme"
import "../state"
import "../services"

Scope {
    id: scope

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: root
            required property var modelData
            screen: modelData
            readonly property bool hasBar: modelData.name === DisplayService.primaryName

            color: "transparent"
            anchors { top: true; left: true; right: true; bottom: true }
            exclusionMode: ExclusionMode.Ignore

            visible: Popups.anyOpen && !root.hasBar

            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: Popups.apertureOpen || Popups.launcherOpen || Popups.wallpaperOpen
                ? WlrKeyboardFocus.None
                : WlrKeyboardFocus.OnDemand

            mask: Region {
                Region {
                    x: 0
                    y: root.hasBar ? Theme.notchHeight : 0
                    width: root.width
                    height: root.height - (root.hasBar ? Theme.notchHeight : 0)
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onPressed: Popups.closeAll()
            }

            Item {
                anchors.fill: parent
                focus: root.visible
                Keys.onEscapePressed: Popups.closeAll()
            }
        }
    }

    property string lastWindow: ""

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (DisplayService.suppressEvents) return
            switch (event.name) {
            case "activewindowv2": {
                var addr = event.data
                if (addr === "" || addr === ",") return
                var changed = scope.lastWindow !== "" && addr !== scope.lastWindow
                scope.lastWindow = addr
                if (changed && Popups.anyOpen) Popups.closeAll()
                return
            }
            case "workspacev2":
            case "activespecial":
            case "openwindow":
            case "closewindow":
            case "movewindowv2":
            case "fullscreen":
            case "changefloatingmode":
                if (Popups.anyOpen) Popups.closeAll()
                return
            }
        }
    }
}
