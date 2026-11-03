pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"

QtObject {
    id: root

    readonly property int historyLength: 60

    property bool wanted: true

    readonly property bool collecting: wanted && Theme.telemetryEnabled

    property real  cpu: 0
    property var   cores: []
    property real  memFrac: 0
    property real  memUsedGb: 0
    property real  memTotalGb: 0
    property var   temps: ({})
    property real  netRx: 0
    property real  netTx: 0
    property var   gpu: null
    property var   batteries: []
    property int   uptime: 0
    property bool  haveSample: false

    property var histCpu: []
    property var histGpu: []
    property var histMem: []
    property var histNet: []

    readonly property real netScale: {
        var m = 0.5
        for (var i = 0; i < histNet.length; i++) m = Math.max(m, histNet[i])
        return m
    }

    function peakOf(hist) {
        var m = 0
        for (var i = 0; i < hist.length; i++) m = Math.max(m, hist[i])
        return m
    }

    function push(arr, v) {
        var a = arr.slice()
        a.push(v)
        while (a.length > root.historyLength) a.shift()
        return a
    }

    function fmtUptime(s) {
        var d = Math.floor(s / 86400)
        var h = Math.floor((s % 86400) / 3600)
        var m = Math.floor((s % 3600) / 60)
        if (d > 0) return d + "d " + h + "h"
        if (h > 0) return h + "h " + m + "m"
        return m + "m"
    }

    readonly property var peripherals: {
        var out = []
        for (var i = 0; i < batteries.length; i++) {
            var b = batteries[i]
            var n = b.name.toLowerCase()
            if (n.indexOf("bif") === 0 || b.id.toLowerCase().indexOf("bat") === 0) continue
            out.push(b)
        }
        return out
    }

    readonly property Process proc: Process {
        id: proc
        running: root.collecting
        command: ["python3", Paths.scripts + "/sysstats.py"]

        stdout: SplitParser {
            onRead: function (line) {
                var d
                try { d = JSON.parse(line) } catch (e) { return }

                root.cpu        = d.cpu
                root.cores      = d.cores
                root.memFrac    = d.mem.frac
                root.memUsedGb  = d.mem.usedGb
                root.memTotalGb = d.mem.totalGb
                root.temps      = d.temps
                root.netRx      = d.net.rx
                root.netTx      = d.net.tx
                root.gpu        = d.gpu
                root.batteries  = d.batt
                root.uptime     = d.uptime

                root.histCpu = root.push(root.histCpu, d.cpu)
                root.histGpu = root.push(root.histGpu, d.gpu ? d.gpu.util / 100 : 0)
                root.histMem = root.push(root.histMem, d.mem.frac)
                root.histNet = root.push(root.histNet, d.net.rx + d.net.tx)

                root.haveSample = true
                root.sampled()
            }
        }
    }

    signal sampled()
}
