pragma Singleton
import QtQuick

QtObject {
    id: root
    property bool wallpaperOpen: false

    property bool   audioOpen:     false
    property string audioPage:     "output"
    property bool   networkOpen:   false
    property bool   bluetoothOpen: false
    property bool   vpnOpen:       false
    property bool   batteryOpen:   false
    property bool   soundboardOpen: false

    property bool   apertureOpen: false
    property string apertureRoom: ""

    property bool   launcherOpen: false

    property bool   almanacOpen: false
    property string almanacRoom: "day"

    property bool   clipboardOpen: false

    property bool   sessionOpen: false

    property bool   winMenuOpen: false
    property real   winMenuX:    0
    property real   winMenuY:    0
    property real   winMenuIconSize: 24
    property var    winMenuGroup: null

    readonly property bool anyOpen: wallpaperOpen || soundboardOpen || audioOpen || networkOpen || bluetoothOpen || vpnOpen || batteryOpen || winMenuOpen || apertureOpen || launcherOpen || almanacOpen || clipboardOpen || sessionOpen

    property var pendingAfterClose: null
    property Timer afterCloseTimer: Timer {
        interval: 90
        onTriggered: {
            var f = root.pendingAfterClose
            root.pendingAfterClose = null
            if (f) f()
        }
    }
    function closeThen(fn) {
        if (!anyOpen) { fn(); return }
        closeAll()
        pendingAfterClose = fn
        afterCloseTimer.restart()
    }

    function closeAll() {
        wallpaperOpen   = false
        audioOpen       = false
        networkOpen     = false
        bluetoothOpen   = false
        vpnOpen         = false
        batteryOpen     = false
        soundboardOpen  = false
        winMenuOpen     = false
        apertureOpen    = false
        apertureRoom    = ""
        launcherOpen    = false
        almanacOpen     = false
        clipboardOpen   = false
        sessionOpen     = false
    }
}
