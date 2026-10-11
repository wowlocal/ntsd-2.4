#!/usr/bin/env python3
"""Loading time and memory footprint of the native game (MEMORY_LOADING phase 0;
a test harness).

Usage: load_memory.py OUT_DIR (--android | --local BINARY [--local BINARY ...])
                      [--apk PATH ...] [--serial S] [--lib DIR] [--label L]
                      [--scenario vs|demo] [--bodies N] [--runs K]
                      [--profile-loading SECONDS] [--call-graph G] [--frequency HZ] [--offcpu]
                      [--fresh-data] [--ticks A,B] [--sounds] [--warmup]
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
  event; against loadSeconds it tells CPU-bound from waiting), the PSS
  summary of `dumpsys meminfo` at body N, its native heap's size, allocated
  and free parts (nativeHeapMB; free is memory the allocator holds but the
  game does not), and the whole report with /proc/PID/smaps_rollup in
  OUT_DIR/<label>-meminfo.txt;
- Mac --snapshots: `heap`'s live bytes by class at the "loaded" event and at
  body N in OUT_DIR/<label>-heap-{loaded,bodies}.txt (attribution, not a gate).

With several --local binaries (or --apk builds) and --runs K it interleaves
them run by run (A B A B ...), K runs each, and prints the medians and ranges
per build: the comparison protocol of MEMORY_LOADING. Rows are appended to
OUT_DIR/load_memory.jsonl.

--ticks A,B keeps each run going from body A to body B (A at least N) and
reports its frame time there, as android_speed.py does: Android main, render
and whole-process (all threads) compute per tick from schedstat
(mainMsPerTick, renderMsPerTick, processMsPerTick, threadMsPerTick); Mac the
game thread's busy time per tick from the progress events (completeMsPerTick)
and the process's CPU per tick (processMsPerTick). The gate's load A/B so
measures loading, memory and frame time in the same interleaved runs. On
Android it also takes the memory readings again at body B (ticksEnd*: RSS,
its anonymous and file parts, swap, RSS + swap and PSS), so a longer match
shows whether memory grows.
--sounds mixes the sound effects as in play (Android; media volume held at 0),
--music plays the music too (the Android host decodes a whole track).
--warmup first runs once, unmeasured (OUT_DIR/warmup.jsonl), the last build
that is not the first one:
the first run of a phone sequence waited longest for the read-ahead whatever
its build (MEMORY_LOADING M5d), so every measured run follows another
build's run.

--fresh-data (Android) removes the asset-extraction marker before each launch,
so startupSeconds includes extracting the APK's assets again.
--profile-loading S records S seconds of simpleperf from the game's launch
(the load) with android_speed.py's recorder; the profile lands in
OUT_DIR/<label>-profile (perf.data, binary_cache, profile.json). With --offcpu
it also records where threads block (cpu-clock with --trace-offcpu: sample
periods are on- and off-CPU time).
"""
import argparse, json, os, re, statistics, subprocess, sys, tempfile, time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import android_speed as phone   # noqa: E402  (the shared device helpers)

PACKAGE, FILES = phone.PACKAGE, phone.FILES


