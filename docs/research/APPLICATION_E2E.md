# End-to-end app check: a whole computer-VS match

2026-09-29. Parent: [constant-cost iterations](APPLICATION_ITERATION_HISTORY.md)
(83f65a6). Author implementation and machine checks; independent review open.
The original was not executed. The plan (below) was fixed after two
exploratory runs of the script and before the reference was recorded.

**Consumer and criterion:** one command replays a whole match on the
release app — WinMain, loading, VS with Naruto/Sasuke and one computer player
on District, the fight, KO, replay file, Summary, epilogue and the return to
Character Selection — and fails on any change of the observed milestones.

## Result

`tools/app_e2e.py` (≈77 s) runs `NTSDNative --original` with
`--virtual-clock 123456789 8`, `--mute-music`, a temporary `--overlay` (new
app option, so no replay or settings touch Application Support) and the
committed script `tools/app_e2e_computer_vs.script` plus a Jump on the
Summary at step 9000. It compares with `tools/app_e2e_reference.json`:

- milestones: startup (75 requests, 76 attempts, fixed dates), loading
  (16105 allocations, 2072 audio, 12817 bitmap requests, 621 files), match
  launch at iteration 1476, the first loaded menu after the match (new app
  event `menu`: 1826 bodies, 1 epilogue, `recording\20260101_010000_VS.lfr`
  of 11044 bytes), the Character Selection capture;
- every 300 bodies: character-AI and object-input counts, window capture
  SHA-256 and the playing track (`bgm\boss1.wma`);
- the overlay files (replay and `data\adinfo.txt`) by SHA-256;
- exit code and boundary.

Captures are PNGs of the window rendering; the reference records the backing
scale (2) and a run on a different scale reports "incomparable". The capture
hashes at 300..1500 equal the tick-speed reference recorded with the user
overlay, so the fresh overlay does not change the match.

Exploratory findings: under this clock the computer knocks out both players
before body 1824; the Summary then stays over the running game until Attack
or Jump (the original behavior; without the key presses bodies continued to
6914); after Jump the epilogue returns to Character Selection with the start
menu on "Fight!".

## Checks

- Recorded once, then a second run: `pass` (6 milestones, 6 progress points).
- `compare` flags a changed object-input count and a changed replay hash.

## Time zone (2026-09-30)

GetLocalTime is answered in the Mac's time zone, and it names the replay files:
the references were recorded in UTC+1, so the virtual clock's 00:00 UTC gives
`20260101_010000`. An independent review noted that the references therefore
matched only on a machine in UTC+1. `tools/app_e2e.py` now starts every app
run with `TZ=Etc/GMT-1`; the vs scenario passes when the script itself runs in
a shell set to `TZ=Asia/Tokyo`.

EXE envelope not recalculated.
