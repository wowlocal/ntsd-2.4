#!/usr/bin/env python3
"""Gameplay speed of the Android app on a device or emulator, from the game's
own progress events (CORE_REALTIME phase 0; a test harness).

Usage: android_speed.py OUT_DIR [--serial S] [--apk PATH] [--label L]
                        [--profile SECONDS] [--lib DIR] [--call-graph fp|dwarf,N]
                        [--frequency HZ]

Runs the debuggable build (local.ntsd.port; the release build cannot be
scripted) with app_e2e's computer-vs script, music, sounds and network off and
no frame capture, and reports ticks per second: gameplay bodies 300 -> 1800
over the app's uptime. Also the busy seconds (the game thread's busy time: the
measure where the game reaches its own paced rate, as on the emulator), the run time and the peak
resident memory (VmHWM). Appends a JSON line to OUT_DIR/speed.jsonl.

With --profile it records that many seconds of simpleperf call graphs
(`simpleperf record --app`, frame pointers) once gameplay reaches 300 bodies,
symbolizes them with the unstripped libNTSDAndroid.so in --lib, and writes
OUT_DIR/<label>-profile/profile.json: inclusive shares of the per-cycle phases
and the top symbols (perf.data and the symbol cache beside it); cpu-clock
samples where the device has no hardware counters (emulators).
security.perf_harden is lowered only for the recording and
restored, and debug.perf_event_max_sample_rate is cleared again.

The device is kept awake (svc power stayon usb). It is left that way so it
cannot lock between runs (a locked phone pauses the game behind the lock
screen); --restore-stayon restores `svc power stayon false` afterwards. A
swipe lock screen is dismissed (wm dismiss-keyguard); a device still showing its
lock screen (a PIN) is refused at once.
"""
import argparse, collections, json, os, subprocess, sys, time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SDK = Path("/opt/homebrew/share/android-commandlinetools")
NDK = SDK / "ndk/30.0.16248370"
ADB = str(SDK / "platform-tools/adb")
PACKAGE = "local.ntsd.port"
FILES = f"/data/user/0/{PACKAGE}/files"
DEFAULT_LIB = Path("/Volumes/X5/ntsd-2.4-research/crossplatform/build-android-aarch64/out/Products/Release-android-aarch64")

# Inclusive phases of a gameplay cycle (symbol substrings).
PHASES = {
    "front-buffer drawing": "OriginalMacDisplayBackendC12performFront",
    "display perform": "OriginalMacDisplayBackendC7perform",
    "Android window drawing": "WindowHostC4draw",
    "gameplay session": "OriginalApplicationGameplaySessionV7advance",
    "gameplay body": "OriginalGameplayBody",
    "loaded cycle": "OriginalApplicationLoadedCycleSessionV7advance",
    "loaded match entry": "OriginalLoadedMatchEntry",
    "bindings store": "OriginalApplicationMatchBindingsV5store",
    "bindings read": "OriginalApplicationMatchBindingsV4read",
    "loaded menu attempt": "OriginalApplicationLoadedMenuSessionV7Attempt",
    "menu state replace": "OriginalApplicationMenuSessionV5StateV7replace",
    "observed iteration": "OriginalApplicationObservedIteration",
}


def adb(serial, *args, input=None, check=False):
    return subprocess.run([ADB, "-s", serial, *args], input=input, capture_output=True, text=True, check=check)


def shell(serial, command, input=None):
    return adb(serial, "shell", command, input=input).stdout


def arguments():
    script = (ROOT / "tools/app_e2e_computer_vs.script").read_text().strip() + "; 9200 exit"
    return ["--events-file", f"{FILES}/speed/events.jsonl", "--tz", "Etc/GMT-1", "--original", "--mute-music",
            "--mute-sounds", "--no-network", "--overlay", f"{FILES}/speed/overlay", "--virtual-clock", "123456789",
            "8", "--script-clock", "gameplay", "--script", script]


def sha256(path):
    import hashlib
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def installed_sha256(serial):
    """SHA-256 of the installed base.apk, or None when the package is not installed."""
    path = shell(serial, f"pm path {PACKAGE}").strip().removeprefix("package:")
    if not path.endswith(".apk"):
        return None
    out = shell(serial, f"sha256sum {path}").split()
    return out[0] if out else None


