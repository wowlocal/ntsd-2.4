#!/usr/bin/env python3
"""Two-process ONLINE GAME check on any host: the UI scripts, names, seeds and
assertions of the retained probe (X5 network-app-client-20261002/pair_probe.py,
docs/research/NETWORK_PLAY.md "Two-process probe"), run with a chosen binary.

Usage: pair_probe.py OUT_DIR (--local BINARY | --linux-sdl BUILD_DIR | --wine RUN_DIR | --android RUN_DIR
                             | --cross HOST CLIENT) [--trace]

`--local` runs both processes on this machine (the AppKit NTSDNative or a
local NTSDSDL). `--linux-sdl` runs both NTSDSDL processes in one
ntsd-linux-runtime:noble container (SDL offscreen/dummy drivers, SDL3 from
$NTSD_SDL_LIB): real TCP over the container's loopback. Each process gets
--network-loopback (127.0.0.1 as the local address), --network-ready-state and
--exit-after-network-ready; no game state is injected. `--wine` runs two
RUN_DIR/NTSDSDL.exe processes in the CrossOver bottle ntsd-xplat-test (test
harness; real Winsock through Wine, SDL offscreen/dummy drivers). `--android`
pushes RUN_DIR (NTSDHeadless built for Android, libc++_shared.so, the resource
bundle; matrix.py stages it) and the music to /data/local/tmp/ntsd-pair on the
device adb reaches (an emulator: a test harness) and runs both headless
processes there over the device's loopback ($ADB names adb). `--cross HOST
CLIENT` runs the host and the client on different platforms, each given as
local:BINARY, wine:RUN_DIR (an exe in the bottle) or android:RUN_DIR (headless
in the emulator); the client still connects to 127.0.0.1:12345, which adb
forwards into the emulator (Android host) or back to this Mac (Android client).
`--trace` adds
--network-trace OUT_DIR/<role>-trace.jsonl (socket replies, for diagnosis);
NTSD_PAIR_STRACE=1 wraps the Linux processes in strace (OUT_DIR/<role>.strace).
"""
import hashlib, json, os, shutil, socket, subprocess, sys, time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MUSIC = ROOT / "native/Sources/NTSDMacPlatform/Resources/OriginalMusic"
CONTROL = ROOT / "native/Sources/NTSDCore/Resources/OriginalStartup/data/control.txt"
HOST_SCRIPT = "20 click 410 262; 60 click 400 287; 2000 exit"
CLIENT_SCRIPT = "; ".join(["20 click 410 262", "60 click 400 317"]
                          + [f"{100 + 25 * i} key {190 if ch == '.' else ord(ch)}" for i, ch in enumerate("127.0.0.1")]
                          + ["350 key 13", "2000 exit"])
ROLES = [("host", 123456789, HOST_SCRIPT, ["Host1", "Host2", "Host3", "Host4"]),
         ("client", 271828182, CLIENT_SCRIPT, ["Peer1", "Peer2", "Peer3", "Peer4"])]


def overlay(out, role, names):
    o = out / f"{role}-overlay"; (o / "data").mkdir(parents=True)
    lines = CONTROL.read_text().splitlines(); lines[4] = " ".join(names)
    (o / "data/control.txt").write_text("\n".join(lines) + "\n")


TRACE = "--trace" in sys.argv


def arguments(base, role, seed, script, music):
    return [*(["--network-trace", f"{base}/{role}-trace.jsonl"] if TRACE else []), "--original", "--mute-music", "--mute-sounds", "--overlay", f"{base}/{role}-overlay",
            "--virtual-clock", str(seed), "8", "--network-loopback", "--network-ready-state", f"{base}/{role}.json",
            "--exit-after-network-ready", *(["--music-dir", music] if music else []), "--script", script]


def run_local(out, binary):
    music = str(MUSIC) if "NTSDSDL" in Path(binary).name else None
    with socket.socket() as s:
        s.bind(("127.0.0.1", 12345))
    procs = {}
    for role, seed, script, _ in ROLES:
        log = (out / f"{role}.log").open("x")
        procs[role] = (subprocess.Popen([binary, *arguments(out, role, seed, script, music)], cwd=ROOT, stdout=log,
                                        stderr=subprocess.STDOUT, env={**os.environ, "TZ": "Etc/GMT-1"}), log)
        if role == "host":
            deadline = time.monotonic() + 30
            while time.monotonic() < deadline:
                rows = subprocess.run(["lsof", "-nP", "-a", "-p", str(procs[role][0].pid), "-iTCP:12345", "-sTCP:LISTEN", "-Fn"],
                                      capture_output=True, text=True).stdout
                if "n127.0.0.1:12345" in rows:
                    break
                time.sleep(0.1)
            else:
                raise AssertionError("host did not open its loopback listener")
    codes = {}
    for role, (p, log) in procs.items():
        codes[role] = p.wait(timeout=120); log.close()
    return codes


