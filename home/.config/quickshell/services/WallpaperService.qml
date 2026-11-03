pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"

QtObject {
    id: root

    readonly property string currentWallFile: Paths.state + "/wallpaper"

    property var    wallpapers:   []
    property var    tempWalls:    []
    property string currentWall:  ""
    property string previewWall:  ""
    property bool   applying:     false
    property string wallpaperDir: Quickshell.env("HOME") + "/Pictures/Wallpapers"


    signal wallpaperApplied(string path)

    readonly property string thumbDir: Paths.cache + "/wall-thumbs"
    signal thumbnailsUpdated()
    function thumbnail(path) {
        return path ? root.thumbDir + "/" + Qt.md5(path) + ".jpg" : ""
    }
    property Process thumbProc: Process {
        command: ["bash", Paths.scripts + "/wall-thumbs.sh",
                  root.wallpaperDir, root.thumbDir]
        onExited: root.thumbnailsUpdated()
    }

    function refresh() {
        if (listProc.running) return
        root.tempWalls = []
        listProc.running = true
    }

    property var listProc: Process {
        command: [
            "bash", "-c",
            "find \"" + root.wallpaperDir + "\" -maxdepth 1 -type f " +
            "\\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' " +
            "-o -iname '*.webp' -o -iname '*.bmp' -o -iname '*.tiff' -o -iname '*.tif' \\) | sort"
        ]
        stdout: SplitParser {
            onRead: function(line) {
                var t = line.trim()
                if (t !== "") root.tempWalls.push(t)
            }
        }
        onExited: function() {
            var same = root.tempWalls.length === root.wallpapers.length &&
                root.tempWalls.every(function(p, i) { return p === root.wallpapers[i] })
            if (!same) root.wallpapers = root.tempWalls
            if (!thumbProc.running) thumbProc.running = true
        }
    }

    property string _cfgBuf: ""
    property var readCurrentProc: Process {
        command: ["bash", "-c", "cat \"" + root.currentWallFile + "\" 2>/dev/null"]
        stdout: SplitParser {
            onRead: function(line) { root._cfgBuf += line }
        }
        onExited: function() {
            var t = root._cfgBuf.trim()
            if (t !== "") root.currentWall = t
            root.refresh()
        }
    }

    function apply(path) {
        if (root.applying || path === "") return
        root.applying    = true
        root.currentWall = path
        applyProc.command = [
            "sh", "-c",
            "awww img --transition-type grow --transition-pos bottom --transition-step 200 " +
            "--transition-duration 1.2 --transition-fps 60 \"$1\" && mkdir -p \"$(dirname \"$2\")\" && printf %s \"$1\" > \"$2\"",
            "sh", path, root.currentWallFile
        ]
        applyProc.running = true
    }

    property Process applyProc: Process {
        onExited: function(exitCode) {
            root.applying = false
            if (exitCode === 0) root.wallpaperApplied(root.currentWall)
        }
    }

    Component.onCompleted: readCurrentProc.running = true
}