def progress(serial):
    text = shell(serial, f"run-as {PACKAGE} cat files/speed/events.jsonl 2>/dev/null")
    return [json.loads(l) for l in text.splitlines() if l.startswith("{")]


def record_profile(serial, seconds, out, label, lib, call_graph="fp", frequency=1000):
    simpleperf = NDK / "simpleperf/bin/android/arm64/simpleperf"
    folder = out / f"{label}-profile"; folder.mkdir(exist_ok=True)
    data = folder / "perf.data"
    adb(serial, "push", str(simpleperf), "/data/local/tmp/simpleperf")
    shell(serial, "chmod 755 /data/local/tmp/simpleperf")
    shell(serial, "setprop security.perf_harden 0")
    try:
        # Emulators have no hardware counters: sample the cpu-clock software event there.
        hardware = "cpu-cycles" in shell(serial, "/data/local/tmp/simpleperf list hw")
        event = "" if hardware else "-e cpu-clock "
        r = adb(serial, "shell", f"/data/local/tmp/simpleperf record --app {PACKAGE} {event}--call-graph {call_graph} "
                f"--duration {seconds} -f {frequency} -o /data/local/tmp/ntsd-perf.data")
        adb(serial, "pull", "/data/local/tmp/ntsd-perf.data", str(data))
    finally:
        shell(serial, "rm -f /data/local/tmp/ntsd-perf.data /data/local/tmp/simpleperf")
        shell(serial, "setprop security.perf_harden 1")
        shell(serial, "setprop debug.perf_event_max_sample_rate ''")
    if not data.exists() or data.stat().st_size == 0:
        raise SystemExit("simpleperf produced no data: " + (r.stdout + r.stderr)[-400:])
    # binary_cache_builder writes ./binary_cache next to the data.
    subprocess.run([sys.executable, str(NDK / "simpleperf/binary_cache_builder.py"), "-i", str(data), "-lib", str(lib),
                    "--disable_adb_root"], capture_output=True, cwd=folder)
    cache = folder / "binary_cache"
    sys.path.insert(0, str(NDK / "simpleperf"))
    from simpleperf_report_lib import ReportLib
    report = ReportLib(); report.SetRecordFile(str(data)); report.SetSymfs(str(cache))
    total, inclusive, own = 0, collections.Counter(), collections.Counter()
    while (sample := report.GetNextSample()) is not None:
        total += 1
        symbol = report.GetSymbolOfCurrentSample().symbol_name
        chain = report.GetCallChainOfCurrentSample()
        names = [symbol] + [chain.entries[i].symbol.symbol_name for i in range(chain.nr)]
        own[symbol[:100]] += 1
        for phase, key in PHASES.items():
            if any(key in n for n in names):
                inclusive[phase] += 1
    report.Close()
    result = {"samples": total, "seconds": seconds,
              "inclusive": {k: round(100 * v / total, 1) for k, v in inclusive.most_common()},
              "self": {k: round(100 * v / total, 1) for k, v in own.most_common(15)}}
    (folder / "profile.json").write_text(json.dumps(result, indent=1) + "\n")
    return result