def run_wine(out, run_dir):
    cx = "/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine"
    def win(p): return "Z:" + str(p).replace("/", "\\")
    with socket.socket() as s:
        s.bind(("127.0.0.1", 12345))
    # CrossOver's wine drops SDL_* variables; NTSDSDL reads these as SDL hints.
    env = {**os.environ, "TZ": "Etc/GMT-1", "NTSD_SDL_VIDEO_DRIVER": "offscreen", "NTSD_SDL_AUDIO_DRIVER": "dummy"}
    procs = {}
    for role, seed, script, _ in ROLES:
        args = [a if not a.startswith(str(out)) else win(a) for a in arguments(out, role, seed, script, str(MUSIC))]
        args = [win(a) if a == str(MUSIC) else a for a in args]
        log = (out / f"{role}.raw").open("x")
        procs[role] = (subprocess.Popen([cx, "--bottle", "ntsd-xplat-test", "--wait-children", win(Path(run_dir).resolve() / "NTSDSDL.exe"), *args],
                                        stdout=log, stderr=subprocess.DEVNULL, env=env), log)
        if role == "host":
            deadline = time.monotonic() + 60
            while time.monotonic() < deadline:
                rows = subprocess.run(["lsof", "-nP", "-iTCP:12345", "-sTCP:LISTEN", "-Fn"], capture_output=True, text=True).stdout
                if "n127.0.0.1:12345" in rows:
                    break
                time.sleep(0.2)
            else:
                raise AssertionError("host did not open its loopback listener")
    codes = {}
    for role, (p, log) in procs.items():
        codes[role] = p.wait(timeout=300); log.close()
        (out / f"{role}.log").write_text((out / f"{role}.raw").read_text().replace("\r\n", "\n"))
    return codes


def run_linux(out, build):
    script = ["set -u", "export TZ=Etc/GMT-1 SDL_VIDEO_DRIVER=offscreen SDL_AUDIO_DRIVER=dummy LD_LIBRARY_PATH=/sdl"]
    if os.environ.get("NTSD_PAIR_STRACE"):   # diagnosis only: syscall traces of both processes
        script.append("apt-get update -qq >/dev/null 2>&1; apt-get install -y -qq strace >/dev/null 2>&1")
    for role, seed, s, _ in ROLES:
        args = " ".join("'" + a.replace("'", "'\\''") + "'" for a in arguments("/out", role, seed, s, "/music"))
        wrap = f"strace -f -tt -e trace=network -o /out/{role}.strace " if os.environ.get("NTSD_PAIR_STRACE") else ""
        script.append(f"{wrap}/app/NTSDSDL {args} >/out/{role}.log 2>&1 & {role}=$!")
        if role == "host":   # 127.0.0.1:12345 (0100007F:3039) in state LISTEN (0A)
            script.append("for _ in $(seq 300); do grep -q ' 0100007F:3039 00000000:0000 0A' /proc/net/tcp && break; sleep 0.1; done")
            script.append("grep -q ' 0100007F:3039 00000000:0000 0A' /proc/net/tcp || { echo 'no listener' >/out/error; kill $host; exit 1; }")
    script += ["wait $host; echo $? >/out/host.exit", "wait $client; echo $? >/out/client.exit"]
    (out / "run.sh").write_text("\n".join(script) + "\n")
    subprocess.run(["docker", "run", "--rm", "-v", f"{build}:/app:ro", "-v", f"{os.environ['NTSD_SDL_LIB']}:/sdl:ro",
                    "-v", f"{MUSIC}:/music:ro", "-v", f"{out}:/out", "ntsd-linux-runtime:noble", "bash", "/out/run.sh"],
                   check=True, timeout=300)
    if (out / "error").exists():
        raise AssertionError((out / "error").read_text())
    return {role: int((out / f"{role}.exit").read_text()) for role, *_ in ROLES}


