#!/usr/bin/env python3
"""Mac-side replay set for the CrossOver cross-play check (CROSSOVER_REPLAY_CROSSPLAY_PLAN.md).

Runs chosen e2e scenarios exactly as tools/app_e2e.py does, but with a kept
overlay, and collects every saved `recording\\*.lfr` with its SHA-256, the
app's milestone events and the Summary-time captures. Nothing original runs.
"""
import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import app_e2e as e2e  # noqa: E402


def collect(out: Path, scenarios, app=e2e.APP, timeout=1800):
    manifest = dict(app=str(app), appSHA256=hashlib.sha256(Path(app).read_bytes()).hexdigest(), scenarios={})
    for name in scenarios:
        root = out / name
        shutil.rmtree(root, ignore_errors=True)
        overlay, captures = root / "overlay", root / "captures"
        overlay.mkdir(parents=True); captures.mkdir(parents=True)
        setup = e2e.SCENARIOS[name]
        extra = setup["extra"](root) if callable(setup["extra"]) else setup["extra"]
        command = [str(app), "--original", "--mute-music", "--mute-sounds", "--overlay", str(overlay),
                   "--virtual-clock", "123456789", "8", "--script-clock", "gameplay",
                   "--body-captures", str(captures), *extra, "--script", setup["script"](captures)]
        done = subprocess.run(command, capture_output=True, text=True, timeout=timeout, env=e2e.APP_ENV)
        events = [json.loads(l) for l in done.stdout.splitlines() if l.startswith("{")]
        (root / "events.json").write_text(json.dumps(events, indent=1))
        replays = []
        for path in sorted(overlay.rglob("*.lfr")):
            data = path.read_bytes()
            replays.append(dict(path=str(path.relative_to(overlay)), bytes=len(data), sha256=hashlib.sha256(data).hexdigest()))
        manifest["scenarios"][name] = dict(exitCode=done.returncode, replays=replays,
            boundaries=[ev.get("error", "")[:200] for ev in events if ev.get("event") == "boundary"],
            replayFilesReported=[ev.get("replayFiles") for ev in events if ev.get("replayFiles")][-1:],
            captures=sorted(p.name for p in captures.glob("*.png")))
        print(name, done.returncode, [(r["path"], r["bytes"]) for r in replays], flush=True)
    (out / "manifest.json").write_text(json.dumps(manifest, indent=1))
    return manifest


if __name__ == "__main__":
    collect(Path(sys.argv[1]), sys.argv[2].split(","))