def main():
    a = argparse.ArgumentParser()
    a.add_argument("out"); a.add_argument("--serial", default=os.environ.get("ANDROID_SERIAL", "R58R36F7VFD"))
    a.add_argument("--apk"); a.add_argument("--label", default=time.strftime("%Y%m%d-%H%M%S"))
    a.add_argument("--profile", type=int, default=0); a.add_argument("--lib", type=Path, default=DEFAULT_LIB)
    a.add_argument("--timeout", type=int, default=1800)
    # dwarf,16384 at -f 200 gives whole stacks where frame pointers stop
    # (runtime leaf functions) at ~3 MB per second of data on the device.
    a.add_argument("--call-graph", default="fp"); a.add_argument("--frequency", type=int, default=1000)
    a.add_argument("--restore-stayon", action="store_true")
    o = a.parse_args()
    out = Path(o.out); out.mkdir(parents=True, exist_ok=True)
    s = o.serial
    if o.apk and installed_sha256(s) == sha256(o.apk):
        o.apk = None   # already installed: a same-size reinstall needs room for two copies
    if o.apk:
        # -d: builds from older commits have lower version codes (debuggable build).
        r = adb(s, "install", "-r", "-d", o.apk)
        if r.returncode != 0 and "INSUFFICIENT_STORAGE" in r.stdout + r.stderr:
            # The test phone's storage is nearly full and install -r keeps the
            # old code until the new one is in place (two 222 MB APKs plus
            # libraries). First let the system trim app caches (disposable by
            # contract; it does the same under storage pressure) and retry.
            adb(s, "shell", "pm trim-caches 4G")
            r = adb(s, "install", "-r", "-d", o.apk)
        if r.returncode != 0 and "INSUFFICIENT_STORAGE" in r.stdout + r.stderr:
            # Then remove the old code but keep the app's data (-k: files/ntsd-data
            # is not extracted again for the same assets).
            adb(s, "shell", f"pm uninstall -k {PACKAGE}")
            r = adb(s, "install", "-d", o.apk)
            if r.returncode != 0:
                raise SystemExit(f"install failed after `pm uninstall -k` ({PACKAGE} is uninstalled, its data kept): "
                                 + (r.stdout + r.stderr).strip()[-300:])
        if r.returncode != 0:
            raise SystemExit("install failed: " + (r.stdout + r.stderr).strip()[-300:])
    shell(s, "svc power stayon usb")
    shell(s, "input keyevent KEYCODE_WAKEUP")
    if "isKeyguardShowing=true" in shell(s, "dumpsys window"):
        # A swipe lock goes away on request; a secure lock shows its PIN screen and stays.
        shell(s, "wm dismiss-keyguard"); time.sleep(3)
        # Fallbacks for a swipe lock that ignores the request after a long
        # sleep: a swipe up, then the MENU key (unlocks a non-secure keyguard).
        for gesture in ("input swipe 360 1400 360 300 300", "input keyevent 82"):
            if "isKeyguardShowing=true" not in shell(s, "dumpsys window"):
                break
            shell(s, gesture); time.sleep(2)
        if "isKeyguardShowing=true" in shell(s, "dumpsys window"):
            raise SystemExit(f"{s} shows its lock screen: unlock it (the game pauses behind it)")
    try:
        shell(s, f"am force-stop {PACKAGE}")
        shell(s, f"run-as {PACKAGE} sh -c 'rm -rf files/speed && mkdir -p files/speed/overlay && cat > files/args.txt'",
              input="\n".join(arguments()) + "\n")
        start = time.time()
        shell(s, f"am start -n {PACKAGE}/android.app.NativeActivity")
        time.sleep(5)
        peak, profiled = 0, None
        while (pid := shell(s, f"pidof {PACKAGE}").strip()):
            hwm = shell(s, f"grep VmHWM /proc/{pid}/status 2>/dev/null").split()
            if len(hwm) > 1 and hwm[1].isdigit():
                peak = max(peak, int(hwm[1]))
            if o.profile and profiled is None:
                if any(e.get("event") == "progress" and e.get("gameplayBodies", 0) >= 300 for e in progress(s)):
                    profiled = record_profile(s, o.profile, out, o.label, o.lib, o.call_graph, o.frequency)
            if time.time() - start > o.timeout:
                shell(s, f"am force-stop {PACKAGE}"); break
            time.sleep(5)
        events = progress(s)
    finally:
        shell(s, f"run-as {PACKAGE} rm -f files/args.txt")
        if o.restore_stayon:
            shell(s, "svc power stayon false")
    marks = [e for e in events if e.get("event") == "progress"]
    row = {"label": o.label, "serial": s, "runSeconds": round(time.time() - start), "peakResidentMB": peak // 1024}
    if len(marks) > 1:
        first, last = marks[0], marks[-1]
        row.update(ticksPerSecond=round((last["gameplayBodies"] - first["gameplayBodies"]) / (last["uptime"] - first["uptime"]), 2),
                   busySeconds=round(last.get("busySeconds", 0), 2), bodies=last["gameplayBodies"])
    else:
        row["error"] = "no progress events: " + ", ".join(str(e.get("event")) for e in events[:6])
    if profiled:
        row["profile"] = profiled["inclusive"]
    with open(out / "speed.jsonl", "a") as f:
        f.write(json.dumps(row) + "\n")
    print(json.dumps(row))


if __name__ == "__main__":
    main()
