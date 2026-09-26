# Display correction2 — sRGB native backing and profile-aware capture

2026-09-26, HEAD1cd74a1. Continue the actual2261-file correction1 candidate,
manifest4f1083e2a0fa1f94696bd78fd6fdf9dca328e0b921497e26ac640bf921a88c37.
Its whole-startup allocation passes; readback fails. The separate48/8 diagnosis
and [capture controls](APPLICATION_MAC_VIEW_CAPTURE.md) preserve the legacy profile
error and four further default-monitor blue mismatches, not an all-passing matrix.

## Evidence-led changes and consumer

Native images are already declared sRGB. Set each created NSWindow.colorSpace to
sRGB before showing it, so its backing uses the same explicit host color space.
The direct and explicit-sRGB pattern controls preserve all16 colors; monitor-profile
roundtrip does not. This is a Native mapping, not measured original Windows color.
Do not infer clipping/quantization details or alter source expectations.

Import the exact tested OriginalMacViewCapture helper from the frozen control task.
Change captureView to return that owned snapshot of the actual AppKit cached bitmap.
No game framebuffer, rendering statement, pixel format, allocation, release, Core
algorithm or original expected changes. This is also an explicitly identified
capture/comparator contract correction: the helper reads actual tagged image data,
never supplied expected colors, and agrees with a separate per-pixel ICC calculation
on all128 opaque samples. Prior overall control nonpasses remain nonpasses.

Add one actual-window whole-startup test: two reversed4x4 patterns, same16 colors,
32 sampled centers at original2/255 tolerance, opaque alpha, bounds and retained
snapshot across another display. It uses the production window backend and new
capture helper. Run it followed by every previous34 method unchanged, preserving
their relative order and per-method limits. Include the420-case original clear
comparison. Total35; no previous failure or method is excluded.

Success requires fresh build, exact package membership199Core/61Reference/
6MacPlatform/280tests and1686 resources, all35 exact one-method outcomes, protected
inputs and full artifact/PAX preservation. Stop at first nonpass. This is production
correction round2; at most3 before contract diagnosis. No original execution or
blocked operation. Source59727 stays terminal34 Objects, not137.

## Ownership, bounds and review

Clone all2261 actual files, add helper/test and modify only window backing/capture:
2263 files. Pin the three-file patch and source provenance; preserve every old test,
fixture/resource, failed candidate and control. Root1034/prior2257/source55 protected.
Only task-owned candidate/alias, adapter, plan/study/evidence and own navigation edit.
Independent review is unavailable; author analysis and control calculations are not
independent review. That gate stays open even after numerical tests pass.

Task application-mac-display-correction2-20260926 under existing X5 parent
01a0dc49-738f-7972-8fb0-e98fb2f34408. Verify writable APFS UUID
3A4F5FA6-DC86-4C6E-87E2-EAC2C2D72548,90GiB external/9GiB internal before preparation;
40/6GiB reserves plus17GiB source commitment. Physical28GiB, stop observed decrease
26GiB, logical150GiB, metadata16MiB/root2MiB. Prep1800s; build3600s/RSS12GiB;
queue14400s, new pattern method600s/RSS8GiB and all34 inherited limits unchanged;
finalization3600s. Reuse existing guarded monitor/queue/package/closure with exact
method predicates, adapting count/membership/task only. Check process PID/start/
command/cwd/job before action. No source restart or old candidate mutation.

Publish and commit this coherent checked increment; root promotion/general raster/
palette/font/conversion/callbacks/fullscreen/providers/loading/Windows/input/audio/
clean-Mac/full match/full game remain open. NTSDApp still Practice; EXE envelope
not recalculated. First complete Naruto/Sasuke District match remains intermediate.