def arguments(scenario, overlay, events=None, sounds=False, music=False):
    """android_speed.py's command line for SCENARIO with its overlay (and events file)."""
    args = phone.arguments(False, scenario, sounds, music)
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
    if o.sounds: row["sounds"] = True
    if o.music: row["music"] = True
    volume = phone.media_volume(s) if o.sounds or o.music else None
    try:
        if volume: phone.media_volume(s, 0)
        phone.shell(s, f"am force-stop {PACKAGE}")
        phone.shell(s, f"run-as {PACKAGE} sh -c 'rm -rf files/speed && mkdir -p files/speed/overlay && cat > files/args.txt'",
                    input="\n".join(arguments(o.scenario, f"{FILES}/speed/overlay", f"{FILES}/speed/events.jsonl", o.sounds, o.music)) + "\n")
        if o.fresh_data:
            # The next launch extracts the APK's assets again (MEMORY_LOADING S2).
            phone.shell(s, f"run-as {PACKAGE} rm -f files/ntsd-data/.extracted")
            row["freshData"] = True
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
            profiled = phone.record_profile(s, o.profile_loading, Path(o.out), label, o.lib, o.call_graph, o.frequency, o.offcpu)
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
                # The whole report (heap size/allocated/free by category) and the
                # kernel's per-process totals, kept for attribution.
                rollup = phone.shell(s, f"run-as {PACKAGE} cat /proc/{pid}/smaps_rollup 2>/dev/null")
                (Path(o.out) / f"{label}-meminfo.txt").write_text(meminfo + "\n--- smaps_rollup\n" + rollup)
                native = re.search(r"^\s*Native Heap\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)", meminfo, re.M)
                if native:   # Pss, Private Dirty, Private Clean, Swapped Dirty, Rss, Heap Size, Heap Alloc, Heap Free (KB)
                    row["nativeHeapMB"] = {k: round(int(native.group(i)) / 1024) for k, i in
                                           (("size", 6), ("allocated", 7), ("free", 8), ("privateDirty", 2), ("swapped", 4))}
                summary = {}
                for key in ("Java Heap", "Native Heap", "Code", "Stack", "Graphics", "Private Other", "System", "TOTAL PSS", "TOTAL RSS"):
                    m = re.search(rf"^\s*{key}:\s+(\d+)", meminfo, re.M)
                    if m: summary[key] = round(int(m.group(1)) / 1024)
                row["pssMB"] = summary
                break
            if time.time() - launched > o.timeout:
                row["error"] = "timeout"; break
            time.sleep(0.5)
        if o.ticks and "error" not in row:
            ticks_window(o, s, pid, row)
        row["peakResidentMB"] = round(peak / 1024)
        row["peakFootprintMB"] = round(footprint_peak / 1024)
        events = phone.progress(s)
        started = next((e for e in events if e.get("event") == "started"), None)
        if started and "uptime" in started:
            row["startupSeconds"] = round(started["uptime"] - started_at, 2)
        if started and "sha256HostBlocks" in started:
            row["sha256HostBlocks"] = started["sha256HostBlocks"]
        if loaded:
            row["loadSeconds"] = round(loaded["seconds"], 2)
            if "packagesWaitSeconds" in loaded:
                row["packagesWaitSeconds"] = round(loaded["packagesWaitSeconds"], 2)
            if "uptime" in loaded:
                row["startToLoadedSeconds"] = round(loaded["uptime"] - started_at, 2)
            row["loadedCounts"] = {k: loaded[k] for k in ("allocations", "audioRequests", "bitmapRequests", "files")}
        if profiled:
            row["profile"] = profiled["self"]
    finally:
        phone.shell(s, f"am force-stop {PACKAGE}")
        phone.shell(s, f"run-as {PACKAGE} rm -f files/args.txt")
        if volume: phone.media_volume(s, volume)
    return row


