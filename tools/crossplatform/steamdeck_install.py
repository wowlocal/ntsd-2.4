#!/usr/bin/env python3
"""Install the Linux x86_64 package on a Steam Deck and add it to Game Mode.

Usage: steamdeck_install.py ARCHIVE [--host deck@HOST] [--stay-in-desktop]

ARCHIVE is an ntsd-linux-x86_64-*.tar.gz from `package_linux.py --arch x86_64`
or a release asset. Over SSH with key authentication (one-time Deck setup in
docs/STEAM_DECK.md) this:

  - checks the Deck: x86_64, glibc 2.39 or newer, the game not running;
  - uploads the archive to ~/ntsd/ (skipped when the same SHA-256 is there),
    unpacks it as ~/ntsd/ntsd-linux-x86_64/ and checks its libraries resolve;
    older ntsd-linux-x86_64-*.tar.gz uploads in ~/ntsd/ are removed;
  - installs Steam's launcher ~/ntsd/ntsd-steam.sh (the run's events go to
    ~/ntsd/last-run.log), the library art and a Desktop Mode menu entry;
  - adds the "NTSD 2.4" non-Steam shortcut with its art for the signed-in
    Steam account (steamdeck/add_shortcut.py). Steam rewrites that file on
    exit, so when the shortcut is missing Steam is shut down first, which
    needs Desktop Mode; the Deck then returns to Game Mode as the desktop's
    "Return to Gaming Mode" does (--stay-in-desktop skips that).
"""
import argparse, hashlib, re, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent / "steamdeck"
SSH = ["-o", "BatchMode=yes", "-o", "ConnectTimeout=10"]
# The desktop session's environment, for commands that talk to Steam or KDE.
SESSION = ("export XDG_RUNTIME_DIR=/run/user/$(id -u) DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus "
           "DISPLAY=:0 WAYLAND_DISPLAY=wayland-0; ")
DESKTOP = """[Desktop Entry]
Type=Application
Name=NTSD 2.4
Comment=Naruto: The Setting Dawn 2.4 (native port)
Exec=$HOME/ntsd/ntsd-steam.sh
Path=$HOME/ntsd/ntsd-linux-x86_64
Icon=$HOME/ntsd/art/icon.png
Categories=Game;
Terminal=false
"""


def sha(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""): h.update(block)
    return h.hexdigest()


def main():
    a = argparse.ArgumentParser()
    a.add_argument("archive", type=Path); a.add_argument("--host", default="deck@steamdeck.local")
    a.add_argument("--stay-in-desktop", action="store_true")
    args = a.parse_args(); host, archive = args.host, args.archive
    if not re.fullmatch(r"ntsd-linux-x86_64-[0-9a-f]+\.tar\.gz", archive.name): sys.exit(f"not an x86_64 package: {archive.name}")

    def ssh(script, check=True):
        r = subprocess.run(["ssh", *SSH, host, script], text=True, capture_output=True)
        if check and r.returncode: sys.exit(f"on the Deck: {script.splitlines()[0][:80]}…\n{r.stdout}{r.stderr}".rstrip())
        return r

    def scp(sources, target):
        subprocess.run(["scp", *SSH, "-q", *map(str, sources), f"{host}:{target}"], check=True)

    arch, libc, running = ssh("uname -m; ldd --version | head -1; pgrep -x NTSDSDL || true").stdout.split("\n")[:3]
    version = tuple(map(int, re.search(r"(\d+)\.(\d+)\s*$", libc).groups()))
    print(f"Deck: {arch}, glibc {version[0]}.{version[1]}")
    if arch != "x86_64" or version < (2, 39): sys.exit("the package needs x86_64 and glibc 2.39 or newer")
    if running.strip(): sys.exit("the game is running on the Deck; close it first")

    digest = sha(archive)
    have = ssh(f"mkdir -p ~/ntsd/tools ~/ntsd/art && sha256sum ~/ntsd/{archive.name} 2>/dev/null || true").stdout
    if not have.startswith(digest):
        print(f"uploading {archive.name} ({archive.stat().st_size >> 20} MiB)")
        scp([archive], f"ntsd/.{archive.name}.part")
        ssh(f"cd ~/ntsd && mv .{archive.name}.part {archive.name}")
        if not ssh(f"sha256sum ~/ntsd/{archive.name}").stdout.startswith(digest): sys.exit("uploaded archive differs")
    ssh(f"""set -e; cd ~/ntsd; rm -rf .unpack; mkdir .unpack; tar xzf {archive.name} -C .unpack
test -x .unpack/ntsd-linux-x86_64/NTSDSDL
if ldd .unpack/ntsd-linux-x86_64/NTSDSDL | grep 'not found'; then exit 1; fi
rm -rf ntsd-linux-x86_64.old; if [ -d ntsd-linux-x86_64 ]; then mv ntsd-linux-x86_64 ntsd-linux-x86_64.old; fi
mv .unpack/ntsd-linux-x86_64 .; rm -rf .unpack ntsd-linux-x86_64.old
for f in ntsd-linux-x86_64-*.tar.gz; do [ "$f" = {archive.name} ] || rm -f "$f"; done""")
    print(f"installed ~/ntsd/ntsd-linux-x86_64 ({archive.name}, sha256 {digest[:12]}…)")

    scp([HERE / "ntsd-steam.sh"], "ntsd/"); scp([HERE / "add_shortcut.py"], "ntsd/tools/")
    scp(sorted((HERE / "art").glob("*.png")), "ntsd/art/")
    ssh(f"""chmod +x ~/ntsd/ntsd-steam.sh; mkdir -p ~/.local/share/applications
cat > ~/.local/share/applications/ntsd.desktop <<EOF
{DESKTOP}EOF""")

    check = ssh("python3 -I ~/ntsd/tools/add_shortcut.py --check ~/ntsd/art", check=False)
    print(check.stdout.strip())
    if check.returncode == 0: print("Steam shortcut already in place"); return
    mode = ssh("pgrep -x gamescope-wl >/dev/null && echo game || echo desktop").stdout.strip()
    if mode == "game" and ssh("pgrep -x steam", check=False).returncode == 0:
        sys.exit("the shortcut needs Steam closed: switch the Deck to Desktop Mode (Steam menu > Power > "
                 "Switch to Desktop) and run this again")
    ssh(SESSION + """if pgrep -x steam >/dev/null; then (steam -shutdown >/dev/null 2>&1 &)
  for i in $(seq 60); do pgrep -x steam >/dev/null || break; sleep 1; done
  if pgrep -x steam >/dev/null; then echo "Steam did not exit in 60 s"; exit 1; fi; fi""")
    print(ssh("python3 -I ~/ntsd/tools/add_shortcut.py ~/ntsd/art").stdout.strip())
    if args.stay_in_desktop: print("Steam is closed; it reads the shortcut when it starts again"); return
    ssh(SESSION + """if [ "$(steamosctl get-default-login-mode)" = desktop ]; then steamosctl switch-to-game-mode
else qdbus org.kde.Shutdown /Shutdown org.kde.Shutdown.logout; fi""")
    print("returning to Game Mode: NTSD 2.4 is in the Steam library")


main()
