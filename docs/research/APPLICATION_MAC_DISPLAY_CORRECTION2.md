# Display correction2 — sRGB window backing and owned view capture

The isolated candidate explicitly sets native windows to sRGB before showing them
and returns an owned, profile-aware snapshot from captureView. Its framebuffer,
NSImage drawing, game requests, allocation/release behavior and Core algorithms
remain unchanged. All earlier test bodies, expectations and per-method limits are
exact; a new whole-window pattern method precedes the previous34 methods.

[Plan](APPLICATION_MAC_DISPLAY_CORRECTION2_PLAN.md),
[prior whole-caller failure](APPLICATION_MAC_DISPLAY_CORRECTION1.md),
[readback diagnosis](APPLICATION_MAC_DISPLAY_COLOR_DIAGNOSIS.md),
[preserved additional color mismatch](APPLICATION_MAC_VIEW_CAPTURE.md).
Input HEAD1cd74a1; actual2261-file base manifest
`4f1083e2a0fa1f94696bd78fd6fdf9dca328e0b921497e26ac640bf921a88c37`.
New2263-file manifest
`89f795574ca6ef954a2f44c0a3c1078a8c259c562f51863092bbfa9ea5131417`.
Task build/research/application-mac-display-correction2-20260926 on declared X5.

## Contract and rationale

Earlier colorAt samples were interpreted in Generic RGB despite the actual bitmap
ICC profile. Separate controls also found input-blue differences after an8-bit
monitor-profile window/cache roundtrip, while explicit sRGB/direct controls retained
all declared colors. Both failures remain immutable and nonpassing. The new native
backing policy matches the already explicit sRGB image format; it is not a measured
Windows format or a conclusion about original monitor calibration.

OriginalMacViewCapture is imported byte-for-byte from the preserved controls. It
reads the cached CGImage with its actual profile into an explicit same-size sRGB
RGBA buffer, copies its bytes, validates bounds and returns tagged sRGB colors.
It never receives expected RGB or game pixel storage. This is an explicitly recorded
capture/comparator contract change, supported by separate calculations on actual
pixels. Independent review remains unavailable; author review is not independent.

The added test runs whole startup with the production physical window backend,
displays two reversed4x4 patterns containing16 colors, checks32 centers with the
original2/255 tolerance and alpha1, rejects out-of-bounds samples, and retains the
first snapshot after another display. All34 earlier methods remain required,
including physical display allocation/clear/lifetimes and420 original clear cases.

Preparation2042 is terminal0/absent in14.213s. One old file changes,
OriginalMacWindowBackend.swift; two files are added, OriginalMacViewCapture.swift
and OriginalMacDisplayColorTests.swift. Every other old candidate file, including
all prior tests/resources, remains exact. Runner monitor and result predicates are
unchanged; only task/count/source-membership domains expand to35 methods and
199Core/61Reference/6MacPlatform/280tests with the same1686 resources.

## Remaining scope

This is a native graphics dependency toward the first Naruto/Sasuke District match,
not full rendering or game acceptance. Original Windows/device/color/palette/text,
general blit/presentation, callbacks/fullscreen, other providers/loading, input/audio,
root promotion, independent review and clean-Mac/full match/full game remain open.
NTSDApp still Practice. Source59727 remains terminal34 Objects, not137. No original
game/emulator/capture/refused operation runs; incidents remain open. EXE envelope
not recalculated. Build, package, each selected method and archive gates are reported
separately below when terminal evidence exists.

## Observed build and comparison

Fresh build2705 terminal0/absent in293.958s, sampled peak tree RSS6,671,466,496
bytes; no guards/signals/residuals. Package verification checks199Core/61Reference/
6MacPlatform/280tests and1686 regular resource files (385fixtures/1301runtime).
Test binary65,600,376 bytes, SHA256
`1c0cf5819cedfe2630fedab52d19260addc1cb69a314a0571ee0db0013d8a184`.

Queue13876 terminal0/absent in185.437s. All35 exact one-method results pass,
including the new32-sample pattern method, the previously failing whole-clear
readback, resource/budget/protocol/late-retry lifetimes, every retained startup
method and the420-case original clear comparison. All child jobs are terminal0,
without guards, signals or remaining processes. New pattern XCTest time0.451s;
whole-clear readback1.366s. These are finite local AppKit observations and controlled
original-request regressions, not original Windows pixel comparison.

The native window client remains794x550 logical points; the readback is1588x1100
pixels. Primary clear0x00336699 still uses client clip(1107,317,794,550). The old
2/255 expected RGB assertions pass unchanged. Earlier default-monitor controls
remain recorded as nonpassing; the new candidate changes the window backing policy
and reader, not their saved results. Independent review/root promotion stay open.

## Verified closure and next dependency

Finalizer20982 terminal0/absent in83.371s. The4944-file regular artifact archive,
173-member PAX metadata archive and three-file patch roundtrip are verified with
full bodies/modes/nsmtimes/membership. Root1034/prior2257, original/failed/correction1
candidates and current2263 files, plus55 source pins, remain exact. Task frozen.
[Publication](../evidence/application-mac-display-correction2.json),
[closure](../evidence/application-mac-display-correction2-close.json),
[patch](../evidence/application-mac-display-correction2.patch).
Build/package/all35/archive pass; independent review and root promotion are open.

NEXT: the concrete native bitmap/DIB acquisition and surface-copy provider for the
startup/front-screen loader, on this same display owner. Use the recovered whole
[bitmap loader](BITMAP_SURFACE_LOADING.md), [source-color ownership](APPLICATION_SURFACE_COLORS.md)
and [graphics ownership](APPLICATION_GRAPHICS_OWNERS.md), pin a finite adapter
contract, and retain whole-caller/error/lifetime comparisons. This supplies actual
artwork to the native loading/menu path.
Unknown DIB masks, palette/format conversion and failed GDI acquisitions stay explicit.
Presentation's109 saved zero destination rectangles must remain zero; live callback/
rectangle provenance and real presentation remain separate required dependencies.
