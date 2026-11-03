pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property var entries: []
    property bool loading: false
    property var pending: []

    function kindOf(preview) {
        if (/^\[\[\s*binary data/.test(preview)) return "image"
        if (/^(https?:\/\/|www\.)/.test(preview.trim())) return "url"
        return "text"
    }

    function refresh() {
        if (loading) return
        loading = true
        pending = []
        listProc.running = true
    }

    readonly property Process listProc: Process {
        id: listProc
        command: ["cliphist", "list"]
        stdout: SplitParser {
            onRead: function (line) {
                var tab = line.indexOf("\t")
                if (tab <= 0) return
                var id = line.substring(0, tab)
                var preview = line.substring(tab + 1)
                if (preview.trim() === "") return
                root.pending.push({ id: id, preview: preview, kind: root.kindOf(preview) })
            }
        }
        onExited: {
            root.entries = root.pending
            root.pending = []
            root.loading = false
        }
    }

    readonly property Process copyProc: Process { id: copyProc }

    function copy(id) {
        copyProc.running = false
        copyProc.command = ["bash", "-c",
            "cliphist decode " + JSON.stringify(id) + " | wl-copy"]
        copyProc.running = true
    }


}
