import Quickshell
import Quickshell.Wayland
import QtQuick
import "../theme"
import "../state"
import "../services"
import "../shapes"
import "../modules/Left"
import "../modules/Center"
import "../modules/Right"
import "../popups"

PanelWindow {
    id: root
    screen: DisplayService.primaryScreen
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-frame"
    WlrLayershell.keyboardFocus: root.panelOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property int t: Theme.borderWidth
    readonly property int islandH: Theme.notchHeight - Theme.borderWidth
    readonly property int pad: Theme.notchPaddingH
    readonly property int centerW: 300

    readonly property real leftTargetW: leftContent.implicitWidth + pad * 2 - t
    readonly property real rightIslandW: rightContent.implicitWidth + pad * 2 - t

    readonly property var rightPanels: [audioPanel, networkPanel, bluetoothPanel, vpnPanel, batteryPanel, soundboardPanel]
    readonly property var rightOpen: {
        for (var i = 0; i < rightPanels.length; i++) if (rightPanels[i].open) return rightPanels[i]
        return null
    }
    readonly property var centerPanels: [aperturePanel, launcherPanel, sessionPanel]
    readonly property var centerOpen: {
        for (var i = 0; i < centerPanels.length; i++) if (centerPanels[i].open) return centerPanels[i]
        return null
    }
    property var centerShown: null
    onCenterOpenChanged: if (centerOpen) centerShown = centerOpen
    readonly property real centerTargetW: centerOpen ? centerOpen.panelW : centerW
    readonly property real centerTargetH: centerOpen ? centerOpen.panelH : islandH

    readonly property real sideCy: (height + Theme.notchHeight) / 2

    readonly property bool panelOpen: rightOpen !== null || centerOpen !== null
                                      || almanacPanel.open || clipboardPanel.open
    property var rightShown: null
    onRightOpenChanged: if (rightOpen) rightShown = rightOpen

    readonly property real rightTargetW: rightOpen ? Math.max(rightOpen.panelW, rightIslandW) : rightIslandW
    readonly property real rightTargetH: rightOpen ? rightOpen.panelH : islandH

    Binding { target: BarGeometry; property: "leftWidth";   value: root.leftTargetW + root.t }
    Binding { target: BarGeometry; property: "rightWidth";  value: root.rightIslandW + root.t }
    Binding { target: BarGeometry; property: "centerX";     value: Math.round(root.width / 2 - root.centerW / 2) }
    Binding { target: BarGeometry; property: "centerWidth"; value: root.centerW }
    Binding { target: BarGeometry; property: "centerHue";   value: Theme.accent }

    mask: Region {
        Region { item: Popups.anyOpen ? shield : noInput }
        Region { x: 0; y: 0; width: root.width; height: root.t }
        Region { x: 0; y: root.height - root.t; width: root.width; height: root.t }
        Region { x: 0; y: 0; width: root.t; height: root.height }
        Region { x: root.width - root.t; y: 0; width: root.t; height: root.height }
        Region { item: leftArea }
        Region { item: centerArea }
        Region { item: rightArea }
        Region { item: almanacArea }
        Region { item: clipboardArea }
        Region { item: notifArea }
    }

    Item { id: noInput; width: 0; height: 0 }

    MouseArea {
        id: shield
        anchors.fill: parent
        enabled: Popups.anyOpen
        acceptedButtons: Qt.AllButtons
        onPressed: Popups.closeAll()
    }

    FrameShape {
        id: shape
        anchors.fill: parent
        leftW: root.leftTargetW
        leftH: root.islandH
        centerW: root.centerTargetW
        centerH: root.centerTargetH
        rightW: root.rightTargetW
        rightH: root.rightTargetH
        lip: "transparent"
        sideCy: root.sideCy
        rcDepth:  almanacPanel.open ? almanacPanel.panelW : 0.001
        rcHeight: almanacPanel.open ? almanacPanel.panelH : 0.001
        lcDepth:  clipboardPanel.open ? clipboardPanel.panelW : 0.001
        lcHeight: clipboardPanel.open ? clipboardPanel.panelH : 0.001
        rtTop: Theme.notchHeight + 2 * Theme.cornerRadius + 6
        rtDepth:  notifStack.open ? notifStack.panelW : 0.001
        rtHeight: notifStack.panelH
    }

    Item {
        id: leftArea
        x: root.t; y: root.t
        width: shape.leftW; height: shape.leftH
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onPressed: Popups.closeAll(); z: -1 }
    }
    LeftContent {
        id: leftContent
        x: root.pad
        y: Math.round((Theme.notchHeight - height) / 2)
    }

    Item {
        id: centerArea
        x: Math.round(root.width / 2 - shape.centerW / 2)
        y: root.t
        width: shape.centerW
        height: shape.centerH
        clip: true
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

        CenterIsland {
            width: root.centerW
            height: root.islandH
            anchors.horizontalCenter: parent.horizontalCenter
            opacity: root.centerOpen ? 0 : 1
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.animContentIn } }
        }

        Item {
            anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
            width: root.centerShown ? root.centerShown.panelW : 1
            height: root.centerShown ? root.centerShown.panelH : 1
            AperturePopup { id: aperturePanel; anchors.fill: parent }
            LauncherPopup { id: launcherPanel; anchors.fill: parent }
            SessionPopup  { id: sessionPanel;  anchors.fill: parent }
        }
    }

    Item {
        id: rightArea
        x: root.width - root.t - shape.rightW
        y: root.t
        width: shape.rightW; height: shape.rightH
        clip: true
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }
        MouseArea { width: parent.width; height: root.islandH; acceptedButtons: Qt.AllButtons; onPressed: Popups.closeAll() }

        Item {
            anchors { top: parent.top; right: parent.right }
            width: root.rightShown ? root.rightShown.panelW : 1
            height: root.rightShown ? root.rightShown.panelH : 1
            AudioPopup      { id: audioPanel;      anchors.fill: parent }
            NetworkPopup    { id: networkPanel;    anchors.fill: parent }
            BluetoothPopup  { id: bluetoothPanel;  anchors.fill: parent }
            VPNPopup        { id: vpnPanel;        anchors.fill: parent }
            BatteryPopup    { id: batteryPanel;    anchors.fill: parent }
            SoundboardPopup { id: soundboardPanel; anchors.fill: parent }
        }
    }
    RightContent {
        id: rightContent
        x: root.width - root.pad - width
        y: Math.round((Theme.notchHeight - height) / 2)
    }

    Item {
        id: almanacArea
        x: root.width - root.t - shape.rcDepth
        y: root.sideCy - shape.rcHeight / 2
        width: shape.rcDepth; height: shape.rcHeight
        clip: true
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }
        AlmanacPopup {
            id: almanacPanel
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            width: panelW; height: panelH
        }
    }
    Item {
        id: clipboardArea
        x: root.t
        y: root.sideCy - shape.lcHeight / 2
        width: shape.lcDepth; height: shape.lcHeight
        clip: true
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }
        ClipboardPopup {
            id: clipboardPanel
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            width: panelW; height: panelH
        }
    }

    Item {
        id: notifArea
        x: root.width - root.t - shape.rtDepth
        y: shape.rtTopEff
        width: shape.rtDepth; height: shape.rtHeightEff
        clip: true
        NotifStack {
            id: notifStack
            x: 0
            y: shape.rtTop - shape.rtTopEff
            width: panelW; height: panelH
            suppressed: root.panelOpen || Popups.anyOpen
        }
    }

    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: BarGeometry.bottomTriggerWidth
        height: root.t
        HoverHandler { cursorShape: Qt.PointingHandCursor }
        TapHandler {
            onTapped: {
                var next = !Popups.wallpaperOpen
                Popups.closeAll()
                Popups.wallpaperOpen = next
            }
        }
    }
}
