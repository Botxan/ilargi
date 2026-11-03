pragma Singleton
import QtQuick
import Quickshell

QtObject {
    readonly property string home: Quickshell.env("HOME")
    readonly property string state: (Quickshell.env("XDG_STATE_HOME") || home + "/.local/state") + "/ilargi"
    readonly property string cache: (Quickshell.env("XDG_CACHE_HOME") || home + "/.cache") + "/ilargi"
    readonly property string scripts: Quickshell.shellDir + "/scripts"
    readonly property string bin: home + "/.local/bin"
}
