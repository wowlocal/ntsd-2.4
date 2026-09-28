# Runtime WinMain providers — the app starts the original application

2026-09-28. [Plan](APPLICATION_RUNTIME_STARTUP_PLAN.md) under WORKFLOW and
PROGRESS_RULES. Author implementation and machine checks; independent review is
unavailable and remains open. No original code executed.

## Result

`NTSDNative --original` now runs the recovered WinMain from the packaged
initial image to `.started` on real Mac services, with no corpus reply,
fixture or expected state. The window, DirectDraw, sound device and five menu
WAV buffers are served by the existing NTSDMacPlatform backends; every other
startup request is answered by new runtime code:

| File | Role |
| --- | --- |
| `NTSDMacPlatform/OriginalMacRuntimeStartupService.swift` | clock, critical section, COM, time zone, calendar allocation, `_write`/close staging, cursor, joystick, OutputDebugStringA; mmio results for packaged WAVs |
| `NTSDMacPlatform/OriginalMacRuntimeZone.swift` | TIME_ZONE_INFORMATION from the macOS zone (Windows day-in-month rules) |
| `NTSDMacPlatform/OriginalMacRuntimeMusic.swift` | DirectShow success path with owned COM identities/refcounts; output silent |
| `NTSDMacPlatform/OriginalMacRuntimeHeap.swift` | runtime logical allocator (declared arena, zero backing) |
| `NTSDMacPlatform/OriginalMacRuntimeStartup.swift` | startup composition and the user-data overlay |
| `NTSDApp/OriginalRuntimeLaunch.swift`, `main.swift` | `--original` launch path |

The window backend gained one additive accessor (`arrowCursorToken`). Core
rules, expected bytes, masks, fixtures and existing tests are unchanged.

Two contracts were corrected during the first app launch, both from saved
source evidence rather than guesses:

- The windowed DirectDraw path issues two OutputDebugStringA calls (`debug`)
  that neither Mac backend owns; in the passing test they were corpus replies.
  They are now recorded runtime no-ops (void API; no debugger attached).
- The source records `_write` inputs `now 0 4` and ` <end>\n` (LF) with result
  7 each. The CRT file is text mode, so the physical file gets CR LF while the
  result counts the caller's bytes. The second app run staged LF-only bytes into
  the overlay; the corrected third run restores the shipped bytes exactly.

## Checks

[Evidence](../evidence/application-runtime-startup.json). Xcode toolchain
(Swift 6.4) debug build of all targets and tests: exit0 in39.9s. The `swift`
first on PATH (swiftly 6.3.3) cannot build this package on the current SDK;
`tools/build-native.sh` now pins Xcode's toolchain through `xcrun`.

- New `OriginalMacRuntimeStartupTests`, 4/4 pass (7.96s): Windows day-in-month
  rules for Berlin, New York, Sydney, Moscow and UTC equal their public registry
  values; heap disjointness/alignment/bound; DirectShow identity/refcount/volume
  path; two whole WinMain runs with pinned clocks. The second run reads the
  overlay and its expiry crosses the October DST change; both formatted dates
  equal an independent Foundation calendar computation. `_write` inputs equal
  the source-recorded defaults write, and the translated overlay file equals the
  shipped `adinfo.txt`. 75 requests: window11/display8/audio22/runtime34.
- Retained regressions (changed window/audio dependency): 9/9 pass.
- App: three recorded launches; the third starts in76 attempts and writes the
  overlay file byte-equal to the original (SHA `bbbc6259…`).

These are Native/Mac executions with declared runtime policies, not Windows
or device observations. Build artifacts stay in the ignored `build/swiftpm-app`
(internal disk, instead of the planned `native/.build`, to keep toolchains apart).

## Remaining blockers toward the Naruto/Sasuke match

1. **Message loop (next card).** `Host.step` takes peek/get/translate/dispatch/
   time/sleep replies only as a prepared array. A permit-based loop driver,
   following the existing lifecycle/bitmap/graphics iteration drivers, is needed
   to serve live NSEvent input and the real clock without predicting Core flow.
2. Front raster text: `OriginalMacDisplayBackend` rejects GDI text requests.
3. Loading/catalog/pool/loaded-menu providers still come from saved corpora in
   the passing whole caller (allocation, bitmap surfaces, file handles, time,
   message).
4. Music output (WMA decode/playback and graph events), window/input/audio on a
   device, Windows, clean-Mac, full match and full game remain open.
EXE envelope not recalculated.
