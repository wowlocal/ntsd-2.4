#!/usr/bin/env python3
"""Add the game to Steam's library as a non-Steam game (runs on the Deck).

Usage: add_shortcut.py [--account ID] [--check] ART_DIR

Writes the "NTSD 2.4" entry into the Steam account's shortcuts.vdf (binary
VDF, every other shortcut kept byte for byte) and copies the library art from
ART_DIR (portrait.png, wide.png, hero.png, icon.png) into its grid folder.
The account is the signed-in one (MostRecent, else AutoLogin, in
loginusers.vdf) unless --account names one. Steam reads the file at start and
rewrites it on exit, so it must not be running. --check only reports: exit 0
when the entry and the art are already in place, 1 otherwise.
"""
import argparse, os, re, shutil, struct, subprocess, sys, time, zlib
from pathlib import Path

HOME = Path.home()
STEAM = HOME / ".local/share/Steam"
NAME = "NTSD 2.4"
EXE = f'"{HOME}/ntsd/ntsd-steam.sh"'
START = f'"{HOME}/ntsd/ntsd-linux-x86_64/"'
ART = {"portrait.png": "{}p.png", "wide.png": "{}.png", "hero.png": "{}_hero.png", "icon.png": "{}_icon.png"}


def parse(data):
    """Binary VDF: 0 map, 1 string, 2 int32, 8 end; returns [(key, value)]."""
    pos = 0
    def cstr():
        nonlocal pos
        end = data.index(b"\0", pos); s = data[pos:end].decode("utf-8"); pos = end + 1; return s
    def node():
        nonlocal pos
        out = []
        while True:
            t = data[pos]; pos += 1
            if t == 8: return out
            key = cstr()
            if t == 0: out.append((key, node()))
            elif t == 1: out.append((key, cstr()))
            elif t == 2: out.append((key, struct.unpack_from("<i", data, pos)[0])); pos += 4
            else: raise ValueError(f"VDF type {t} at {pos - 1}")
    return node()


def emit(items):
    out = bytearray()
    for key, value in items:
        k = key.encode() + b"\0"
        if isinstance(value, list): out += b"\0" + k + emit(value) + b"\x08"
        elif isinstance(value, str): out += b"\x01" + k + value.encode() + b"\0"
        else: out += b"\x02" + k + struct.pack("<i", value)
    return bytes(out)


def signed_in_account():
    text = (STEAM / "config/loginusers.vdf").read_text(errors="replace")
    users = re.findall(r'"(\d{17})"\s*\{([^}]*)\}', text)
    for flag in ("MostRecent", "AutoLogin"):
        hits = [sid for sid, body in users if re.search(rf'"{flag}"\s*"1"', body)]
        if len(hits) == 1: return str(int(hits[0]) - 76561197960265728)
    dirs = [d.name for d in (STEAM / "userdata").iterdir() if d.name.isdigit()]
    if len(dirs) == 1: return dirs[0]
    sys.exit("cannot tell which Steam account is signed in; pass --account (a folder name in ~/.local/share/Steam/userdata)")


def main():
    a = argparse.ArgumentParser()
    a.add_argument("art", type=Path); a.add_argument("--account"); a.add_argument("--check", action="store_true")
    args = a.parse_args()
    account = args.account or signed_in_account()
    config = STEAM / "userdata" / account / "config"
    if not config.is_dir(): sys.exit(f"no Steam account folder {config}")
    vdf, grid = config / "shortcuts.vdf", config / "grid"
    appid = zlib.crc32((EXE + NAME).encode()) | 0x80000000      # Steam's id for a non-Steam shortcut
    signed = struct.unpack("<i", struct.pack("<I", appid))[0]
    top = parse(vdf.read_bytes()) if vdf.exists() else [("shortcuts", [])]
    others = [e for _, e in dict(top)["shortcuts"] if dict(e).get("appid") != signed]
    ours = [e for _, e in dict(top)["shortcuts"] if dict(e).get("appid") == signed]
    if args.check:
        art = all((grid / n.format(appid)).exists() and (grid / n.format(appid)).read_bytes() == (args.art / s).read_bytes()
                  for s, n in ART.items())
        present = any(dict(e).get("exe") == EXE and dict(e).get("StartDir") == START for e in ours)
        print(f"account {account} appid {appid} shortcut {'present' if present else 'missing'} art {'current' if art else 'missing'}")
        sys.exit(0 if present and art else 1)
    if subprocess.run(["pgrep", "-x", "steam"], capture_output=True).returncode == 0:
        sys.exit("Steam is running; it would overwrite shortcuts.vdf on exit — shut it down first")
    grid.mkdir(parents=True, exist_ok=True)
    for src, dst in ART.items(): shutil.copyfile(args.art / src, grid / dst.format(appid))
    if vdf.exists():
        backup = vdf.with_name(f"shortcuts.vdf.bak-{time.strftime('%Y%m%d-%H%M%S')}")
        shutil.copy2(vdf, backup); print("backup", backup)
    entry = [("appid", signed), ("appname", NAME), ("exe", EXE), ("StartDir", START),
             ("icon", str(grid / ART["icon.png"].format(appid))), ("ShortcutPath", ""), ("LaunchOptions", ""),
             ("IsHidden", 0), ("AllowDesktopConfig", 1), ("AllowOverlay", 1), ("OpenVR", 0),
             ("Devkit", 0), ("DevkitGameID", ""), ("DevkitOverrideAppID", 0),
             ("LastPlayTime", dict(ours[0]).get("LastPlayTime", 0) if ours else 0), ("FlatpakAppID", ""), ("tags", [])]
    entries = others + [entry]
    data = emit([("shortcuts", [(str(i), e) for i, e in enumerate(entries)])]) + b"\x08"
    assert parse(data) == [("shortcuts", [(str(i), e) for i, e in enumerate(entries)])]
    tmp = vdf.with_name("shortcuts.vdf.tmp"); tmp.write_bytes(data); os.replace(tmp, vdf)
    print(f"account {account} appid {appid} gameid {(appid << 32) | 0x02000000} shortcuts {len(entries)}")


main()
