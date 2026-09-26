# Native AppKit color-path diagnosis after correction1

2026-09-26, HEAD6a2fc84. The preserved correction1 second test reports nine color
mismatches while framebuffer words/masks pass. This finite diagnosis identifies
the physical color boundary blocking graphics for Naruto/Sasuke on District.
It does not accept a renderer or replace the unchanged34-method comparison.

Read the [failure](APPLICATION_MAC_DISPLAY_CORRECTION1.md), its plan, the display
implementation and direct window/clear dependencies. Reuse the pinned failed
Native code as the reproduction reference; original NTSD remains the only game-rule
reference. No EXE/DLL, emulator, source capture, blocked operation or old test runs.
Root Native, all old candidates/tests/expected/masks and safety incidents stay exact.

## Finite observations

Compile one standalone AppKit diagnostic with the installed Swift/SDK. Reproduce
the production XRGB8888 CGImage construction, exact NSImage drawing statement and
bitmapImageRepForCachingDisplay/cacheDisplay pair. Preserve extracted source lines
and their parent hashes. Also draw the same CGImage directly through CGContext to
locate the conversion, without changing production code or cached bitmap tags.

Use eight colors: the seven existing clear inputs0,1,0xff,0xff0000,0xff00,0x123456,
0xffabcdef plus failed0x336699. For each, observe an NSBitmapImageRep made directly
from CGImage, and48 view combinations: two drawing paths times three declared
window profiles(default, explicit sRGB, actual screen profile) times eight colors.
Use the same794x550 logical client size, flipped view and no interpolation.
For each cached bitmap record actual dimensions, raw three sample pixels, bitmap
format/color space, returned NSColor space and converted sRGB, CGImage color space,
window/screen profile names and ICC hashes when available. Record draw-context
profiles if available. No retagging or post-hoc correction of measured pixels.
These are controlled Native observations, not original Windows or monitor capture.

Completion: one build and one finite probe, exact case membership and source pins,
diagnosis separating observed facts from inference. Stop/preserve compile, runtime
or result failures before a new bounded correction; no automatic retry. An exit0
only permits inspecting the48 records. If evidence identifies a production defect,
the next task is separately pinned correction2 with unchanged34 tests/limits.
Comparator/readback-contract changes require separate evidence/review; none are
authorized by a convenient passing alternative in this probe. Author review is not
independent review; that gate stays open.

## Storage, process and delivery

Task application-mac-display-color-diagnosis-20260926 on the existing task-owned X5
parent01a0dc49-738f-7972-8fb0-e98fb2f34408. Verify writable APFS UUID
3A4F5FA6-DC86-4C6E-87E2-EAC2C2D72548, free>=65GiB external/9GiB internal before IO;
retain40/6GiB reserves plus17GiB source commitment. Physical allowance4GiB,
stop observed decrease3GiB, logical8GiB, metadata/report<=4MiB, root<=1MiB.
Compile<=300s/RSS4GiB; probe<=120s/RSS2GiB; finalization<=300s. Reuse the existing
host monitor body unchanged, adapting only this finite preflight/task/command
domain. Check process PID/start/command/cwd/job before action, never restart for
silence. Save all source/log/job/config/output pins and a verified PAX archive;
update handoff and commit this coherent evidence before independent work.
No full candidate build/clone is needed for this diagnostic. Source59727 stays
terminal34 Objects, not137. Full comparison/review/root promotion/Windows/visual/
input/audio/full match/full game remain open. EXE envelope not recalculated.
