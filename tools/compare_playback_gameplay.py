#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["pillow==11.3.0"]
# ///
"""Playback gameplay check (APPLICATION_PLAYBACK_PLAN.md P4): the release app
records the e2e computer-VS match, then plays that recording back through
Playback Recording (`--playback-file`) and quits it with F4. Body captures at
the same gameplay bodies are compared: every pixel outside the playback
indicator rows (window y >= 500: time, mode text and the key help bar the
original draws only while a recording plays) must be identical. Both runs are
Native; the original is not executed. Writes docs/evidence/playback-gameplay.json.
"""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

from PIL import Image, ImageChops

sys.path.insert(0, str(Path(__file__).resolve().parent))
from app_e2e import APP, PLAYBACK, ROOT, SCRIPT, TAIL  # noqa: E402

WORK = ROOT / "build/research/playback/gameplay"
INDICATOR_TOP = 500  # window rows; the capture is scaled by the backing scale


def run(name, script, extra):
    folder = WORK / name
    subprocess.run(["rm", "-rf", str(folder)], check=True)
    overlay, captures = folder / "overlay", folder / "captures"
    overlay.mkdir(parents=True); captures.mkdir()
    command = [str(APP), "--original", "--mute-music", "--mute-sounds", "--overlay", str(overlay), "--virtual-clock", "123456789", "8",
               "--script-clock", "gameplay", "--body-captures", str(captures), *extra,
               "--script", script.replace("{captures}", str(captures))]
    done = subprocess.run(command, capture_output=True, text=True, timeout=1800)
    events = [json.loads(line) for line in done.stdout.splitlines() if line.startswith("{")]
    return done.returncode, events, overlay, captures


def main():
    code, events, overlay, recorded = run("record", SCRIPT.read_text().strip() + "; " + TAIL, [])
    files = sorted((overlay / "recording").glob("*.lfr"))
    assert code == 0 and len(files) == 1, (code, files, [e for e in events if e.get("event") == "boundary"])
    recording = files[0]
    code, events, _, replayed = run("replay", PLAYBACK, ["--playback-file", str(recording)])
    boundary = [e for e in events if e.get("event") == "boundary"]
    menus = [e for e in events if e.get("event") == "menu"]
    frames = []
    for path in sorted(recorded.glob("b*.png")):
        other = replayed / path.name
        if not other.exists():
            frames.append(dict(capture=path.name, replayed=False)); continue
        a, b = Image.open(path).convert("RGB"), Image.open(other).convert("RGB")
        scale = a.size[1] / 550
        top = int(INDICATOR_TOP * scale)
        upper = ImageChops.difference(a.crop((0, 0, a.size[0], top)), b.crop((0, 0, b.size[0], top))).getbbox()
        full = ImageChops.difference(a, b).getbbox()
        frames.append(dict(capture=path.name, replayed=True, size=list(a.size), upperDifference=upper,
                           fullDifference=full, identical=full is None))
    ok = (code == 0 and not boundary and len(menus) == 1 and frames
          and all(f.get("replayed") and f["upperDifference"] is None for f in frames))
    report = dict(scope=__doc__, recordingSHA256=hashlib.sha256(recording.read_bytes()).hexdigest(),
                  replayExit=code, boundary=boundary[0]["error"] if boundary else None,
                  replayMenu={k: menus[0][k] for k in ("gameplayBodies", "iterations", "epilogues")} if menus else None,
                  replayOverlayFiles=sorted(str(p.relative_to(WORK / "replay/overlay")) for p in (WORK / "replay/overlay").rglob("*") if p.is_file()),
                  indicatorTop=INDICATOR_TOP, frames=frames, result="pass" if ok else "fail")
    (ROOT / "docs/evidence/playback-gameplay.json").write_text(json.dumps(report, indent=1) + "\n")
    print(json.dumps({k: report[k] for k in ("result", "replayExit", "boundary", "replayMenu")}))
    for f in frames:
        print(f)
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
