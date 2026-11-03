pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

QtObject {
    id: root

    readonly property var players: Mpris.players.values

    property string pinnedId: ""

    readonly property var active: {
        var ps = players
        if (ps.length === 0) return null

        if (pinnedId !== "") {
            for (var i = 0; i < ps.length; i++)
                if (ps[i].dbusName === pinnedId) return ps[i]
        }
        for (var j = 0; j < ps.length; j++)
            if (ps[j].isPlaying) return ps[j]
        for (var k = 0; k < ps.length; k++)
            if (ps[k].trackTitle !== "") return ps[k]
        return ps[0]
    }

    readonly property bool hasPlayer: active !== null
    readonly property bool playing: active !== null && active.isPlaying

    function stripEmoji(s) {
        if (!s) return ""
        return s.replace(/[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}\u{1F1E6}-\u{1F1FF}]/gu, "")
                .replace(/\s{2,}/g, " ")
                .trim()
    }
    readonly property string title:  active ? root.stripEmoji(active.trackTitle) : ""
    readonly property string artist: active ? active.trackArtist : ""
    readonly property string album:  active ? active.trackAlbum : ""
    readonly property string artUrl: active ? active.trackArtUrl : ""
    readonly property string identity: active ? active.identity : ""

    readonly property real length: active && active.lengthSupported ? active.length : 0

    property real pos: 0

    readonly property real progress: (length > 0 && pos > 0)
        ? Math.max(0, Math.min(1, pos / length)) : 0

    readonly property Timer posTimer: Timer {
        running: root.playing && root.active !== null && root.active.positionSupported
        interval: 500
        repeat: true
        triggeredOnStart: true
        onTriggered: root.pos = root.active ? root.active.position : 0
    }

    readonly property Connections activeWatch: Connections {
        target: root
        function onActiveChanged() {
            root.pos = root.active && root.active.positionSupported ? root.active.position : 0
            if (root.active === null) root.pinnedId = ""
        }
        function onPlayingChanged() {
            if (root.active && root.active.positionSupported) root.pos = root.active.position
        }
    }

    function fmt(seconds) {
        if (!isFinite(seconds) || seconds <= 0) return "0:00"
        var s = Math.floor(seconds)
        var m = Math.floor(s / 60)
        var h = Math.floor(m / 60)
        var ss = ("0" + (s % 60)).slice(-2)
        return h > 0 ? (h + ":" + ("0" + (m % 60)).slice(-2) + ":" + ss) : (m + ":" + ss)
    }

    function seekFraction(f) {
        if (!active || !active.canSeek || length <= 0) return
        active.position = Math.max(0, Math.min(length, f * length))
        root.pos = active.position
    }

    function toggle()   { if (active && active.canTogglePlaying) active.togglePlaying() }
    function next()     { if (active && active.canGoNext) active.next() }
    function previous() { if (active && active.canGoPrevious) active.previous() }
}
