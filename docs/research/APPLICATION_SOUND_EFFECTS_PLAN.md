# Sound effects in the app — plan

2026-09-29. The app plays music (DirectShow graph → `OriginalMacMusicOutput`)
but no WAV sound effects: the ported sound helpers issue DirectSound buffer
methods, Core records them, and the Mac runtime drops them. This card makes
them audible. The original is not executed.

## Static reading (what Core already produces)

- Helpers: `OriginalMatchPrelude.playSound` (menus, character screens,
  tournaments, hotkeys 416c70/416ca0) and `OriginalQueuedSound.play`/`drain`
  (gameplay queue, per tick). Method calls on an IDirectSoundBuffer token:
  0x48 Stop, 0x34 SetCurrentPosition(0), 0x30 Play(0, 0, flags; 1 = loop),
  0x40 SetPan(pan), 0x3c SetVolume(volume). 44eecc = 0 (no device) skips them.
- Volume and pan from the queue: base ((44d000 − 100)·3800)/100, attenuation
  ((level − 100)·2000)/100, pan ((right − left)·1500)/100 — DirectSound units
  (hundredths of a decibel).
- Loading registers each buffer with SetVolume(−10000); the Mac audio backend
  keeps the float PCM, format and that volume per buffer token
  (`OriginalMacAudioBackend.pcmSnapshot`, `volumeObservation`).
- Commits carry the calls in order: loaded-menu operations
  `.menu(.soundMethod(e, _))` (menus, gameplay drain), input-session
  `.control(q, _)` with `q.kind == .method` (hotkeys) and `.roundMethod(e)`
  (round start). The runtime's `finish()` replays only graphics today, and
  `control()` throws on `.soundRequest`/`.method`.

## Declared platform policy (not from the EXE)

DirectSound's documented semantics, as for DirectDraw's DDERR_INVALIDRECT:
one voice per buffer; Play starts or continues from the current position
(looping with flag 1); Stop pauses and keeps the position;
SetCurrentPosition moves it (bytes → frames by block alignment); volume v and
pan p in hundredths of a decibel: gain 10^(v/2000); p > 0 attenuates the left
channel by 10^(−p/2000), p < 0 the right by 10^(p/2000); voices sum and clip.
DirectSound's resampler is unspecified: linear interpolation to the output
rate. A Windows listening comparison stays open.

## Stages

- **E1 — voice model.** `OriginalMacSoundEffects` (MacPlatform): a DirectSound
  buffer model over PCM from the audio backend, the five methods (other
  offsets are boundaries), and an offline render (frames → stereo floats).
  Tests: method sequences, gain/pan law, looping, stop/position, mixing.
- **E2 — runtime.** Route committed sound calls (the three operation kinds,
  plus the pre-START main menu path if it has its own) to the model in commit
  order; `control()` answers `.soundRequest` as a notice and records
  `.method`; an AVAudioEngine source node renders the voices. `--mute-sounds`
  keeps the model and silences output; scripted checks pass it. Counts of
  served calls appear in progress events.
- **E3 — checks.** The e2e set (sound calls counted, not heard), a listening
  run in the app, and the cheat codes `LF2.NET` / `HEROFIGHTER.COM`, whose
  sounds were a boundary.

EXE envelope not recalculated.
