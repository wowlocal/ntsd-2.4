# The game on a Steam Deck

Requested by the user on 2026-10-16: "хочу собрать игру на steam deck. что
для этого нужно?", then "I want the game to be launchable from steam deck
interface, not from desktop mode" and "добавь в репу инструкцию по установке
на steam deck и скрипты".

A Steam Deck runs SteamOS, an x86_64 Linux, so it runs the Linux SDL package
(`tools/crossplatform/package_linux.py --arch x86_64`) as it is. Nothing is
built on the Deck: the Mac uploads the package over SSH and adds the game to
Steam's library, so it starts from Game Mode like any other game.

## What you need

- The Deck on the same network as the Mac (Wi-Fi, or Ethernet through a dock).
  A USB-C cable between the Deck and the Mac does not connect them: both are
  USB hosts.
- SteamOS with glibc 2.39 or newer (`ldd --version`). SteamOS 3.8.28 has 2.41.
- A package `ntsd-linux-x86_64-<commit>.tar.gz`: a release asset, or one built
  on the Mac (Docker for the libraries; the Swift 6.4.0 toolchain and the
  `ntsd-6.4.0-ubuntu24.04-x86_64` SDK as in `package_linux.py`'s header):

  ```sh
  tools/crossplatform/build_linux_deps.sh DEPS linux/amd64    # once: SDL3 and FreeType
  tools/crossplatform/package_linux.py OUT --arch x86_64 --deps DEPS
  ```

## One-time Deck setup

1. Hold the power button and choose **Switch to Desktop**. Open **Konsole**.
2. Give the `deck` user a password if it has none, start SSH and note the
   address:

   ```sh
   passwd
   sudo systemctl enable --now sshd
   ip -4 addr | grep inet
   ```

3. On the Mac, install your SSH key on the Deck (asks for that password once):

   ```sh
   ssh-copy-id deck@<address>
   ```

## Install or update

```sh
tools/crossplatform/steamdeck_install.py ntsd-linux-x86_64-<commit>.tar.gz --host deck@<address>
```

The first time, run it with the Deck in **Desktop Mode**. Steam rewrites its
list of non-Steam games when it exits, so the script closes Steam, adds the
game, and returns the Deck to Game Mode (`--stay-in-desktop` keeps it on the
desktop). Later updates only replace the game files and work in either mode;
the game itself must be closed.

What ends up on the Deck:

| Path | Contents |
| --- | --- |
| `~/ntsd/ntsd-linux-x86_64/` | the unpacked package (the uploaded archive stays beside it) |
| `~/ntsd/ntsd-steam.sh` | the shortcut's target; the last run's log goes to `~/ntsd/last-run.log` |
| `~/ntsd/art/`, `~/ntsd/tools/add_shortcut.py` | library art and the shortcut writer |
| `~/.local/share/applications/ntsd.desktop` | "NTSD 2.4" in Desktop Mode's application menu |
| `~/.local/share/Steam/userdata/<account>/config/shortcuts.vdf`, `grid/` | the "NTSD 2.4" non-Steam game and its art, for the signed-in account (a backup of an existing file is kept beside it) |
| `~/.local/share/NTSD Native/` | the game's settings and recordings (created by the game) |

`tools/crossplatform/steamdeck/add_shortcut.py` keeps every other shortcut
unchanged; its reader and writer reproduce a Steam-written `shortcuts.vdf`
byte for byte. The shortcut id is Steam's own rule for non-Steam games,
`crc32(exe + name) | 0x80000000`, checked against a shortcut Steam made.

## Playing

In Game Mode the game is **NTSD 2.4** in the library. It runs full screen
under gamescope (SDL's X11 driver) with PipeWire sound.

Steam gives the game a virtual Xbox 360 pad, which the game treats as the
original's joystick 1. The controls are the original's, except on the title:

- The title screen (START … OFFICAL WEBSITE) is mouse-only in the original.
  Here up and down on the d-pad or the left stick also move the cursor from
  item to item and A presses the item, a departure from the original the
  user asked for ([MENU_GAMEPAD](research/MENU_GAMEPAD.md)). The touchscreen
  and the right trackpad work as a mouse too.
- From the mode menu on the game reads the players' own devices. Joystick 1
  is player 3's default device: up and down choose the mode and A confirms;
  at the character selection A joins. CONTROL SETTINGS can give the
  joystick to player 1 instead.
- CONTROL SETTINGS, RECORDING INFO and ONLINE GAME need the mouse (and the
  keyboard for text) as in the original: use the touchscreen or trackpad.
- In Game Mode B is a game button. Leave the game with the Steam button and
  **Exit Game**. In Desktop Mode Steam's desktop layout sends Esc for B, and
  Esc is the original's "Are you sure to quit?".

## Logs and remote checks

```sh
ssh deck@<address> 'cat ~/ntsd/last-run.log'        # JSON events of the last Steam launch
```

From SSH, start the game through Steam in Game Mode with
`steam steam://rungameid/<gameid>` (`add_shortcut.py` prints the id;
17181063300905959424 for the `deck` user). In Desktop Mode start it as a user
unit:

```sh
export XDG_RUNTIME_DIR=/run/user/$(id -u) DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus
systemd-run --user -E WAYLAND_DISPLAY=wayland-0 -E DISPLAY=:0 ~/ntsd/ntsd-steam.sh
```

A plain `nohup ./NTSDSDL &` from SSH quit cleanly (window destroyed, exit 0)
about 6 s after it started, when the SSH session closed; the cause was not
established. Started as a unit or by Steam it keeps running.

Screenshots: in Desktop Mode `spectacle -b -n -f -o FILE` with the variables
above; in Game Mode
`DISPLAY=:0 xprop -root -f GAMESCOPECTRL_REQUEST_SCREENSHOT 32c -set GAMESCOPECTRL_REQUEST_SCREENSHOT 1`
writes `/tmp/gamescope.png`.

## Checked (2026-10-16)

Deck: SteamOS 3.8.28 (build 20260922.1), glibc 2.41, over Wi-Fi. Package:
the 2026-10-13 release asset `ntsd-linux-x86_64-f340f1e.tar.gz` (SHA-256
`3c6048dc34feab1e6ac16bb91790d6979e068fa78feae8c5ccd80d0b4098dea4`, equal on
the Mac's copy and after upload); every library resolved.

- **Desktop Mode** (KDE Plasma, Wayland): SDL chose Wayland video and PipeWire
  audio and found DejaVu Sans Condensed Bold. The user played a VS match
  (`matchLaunched`, `gameplay`); B (Esc) brought the quit question, answered
  No three times and Yes once, which closed the game.
- **Game Mode**: Steam's log shows the shortcut launched through
  `steam-launch-wrapper` and `reaper`; the game chose X11 under gamescope and
  PipeWire, opened Steam's virtual pad ("Microsoft X-Box 360 pad 0"), and a
  gamescope capture shows the title screen full screen. Steam loaded its
  default gamepad template for the shortcut (`controller_neptune_gamepad_fps`).
  The user then started a match (`matchLaunched`, `gameplay`), still running
  12 000 cycles later.
- **Scripts**: `add_shortcut.py` wrote the shortcut and art with Steam closed,
  and Steam launched the shortcut; on the Deck, `--check` recognised the
  installed shortcut and the signed-in account, and a write while Steam ran
  was refused. `steamdeck_install.py` refused a running game and a non-x86_64
  archive name, and then, in Game Mode with the game closed, installed a
  package built from `main` 94581233 end to end in 9.5 s: uploaded 208 MiB,
  unpacked with every library resolved, removed the older archive and found
  the shortcut and art already in place, so Steam was left running.

Not checked: which of touchscreen and trackpad the user used on the title
screen, the Steam overlay (the 32-bit
`gameoverlayrenderer.so` preload warning in the log is expected for a 64-bit
game), suspend and resume.

## Library art

`tools/crossplatform/steamdeck/art/` was cut with `sips` from a Desktop Mode
screenshot of the title screen: `portrait.png` 600×900 (the title and menu,
letterboxed), `wide.png` 920×430, `hero.png` 1920×620 and `icon.png`
256×256 (Naruto's face).