def run_android(out, run_dir):
    adb = os.environ.get("ADB", "adb"); device = "/data/local/tmp/ntsd-pair"
    def sh(*args, **kw): return subprocess.run([adb, *args], check=True, capture_output=True, text=True, **kw)
    sh("shell", f"rm -rf {device} && mkdir -p {device}")
    sh("push", str(Path(run_dir).resolve()), f"{device}/app"); sh("push", str(MUSIC), f"{device}/music")
    for role, *_ in ROLES: sh("push", str(out / f"{role}-overlay"), f"{device}/{role}-overlay")
    script = ["cd " + device + "/app && chmod 755 NTSDHeadless", "export TZ=Etc/GMT-1"]
    for role, seed, s, _ in ROLES:
        args = " ".join("'" + a.replace("'", "'\\''") + "'" for a in arguments(device, role, seed, s, f"{device}/music"))
        script.append(f"./NTSDHeadless {args} >{device}/{role}.log 2>&1 & {role}=$!")
        if role == "host":   # 127.0.0.1:12345 (0100007F:3039) in state LISTEN (0A)
            script.append("for _ in $(seq 300); do grep -q ' 0100007F:3039 00000000:0000 0A' /proc/net/tcp && break; sleep 0.1; done")
            script.append(f"grep -q ' 0100007F:3039 00000000:0000 0A' /proc/net/tcp || {{ echo 'no listener' >{device}/error; kill $host; exit 1; }}")
    script += [f"wait $host; echo $? >{device}/host.exit", f"wait $client; echo $? >{device}/client.exit"]
    (out / "run.sh").write_text("\n".join(script) + "\n")
    sh("push", str(out / "run.sh"), f"{device}/run.sh")
    sh("shell", f"sh {device}/run.sh", timeout=300)
    for name in ("error", "host.exit", "client.exit", "host.log", "client.log", "host.json", "client.json", "host-trace.jsonl", "client-trace.jsonl"):
        subprocess.run([adb, "pull", f"{device}/{name}", str(out / name)], capture_output=True)
    if (out / "error").exists():
        raise AssertionError((out / "error").read_text())
    return {role: int((out / f"{role}.exit").read_text()) for role, *_ in ROLES}


def run_cross(out, host_spec, client_spec):
    adb = os.environ.get("ADB", "adb"); device = "/data/local/tmp/ntsd-pair"
    cx = "/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine"
    def win(p): return "Z:" + str(p).replace("/", "\\")
    specs = dict(host=host_spec.split(":", 1), client=client_spec.split(":", 1))
    with socket.socket() as s:   # no listener on the port before adb takes it for forwarding (TIME_WAIT is fine)
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1); s.bind(("127.0.0.1", 12345))
    if any(kind == "android" for kind, _ in specs.values()):
        subprocess.run([adb, "shell", f"rm -rf {device} && mkdir -p {device}"], check=True, capture_output=True)
        run_dir = next(target for kind, target in specs.values() if kind == "android")
        subprocess.run([adb, "push", str(Path(run_dir).resolve()), f"{device}/app"], check=True, capture_output=True)
        subprocess.run([adb, "push", str(MUSIC), f"{device}/music"], check=True, capture_output=True)
        subprocess.run([adb, "forward", "--remove-all"], capture_output=True); subprocess.run([adb, "reverse", "--remove-all"], capture_output=True)
        # The client dials 127.0.0.1:12345 on its own side; adb carries it to the host's side.
        subprocess.run([adb, "forward" if specs["host"][0] == "android" else "reverse", "tcp:12345", "tcp:12345"], check=True, capture_output=True)
    procs = {}
    for role, seed, script, _ in ROLES:
        kind, target = specs[role]
        if kind == "android":
            subprocess.run([adb, "push", str(out / f"{role}-overlay"), f"{device}/{role}-overlay"], check=True, capture_output=True)
            args = " ".join("'" + a.replace("'", "'\\''") + "'" for a in arguments(device, role, seed, script, f"{device}/music"))
            command = [adb, "shell", f"cd {device}/app && chmod 755 NTSDHeadless && TZ=Etc/GMT-1 ./NTSDHeadless {args} >{device}/{role}.log 2>&1"]
            env = None
        elif kind == "wine":
            args = [win(a) if a.startswith(str(out)) or a == str(MUSIC) else a for a in arguments(out, role, seed, script, str(MUSIC))]
            exe = "NTSDSDL.exe" if (Path(target) / "NTSDSDL.exe").exists() else "NTSDHeadless.exe"
            command = [cx, "--bottle", "ntsd-xplat-test", "--wait-children", win(Path(target).resolve() / exe), *args]
            env = {**os.environ, "TZ": "Etc/GMT-1", "NTSD_SDL_VIDEO_DRIVER": "offscreen", "NTSD_SDL_AUDIO_DRIVER": "dummy"}
        else:
            music = str(MUSIC) if "NTSDSDL" in Path(target).name else None
            command = [target, *arguments(out, role, seed, script, music)]; env = {**os.environ, "TZ": "Etc/GMT-1"}
        log = (out / f"{role}.raw").open("x")
        procs[role] = (subprocess.Popen(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, env=env), log, kind)
        if role == "host":
            deadline = time.monotonic() + 60
            while time.monotonic() < deadline:
                if kind == "android":
                    tcp = subprocess.run([adb, "shell", "cat /proc/net/tcp"], capture_output=True, text=True).stdout
                    if " 0100007F:3039 00000000:0000 0A" in tcp: break
                else:
                    rows = subprocess.run(["lsof", "-nP", "-iTCP:12345", "-sTCP:LISTEN", "-Fn"], capture_output=True, text=True).stdout
                    if "n127.0.0.1:12345" in rows: break
                time.sleep(0.2)
            else:
                raise AssertionError("host did not open its loopback listener")
    codes = {}
    for role, (p, log, kind) in procs.items():
        code = p.wait(timeout=300); log.close()
        if kind == "android":
            for name in (f"{role}.log", f"{role}.json", f"{role}-trace.jsonl"):
                subprocess.run([adb, "pull", f"{device}/{name}", str(out / name)], capture_output=True)
        else:
            (out / f"{role}.log").write_text((out / f"{role}.raw").read_text().replace("\r\n", "\n"))
        codes[role] = code
    if specs["host"][0] == "android" or specs["client"][0] == "android":
        subprocess.run([adb, "forward", "--remove-all"], capture_output=True); subprocess.run([adb, "reverse", "--remove-all"], capture_output=True)
    return codes


