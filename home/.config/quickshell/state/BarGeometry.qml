pragma Singleton
import QtQuick
import "../theme"

QtObject {
    property real leftWidth:   0
    property real centerX:     0
    property real centerWidth: 0
    property real rightWidth:  0

    readonly property real islandHeight: Theme.notchHeight

    readonly property real popupFlare: Theme.borderWidth + Theme.cornerRadius

    readonly property real rightMinPanelWidth: rightWidth + popupFlare - Theme.borderWidth

    readonly property real bottomTriggerWidth: 420

    property color centerHue: Theme.accent

}
