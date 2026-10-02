#!/usr/bin/env python3
"""Small Cua Driver helper for the cross-play trial: capture the game window, act, capture again.

usage: cua.py shot NAME
       cua.py click X Y [foreground|background] NAME
       cua.py key KEY [foreground|background] NAME
"""
import json
import subprocess
import sys
import time
from pathlib import Path

CUA = str(Path.home() / ".local/bin/cua-driver")
HERE = Path(__file__).resolve().parent
LOG = HERE / "actions.jsonl"
SESSION = __import__("os").environ.get("CUA_SESSION", "crossplay2")


def call(tool, args):
    out = subprocess.run([CUA, "call", tool, json.dumps(args)], capture_output=True, text=True)
    try:
        return json.loads(out.stdout)
    except json.JSONDecodeError:
        return dict(raw=out.stdout, stderr=out.stderr)


def window():
    # Only the CrossOver original: other apps (the parallel agent's NTSDNative
    # matches) also title their windows "Little Fighter 2".
    title = __import__("os").environ.get("WIN", "Little Fighter 2")
    for w in call("list_windows", {})["windows"]:
        if w["app_name"] == "NTSD 2.4.exe" and w["title"] == title and w["is_on_screen"]:
            return w["pid"], w["window_id"]
    raise SystemExit("no original window titled " + title)


def shot(name):
    pid, wid = window()
    d = call("get_window_state", dict(pid=pid, window_id=wid, include_accessibility_tree=False, max_image_dimension=0,
                                      screenshot_out_file=str(HERE / f"{name}.png"), session=SESSION))
    return pid, wid, d.get("capture_id"), d


def log(entry):
    entry["utc"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    with LOG.open("a") as f:
        f.write(json.dumps(entry) + "\n")


if __name__ == "__main__":
    op = sys.argv[1]
    if op == "shot":
        pid, wid, cap, d = shot(sys.argv[2])
        log(dict(op="shot", name=sys.argv[2], window=wid, capture=cap))
        print(wid, cap, d.get("window_title"))
    elif op == "open":
        # open X Y LABEL SECONDS: with the Open dialog up, select the row at (X, Y), press Open,
        # dismiss the music ERROR, report a data/version Error, and capture frames for SECONDS.
        import os
        x, y, label, seconds = sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]
        env = dict(os.environ, WIN="Open")
        subprocess.run([sys.executable, __file__, "click", x, y, "foreground", f"{label}-select"], env=env)
        subprocess.run(["sips", "-c", "60", "840", "--cropOffset", "410", "0", str(HERE / f"{label}-select.png"),
                        "--out", str(HERE / f"{label}-name.png")], capture_output=True)
        subprocess.run([sys.executable, __file__, "click", "745", "438", "foreground", f"{label}-opened"], env=env)
        titles = []
        for _ in range(10):
            titles = [w["title"] for w in call("list_windows", {})["windows"] if w["app_name"] == "NTSD 2.4.exe" and w["is_on_screen"]]
            if "ERROR" in titles or "Error" in titles: break
            time.sleep(0.5)
        if "Error" in titles:
            os.environ["WIN"] = "Error"; shot(f"{label}-rejected")
            log(dict(op="open", label=label, result="rejected")); print("rejected"); sys.exit(0)
        if "ERROR" in titles:
            subprocess.run([sys.executable, __file__, "click", "237", "140", "foreground", f"{label}-music-ok"], env=dict(os.environ, WIN="ERROR"))
        subprocess.Popen([str(HERE / "frames.sh"), f"frames-{label}", seconds], cwd=HERE,
                         stdout=open(HERE / f"frames-{label}.log", "w"), stderr=subprocess.STDOUT, start_new_session=True)
        log(dict(op="open", label=label, titles=titles, result="playing")); print("playing", titles)
    elif op == "keys":
        # keys NAME CODE...: front the game window, then held keys posted to its pid.
        pid, wid = window()
        call("bring_to_front", dict(pid=pid, window_id=wid, session=SESSION)); time.sleep(0.4)
        done = subprocess.run([str(HERE / "keyhold"), str(pid), "pid", "150", "300", *sys.argv[3:]], capture_output=True, text=True)
        time.sleep(float(__import__("os").environ.get("SETTLE", "1.5")))
        shot(sys.argv[2])
        log(dict(op="keys", codes=sys.argv[3:], window=wid, result=done.stdout.strip()))
        print(done.stdout.strip().replace("\n", "; "))
    elif op in ("click", "key"):
        mode = sys.argv[-2] if len(sys.argv) > 4 else "background"
        name = sys.argv[-1]
        pid, wid, cap, _ = shot(name + "-before")
        if op == "click":
            x, y = float(sys.argv[2]), float(sys.argv[3])
            if mode == "foreground":
                # Move the real pointer first so Wine sees the motion before the button.
                b = next(w["bounds"] for w in call("list_windows", {})["windows"] if w["window_id"] == wid)
                scale = call("get_screen_size", {}).get("scale_factor", 2)
                call("move_cursor", dict(x=(b["x"] + x / 2) * scale, y=(b["y"] + y / 2) * scale, scope="desktop", session=SESSION))
                time.sleep(0.6)
                pid, wid, cap, _ = shot(name + "-moved")
            r = call("click", dict(pid=pid, window_id=wid, x=x, y=y, capture_id=cap, delivery_mode=mode, session=SESSION))
        else:
            r = call("press_key", dict(pid=pid, window_id=wid, key=sys.argv[2], delivery_mode=mode, session=SESSION))
        time.sleep(float(__import__("os").environ.get("SETTLE", "1.5")))
        _, _, cap2, _ = shot(name)
        log(dict(op=op, args=sys.argv[2:], window=wid, result=r))
        print(json.dumps(r.get("summary") or r)[:300])