def ticks_window(o, s, pid, row):
    """Android frame time between bodies A and B of a running game (--ticks):
    each thread's on-CPU share of the wall time over the window, times the
    wall time per tick (android_speed.py's measure)."""
    first, last = o.ticks
    marks, cpu = {}, {}
    end_status, end_pss = None, None
    deadline = time.time() + o.timeout
    while len(cpu) < 2 and time.time() < deadline:
        bodies = max((e.get("gameplayBodies", 0) for e in phone.progress(s) if e.get("event") == "progress"), default=0)
        for name, at in (("a", first), ("b", last)):
            if name not in cpu and bodies >= at:
                cpu[name] = phone.thread_cpu(s, pid)
                if name == "b":
                    # The memory readings again at the window's end (after the CPU reading).
                    end_status = phone.shell(s, f"cat /proc/{pid}/status 2>/dev/null")
                    meminfo = phone.shell(s, f"dumpsys meminfo {pid}")
                    (Path(o.out) / f"{row['label']}-meminfo-end.txt").write_text(meminfo)
                    m = re.search(r"TOTAL PSS:\s+(\d+)", meminfo)
                    end_pss = round(int(m.group(1)) / 1024) if m else None
                    native = re.search(r"^\s*Native Heap\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)", meminfo, re.M)
                    if native:
                        row["ticksEndNativeHeapMB"] = {k: round(int(native.group(i)) / 1024) for k, i in
                                                       (("size", 6), ("allocated", 7), ("free", 8), ("privateDirty", 2), ("swapped", 4))}
        if not phone.shell(s, f"pidof {PACKAGE}").strip():
            break
        time.sleep(0.5)
    events = [e for e in phone.progress(s) if e.get("event") == "progress"]
    a = next((e for e in events if e["gameplayBodies"] >= first), None)
    b = next((e for e in events if e["gameplayBodies"] >= last), None)
    if len(cpu) < 2 or not a or not b or b["uptime"] <= a["uptime"]:
        row["ticksError"] = f"window {first}-{last} not reached"; return
    if end_status:
        for key, name in (("VmRSS", "ResidentMB"), ("RssAnon", "AnonMB"), ("RssFile", "FileMB"), ("VmSwap", "SwapMB")):
            if kib(end_status, key) is not None: row["ticksEnd" + name] = round(kib(end_status, key) / 1024)
        if "ticksEndResidentMB" in row and "ticksEndSwapMB" in row:
            row["ticksEndFootprintMB"] = row["ticksEndResidentMB"] + row["ticksEndSwapMB"]
        if end_pss is not None: row["ticksEndPssMB"] = end_pss
    tps = (b["gameplayBodies"] - a["gameplayBodies"]) / (b["uptime"] - a["uptime"])
    wall = cpu["b"][0] - cpu["a"][0]
    per_tick = {n: 1000 * (cpu["b"][1][n] - cpu["a"][1][n]) / 1e9 / wall / tps for n in cpu["b"][1]}
    row["ticksPerSecond"] = round(tps, 2)
    row["completeMsPerTick"] = round(1000 * (b["busySeconds"] - a["busySeconds"]) / (b["gameplayBodies"] - a["gameplayBodies"]), 2)
    row["mainMsPerTick"] = round(per_tick.get(PACKAGE[:15], 0.0), 2)
    row["renderMsPerTick"] = round(per_tick.get("DispatchWorker", 0.0), 2)
    row["processMsPerTick"] = round(sum(per_tick.values()), 2)
    row["threadMsPerTick"] = {n: round(v, 2) for n, v in sorted(per_tick.items(), key=lambda kv: -kv[1]) if v >= 0.1}


def cpu_seconds(pid):
    """The process's CPU time so far (user + system), from ps."""
    text = subprocess.run(["ps", "-o", "time=", "-p", str(pid)], capture_output=True, text=True).stdout.strip()
    if not text:
        return None
    parts = [float(x) for x in text.replace("-", ":").split(":")]
    seconds = 0.0
    for x in parts:
        seconds = seconds * 60 + x
    return seconds


def footprint(pid):
    text = subprocess.run(["footprint", str(pid)], capture_output=True, text=True).stdout
    now = re.search(r"phys_footprint:\s+(\d+) MB", text); peak = re.search(r"phys_footprint_peak:\s+(\d+) MB", text)
    return (int(now.group(1)) if now else None), (int(peak.group(1)) if peak else None)


