# Sound effects in the app

2026-09-29. [Plan](APPLICATION_SOUND_EFFECTS_PLAN.md) stages E1–E3. Before this
card the app played music only: every WAV sound effect the ported code asked
for was recorded and dropped. The original was not executed.

## E1 — DirectSound buffers as voices

`OriginalMacSoundEffects` (MacPlatform) models the original's secondary
buffers under the declared DirectSound policy of the plan: one voice per
buffer token; Stop (0x48) keeps the cursor, SetCurrentPosition (0x34) moves it
(bytes → frames by block alignment), Play (0x30) starts at the cursor and
loops with flag 1, SetVolume (0x3c) and SetPan (0x40) in hundredths of a
decibel (gain 10^(v/2000), positive pan attenuates the left channel, negative
the right). Values outside DirectSound's ranges are rejected
(DSERR_INVALIDPARAM) and leave the voice unchanged; other methods or argument
counts are boundaries. Voices sum and clip; linear interpolation resamples to
the output rate; a one-shot voice that ends stops with its cursor at 0. PCM,
format and the registered volume come from the audio backend that already
owns every loaded WAV (`OriginalMacAudioBackend.pcmSnapshot`, `observation`,
`volumeObservation`: catalog sounds are registered at −10000, the menu sounds
at 0).

`OriginalMacSoundOutput` renders the voices through an AVAudioEngine source
node. The original creates its buffers with flags 0xe0 (pan, volume and
frequency control) and without DSBCAPS_GLOBALFOCUS / DSBCAPS_STICKYFOCUS, so
DirectSound silences them while the game window is not in the foreground; the
output does the same while the app is inactive (music is unaffected).

Tests (`OriginalMacSoundEffectsTests`): the helpers' Stop/SetCurrentPosition/
Play sequence from a registered −10000 volume, looping and Stop keeping the
cursor, the gain/pan law and rejected ranges, stereo mixing with resampling,
committed-batch extraction in order with music tokens separated, and
boundaries for unknown methods, argument counts and buffers.

## E2 — the runtime

Sound methods have no permits; Core records them in committed batches. The
runtime now performs them in commit order: iteration effects before START
(`OriginalMacRuntimeMenu.step`), and loaded batches after START
(`OriginalMacRuntimeLoading.finish`) — their own `.soundMethod` effects (menus,
the gameplay queue drain) and the input phase they carry (hotkey controls,
round methods, staged pool/catalog/loading effects). `control()` answers a
hotkey's `.soundRequest` and `.method` as notices; the methods play at
commit. Round and control methods also carry DirectShow calls: in Mission
(mode 1) the round stops the music (IMediaControl::Stop 0x24,
IMediaPosition::put_CurrentPosition 0x20) through the same `.method` event
kind. Calls on the music runtime's interface tokens
(`OriginalMacRuntimeMusic.interface`) are therefore not sounds; any other
token goes to the voice model, where an unknown buffer is a boundary (the
Mission e2e first stopped there, on music token 9).

`--mute-sounds` keeps the voices running at zero output gain; the scripted
tools pass it. Progress and capture events report `sounds` (performed,
rejected, playing, looping, rendered/audible frames, peak).

Found gap, not changed here: those round music methods were delivered to no
one, so the app's Mission music kept playing where the original stops it —
fixed by the next card, [round music stop](APPLICATION_ROUND_MUSIC.md).

## E3 — checks

- Computer-VS e2e match (release app, muted output): 1835 calls, 0 rejected,
  no boundary; about 63 % of the rendered frames carry signal; overlapping
  full-volume hits reach a pre-clip peak of about 3.4 (the queue's volumes are
  mostly 0: its base term is 0 when 44d000 is 100). In the first 300 bodies
  the buffers were mono, mostly 22,050 Hz, under a second each; no voice
  looped.
- `LF2.NET` typed on the mode menu (its latch 455471 → 416c70) now plays its
  sound — three more calls than the same run without it — where it used to
  stop at the `soundRequest` boundary.
- The whole e2e set passes on the final release app with `--mute-sounds`
  (vs with the Quit check, mission, demo, war, playback, tournament,
  team-tournament; the references are unchanged).
- `OriginalMacSoundEffectsTests` 6/6; the Mac music-output, audio-backend,
  runtime menu/loading/startup suites 20/20. The whole-catalog
  `OriginalMacLoadingAudioTests` suite was not rerun (its paths are unchanged).

[Evidence](../evidence/application-sound-effects.json). A listening check on a
device and a Windows comparison remain open.

EXE envelope not recalculated.

**Review (2026-09-30):** an independent review confirmed the DirectSound
semantics (vtable offsets, DSBPLAY_LOOPING, volume and pan ranges and signs,
byte positions, Stop keeping the cursor, Play on a playing buffer, 8/16-bit and
mono handling, resampling across the loop point, locking) and found that the
output engine was never restarted after an audio hardware change, which leaves
the effects silent for the rest of the session. `OriginalMacSoundOutput` now
restarts its engine on `AVAudioEngineConfigurationChange`. It also found the
menus' call order issue fixed in APPLICATION_FRONT_MENU_ITEMS.md.
