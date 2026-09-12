# Native pixels for the original startup DIB resources

The Native decoder and image-owned colors/masks are verified in the finite
format and provenance scope below. Unknown colors remain unknown.

This finite card supplies actual color data to the accepted
[startup input owners](APPLICATION_STARTUP_INPUTS.md), toward the native renderer
and standalone game. Its plan and independent reports are under
`build/research/application-dib-pixels-native-20260912/`.
The prior turn made progress: commit `401fdb0` completed the input package and
was verified against the remote with a clean workspace. The full goal is open.

## Reference and format boundary

The only game content is the same 36 original RT_BITMAP DIB payloads, whose
28,986,014-byte extent is checked against the prior package manifest.
The pinned EXE SHA-256 remains
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.
No original EXE/DLL, emulator, historical producer or historical auditor executes.
The new reference performs file-format conversion in Python; a separate macOS
ImageIO check compares the format under its declared channel/orientation profile.
That system check is not a Windows game or device observation.

The format contract comes from Microsoft's [DIB description](https://learn.microsoft.com/en-us/windows/win32/gdi/device-independent-bitmaps),
[BITMAPINFOHEADER](https://learn.microsoft.com/en-us/windows/win32/api/wingdi/ns-wingdi-bitmapinfoheader)
and [RLE compression](https://learn.microsoft.com/en-us/windows/win32/gdi/bitmap-compression).
The selected inputs have positive dimensions, a 40-byte header and one plane:
23 use 24-bit BI_RGB, and 13 use 8-bit BI_RLE8. Output is packed top-left RGB8
with one explicit defined flag per pixel. BGR samples and palette colors become
RGB; storage rows are bottom-up. Row/absolute-run padding is consumed separately.
Palette reserved bytes supply no alpha. Color-key transparency remains a later
surface operation.

The profile explicitly bounds dimensions, palette reads, integer products,
stream reads and output positions. A caller pixel budget (default 16,777,216)
limits allocation; it is not a recovered game limit. BI_RGB uses no color table
and accepts an image size of zero or exactly the padded row extent. BI_RLE8 uses
a bounded positive image-size field and requires an end marker inside it.
Reaching the right edge does not wrap automatically. After a final EOL reaches
the image height, only EOB is accepted. Any bytes after EOB remain input evidence
and never become pixel commands.

## Written pixels and independent reference gate

The first data-only reference yields 10,184,161 pixel positions: 10,037,872 have
explicit writes, and 146,289 remain unwritten. The latter occur in LF2_CURSOR
(101), SLOGAN (20,998), WORDS0 (21,187), WORDS1/2 (20,800 each) and WORDS3/4/5
(20,801 each). Their placeholder RGB storage is zero with mask=false; this
does not establish black, transparency or actual Windows initialization.

Actual RLE streams contain 28,738 runs, 13,400 absolute sequences, 792 deltas,
2,037 EOL and 13 EOB markers. All observed absolute padding and palette reserved
bytes are zero. CS2, CS3, WORDS0, WORDS4 and WORDS5 retain two bytes after EOB
inside their image-size extent. No whole-DIB bytes lie outside the declared
header/palette/image extent. Full byte/mask output and per-row checks are saved;
two independently frozen data decoders compare every byte and mask, including
14,632 row checks. The separate reviewer also reconstructs every RLE mask from
the saved command offsets, arguments and cursor movements.

The plan names 18 decoder controls. Nonzero RGB padding or palette reserved
bytes are explicit tolerance controls, separate from conforming original assets.
Missing padding, palette or stream bytes and invalid cursor/output extents are
declared Native rejection cases. They do not reproduce source memory faults.

## Separate ImageIO observations

ImageIO's raw CGImage output is RGBX/top-left for RGB24 and indexed with an RGB
palette for RLE8. No CGContext draw, color conversion or Practice alpha transform
is used. All 13 host palette tables equal the original RGB palette bytes.
ImageIO matches every written pixel in 29 original resources. Seven differ at
567 written positions: LF2_CURSOR3, WORDS0 99 and WORDS1..5 93 each. A separate
synthetic vertical-delta control differs at two positions. These observations
are consistent with vertical-delta positioning; they do not prove ImageIO's
internal cause. All differences and original provider data remain preserved.

The first ImageIO Swift script failed type checking before decoding. Its pinned
successor only split the header-construction expression. The first independent
checker remained frozen and unexecuted; its successor added the actually observed
RGBX profile without altering the independent decoder. Neither the host result
nor its canonical values in RLE holes supplies a Windows oracle or changes the
reference. Acceptance rests on two independent complete data decoders, primary
format semantics, independent command/mask review and actual Native comparison.

## Ownership and remaining work

Core decodes each packaged resource before a Core attempt and retains an
immutable pixel value beside its original DIB. Live image lookup exposes that
value through the existing handle; deleted handles reject that lookup while
retaining immutable data. Strict color access rejects an unknown pixel. Full
Session comparisons and late rollback retain the new colors and masks. A temporary bitmap's pixels are not automatically linked
to a DirectDraw surface: copy/stretch, surface format, palette realization,
color key, actual destruction and presentation remain separate work.

All 20 selected bundled release methods passed in 135.303s; the build took
297.09s. Three new methods compare every packaged pixel/row, the 18 declared
controls (three returns and 15 typed rejections), immutable ownership and live/dead
lookup. The prior 48/50/12 whole parent routes compare colors/masks for actual
image bindings while preserving their complete events, records and late rollback.
All 370 old fixtures and 46 package files remain unchanged; two new fixtures
preserve the full reviewed 40,736,644-byte payload and all reference JSON fields,
with the separately authored controls appended. No game/expected correction was
made for Native acceptance.

The tested Native archive has 875 members /
4089794699 payload bytes; the evidence archive has
253 members /
245938234 payload bytes. All member bytes, SHA and
modes match. The evidence retains all plan pins, original DIBs, both data-decoder
outputs, host provider bytes, failed/unexecuted script versions, jobs, logs and
reviews. Builds and archives use the verified X5 task area; the package and test
fixtures are regular local files. Git composition and final publication review
are separate post-archive records required before commit. The first Git check
treated the RGB/mask payload as text because its initial bytes contain no NUL.
Its diagnostic is retained; the exact binary fixture now has `-text -diff`
attributes. No pixel, mask, package, Native code or expected byte changed.

[Machine-readable acceptance](../evidence/application-dib-pixels.json) pins those
results and the remaining boundaries. No surface raster, window, input,
audio, full catalog/loading, War gameplay, complete match or Windows/clean-Mac
result is claimed. All three existing safety incidents remain open.
