# Native display color diagnosis — bitmap profile lost during sampling

The finite probe reproduces correction1's failed RGB triplet exactly and identifies
a readback-profile discrepancy. NSBitmapImageRep.colorAt returns Generic RGB colors
although the bitmap itself carries sRGB or the actual monitor ICC profile. Applying
usingColorSpace(.sRGB) to those returned colors interprets the components in Generic
RGB. Changing production rendering or expected values is not supported by this
evidence. The failed production method and all34 comparison gate remain unchanged.

[Plan](APPLICATION_MAC_DISPLAY_COLOR_DIAGNOSIS_PLAN.md),
[preserved production failure](APPLICATION_MAC_DISPLAY_CORRECTION1.md).
HEAD6a2fc84; task build/research/application-mac-display-color-diagnosis-20260926.
This diagnoses the validation boundary needed to accept native graphics toward
Naruto/Sasuke on District. No original game/emulator/source capture or refused
operation ran. Root Native and all earlier candidates are preserved.

## Observation scope and provenance

One standalone AppKit program reproduces the production CGImage layout, exact
NSImage draw expression and cacheDisplay pair. It adds a direct CGContext control
and explicit window profiles, without changing production code. Source expressions,
parent SHA256, SDK header pins and declared differences are in author-review1.json.
Eight colors are the seven existing raw-clear inputs plus failed0x00336699.
Three window profile policies(default/sRGB/screen) times two draw paths times eight
colors produce48 view cases, each with three samples. Eight direct CGImage-to-bitmap
controls bypass view drawing. These are Native uniform-color controls, not an
original Windows/device comparison or a physical monitor screenshot.

The first compile63383 exited1 in1.121s: the direct invocation lacked -sdk and
could not load the standard library for arm64-apple-macosx27.0.0. No probe ran.
Its exact log/config/job remain preserved. compiler-amendment1.md declares one
separate build2 with explicit installed SDK and macOS14 deployment, matching the
successfully built package. No probe source/cases were changed. Build65983 exited0
in3.200s, sampled peak tree RSS354,910,208 bytes. Probe66814 exited0 in1.101s.
All three processes are absent, without guards, signals or remaining descendants.
Probe RSS sampling was brief; its recorded32,768 bytes is not a reliable peak.

## Results

Exact case membership and all samples were checked. All24 pairs of NSImage versus
direct CGContext bitmaps agree. All16 pairs of default versus explicit screen
profile agree. Direct images and explicit sRGB windows preserve the exact input
RGB bytes for all eight colors. Every sampled colorAt result uses Generic RGB,
including those whose bitmap profile is explicitly sRGB.

For0x00336699:

| Bitmap source/profile | Raw RGB | colorAt result profile | After usingColorSpace(.sRGB) |
| --- | --- | --- | --- |
| Direct CGImage / sRGB | 51,102,153 | Generic RGB | 0.252791,0.480295,0.664904 |
| View / explicit sRGB | 51,102,153 | Generic RGB | 0.252791,0.480295,0.664904 |
| View / default monitor | 64,101,149 | Generic RGB | 0.314515,0.476564,0.650694 |

The last row reproduces the saved production failure at full precision at all
three positions. The actual monitor profile is Pro Display XDR, ICC SHA256
`1b548790cbe545fd80739f440ad3058c527a3e8dce27d9691825d137eee82d22`.
The sRGB bitmap and Generic RGB returned-color profiles have distinct ICC hashes,
recorded with raw samples and full-precision conversions in result2.json.

The separate bitmap colorSpace and legacy colorSpaceName are both recorded:
the latter is NSCalibratedRGBColorSpace in these cases. Apple's
[colorSpace documentation](https://developer.apple.com/documentation/appkit/nsbitmapimagerep/colorspace)
identifies the bitmap's color space; its
[cacheDisplay documentation](https://developer.apple.com/documentation/appkit/nsview/cachedisplay(in:to:))
describes drawing into a compatible bitmap obtained from the view. The diagnostic
uses that documented pair. It never retags or post-corrects measured pixels.
All draw callbacks reported isDrawingToScreen=true, so the diagnostic did not
attempt a bitmap-context color-space query there. It does not infer missing values.

## Interpretation and next contract

The direct sRGB control already shows the discrepancy without drawing a window.
Consequently the old colorAt/usingColorSpace chain is not a faithful reader of
these bitmap ICC profiles. This evidence localizes a readback contract problem;
it does not prove general rendering correctness or original Windows equivalence.
No framebuffer change, looser tolerance, altered expected RGB, or switch from
NSImage to CGContext is justified by the failed triplet.

NEXT: separately validate profile-aware bitmap sampling/conversion, using actual
bitmap profiles and independent known-color controls before changing captureView
or the comparator. Preserve existing failed methods and expectations. A possible
bridge must convert actual pixels, never merely retag them or return input colors.
Keep the old34 tests required; any comparator contract correction needs separately
identified evidence and independent review. Author review here is not independent;
the review gap remains open. No production correction2 has been made.

Source59727 stays terminal34 Objects, not137. Independent review, all34 comparison,
root promotion/general raster/providers/callbacks/fullscreen/loading, actual Windows/
input/audio/visual/clean-Mac, full match and full game remain open. NTSDApp still
Practice. EXE envelope not recalculated; existing safety incidents remain open.

## Verified preservation and publication

Finalizer71256 terminal0/absent in5.956s verifies the34-member PAX archive, full
member bodies/modes/nsmtimes/membership, root1034/failed candidate2261/source55
and all protected inputs. Source, executable, both compiler invocations, failed log,
probe output and reports are retained. Rebuildable module caches and empty temporary
directory are excluded from the evidence archive. Task frozen; no production change.
The separate read-only publication checker reproduces the saved48/8 observations
and exact failed triplet; it is author verification, not independent review.
[Publication](../evidence/application-mac-display-color-diagnosis.json),
[closure](../evidence/application-mac-display-color-diagnosis-close.json).
