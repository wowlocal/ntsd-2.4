#!/usr/bin/env python3
"""Loading time and memory footprint of the native game (MEMORY_LOADING phase 0;
a test harness).

Usage: load_memory.py OUT_DIR (--android | --local BINARY [--local BINARY ...]
                               | --web BUILD_DIR [...] | --wasi BUILD_DIR [...])
                      [--apk PATH ...] [--serial S] [--lib DIR] [--label L]
                      [--scenario vs|demo] [--bodies N] [--runs K]
                      [--profile-loading SECONDS] [--call-graph G] [--frequency HZ] [--offcpu]
                      [--fresh-data] [--ticks A,B] [--sounds] [--warmup]
                      [--snapshots] [--restore-stayon] [--game-arg=ARG ...]

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
shows whether memory grows. It also reports the CPU spent since launch by
body B: the whole process (cpuToEndSeconds, from /proc/PID/stat, exited
threads included) and each live thread (threadCpuToEndSeconds), so work that
moved in time (a whole-track decode at its start against a decode as it
plays) compares by its total; and the AAudio underruns the app reported
(xruns, by stream kind).
--sounds mixes the sound effects as in play (Android; media volume held at 0),
--music plays the music too (the Android host decodes a whole track).
--warmup first runs once, unmeasured (OUT_DIR/warmup.jsonl), the last build
that is not the first one:
the first run of a phone sequence waited longest for the read-ahead whatever
its build (MEMORY_LOADING M5d), so every measured run follows another
build's run.

--web BUILD_DIR runs the browser host (BUILD_DIR's NTSDWeb.wasm through
web_run.mjs, in NTSD_BROWSER_ENGINE's engine) and --wasi BUILD_DIR the
headless build under Node's WASI (NTSDHeadless.wasm through wasi_run.mjs)
with the same arguments (TVOS_WEB W3a): load and frame time from the same
events (loadSeconds; startedToLoadedSeconds, the game's own clock from the
"started" to the "loaded" event, which includes the loading packages WASI
computes inline before the load; completeMsPerTick: the game's busy time per
tick from the progress events, rendering included there as it runs inline;
ticksPerSecond from their uptime, mostly the virtual clock's pacing;
windowCycles, the cycles at A and B, the same on every host when the run is
deterministic; exitCode, informational: the harness ends the runner), no
wall-clock startup (the worker buffers its output and flushes it at 64 KiB
or at exit, so a browser run plays to its script's exit before its events
arrive), no process memory or CPU readings (the runner's process is not the
game's; the module's linear memory is in each scenario run's metrics).
local_run reports startedToLoadedSeconds too. --ticks A and B are multiples
of 300 (progress events come every 300 bodies). --game-arg=ARG adds ARG to
the game's command line on the Mac, browser and WASI hosts (not Android),
e.g. --synchronous-render: the Mac
renders on its game thread, as WASI does, for a like-for-like
completeMsPerTick).

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
                    # The process's CPU since launch (utime + stime, clock ticks).
                    fields = phone.shell(s, f"cat /proc/{pid}/stat").rsplit(")", 1)[-1].split()
                    if len(fields) > 12: row["cpuToEndSeconds"] = round((int(fields[11]) + int(fields[12])) / 100, 2)
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
    row["threadCpuToEndSeconds"] = {n: round(v / 1e9, 2) for n, v in sorted(cpu["b"][1].items(), key=lambda kv: -kv[1]) if v >= 5e7}
    presents = [e for e in phone.progress(s) if e.get("event") == "androidPresent" and "xruns" in e]
    if presents: row["xruns"] = presents[-1]["xruns"]


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
    window, started_uptime = {}, None
    with tempfile.TemporaryDirectory(prefix="ntsd-load-") as overlay:
        launched = time.monotonic()
        p = subprocess.Popen([str(binary), *arguments(o.scenario, overlay), *o.game_arg], stdout=subprocess.PIPE, text=True,
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
                    row["startupSeconds"] = round(time.monotonic() - launched, 3); started_uptime = e.get("uptime")
                elif kind == "loaded" and "loadSeconds" not in row:
                    row["loadSeconds"] = round(e["seconds"], 3)
                    if started_uptime is not None and "uptime" in e:   # the game's clock: "started" to "loaded"
                        row["startedToLoadedSeconds"] = round(e["uptime"] - started_uptime, 3)
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


def script_run(o, kind, build, label):
    """--web or --wasi: the game in the browser host or under Node's WASI, read as local_run reads it."""
    build = Path(build).resolve()
    row = {"label": label, "host": kind, "scenario": o.scenario, "bodies": o.bodies, "binary": str(build)}
    if kind == "web":
        row["engine"] = os.environ.get("NTSD_BROWSER_ENGINE", "chromium")
    found = sorted((Path.home() / ".local/share/fnm/node-versions").glob("v26.*/installation/bin/node"))
    node = os.environ.get("NTSD_NODE") or (str(found[-1]) if found else "node")
    music = ROOT / "native/Sources/NTSDMacPlatform/Resources/OriginalMusic"
    window, started_uptime = {}, None
    with tempfile.TemporaryDirectory(prefix="ntsd-load-") as out:
        Path(out, "overlay").mkdir()
        game = ["--resources", "/app/NTSDNative_NTSDCore.bundle", "--music-dir", "/music", *arguments(o.scenario, "/out/overlay"), *o.game_arg]
        if kind == "web":
            command = [node, str(ROOT / "tools/crossplatform/web_run.mjs"), "--ro", f"/app={build}", "--ro", f"/music={music}",
                       "--map", f"/out={out}", "--argv0", "/app/NTSDWeb.wasm", "--canvas", "--", str(build / "NTSDWeb.wasm"), *game]
        else:
            command = [node, "--disable-warning=ExperimentalWarning", str(ROOT / "tools/crossplatform/wasi_run.mjs"), "--map", f"/app={build}",
                       "--map", f"/music={music}", "--map", f"/out={out}", "--argv0", "/app/NTSDHeadless.wasm", "--",
                       str(build / "NTSDHeadless.wasm"), *game]
        p = subprocess.Popen(command, stdout=subprocess.PIPE, text=True, env={**os.environ, "TZ": "Etc/GMT-1"})
        try:
            for line in p.stdout:
                if not line.startswith("{"):
                    continue
                e = json.loads(line); kind_ = e.get("event")
                # Only the game's own clocks: the worker buffers its output, so
                # an event's arrival time here says nothing (no startupSeconds).
                # "started" to "loaded" includes what WASI does before the load
                # (the loading packages, inline there; the Mac overlaps them).
                if kind_ == "started" and started_uptime is None:
                    started_uptime = e.get("uptime")
                elif kind_ == "loaded" and "loadSeconds" not in row:
                    row["loadSeconds"] = round(e["seconds"], 3)
                    if started_uptime is not None and "uptime" in e:
                        row["startedToLoadedSeconds"] = round(e["uptime"] - started_uptime, 3)
                    if "packagesWaitSeconds" in e: row["packagesWaitSeconds"] = round(e["packagesWaitSeconds"], 3)
                    row["loadedCounts"] = {k: e[k] for k in ("allocations", "audioRequests", "bitmapRequests", "files") if k in e}
                elif kind_ == "progress" and e.get("gameplayBodies", 0) >= o.bodies and not o.ticks:
                    break
                if kind_ == "progress" and o.ticks:
                    if e["gameplayBodies"] >= o.ticks[0] and "a" not in window:
                        window["a"] = e
                    if e["gameplayBodies"] >= o.ticks[1]:
                        a = window["a"]; ticks = e["gameplayBodies"] - a["gameplayBodies"]
                        row["completeMsPerTick"] = round(1000 * (e["busySeconds"] - a["busySeconds"]) / ticks, 4)
                        row["ticksPerSecond"] = round(ticks / (e["uptime"] - a["uptime"]), 2)   # mostly the virtual clock's pacing
                        row["windowCycles"] = [a.get("cycles"), e.get("cycles")]   # the same on every host if deterministic
                        break
                if kind_ == "boundary":
                    row["error"] = e.get("error"); break
        finally:
            p.terminate()
            try: p.wait(timeout=30)
            except subprocess.TimeoutExpired: p.kill(); p.wait()
            row["exitCode"] = p.returncode
    if "loadSeconds" not in row and "error" not in row:
        row["error"] = f"no loaded event (runner exit {p.returncode})"
    if o.ticks and "completeMsPerTick" not in row and "error" not in row:
        row["ticksError"] = f"window {o.ticks[0]}-{o.ticks[1]} not reached"
    return row


