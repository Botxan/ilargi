import Quickshell
import QtQuick
import "./theme"
import "./windows"
import "./popups"
import "./services"

ShellRoot {
    Component.onCompleted: SysStatsService.wanted = true

    Frame {}
    Strut { edge: "top"; reserve: Theme.notchHeight - Theme.borderWidth }
    PopupDismiss {}
    IdentifyOverlay {}
    WallpaperPopup {}
    WindowMenuPopup {}
    LockScreen {}
    PolkitDialog {}
    WindowSend {}
}
