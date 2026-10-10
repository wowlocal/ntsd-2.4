#!/usr/bin/env python3
"""Loading time and memory footprint of the native game (MEMORY_LOADING phase 0;
a test harness).

Usage: load_memory.py OUT_DIR (--android | --local BINARY [--local BINARY ...])
                      [--apk PATH ...] [--serial S] [--lib DIR] [--label L]
                      [--scenario vs|demo] [--bodies N] [--runs K]
                      [--profile-loading SECONDS] [--call-graph G] [--frequency HZ]
                      [--snapshots] [--restore-stayon]

Runs the scenario's app_e2e script as android_speed.py does (virtual clock,
music, sounds and network off, no frame capture) until the progress event of
N gameplay bodies (default 600), takes the memory readings there and stops
the game. Per run it reports:

- startupSeconds: process start -> the "started" event (startup inputs,
  window and display);
- loadSeconds: the "loaded" event's own seconds, the first loading cycle: the
  game's whole data load (DAT files, bitmaps, sounds) behind its loading screen;
- startToLoadedSeconds: process start -> the "loaded" event (startup, the
  scripted menu iterations before the load, and the load);
- peakResidentMB: VmHWM (Mac: phys_footprint_peak) at body N;
- Android peakFootprintMB: the largest VmRSS + VmSwap seen (polled every
  ~0.5 s): resident memory leaves out what the kernel swapped to zram under
  memory pressure, so RSS alone varies with the phone's other apps;
- loadedResidentMB / bodiesResidentMB: VmRSS (Mac: phys_footprint) at the
  "loaded" event and at body N, with the anonymous, file and swapped parts on
  Android;
- Android: mainLoadCpuSeconds (the game thread's on-CPU time by the "loaded"
  event; against loadSeconds it tells CPU-bound from waiting), and the PSS
  summary of `dumpsys meminfo` at body N;
- Mac --snapshots: `heap`'s live bytes by class at the "loaded" event and at
  body N in OUT_DIR/<label>-heap-{loaded,bodies}.txt (attribution, not a gate).

With several --local binaries (or --apk builds) and --runs K it interleaves
them run by run (A B A B ...), K runs each, and prints the medians and ranges
per build: the comparison protocol of MEMORY_LOADING. Rows are appended to
OUT_DIR/load_memory.jsonl.

--profile-loading S records S seconds of simpleperf from the game's launch
(the load) with android_speed.py's recorder; the profile lands in
OUT_DIR/<label>-profile (perf.data, binary_cache, profile.json).
"""
import argparse, json, os, re, statistics, subprocess, sys, tempfile, time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import android_speed as phone   # noqa: E402  (the shared device helpers)

PACKAGE, FILES = phone.PACKAGE, phone.FILES


def arguments(scenario, overlay, events=None):
    """android_speed.py's command line for SCENARIO with its overlay (and events file)."""
    args = phone.arguments(False, scenario)
    i = args.index("--overlay"); args[i + 1] = overlay
    if events is None:
        j = args.index("--events-file"); del args[j:j + 2]
    else:
        args[args.index("--events-file") + 1] = events
    return args


def kib(status, key):
    m = re.search(rf"^{key}:\s+(\d+) kB", status, re.M)
    return int(m.group(1)) if m else None


