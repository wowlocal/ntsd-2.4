# Music output in the app: plan

2026-09-29. Parent: [tick speed](APPLICATION_TICK_SPEED.md) (9d33d8d).
Rules: [WORKFLOW](WORKFLOW.md), [PROGRESS_RULES](PROGRESS_RULES.md). Written
before the change. **Executor/reviewer:** Claude; independent review open.

**Consumer and criterion:** the app plays the original tracks where the game
asks for them — `bgm\main.wma` in the menus, the arena track in matches —
following the recovered DirectShow calls (RenderFile, Run, Stop,
put_CurrentPosition, put_Volume), and (stage 2) loops a track the way the
game does after EC_COMPLETE.
**Proven blocker:** `OriginalMacRuntimeMusic` answers every call but is silent
(startup plan: "audio output is silent: WMA decode/playback is a separate
dependency"). The 8 `bgm/*.wma` files are WMA v2 (5) and WMA Pro (3); macOS
has no decoder for either.

## Stage 1: assets and playback

1. `tools/package_music.py` (build tool, never runtime): checks the 8 source
   SHA-256s; decodes each with FFmpeg's native decoders to float (version
   recorded); converts to int16 by round-half-even of x·32768 with saturation
   (declared rule; Windows' WMA decoder PCM is not claimed); encodes ALAC in
   CAF with Apple's `afconvert`; verifies Apple's decode returns the int16
   PCM bit for bit; writes `NTSDMacPlatform/Resources/OriginalMusic/*.caf`
   and a manifest (source, PCM and file hashes, frames, tool versions).
   Verify mode re-checks without rewriting. The CAF files go through LFS.
2. `OriginalMacRuntimeMusic` keeps its answers and adds the state the output
   needs: the rendered file per graph, running, volume and a seek generation
   with the put_CurrentPosition value (REFTIME, a double of the two words).
3. `OriginalMacMusicOutput` (AVAudioPlayer): after each committed iteration
   the app presents the live graph's state; the output loads the packaged
   track for the rendered path (`bgm\<name>.wma`, ASCII, case-insensitive),
   plays while running, pauses on Stop, seeks when the generation changes and
   sets gain 10^(volume/2000) (hundredths of dB; −10000 is silence). Nothing
   plays from an uncommitted attempt. Unknown paths stay silent and are
   reported.

## Stage 2: track end

Compose the recovered WndProc graph callback (`OriginalGraphEvents.receive`,
message 0x400, [GRAPH_EVENTS](GRAPH_EVENTS.md)) into the application message
dispatch; the runtime answers GetEvent (EC_COMPLETE once per finished track,
then E_ABORT) and FreeEventParams, and posts the registered notify message
when the output reports the end. Planned separately before implementation.

## Checks

1. Tool: verify mode on all 8 tracks; manifest committed.
2. Unit tests: path resolution, volume mapping, present() decisions with a
   recording player; every packaged track opens with the manifest's frame
   count.
3. App: menu and computer-VS runs report the live track, running state and
   volume at checkpoints; the tick-speed captures stay byte-identical.

EXE envelope not recalculated. Out of scope: GDI text, device/Windows audio
comparison.
