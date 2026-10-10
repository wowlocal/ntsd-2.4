# P5: shared runtime split (NTSDRuntime)

Design for phase P5 of [CROSS_PLATFORM](CROSS_PLATFORM.md). It comes from a
read-only mapping of `native/Sources/NTSDApp` and
`native/Sources/NTSDMacPlatform` on 2026-10-03 (`ebb9adc`). Line numbers are as
of that commit.

The goal is a target, `NTSDRuntime`, that compiles without AppKit or
AVFoundation and holds orchestration, surface semantics and audio/music
sequencing. An SDL3 backend can then reuse it. The AppKit app must behave
identically, and Core's `OriginalRequestExchange` ordering, retry and lifetime
rules stay as they are.

## Where the Apple dependencies are

Most of NTSDMacPlatform is plain Swift and Foundation. Apple APIs are
concentrated in a few places:

- the AppKit window host (`OriginalMacWindowBackend`, ~150 portable lines out
  of 444; `(NSEvent)->Bool` appears in signatures at 178 and 208);
- CoreText `textMask` (`OriginalMacDisplayBackend` 644-662) and CGImage
  wrapping (285-289). About 850 of the display backend's 899 lines are
  portable;
- `AVAudioPCMBuffer` used as sample storage (`OriginalMacAudioBackend`), the
  `AVAudioEngine` output (`OriginalMacSoundEffects` 224-256) and the
  `AVAudioPlayer` wrapper (`OriginalMacMusicOutput` 118-136, which already has
  a `Player` protocol at 12-19);
- Darwin sockets with DispatchSource in `OriginalMacWinsock`. It uses
  `SO_NOSIGPIPE` and `sin_len`, and its `10000+errno` mapping is only valid for
  BSD errno numbers;
- NSAlert, NSOpenPanel and NSWorkspace defaults in RuntimeMusic, RuntimeMenu
  and RuntimeLoading, and the caps-lock default from NSEvent (Menu 38);
- in the launcher (`NTSDApp/OriginalRuntimeLaunch`), GameController, NSEvent
  translation (284-321), NSAlert, the menu, focus notifications and App Nap.
  About 520 of its 701 lines (argument parsing, `iterate`, traces,
  `presentMusic`) are portable.

`OriginalMacRuntimeMessages` imports AppKit but uses nothing from it. Its key
table is keyed by Mac key codes. IdentityPool, Heap, Zone, RuntimeNetwork,
StartupService and the six `*Service` files have no Apple APIs; they only
depend on concrete backend classes.

## Seams

- **Move unchanged:** IdentityPool, Heap, Zone, RuntimeMessages, RuntimeNetwork,
  StartupService, Wave, Overlay (without `standard()`), and the
  Audio/Bitmap/Front/DisplayStartup services.
- **`OriginalRuntimeWindowing`:** `identities`, `lease(token)`,
  `displayGeometry(token)`, `present(_ frame: OriginalFramebuffer, in:)`,
  `arrowCursorToken`/`loadArrowCursor()`, `retainedResources`, and opaque
  `prepareWindow`/`performWindow`. The framebuffer is little-endian XRGB8888.
  The Mac conformance builds the same sRGB `noneSkipFirst|byteOrder32Little`
  CGImage as today.
- **Glyph rasteriser:** `textMask(_ bytes:) -> TextMask`. CoreText stays on
  Mac. An SDL backend must reproduce identical masks before frame equality
  can hold.
- **Input:** no new protocol. The host pushes into `messages.key/mouse/joystick/close`
  and supplies `point()`, `capsLock()` and the joystick count.
- **Audio:** the shared mixer keeps voice start, stop and position. The output
  pulls `effects.render(frames:rate:left:right:)`. A portable sample buffer
  replaces `AVAudioPCMBuffer`; keep the `ready` = `frameLength > 0` rule.
- **Music:** the existing `Player` plus `load(url, ended:)` and a track map.
- **Winsock provider:** the public surface of `OriginalMacWinsock`. It becomes
  POSIX on Linux and real Winsock on Windows in P7.
- **Dialogs and app host:** `messageBox`, `chooseRecording`, `alert`,
  `open(after:)`, `schedule(after:)`, snapshots, fullscreen and terminate.

## Steps (lowest risk first)

Every step must leave the Mac app building and behaving identically. Checks:

- the Xcode release build;
- the release-path Mac tests named for the step;
- `swift test list` still returning 696 tests (697 or more after new tests);
- an `NTSD_PORTABLE=1` Linux build of `NTSDRuntime`.

1. Manifest: add `NTSDRuntime`; NTSDMacPlatform does
   `@_exported import NTSDRuntime`. Add `@testable import NTSDRuntime` to the
   Mac tests that use internal members.
2. Leaf moves: IdentityPool (`take()` becomes public), Heap, Zone,
   RuntimeMessages. Tests: RuntimeStartup, RuntimeMenu, ObservedIteration.
3. Sound mixer, with a lock wrapper that keeps `OSAllocatedUnfairLock` on Apple
   platforms. Tests: SoundEffects, LoadingAudio.
4. Music sequencing; the Mac startup still installs the NSAlert `present`.
   Tests: MusicOutput, RuntimeLoading.
5. `OriginalRuntimeWindowing`, with the Mac window backend conforming. Tests:
   WindowBackend, WindowGeometry, DisplayColor.
6. Display backend and its three services, with the rasteriser injected.
   Tests: DisplayBackend, BitmapBackend, FrontRaster, ObservedBitmap/Graphics/Iteration,
   plus app e2e captures.
7. Audio backend, AudioService, `backed(by:)`. Tests: AudioBackend,
   LoadingAudio, SoundEffects.
8. Startup: StartupService, Wave, Overlay, `run(host:)`. The Mac wrapper calls
   `NSApplication.shared` first.
9. Menu, Loading and Network, with dialogs, caps-lock and the Winsock provider
   injected. Tests: RuntimeMenu, RuntimeLoading, NetworkHost/Exit, Winsock,
   plus the full `tools/app_e2e.py` set and the network check.
10. Launcher → `OriginalRuntimeSession(arguments:host:)`. The gate is every
    `tools/app_e2e_*_reference.json` scenario; add a fake-host session test.
11. Window request model into the runtime (prerequisite for P6).

## Risks

- **Globals:** the launcher's global `arguments`; `NSEvent.modifierFlags`,
  `NSEvent.mouseLocation`/`NSScreen.screens`; `Bundle.module` in music.
- **Main-queue draining** must happen at the same point in an SDL loop: Winsock
  FD_* posts (Winsock 331), window lease close (Window 64), delayed document
  open (Loading 480), iteration scheduling (Launch 323), and the music end
  callback (Music 133).
- **Ordering:**
  - the five `windows.present` call sites (Display 365, 685, 848, 861, 873);
  - startup order audio → window → display → runtime (Startup 88-93);
  - `presentMusic` before the WM_QUIT posts and the summed sleeps
    (Launch 452-458);
  - the blocking `Thread.sleep` calls in Network.
- **Defaults:** if the runtime gets no-op defaults for dialogs or caps-lock and
  the Mac side forgets to install the real ones, interactive play changes
  while scripted tests still pass.
- **Frozen tooling:** about 24 historical `apply_*`/`finalize_*`/`verify_*`
  scripts assert `Sources/NTSDMacPlatform` paths, and `tools/OriginalMac*.swift`
  are frozen candidate copies. Leave them unchanged; they are records, not
  gates.
- `OriginalMusic` resources stay in NTSDMacPlatform: `package_music.py:25` and
  `package_assets.py:45` hard-code that path.