def local_run(o, binary, label):
    out = Path(o.out)
    row = {"label": label, "host": "mac", "scenario": o.scenario, "bodies": o.bodies, "binary": str(binary)}
    window = {}
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
                    if "packagesWaitSeconds" in e: row["packagesWaitSeconds"] = round(e["packagesWaitSeconds"], 3)
                    row["startToLoadedSeconds"] = round(time.monotonic() - launched, 3)
                    row["loadedCounts"] = {k: e[k] for k in ("allocations", "audioRequests", "bitmapRequests", "files")}
                    row["loadedResidentMB"], _ = footprint(p.pid); snapshot("loaded")
                elif kind == "progress" and e.get("gameplayBodies", 0) >= o.bodies and "bodiesResidentMB" not in row:
                    row["bodiesResidentMB"], row["peakResidentMB"] = footprint(p.pid); snapshot("bodies")
                    if not o.ticks:
                        break
                if kind == "progress" and o.ticks:
                    # Frame time between bodies A and B (--ticks).
                    if e["gameplayBodies"] >= o.ticks[0] and "a" not in window:
                        window["a"] = (e, cpu_seconds(p.pid))
                    if e["gameplayBodies"] >= o.ticks[1]:
                        a, cpu_a = window["a"]; cpu_b = cpu_seconds(p.pid); ticks = e["gameplayBodies"] - a["gameplayBodies"]
                        row["completeMsPerTick"] = round(1000 * (e["busySeconds"] - a["busySeconds"]) / ticks, 4)
                        row["ticksPerSecond"] = round(ticks / (e["uptime"] - a["uptime"]), 2)
                        if cpu_a is not None and cpu_b is not None:
                            row["processMsPerTick"] = round(1000 * (cpu_b - cpu_a) / ticks, 3)
                        break
                if kind == "boundary":
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
    a.add_argument("--offcpu", action="store_true", help="with --profile-loading, record off-CPU time too")
    a.add_argument("--fresh-data", action="store_true")
    a.add_argument("--ticks", type=lambda t: tuple(int(x) for x in t.split(",")), default=None, help="A,B: frame time between bodies A and B")
    a.add_argument("--sounds", action="store_true")
    a.add_argument("--music", action="store_true", help="play the music as in play (Android; media volume held at 0)")
    a.add_argument("--warmup", action="store_true", help="one unmeasured run of the last build first")
    o = a.parse_args()
    if o.ticks and (len(o.ticks) != 2 or not o.bodies <= o.ticks[0] < o.ticks[1]):
        a.error("--ticks A,B needs N <= A < B")
    out = Path(o.out); out.mkdir(parents=True, exist_ok=True)
    builds = [str(b) for b in o.local] if o.local else (o.apk or [None])
    rows = []
    try:
        if o.warmup:
            # A build other than the first measured one, so that run, like
            # every other, follows another build's run (and install).
            build = next((b for b in reversed(builds) if b != builds[0]), builds[0])
            name = Path(build).parent.name if o.local else (Path(build).stem if build else "installed")
            row = local_run(o, build, f"{o.label}-warmup") if o.local else android_run(o, build, f"{o.label}-warmup")
            row["build"] = name; row["warmup"] = True
            with open(out / "warmup.jsonl", "a") as f:
                f.write(json.dumps(row) + "\n")
            print(json.dumps(row), flush=True)
        for run in range(1, o.runs + 1):
            for index, build in enumerate(builds):
                name = Path(build).parent.name if o.local else (Path(build).stem if build else "installed")
                # The run's position in the interleaved sequence keeps labels unique.
                label = f"{o.label}-{len(rows) + 1:02d}-{name}" if len(builds) > 1 or o.runs > 1 else o.label
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
                        "loadedResidentMB", "bodiesResidentMB", "mainMsPerTick", "renderMsPerTick", "processMsPerTick", "completeMsPerTick",
                        "loadedSwapMB", "bodiesSwapMB", "ticksEndResidentMB", "ticksEndSwapMB", "ticksEndFootprintMB", "ticksEndPssMB"):
                values = [r[key] for r in mine if r.get(key) is not None]
                if values:
                    summary[key] = {"median": statistics.median(values), "min": min(values), "max": max(values)}
            print(json.dumps({"summary": summary}), flush=True)


if __name__ == "__main__":
    main()
