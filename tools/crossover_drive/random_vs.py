#!/usr/bin/env python3
"""Random VS cross-check: the Mac app records a VS match of P1 and N computers,
all with Random characters on a Random background, then the original under
CrossOver plays the recording and both Summaries are compared from memory.

usage: random_vs.py OUT_DIR SEED [SEED...] [--mode vs|stage|war] [--computers N] [--rerolls K]
                    [--background-steps N...] [--difficulty-steps N...] [--p1 idle|walk] [--mac-only]

Per seed: the app runs with `--virtual-clock SEED 8`; P1 joins as Random and
stays idle; the final menu's Randomize is pressed K times before Fight!. The
recording, the app's `--summary-json`, the original's dump (play_original.py)
and the comparison go to OUT_DIR/SEED/. CROSSPLAY_LOOP.md.
"""
import argparse
import json
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
import compare_summaries  # noqa: E402
import play_original  # noqa: E402

APP = ROOT / "build/swiftpm-app/release/NTSDNative"


# Mode menu after START: VS is the first line, Stage the second.
PREFIX = {"war": None, "vs": ["20 click 350 230", "60 click 402 218", "100 key 74", "150 key 74", "200 key 74", "250 key 74"],
          "stage": ["20 click 350 230", "60 click 402 218", "100 key 83", "125 key 74", "175 key 74", "225 key 74", "275 key 74"]}


# War as in app_e2e.py (P1 Naruto and one computer) up to its settings screen.
WAR_PREFIX = ["20 click 350 230", "60 click 402 218", "100 key 83", "125 key 83", "150 key 83", "175 key 83", "200 key 74",
              "250 key 74", "275 key 68", "300 key 74", "325 key 74", "400 key 75", "425 key 75", "450 key 75", "475 key 75",
              "1000 key 74", "1100 key 68", "1150 key 74", "1200 key 74"]


def war_script(seed):
    """War with troop settings drawn from the seed. The settings screen starts
    on OK! (section 6); S wraps to the Defense multipliers (section 0: J +0.5,
    D switches the squad), then sections 1-4 (in-screen and reserve counts:
    J +1, L +5, K -1, D moves the cursor and past the end the squad). W x5
    returns to OK!, J opens the final menu, W x2 and J start the battle."""
    import random
    rng = random.Random(seed); steps = list(WAR_PREFIX); t = 1400; settings = []
    def press(vk, label=None):
        nonlocal t
        steps.append(f"{t} key {vk}"); t += 40
        if label: settings.append(label)
    press(83)
    for squad in range(2):
        for _ in range(rng.randint(0, 4)): press(74, f"squad {squad + 1} defense +0.5")
        if squad == 0: press(68)
    for section in range(1, 5):
        press(83)
        for _ in range(12):
            key = rng.choice([None, None, 74, 76, 75])
            if key: press(key, f"section {section} {dict([(74, '+1'), (76, '+5'), (75, '-1')])[key]}")
            press(68)
    for _ in range(5): press(87)
    press(74); t += 60; press(87); press(87); t += 20; press(74)
    steps.append("900000 exit")
    return "; ".join(steps), settings


def walk(t, end=300000):
    """P1 walks right and attacks: Right held 45 steps, then Attack, every 60
    steps of the gameplay script clock. A Stage advances only when a fighter
    walks on at GO, so idle P1 with computer allies stalls once the phase is
    clear; with P1 walking the run ends when P1 is knocked out."""
    return [f"{u} hold 68 45; {u + 50} key 74" for u in range(t, end, 60)]


def script(computers, rerolls, background_steps=0, mode="vs", difficulty_steps=0, p1="idle"):
    """P1 joins as Random and stays idle. VS starts with one computer and Stage
    with none; D adds one. On the final menu the marker starts at Randomize
    (line 2) and each J acts on its line: 2 rerolls the Random fighters, 3
    steps the background 100 (Random) -> 99 -> 0 -> 1 ... (in Stage the stage
    +10, 50 = Survival), 4 the difficulty 0 -> 2 -> 1 -> 0. A/D change the music."""
    steps = list(PREFIX[mode]); t = 1000
    for _ in range(computers - (1 if mode == "vs" else 0)): steps.append(f"{t} key 68"); t += 30
    steps.append(f"{t} key 74"); t += 90
    for _ in range(computers): steps += [f"{t} key 74", f"{t + 100} key 74"]; t += 200
    t += 100
    for _ in range(rerolls): steps.append(f"{t} key 74"); t += 100
    line = 2
    for target, count in ((3, background_steps), (4, difficulty_steps)):
        if not count: continue
        while line < target: steps.append(f"{t} key 83"); t += 40; line += 1
        for _ in range(count): steps.append(f"{t} key 74"); t += 40
    for _ in range(line): steps.append(f"{t} key 87"); t += 30
    # The exit is only a backstop: --exit-after-summary ends the run. The
    # gameplay script clock counts loop iterations (about 3.3 per tick), and a
    # Stage run with allies can last far beyond 60000.
    steps.append(f"{t + 50} key 74")
    if p1 == "walk": steps += walk(t + 400)
    steps.append("900000 exit")
    return "; ".join(steps)


