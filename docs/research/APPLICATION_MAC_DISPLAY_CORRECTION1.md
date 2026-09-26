# Display correction1 — build passes, AppKit color readback fails

The explicit Int storage-count correction builds and passes package verification.
The whole-startup display allocation test passes. The second method fails nine
color assertions at three AppKit view samples; the remaining32 of34 methods were
not started. The display implementation is not accepted. Original expected values,
test bodies, masks and all per-method limits remain unchanged.

[Plan](APPLICATION_MAC_DISPLAY_CORRECTION1_PLAN.md),
[original implementation](APPLICATION_MAC_DISPLAY.md),
[preserved compile failure](APPLICATION_MAC_DISPLAY_VALIDATION.md).
Input HEAD9c7bcf5; task build/research/application-mac-display-correction1-20260926
on the declared X5 parent. No original game, emulator, capture or refused operation
was executed. This corrects a Native diagnostic expression, not a game rule.

## Implementation and build

Only OriginalMacDisplayBackend.observation changes: explicitly unwrap its optional
storage, retain the same mask-byte count, otherwise return Int0. All other2260
candidate files remain exact. Candidate manifest SHA256
`4f1083e2a0fa1f94696bd78fd6fdf9dca328e0b921497e26ac640bf921a88c37`.
Preparation30707 terminal0. Fresh build31641 terminal0 in296.105s, sampled peak
tree RSS6,574,080,000 bytes; no guard, signal or residual process.

Package verification checks199Core/61Reference/5MacPlatform/279test sources and
1686 exact resource files (385fixtures/1301runtime). Test binary65,564,072 bytes,
SHA256 `611d62c75c3727441d4c3a45608ec938855b5aa89384bdd5b283108e8907a8d2`.
Compilation/package success is separate from the failed physical comparison.

## Actual Native observations and failed comparison

Queue42859 ended2026-09-26T15:01:06.949553Z, terminal1 after10.849s. Its two
children43011/43172 are terminal0/1 and absent; no guard/signal/residual. Method1
passes in0.456s XCTest time, method2 fails in1.837s. No repeated execution occurred.

Whole startup observes display4, primary5, backbuffer6 and clipper7 on window3,
all with one retained reference. Primary extent3008x1692 and backbuffer794x550
allocate27,631,180 bytes including defined masks. Initial known pixels are zero.
Eight physical display requests preserve the source-controlled windowed order;
windowed startup still performs no clear or pixel-format query.

The separate whole-clear method writes exact raw words and defined masks, checks
the declared XRGB8888 masks, and reads the actual AppKit view. Its only failures
are the nine channel assertions below; other assertions in that method did not
fail. This does not turn the failed method into a passing comparison.

| sRGB channel | Expected | Actual at all three samples | Original tolerance |
| --- | ---: | ---: | ---: |
| Red | 0.2 | 0.3145145773887634 | 2/255 |
| Green | 0.4 | 0.4765637516975403 | 2/255 |
| Blue | 0.6 | 0.6506941914558411 | 2/255 |

The primary clear is0x00336699, client clip(1107,317,794,550), cached view1588x1100.
Samples are(1,1), center, and(width-2,height-2). Exact errors, logs and pins are
preserved in failure-diagnosis1.json and actual-observations1.json. A color-space
conversion or cached bitmap profile issue is a hypothesis, not a diagnosis.
This is Native AppKit rendering/readback, not a physical monitor screenshot or
original Windows pixel observation. It is not a source fault or safety refusal.

## Review and continuation

Author review verifies the one-expression correction and unchanged tests/limits;
it is not independent review. Round1 fixes compilation but exposes a separate
rendering/readback failure. NEXT: a finite Native color-path diagnosis of CGImage,
NSImage drawing and NSBitmapImageRep capture, then a separately pinned correction2
supported by that evidence. Keep expected RGB/tolerance and all old test bodies
unchanged; no automatic rerun or weaker comparator. At most three correction rounds
before revisiting the contract. Required all34 comparison remains open.

This removes the compilation obstacle toward native graphics for the first full
Naruto/Sasuke District match; the color mismatch blocks graphics acceptance.
Independent review, root promotion, general raster/presentation/conversion,
callbacks/fullscreen, other providers/input/audio/loading, Windows/visual/clean-Mac,
full match and full game remain open. NTSDApp still uses Practice. Source59727
remains terminal at34 Objects, not137. Safety incidents remain open. EXE envelope
was not recalculated.

## Verified preservation

Finalizer52939 terminal0/absent in66.722s verifies4940 regular artifact files,
75-member PAX metadata archive, exact one-file patch roundtrip, root1034/prior2257/
original2261/failed2261/current2261/source55 preservation. The task is frozen.
[Publication](../evidence/application-mac-display-correction1.json),
[closure](../evidence/application-mac-display-correction1-close.json),
[patch](../evidence/application-mac-display-correction1.patch).
Build/package/archive gates pass; all34 Native comparison remains false.
