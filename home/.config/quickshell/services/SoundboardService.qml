pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"

QtObject {
    id: root

    readonly property string home:     Quickshell.env("HOME")
    readonly property string soundDir: home + "/.local/share/soundboard"
    readonly property string exe:      Paths.bin + "/soundboard"

    readonly property FileView file: FileView {
        id: file
        path: Paths.state + "/soundboard.json"
        watchChanges: true
        onFileChanged: reload()
        onLoadFailed: function (error) {
            file.writeAdapter()
        }
        JsonAdapter {
            id: store
            property int masterVolume: 100
            property var items: []
        }
    }

    readonly property var items: store.items
    readonly property int masterVolume: store.masterVolume

    function _copy() {
        var out = []
        for (var i = 0; i < items.length; i++) out.push(items[i])
        return out
    }

    function _commit(next) {
        store.items = next
        file.writeAdapter()
        syncProc.running = true
    }

    function setMaster(v) {
        store.masterVolume = Math.max(0, Math.min(150, Math.round(v)))
        file.writeAdapter()
    }

    function setFile(id, name) {
        var next = _copy()
        for (var i = 0; i < next.length; i++)
            if (next[i].id === id) next[i] = _with(next[i], { file: name })
        _commit(next)
    }

    function setVolume(id, v) {
        var next = _copy()
        for (var i = 0; i < next.length; i++)
            if (next[i].id === id)
                next[i] = _with(next[i], { volume: Math.max(0, Math.min(200, Math.round(v))) })
        store.items = next
        file.writeAdapter()
    }

    function addKey(key, label) {
        var next = _copy()
        next.push({
            id: "k" + Date.now() + "-" + Math.floor(Math.random() * 1000),
            key: key,
            label: label,
            file: "",
            volume: 100,
            fixed: false
        })
        _commit(next)
    }

    function remove(id) {
        var next = []
        for (var i = 0; i < items.length; i++)
            if (items[i].id !== id) next.push(items[i])
        _commit(next)
    }

    function _with(src, patch) {
        var out = {
            id: src.id, key: src.key, label: src.label,
            file: src.file, volume: src.volume, fixed: src.fixed === true
        }
        for (var k in patch) out[k] = patch[k]
        return out
    }

    function keyTaken(key) {
        for (var i = 0; i < items.length; i++)
            if (items[i].key === key) return true
        return false
    }

    readonly property Process playProc: Process { id: playProc }
    function preview(id) {
        playProc.command = [root.exe, "play", id]
        playProc.running = true
    }
    readonly property Process stopProc: Process { id: stopProc }
    function stopAll() {
        hearing = ""
        playing = ""
        stopProc.command = [root.exe, "stop"]
        stopProc.running = true
    }

    property string playing: ""
    readonly property IpcHandler ipc: IpcHandler {
        target: "soundboard"
        function started(id: string): void { root.playing = id }
        function stopped(id: string): void { if (root.playing === id) root.playing = "" }
        function current(): string { return root.playing }
    }

    readonly property Process currentProc: Process {
        id: currentProc
        command: [root.exe, "current"]
        running: true
        stdout: StdioCollector { onStreamFinished: root.playing = text.trim() }
    }

    readonly property Process syncProc: Process {
        id: syncProc
        command: [root.exe, "sync"]
    }

    property var files: []
    readonly property Process listProc: Process {
        id: listProc
        command: ["sh", "-c",
                  "scan() { [ -d \"$2\" ] || return 0; " +
                  "find \"$2\" -maxdepth \"$3\" -type f \\( -iname '*.mp3' -o -iname '*.wav' " +
                  "-o -iname '*.ogg' -o -iname '*.flac' -o -iname '*.opus' \\) " +
                  "-printf \"$1\\t%p\\n\" 2>/dev/null | sort -f -t '\t' -k2; }; " +
                  "scan soundboard \"" + root.soundDir + "\" 1; " +
                  "scan downloads \"$(xdg-user-dir DOWNLOAD 2>/dev/null || echo $HOME/Downloads)\" 1; " +
                  "scan music \"$(xdg-user-dir MUSIC 2>/dev/null || echo $HOME/Music)\" 4"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = []
                var prefix = root.soundDir + "/"
                var lines = text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var tab = lines[i].indexOf("\t")
                    if (tab < 0) continue
                    var source = lines[i].slice(0, tab)
                    var path = lines[i].slice(tab + 1)
                    var own = source === "soundboard" && path.indexOf(prefix) === 0
                    out.push({
                        file: own ? path.slice(prefix.length) : path,
                        name: path.slice(path.lastIndexOf("/") + 1),
                        source: source
                    })
                }
                root.files = out
            }
        }
    }
    function refreshFiles() { listProc.running = true }

    function hasOwnFile(name) {
        for (var i = 0; i < files.length; i++)
            if (files[i].source === "soundboard" && files[i].file === name) return true
        return false
    }

    property var    webItems:   []
    property string webQuery:   ""
    property int    webPage:    0
    property bool   webMore:    false
    property bool   webLoading: false
    property string webError:   ""

    readonly property Process webProc: Process {
        id: webProc
        stdout: StdioCollector {
            onStreamFinished: {
                var d
                try { d = JSON.parse(text) } catch (e) {
                    if (!webProc.running) {
                        root.webLoading = false
                        root.webError = "unexpected reply from myinstants"
                    }
                    return
                }
                if (d.query !== root.webQuery || d.page !== root._webWant) return
                root.webLoading = false
                root.webError = d.error || ""
                root.webItems = d.page > 1 ? root.webItems.concat(d.items) : d.items
                root.webPage = d.page
                root.webMore = d.more
            }
        }
    }

    function webSearch(q) {
        webQuery = (q || "").trim()
        webItems = []
        webPage = 0
        webMore = false
        webError = ""
        _webLoad(1)
    }
    function webNext() {
        if (webLoading || !webMore) return
        _webLoad(webPage + 1)
    }
    property int _webWant: 0
    function _webLoad(page) {
        _webWant = page
        webLoading = true
        webProc.running = false
        var cmd = [root.exe, "web", String(page)]
        if (webQuery !== "") cmd.push(webQuery)
        webProc.command = cmd
        webProc.running = true
    }

    property var downloading: ({})
    property var _queue: []
    readonly property Process fetchProc: Process {
        id: fetchProc
        property string url: ""
        onExited: function (code, status) {
            var d = Object.assign({}, root.downloading)
            delete d[fetchProc.url]
            root.downloading = d
            root.refreshFiles()
            Qt.callLater(root._nextFetch)
        }
    }
    function download(url) {
        if (downloading[url]) return
        var d = Object.assign({}, downloading)
        d[url] = true
        downloading = d
        _queue = _queue.concat([url])
        if (!fetchProc.running) _nextFetch()
    }
    function _nextFetch() {
        if (fetchProc.running || _queue.length === 0) return
        var url = _queue[0]
        _queue = _queue.slice(1)
        fetchProc.url = url
        fetchProc.command = [root.exe, "fetch", url]
        fetchProc.running = true
    }

    property string hearing: ""
    readonly property Process hearProc: Process { id: hearProc }
    function hear(url) {
        hearing = url
        hearProc.running = false
        hearProc.command = [root.exe, "hear", url]
        hearProc.running = true
    }

    property bool micReady: true
    readonly property Process statusProc: Process {
        id: statusProc
        command: [root.exe, "status"]
        onExited: function (code, status) { root.micReady = (code === 0) }
    }
    function refreshStatus() { statusProc.running = true }
}
