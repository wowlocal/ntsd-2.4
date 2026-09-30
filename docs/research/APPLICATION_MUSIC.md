# Music output in the app: the original tracks play and loop

2026-09-29. [Plan](APPLICATION_MUSIC_PLAN.md). Parent: [tick speed](APPLICATION_TICK_SPEED.md)
(9d33d8d). Author implementation and machine checks; independent review open.
The original was not executed.

## Result

The app plays the original music where the game asks for it: `bgm\main.wma`
in the menus and `bgm\boss1.wma` in the District match of the computer-VS
script, at the game's requested volume −500 (gain 10^(−500/2000) ≈ 0.56).
Tracks change only with committed DirectShow graph state. When a track ends,
the recovered WndProc callback restarts it, as in the original (stage 2).

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

- **Track end (stage 2):** message 0x400 is no longer an "Unrecovered window
  message": `OriginalApplicationMenuSession.step` routes it to the accepted
  `OriginalGraphEvents.receive` (401e90, GRAPH_EVENTS) with a fresh undefined
  64-byte frame and no global writes; its DefWindowProc joins the window
  provider, GetEvent/FreeEventParams/seek go to a new `graph` provider
  threaded through Bootstrap, Host `step` and the iteration exchange
  (`.graph` request/reply; default: dependency boundary). The runtime
  (declared DirectShow behavior) keeps SetNotifyWindow/Flags, queues
  EC_COMPLETE (1, S_OK, 0) once when the output reports the end of the
  running graph's track, posts the registered message (wParam 0), answers
  GetEvent with timeout 0 (the event, else E_ABORT without outputs) and
  FreeEventParams, and DefWindowProc(0x400) returns 0. The app posts after a
  committed iteration; the callback's put_CurrentPosition(0) restarts the
  player. Script action `musicend` forces an end for automated runs.

## Checks

- `OriginalMacRuntimeMenuTests.testGraphNotificationRestartsTheMenuTrack`:
  real front-menu iterations on runtime providers until `bgm\main.wma` runs,
  then EC_COMPLETE and the posted 0x400 pass PeekMessage/DispatchMessage into
  the WndProc callback; requests in order GetEvent→(1,0,0),
  put_CurrentPosition(0), FreeEventParams(1,0,0), GetEvent→E_ABORT; the graph
  keeps running with one seek to 0.
- `OriginalMacMusicOutputTests` (6: packaged frames = manifest, graph state
  with seeks and release, graph event queue/notify flags/stop, output
  decisions, one report per end, gain), `OriginalMacRuntimeMenuTests` (3),
  `OriginalMacRuntimeStartupTests` (4): 13/13. Suites of the changed layers
  (Bootstrap, Host session, observed iteration/graphics, menu input, input,
  runtime loading): 25/25 in 13.6 min with 3 parallel workers.
- App (release, `--mute-music --virtual-clock 123456789 8`, `cpu12`):
  `bgm\main.wma` in the menus, `bgm\boss1.wma` through the match; forced
  ends at menu iteration 100 and game step 2001 each post one notification,
  the callback makes its 4 requests and the track restarts from 0.00 s;
  body captures stay byte-identical to the tick-speed reference (300..1500
  with the stage-1 binary, 300/600 with the stage-2 binary).
  A real-clock menu run left idle: `main.wma` ended on its own twice (after
  the 241 s track), each end posting one notification and restarting the
  track (music time 203 s → 49 s → 177 s → 80 s at iterations 20000..35000).
  That run also showed front-menu iterations slowing over time (41, 53, 74,
  87, 127, 145 s per 5000 iterations): per-iteration work grows with the
  history (cause not yet profiled); recorded as the next speed follow-up.
  [Evidence](../evidence/application-music.json).

## Remaining

The `.app` packaging for `--original` still relies on SwiftPM resource
bundles in the build directory (Core catalog and music alike). No device
listening test or Windows audio comparison. EXE envelope not recalculated.

**Review (2026-09-30):** an independent review confirmed the DirectShow
answers (method offsets, put_CurrentPosition word order, volume, E_ABORT on an
empty GetEvent, EC_COMPLETE with the graph still running, SetNotifyFlags(0),
the 401e90 callback order) and found two defects, both fixed:

- **Determinism.** A track's end was timed by AVAudioPlayer on the wall clock
  even with `--virtual-clock`; its EC_COMPLETE message then took an iteration
  at a machine-dependent point, shifting later script steps, the virtual time
  and the loop counter on long runs. With a virtual clock the output now keeps
  the position in virtual time (advancing while the graph runs, held while it
  is stopped, reset by seeks) and ends the track there; the real player's end
  is ignored. The e2e set passes unchanged (no scenario had crossed a track end
  in a way its references recorded).
- **A late end report.** The finish callback hopped asynchronously to the main
  thread, so a seek in between could be overtaken and leave the track marked
  ended; it is now handled synchronously when AVAudioPlayer calls it on the main
  thread (its usual thread).

The review found nothing definite in the Demo start (its declared ECX value is
used only as "outside 0..8"; the doc's "E_FAIL of its own GetDC" is only the
reason for the chosen constant) or in the Mission app wiring.
