#!/usr/bin/env python3
"""Run every portable XCTest suite of a cross-built Linux test bundle, one
suite per container, and append one JSON line per suite.

Usage: run_linux_suites.py BUILD_DIR OUT.jsonl [--jobs N] [--timeout SECONDS] [--only A,B] [--platform linux/amd64]

BUILD_DIR is the Linux products directory holding NTSDCoreTests-test-runner.
The repository and BUILD_DIR are mounted read-only into swift:6.4.0-noble and
their macOS absolute paths are recreated by tools/crossplatform/linux-test-run.sh,
so #filePath and Bundle.module resolve. Suites already in OUT.jsonl are skipped,
so an interrupted run resumes. --platform runs the containers for another
architecture (linux/amd64 under Rosetta on Apple silicon: a test harness).
"""
import argparse, concurrent.futures, json, os, re, subprocess, sys, time

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
IMAGE = "swift:6.4.0-noble"
TOOLS = os.path.dirname(os.path.abspath(__file__))


PLATFORM = []


def docker(build, args, timeout):
    cmd = ["docker", "run", "--rm", *PLATFORM, "-e", f"NTSD_REPO={REPO}", "-e", f"NTSD_BUILD={build}",
           "-v", f"{REPO}:/repo:ro", "-v", f"{build}:/build:ro", "-v", f"{TOOLS}:/tools:ro",
           IMAGE, "/tools/linux-test-run.sh", *args]
    return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)


def suites(build):
    out = docker(build, ["--list-tests"], 600).stdout
    names = []
    for line in out.splitlines():
        m = re.match(r"^\s*NTSDCoreTests\.([A-Za-z0-9_]+)/", line.strip())
        if m and m.group(1) not in names:
            names.append(m.group(1))
    return names


def run(build, suite, timeout, logdir):
    start = time.time()
    try:
        p = docker(build, [f"NTSDCoreTests.{suite}"], timeout)
        text, code = p.stdout + p.stderr, p.returncode
    except subprocess.TimeoutExpired as e:
        text = (e.stdout or b"").decode() if isinstance(e.stdout, bytes) else (e.stdout or "")
        code = "timeout"
    with open(os.path.join(logdir, f"{suite}.log"), "w") as f:
        f.write(text)
    passed = len(re.findall(r"Test Case '.*' passed", text))
    failed = len(re.findall(r"Test Case '.*' failed", text))
    skipped = len(re.findall(r"Test Case '.*' skipped", text))
    first = next((l.strip() for l in text.splitlines() if ": error: " in l), None)
    crash = None if code in (0, 1) else (text.strip().splitlines() or ["(no output)"])[-1][:300]
    return {"suite": suite, "exit": code, "passed": passed, "failed": failed, "skipped": skipped,
            "seconds": round(time.time() - start, 1), "first_error": first, "crash": crash}


def main():
    a = argparse.ArgumentParser()
    a.add_argument("build"); a.add_argument("out")
    a.add_argument("--jobs", type=int, default=2); a.add_argument("--timeout", type=int, default=7200)
    a.add_argument("--only", default=""); a.add_argument("--platform", default="")
    o = a.parse_args()
    if o.platform: PLATFORM[:] = ["--platform", o.platform]
    logdir = os.path.splitext(o.out)[0] + "-logs"
    os.makedirs(logdir, exist_ok=True)
    done = set()
    if os.path.exists(o.out):
        done = {json.loads(l)["suite"] for l in open(o.out) if l.strip()}
    todo = [s for s in (o.only.split(",") if o.only else suites(o.build)) if s and s not in done]
    print(f"{len(todo)} suites to run, {len(done)} already recorded", flush=True)
    with concurrent.futures.ThreadPoolExecutor(o.jobs) as pool, open(o.out, "a") as out:
        futures = [pool.submit(run, o.build, s, o.timeout, logdir) for s in todo]
        for f in concurrent.futures.as_completed(futures):
            r = f.result()
            out.write(json.dumps(r) + "\n"); out.flush()
            print(f"{r['suite']}: exit={r['exit']} passed={r['passed']} failed={r['failed']} "
                  f"skipped={r['skipped']} {r['seconds']}s", flush=True)


if __name__ == "__main__":
    sys.exit(main())
