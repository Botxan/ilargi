#!/usr/bin/env python3
"""System stats for the Vitals room: one JSON line per second on stdout."""
import glob, json, os, shutil, subprocess, sys, time

HWMON = "/sys/class/hwmon"
PSU = "/sys/class/power_supply"


def read(path, default=""):
    try:
        with open(path) as f:
            return f.read().strip()
    except OSError:
        return default


def cpu_sample():
    cores = []
    tot = None
    for line in read("/proc/stat").splitlines():
        if not line.startswith("cpu"):
            break
        parts = line.split()
        vals = [int(v) for v in parts[1:]]
        idle = vals[3] + (vals[4] if len(vals) > 4 else 0)
        busy = sum(vals) - idle
        if parts[0] == "cpu":
            tot = (idle, busy)
        else:
            cores.append((idle, busy))
    return tot, cores


def frac(prev, cur):
    di = cur[0] - prev[0]
    db = cur[1] - prev[1]
    d = di + db
    return round(db / d, 4) if d > 0 else 0.0


def mem():
    info = {}
    for line in read("/proc/meminfo").splitlines():
        k, _, v = line.partition(":")
        info[k] = int(v.split()[0])
    total = info.get("MemTotal", 1)
    avail = info.get("MemAvailable", 0)
    used = total - avail
    return {
        "frac": round(used / total, 4),
        "usedGb": round(used / 1048576, 1),
        "totalGb": round(total / 1048576, 1),
    }


def hwmons():
    out = {}
    if not os.path.isdir(HWMON):
        return out
    for d in sorted(os.listdir(HWMON)):
        base = os.path.join(HWMON, d)
        name = read(os.path.join(base, "name"))
        if name:
            out.setdefault(name, base)
    return out


CHIPS = hwmons()


def temp(chip):
    base = CHIPS.get(chip)
    v = read(os.path.join(base, "temp1_input")) if base else ""
    return round(int(v) / 1000) if v else None


def temps():
    out = {}
    pkg = temp("coretemp") or temp("k10temp") or temp("zenpower")
    for key, val in (("pkg", pkg), ("nvme", temp("nvme")), ("acpi", temp("acpitz"))):
        if val is not None:
            out[key] = val
    return out


def net_sample():
    rx = tx = 0
    for line in read("/proc/net/dev").splitlines()[2:]:
        iface, _, rest = line.partition(":")
        iface = iface.strip()
        if iface == "lo" or iface.startswith(("docker", "veth", "br-", "virbr")):
            continue
        f = rest.split()
        rx += int(f[0])
        tx += int(f[8])
    return rx, tx


def batteries():
    out = []
    if not os.path.isdir(PSU):
        return out
    for d in sorted(os.listdir(PSU)):
        base = os.path.join(PSU, d)
        if read(os.path.join(base, "type")) != "Battery":
            continue
        cap = read(os.path.join(base, "capacity"))
        if not cap:
            continue
        model = read(os.path.join(base, "model_name")) or d
        out.append({
            "id": d,
            "name": model,
            "pct": int(cap),
            "status": read(os.path.join(base, "status"), "Unknown"),
        })
    return out


def nvidia():
    if not shutil.which("nvidia-smi"):
        return None
    try:
        r = subprocess.run(
            ["nvidia-smi",
             "--query-gpu=name,utilization.gpu,temperature.gpu,memory.used,memory.total",
             "--format=csv,noheader,nounits"],
            capture_output=True, text=True, timeout=3)
        if r.returncode != 0 or not r.stdout.strip():
            return None
        f = [x.strip() for x in r.stdout.strip().splitlines()[0].split(",")]
        return {"name": f[0], "util": int(f[1]), "temp": int(f[2]),
                "memUsed": int(f[3]), "memTotal": int(f[4])}
    except (OSError, ValueError, subprocess.SubprocessError):
        return None


def amdgpu():
    for dev in glob.glob("/sys/class/drm/card*/device"):
        busy = read(os.path.join(dev, "gpu_busy_percent"))
        if not busy:
            continue
        mib = lambda f: int(read(os.path.join(dev, f), "0")) // 1048576
        t = glob.glob(os.path.join(dev, "hwmon/hwmon*/temp1_input"))
        return {"name": "AMD GPU", "util": int(busy),
                "temp": round(int(read(t[0], "0")) / 1000) if t else 0,
                "memUsed": mib("mem_info_vram_used"), "memTotal": mib("mem_info_vram_total")}
    return None


def gpu():
    return nvidia() or amdgpu()


def main():
    interval = 1.0
    gpu_every = 3  # nvidia-smi is slow
    pcpu, pcores = cpu_sample()
    pnet = net_sample()
    pt = time.monotonic()
    gpu_cache = gpu()
    tick = 0

    while True:
        time.sleep(interval)
        now = time.monotonic()
        dt = max(1e-3, now - pt)
        pt = now
        tick += 1

        ccpu, ccores = cpu_sample()
        cnet = net_sample()

        if tick % gpu_every == 0:
            g = gpu()
            if g is not None:
                gpu_cache = g

        sample = {
            "cpu": frac(pcpu, ccpu) if pcpu else 0.0,
            "cores": [frac(p, c) for p, c in zip(pcores, ccores)],
            "mem": mem(),
            "temps": temps(),
            "net": {
                "rx": round(max(0, cnet[0] - pnet[0]) / dt / 1048576, 3),
                "tx": round(max(0, cnet[1] - pnet[1]) / dt / 1048576, 3),
            },
            "gpu": gpu_cache,
            "batt": batteries(),
            "uptime": round(float(read("/proc/uptime", "0 0").split()[0])),
        }
        pcpu, pcores, pnet = ccpu, ccores, cnet

        sys.stdout.write(json.dumps(sample, separators=(",", ":")) + "\n")
        sys.stdout.flush()


if __name__ == "__main__":
    try:
        main()
    except (KeyboardInterrupt, BrokenPipeError):
        pass
