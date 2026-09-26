# Profile-aware view capture controls before display correction2

2026-09-26, HEAD6ba168e. The preceding goal turn made progress: preserved the
display failure and identified its bitmap-profile readback discrepancy in48/8
Native controls. Parent [diagnosis](APPLICATION_MAC_DISPLAY_COLOR_DIAGNOSIS.md),
[display implementation](APPLICATION_MAC_DISPLAY.md), [failed whole caller](APPLICATION_MAC_DISPLAY_CORRECTION1.md).
The next consumer is the required whole-clear/AppKit readback method, a graphics
gate toward Naruto/Sasuke District and full native game. No original execution.

## Contract and finite controls

Implement a standalone OriginalMacViewCapture value which owns an immutable copy
of actual cached bitmap pixels. Obtain its CGImage (with its actual color space),
draw into an explicit sRGB8 premultiplied RGBA bitmap CGContext without scaling or
interpolation, then copy all bytes. Expose dimensions and bounds-checked colorAt
returning an explicitly sRGB NSColor, undoing alpha premultiplication; zero alpha
returns transparent black. Reject absent image, overflow, allocation failure or
an explicit byte budget before copying. Never take input expected RGB, source
framebuffer values or a re-tagged bitmap as captured output. Window rendering and
framebuffer remain unchanged. This is a capture/comparator contract correction,
not a game-rendering correction or original Windows color claim.

One new finite probe reuses the prior NSImage view draw/cache pair with two4x4
patterns (16 declared colors and their reversed order) and the same794x550 client.
Six view cases = default/sRGB/screen window profile times two patterns; two direct
sRGB pattern bitmaps provide known-color controls. Sample16 tile centers each:
128 opaque samples. Reference calculation constructs NSColor from raw getPixel
components plus the bitmap's actual colorSpace, independently of the proposed
whole-image CGContext path; compare both to declared input RGB within original
2/255 tolerance. Keep raw observations and wrong legacy colorAt values.

Add one2x2 sRGB premultiplied-alpha bitmap with four fixed RGBA inputs:
(0,0,0,0), (32,16,8,64), (64,32,16,128), (255,128,64,255). Compare straight RGB/alpha
against direct component arithmetic at2/255. Check four out-of-bounds points,
two snapshot-after-source-mutation cases, missing image and maximumBytes1 rejection.
These are finite native diagnostic controls, not all formats/gamuts/devices or
whole production acceptance. Pin the cases before running. If any check fails,
preserve it before correction; do not relax the tolerance or orientation contract.

Keep prior probes, errors, test bodies, expected values and masks immutable.
Independent review is unavailable; author review and different calculation paths
are not independent human/agent review. Record that gap and continue permitted
implementation/checks under WORKFLOW. Do not mark the comparator independently
accepted. After successful controls publish/commit before a separate exact-clone
display correction2 importing this exact helper and replacing captureView's return
type/body only. Then require fresh package/build and unchanged34 methods/limits.

## Inputs, bounds and delivery

Task application-mac-view-capture-20260926 under X5 parent
01a0dc49-738f-7972-8fb0-e98fb2f34408; verify writable APFS UUID
3A4F5FA6-DC86-4C6E-87E2-EAC2C2D72548 and>=65GiB external/9GiB internal before IO.
Retain40/6GiB reserves plus17GiB source commitment. Physical4GiB, stop observed
decrease3GiB, logical8GiB, metadata/archive4MiB, root1MiB. One compile300s/RSS4GiB,
one probe120s/RSS2GiB, closure300s. Reuse the existing diagnostic preparation,
unchanged monitor body and PAX closure; explicit installed SDK/macOS14 target.
Revalidate terminal predecessor jobs and PID/start/command/cwd/job before action.
Only task files, its adapter/probe/helper, plan/study/evidence and own navigation
may change. Root1034, failed2261, source55, old artifacts/incidents are protected.
No EXE/DLL/emulator/capture/refused operation; Source59727 remains terminal34 Objects,
not137. Compile/probe failure stops the task before another declared round.
Full34/review/root promotion/general graphics/providers/loading/Windows/input/audio/
clean-Mac/full match/full game remain open; EXE envelope not recalculated.