def run(out, seed, computers, rerolls, background_steps=0, mode="vs", difficulty_steps=0, mac_only=False, p1="idle"):
    d = out / str(seed); d.mkdir(parents=True, exist_ok=True); overlay = d / "overlay"; overlay.mkdir(exist_ok=True)
    mac = d / "mac.json"
    if mode == "war": text, settings = war_script(seed)
    else: text, settings = script(computers, rerolls, background_steps, mode, difficulty_steps, p1), None
    if not mac.exists():
        done = subprocess.run([str(APP), "--original", "--mute-music", "--mute-sounds", "--no-activate", "--overlay", str(overlay),
                               "--virtual-clock", str(seed), "8", "--script-clock", "gameplay", "--exit-after-summary",
                               "--summary-json", str(mac), "--summary-capture", str(d / "mac-summary.png"),
                               "--script", text], capture_output=True, text=True, timeout=7200,
                              env={"TZ": "Etc/GMT-1", "PATH": "/usr/bin:/bin"})
        (d / "mac.stdout").write_text(done.stdout + done.stderr)
    recordings = sorted(overlay.rglob("*.lfr"))
    if settings is not None: (d / "war-settings.json").write_text(json.dumps(settings, indent=1))
    result = dict(seed=seed, mode=mode, p1=p1, computers=computers, rerolls=rerolls, backgroundSteps=background_steps, difficultySteps=difficulty_steps, recording=[str(r) for r in recordings])
    if not mac.exists() or not recordings:
        result["result"] = "no Mac summary or recording"; return result
    if mac_only: result["result"] = "Mac only"; return result
    original = d / "original.json"
    if not original.exists():
        # One retry: a lost key in the menu or the Open dialog is a tooling
        # failure, not a game result.
        for attempt in range(2):
            # The original plays in real time (30 ticks a second).
            timeout = json.loads(mac.read_text())["ticks"] // 30 + 600
            try: play_original.main(str(recordings[-1]), str(original), timeout=timeout); break
            except SystemExit as e:
                if attempt: result["result"] = f"original: {e}"; return result
    status = compare_summaries.main(str(mac), str(original))
    result["result"] = "equal" if status == 0 else "different"
    result["mac"] = json.loads(mac.read_text()); result["original"] = json.loads(original.read_text())
    return result


def main():
    p = argparse.ArgumentParser(description=__doc__); p.add_argument("out"); p.add_argument("seeds", nargs="+", type=int)
    p.add_argument("--computers", type=int, default=3); p.add_argument("--rerolls", type=int, default=0)
    p.add_argument("--background-steps", type=int, nargs="*", default=[], help="per seed: J presses on the Background line")
    p.add_argument("--difficulty-steps", type=int, nargs="*", default=[], help="per seed: J presses on the Difficulty line")
    p.add_argument("--mode", choices=sorted(PREFIX), default="vs")
    p.add_argument("--mac-only", action="store_true", help="record and dump on the Mac only (the original runs later)")
    p.add_argument("--p1", choices=["idle", "walk"], default="idle", help="P1 stays idle or walks right and attacks")
    a = p.parse_args(); out = Path(a.out); out.mkdir(parents=True, exist_ok=True)
    results = []
    for i, seed in enumerate(a.seeds):
        steps = a.background_steps[i] if i < len(a.background_steps) else 0
        difficulty = a.difficulty_steps[i] if i < len(a.difficulty_steps) else 0
        r = run(out, seed, a.computers, a.rerolls, steps, a.mode, difficulty, a.mac_only, a.p1); results.append(r)
        print(seed, r["result"], [s["id"] for s in r.get("mac", {}).get("seats", [])], flush=True)
        if not a.mac_only: (out / "results.json").write_text(json.dumps(results, indent=1))


if __name__ == "__main__":
    main()