def android_run(o, apk, label):
    s = o.serial
    if apk:
        phone.install(s, apk)
    phone.wake(s)
    row = {"label": label, "host": "android", "serial": s, "scenario": o.scenario, "bodies": o.bodies,
           "apk": Path(apk).name if apk else None}
    try:
        phone.shell(s, f"am force-stop {PACKAGE}")
        phone.shell(s, f"run-as {PACKAGE} sh -c 'rm -rf files/speed && mkdir -p files/speed/overlay && cat > files/args.txt'",
                    input="\n".join(arguments(o.scenario, f"{FILES}/speed/overlay", f"{FILES}/speed/events.jsonl")) + "\n")
        launched = time.time()
        phone.shell(s, f"am start -n {PACKAGE}/android.app.NativeActivity")
        pid = ""
        while not pid and time.time() - launched < 30:
            pid = phone.shell(s, f"pidof {PACKAGE}").strip()
        if not pid:
            raise SystemExit("the game did not start")
        stat = phone.shell(s, f"cat /proc/{pid}/stat").rsplit(")", 1)[-1].split()
        started_at = int(stat[19]) / 100   # starttime (field 22): clock ticks since boot
        profiled = None
        if o.profile_loading:
            profiled = phone.record_profile(s, o.profile_loading, Path(o.out), label, o.lib, o.call_graph, o.frequency)
        loaded = None; peak = 0; footprint_peak = 0
        while True:
            status = phone.shell(s, f"cat /proc/{pid}/status 2>/dev/null")
            if not status:
                row["error"] = "the game ended before body %d" % o.bodies; break
            peak = max(peak, kib(status, "VmHWM") or 0)
            # RSS leaves out what the kernel swapped to zram under memory
            # pressure; RSS + swap is the process's whole footprint.
            footprint_peak = max(footprint_peak, (kib(status, "VmRSS") or 0) + (kib(status, "VmSwap") or 0))
            events = phone.progress(s)
            if loaded is None and (e := next((e for e in events if e.get("event") == "loaded"), None)):
                loaded = e
                row["loadedResidentMB"] = round(kib(status, "VmRSS") / 1024)
                row["loadedAnonMB"] = round(kib(status, "RssAnon") / 1024)
                row["loadedFileMB"] = round(kib(status, "RssFile") / 1024)
                row["loadedSwapMB"] = round(kib(status, "VmSwap") / 1024)
                cpu = phone.shell(s, f"cat /proc/{pid}/task/{pid}/schedstat").split()
                row["mainCpuToLoadedSeconds"] = round(int(cpu[0]) / 1e9, 2) if cpu else None
            if any(e.get("event") == "progress" and e.get("gameplayBodies", 0) >= o.bodies for e in events):
                row["bodiesResidentMB"] = round(kib(status, "VmRSS") / 1024)
                row["bodiesAnonMB"] = round(kib(status, "RssAnon") / 1024)
                row["bodiesFileMB"] = round(kib(status, "RssFile") / 1024)
                row["bodiesSwapMB"] = round(kib(status, "VmSwap") / 1024)
                meminfo = phone.shell(s, f"dumpsys meminfo {pid}")
                summary = {}
                for key in ("Java Heap", "Native Heap", "Code", "Stack", "Graphics", "Private Other", "System", "TOTAL PSS", "TOTAL RSS"):
                    m = re.search(rf"^\s*{key}:\s+(\d+)", meminfo, re.M)
                    if m: summary[key] = round(int(m.group(1)) / 1024)
                row["pssMB"] = summary
                break
            if time.time() - launched > o.timeout:
                row["error"] = "timeout"; break
            time.sleep(0.5)
        row["peakResidentMB"] = round(peak / 1024)
        row["peakFootprintMB"] = round(footprint_peak / 1024)
        events = phone.progress(s)
        started = next((e for e in events if e.get("event") == "started"), None)
        if started and "uptime" in started:
            row["startupSeconds"] = round(started["uptime"] - started_at, 2)
        if loaded:
            row["loadSeconds"] = round(loaded["seconds"], 2)
            if "uptime" in loaded:
                row["startToLoadedSeconds"] = round(loaded["uptime"] - started_at, 2)
            row["loadedCounts"] = {k: loaded[k] for k in ("allocations", "audioRequests", "bitmapRequests", "files")}
        if profiled:
            row["profile"] = profiled["self"]
    finally:
        phone.shell(s, f"am force-stop {PACKAGE}")
        phone.shell(s, f"run-as {PACKAGE} rm -f files/args.txt")
    return row


def footprint(pid):
    text = subprocess.run(["footprint", str(pid)], capture_output=True, text=True).stdout
    now = re.search(r"phys_footprint:\s+(\d+) MB", text); peak = re.search(r"phys_footprint_peak:\s+(\d+) MB", text)
    return (int(now.group(1)) if now else None), (int(peak.group(1)) if peak else None)


