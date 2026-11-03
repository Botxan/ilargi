pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"

QtObject {
    id: root

    readonly property int barCount: 42

    property bool wanted: false
    property bool barWanted: false

    property var bars: []
    property bool available: false
    property bool checked: false

    Component.onCompleted: probe.running = true

    readonly property Process probe: Process {
        id: probe
        command: ["bash", "-c", "command -v cava >/dev/null 2>&1 && echo yes || echo no"]
        stdout: SplitParser {
            onRead: function (line) {
                root.available = line.trim() === "yes"
                root.checked = true
            }
        }
    }

    readonly property string configPath:
        (Quickshell.env("XDG_RUNTIME_DIR") !== "" ? Quickshell.env("XDG_RUNTIME_DIR") : "/tmp")
        + "/quickshell-cava.conf"

    readonly property Process proc: Process {
        id: proc
        running: (root.wanted || root.barWanted) && root.available && Theme.spectrumEnabled

        command: ["bash", "-c",
            "printf '%s\\n' " +
            "'[general]' 'framerate = 60' 'bars = " + root.barCount + "' 'autosens = 1' " +
            "'[output]' 'method = raw' 'raw_target = /dev/stdout' 'data_format = ascii' " +
            "'ascii_max_range = 100' 'bar_delimiter = 59' 'frame_delimiter = 10' " +
            "'[smoothing]' 'noise_reduction = 40' " +
            "> \"" + root.configPath + "\" && exec cava -p \"" + root.configPath + "\""
        ]

        stdout: SplitParser {
            onRead: function (line) {
                var parts = line.split(";")
                var out = []
                for (var i = 0; i < parts.length; i++) {
                    if (parts[i] === "") continue
                    var v = parseInt(parts[i], 10)
                    out.push(isNaN(v) ? 0 : Math.max(0, Math.min(100, v)) / 100)
                }
                if (out.length > 0) root.bars = out
            }
        }

        onRunningChanged: if (!running) root.bars = []
    }
}