def check(out, codes):
    for role, *_ in ROLES:
        assert codes[role] == 0, (role, codes[role])
        events = [json.loads(l) for l in (out / f"{role}.log").read_text().splitlines() if l.startswith("{")]
        assert any(e.get("event") == "networkReady" for e in events), role
        assert not any(e.get("event") in ("boundary", "messageBox") for e in events), (role, events)
    h = json.loads((out / "host.json").read_text()); c = json.loads((out / "client.json").read_text())
    assert h["role"] == 2 and c["role"] == 1
    assert h["world"] == c["world"] == 2
    assert h["selector"] == 2 and c["selector"] == 4
    assert h["localAddress"] == c["localAddress"] == [127, 0, 0, 1]
    assert h["notificationRequests"] == 9 and h["clientRequests"] == 0
    assert c["notificationRequests"] == 0 and c["clientRequests"] == 11
    assert len(h["rng"]) == 3001 and h["rng"] == c["rng"]
    assert h["seats"] == [1, 2, 3, 4, -1, -1, -1, -1]
    assert c["seats"] == [-1, -1, -1, -1, 1, 2, 3, 4]
    def names(bank):
        return [bytes(bank[i:i + 11]).split(b"\0")[0].split(b"_")[0].decode("ascii") for i in range(0, 88, 11)]
    assert names(h["names"]) == names(c["names"]) == ["Host1", "Host2", "Host3", "Host4", "Peer1", "Peer2", "Peer3", "Peer4"]
    return hashlib.sha256(bytes(h["rng"])).hexdigest()


def main():
    out = Path(sys.argv[1]).resolve(); mode, target = sys.argv[2], sys.argv[3]
    client = sys.argv[4] if mode == "--cross" else None
    shutil.rmtree(out, ignore_errors=True); out.mkdir(parents=True)
    for role, _, _, names in ROLES:
        overlay(out, role, names)
    codes = (run_local(out, target) if mode == "--local" else run_wine(out, target) if mode == "--wine"
             else run_android(out, target) if mode == "--android" else run_cross(out, target, client) if mode == "--cross"
             else run_linux(out, target))
    rng = check(out, codes)
    result = {"result": "PASS", "mode": mode, "exitCodes": codes, "rngSHA256": rng}
    if client: result["roles"] = {"host": target.split(":")[0], "client": client.split(":")[0]}
    (out / "result.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result))


if __name__ == "__main__":
    main()
