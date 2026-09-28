# Music output in the app, stage 1: the original tracks play

2026-09-29. [Plan](APPLICATION_MUSIC_PLAN.md). Parent: [tick speed](APPLICATION_TICK_SPEED.md)
(9d33d8d). Author implementation and machine checks; independent review open.
The original was not executed.

## Result

The app plays the original music where the game asks for it: `bgm\main.wma`
in the menus and `bgm\boss1.wma` in the District match of the computer-VS
script, at the game's requested volume −500 (gain 10^(−500/2000) ≈ 0.56).
Tracks change only with committed DirectShow graph state. Looping after the
end of a track (EC_COMPLETE → WndProc 0x400) is stage 2 and not connected:
a track plays once, then the running graph stays silent until it seeks.

- **Assets:** `tools/package_music.py` decodes the 8 `bgm/*.wma` (5 WMA v2,
  3 WMA Pro) with FFmpeg 9.0.1's native decoders to float, converts to int16
  by round-half-even of x·32768 with saturation (declared rule; 7 samples of
  `main` saturate), encodes ALAC/CAF with Apple's `afconvert` and requires
  Apple's decode to return the int16 samples bit for bit. 8 tracks, 56423177
  frames (21.3 min), 116.9 MB through LFS in
  `NTSDMacPlatform/Resources/OriginalMusic` with a manifest (source, PCM and
  file hashes). Verify mode passes. Windows' WMA decoder PCM is not claimed:
  FFmpeg's decode and two FFmpeg int16 paths already differ by 1 LSB.
- **Runtime:** `OriginalMacRuntimeMusic` still answers every call without
  effect and now records put_CurrentPosition (REFTIME double of the two
  argument words; count and value) and exposes the newest live graph
  (`presented()`).
- **Output:** `OriginalMacMusicOutput` (AVAudioPlayer) follows that state
  after startup and after every committed iteration: loads the packaged track
  for the rendered path (case-insensitive), plays while running, pauses on
  Stop, applies each seek once (clamped), sets gain 10^(volume/2000) with
  −10000 silent; a new graph gets a new player; unknown paths stay silent and
  are reported. `--mute-music` keeps real playback at zero gain for automated
  runs.

## Checks

- `OriginalMacMusicOutputTests` (4: packaged frames = manifest, graph state
  with seeks and release, output decisions with a recording player, gain) and
  `OriginalMacRuntimeStartupTests` (4, including whole WinMain with runtime
  providers): 8/8.
- App (release, `--mute-music --virtual-clock 123456789 8`, `cpu12`): the
  player reports `bgm\main.wma` playing at menu iterations 30/500/1200 and
  `bgm\boss1.wma` playing through 1500 bodies (time 9.2 → 48.7 s); body
  captures 300..1500 stay byte-identical to the tick-speed reference.
  [Evidence](../evidence/application-music.json).

## Remaining

Stage 2: compose `OriginalGraphEvents.receive` into the application message
dispatch (0x400 is "Unrecovered window message" there today), answer
GetEvent/FreeEventParams and post the notify message when a track ends. The
`.app` packaging for `--original` still relies on SwiftPM resource bundles in
the build directory (Core catalog and music alike). No device listening test
or Windows audio comparison. EXE envelope not recalculated.
