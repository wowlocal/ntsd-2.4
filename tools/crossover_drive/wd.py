import os, re, subprocess, sys
BOTTLES = "/Volumes/X5/ntsd-2.4-research/01a0dc49-738f-7972-8fb0-e98fb2f34408/crossover-reference-20260926/Bottles"
WINE = "/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine"
def wine(*args, timeout=60):
    env = dict(os.environ, CX_BOTTLE_PATH=BOTTLES)
    try: return subprocess.run([WINE, "--bottle", "NTSD24XP", "--no-gui", "--", *args], capture_output=True, text=True, timeout=timeout, env=env).stdout
    except subprocess.TimeoutExpired: return ""
def wpid():
    for line in wine("winedbg", "--command", "info process").splitlines():
        if "'NTSD 2.4.exe'" in line: return line.split()[0].lstrip("=")
def cmd(pid, command): return wine("winedbg", "--command", command, "0x" + pid)
if __name__ == "__main__":
    pid = wpid(); print("wpid", pid)
    for c in sys.argv[1:]: print(c, "->", "\n".join(l for l in cmd(pid, c).splitlines() if "Using a 32-bit" not in l))