def local_run(o, binary, label):
    out = Path(o.out)
    row = {"label": label, "host": "mac", "scenario": o.scenario, "bodies": o.bodies, "binary": str(binary)}
    with tempfile.TemporaryDirectory(prefix="ntsd-load-") as overlay:
        launched = time.monotonic()
        p = subprocess.Popen([str(binary), *arguments(o.scenario, overlay)], stdout=subprocess.PIPE, text=True,
                             env={**os.environ, "TZ": "Etc/GMT-1"})
        def snapshot(tag):
            if o.snapshots:
                heap = subprocess.run(["heap", "-sortBySize", str(p.pid)], capture_output=True, text=True).stdout
                (out / f"{label}-heap-{tag}.txt").write_text(heap)
        try:
            for line in p.stdout:
                if not line.startswith("{"):
                    continue
                e = json.loads(line); kind = e.get("event")
                if kind == "started" and "startupSeconds" not in row:
                    row["startupSeconds"] = round(time.monotonic() - launched, 3)
                elif kind == "loaded" and "loadSeconds" not in row:
                    row["loadSeconds"] = round(e["seconds"], 3)
                    row["startToLoadedSeconds"] = round(time.monotonic() - launched, 3)
                    row["loadedCounts"] = {k: e[k] for k in ("allocations", "audioRequests", "bitmapRequests", "files")}
                    row["loadedResidentMB"], _ = footprint(p.pid); snapshot("loaded")
                elif kind == "progress" and e.get("gameplayBodies", 0) >= o.bodies:
                    row["bodiesResidentMB"], row["peakResidentMB"] = footprint(p.pid); snapshot("bodies")
                    break
                elif kind == "boundary":
                    row["error"] = e.get("error"); break
        finally:
            p.terminate(); p.wait()
    return row


def main():
    a = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    a.add_argument("out")
    a.add_argument("--android", action="store_true"); a.add_argument("--local", action="append", type=Path, default=[])
    a.add_argument("--apk", action="append", default=[]); a.add_argument("--serial", default=os.environ.get("ANDROID_SERIAL", "R58R36F7VFD"))
    a.add_argument("--lib", type=Path, default=phone.DEFAULT_LIB); a.add_argument("--label", default=time.strftime("%Y%m%d-%H%M%S"))
    a.add_argument("--scenario", choices=["vs", "demo"], default="vs"); a.add_argument("--bodies", type=int, default=600)
    a.add_argument("--runs", type=int, default=1); a.add_argument("--timeout", type=int, default=1200)
    a.add_argument("--profile-loading", type=int, default=0)
    a.add_argument("--call-graph", default="dwarf,8192"); a.add_argument("--frequency", type=int, default=200)
    a.add_argument("--snapshots", action="store_true"); a.add_argument("--restore-stayon", action="store_true")
    o = a.parse_args()
    out = Path(o.out); out.mkdir(parents=True, exist_ok=True)
    builds = [str(b) for b in o.local] if o.local else (o.apk or [None])
    rows = []
    try:
        for run in range(1, o.runs + 1):
            for index, build in enumerate(builds):
                name = Path(build).parent.name if o.local else (Path(build).stem if build else "installed")
                label = f"{o.label}-{name}-{run}" if len(builds) > 1 or o.runs > 1 else o.label
                row = local_run(o, build, label) if o.local else android_run(o, build, label)
                row["build"] = name; rows.append(row)
                with open(out / "load_memory.jsonl", "a") as f:
                    f.write(json.dumps(row) + "\n")
                print(json.dumps(row), flush=True)
    finally:
        if o.android and o.restore_stayon:
            phone.shell(o.serial, "svc power stayon false")
    if len(rows) > 1:
        for name in dict.fromkeys(r["build"] for r in rows):
            mine = [r for r in rows if r["build"] == name]
            summary = {"build": name, "runs": len(mine)}
            for key in ("startupSeconds", "loadSeconds", "startToLoadedSeconds", "peakResidentMB", "peakFootprintMB",
                        "loadedResidentMB", "bodiesResidentMB"):
                values = [r[key] for r in mine if r.get(key) is not None]
                if values:
                    summary[key] = {"median": statistics.median(values), "min": min(values), "max": max(values)}
            print(json.dumps({"summary": summary}), flush=True)


if __name__ == "__main__":
    main()