def main():
    a = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    a.add_argument("out")
    a.add_argument("--android", action="store_true"); a.add_argument("--local", action="append", type=Path, default=[])
    a.add_argument("--web", action="append", type=Path, default=[]); a.add_argument("--wasi", action="append", type=Path, default=[])
    a.add_argument("--game-arg", action="append", default=[], help="an argument added to the game's command line (--game-arg=--synchronous-render)")
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
    if o.ticks and (o.ticks[0] % 300 or o.ticks[1] % 300):
        a.error("--ticks A,B: progress events come every 300 bodies, so A and B are multiples of 300")
    if o.local and (o.web or o.wasi):
        a.error("--local and --web/--wasi measure in separate runs")
    out = Path(o.out); out.mkdir(parents=True, exist_ok=True)
    # Each build is (kind, path): kind "web" or "wasi" (W3a), else None (a Mac binary or an APK).
    scripted = [("web", str(b)) for b in o.web] + [("wasi", str(b)) for b in o.wasi]
    builds = [(None, str(b)) for b in o.local] if o.local else scripted if scripted else [(None, b) for b in (o.apk or [None])]
    def measure(build, label):
        kind, path = build
        if kind: return script_run(o, kind, path, label)
        return local_run(o, path, label) if o.local else android_run(o, path, label)
    def name_of(build):
        kind, path = build
        return f"{kind}-{Path(path).name}" if kind else Path(path).parent.name if o.local else (Path(path).stem if path else "installed")
    rows = []
    try:
        if o.warmup:
            # A build other than the first measured one, so that run, like
            # every other, follows another build's run (and install).
            build = next((b for b in reversed(builds) if b != builds[0]), builds[0])
            name = name_of(build)
            row = measure(build, f"{o.label}-warmup")
            row["build"] = name; row["warmup"] = True
            with open(out / "warmup.jsonl", "a") as f:
                f.write(json.dumps(row) + "\n")
            print(json.dumps(row), flush=True)
        for run in range(1, o.runs + 1):
            for index, build in enumerate(builds):
                name = name_of(build)
                # The run's position in the interleaved sequence keeps labels unique.
                label = f"{o.label}-{len(rows) + 1:02d}-{name}" if len(builds) > 1 or o.runs > 1 else o.label
                row = measure(build, label)
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
            for key in ("startupSeconds", "loadSeconds", "startToLoadedSeconds", "startedToLoadedSeconds", "peakResidentMB", "peakFootprintMB",
                        "loadedResidentMB", "bodiesResidentMB", "mainMsPerTick", "renderMsPerTick", "processMsPerTick", "completeMsPerTick",
                        "loadedSwapMB", "bodiesSwapMB", "ticksEndResidentMB", "ticksEndSwapMB", "ticksEndFootprintMB", "ticksEndPssMB", "cpuToEndSeconds"):
                values = [r[key] for r in mine if r.get(key) is not None]
                if values:
                    summary[key] = {"median": statistics.median(values), "min": min(values), "max": max(values)}
            print(json.dumps({"summary": summary}), flush=True)


if __name__ == "__main__":
    main()
