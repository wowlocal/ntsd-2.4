# Original catalog image inputs

Status: accepted for the declared original image formats and logical API owners.
This prerequisite supports the [production catalog continuation](APPLICATION_CATALOG_SESSION_PLAN.md).

The previous source-color decoder rejected 85 of the original catalog's
669 images. The extension covers uncompressed 4/8-bit indexed pixels,
RGB24 color-table offsets, the original BMP file header and resource-origin
bindings. It preserves positive dimensions, the 40-byte DIB header and one-plane
domain. Top-down images, 16-bit RGB and other formats remain explicit boundaries.

The reference consists of the unchanged original files and four exact embedded
DIB ranges in the pinned EXE. The original complete catalog supplies the image
inventory, while the saved guarded20 capture establishes the immediate input
and request dependency. No new original execution occurs. The new reference
decodes these data files; separate ImageIO observations inspect host provider
bytes and are not Windows device output.

Microsoft's [GDI format description](https://learn.microsoft.com/en-us/previous-versions/dd183376(v=vs.85))
defines palette indices and BGR color samples. Four-bit indices consume the high
nibble first; row padding is separate from pixels. RGB24 optimization palette
entries affect data location without supplying the pixel colors. Reserved palette
bytes do not establish alpha. The [BMP file header](https://learn.microsoft.com/en-us/windows/win32/api/wingdi/ns-wingdi-bitmapfileheader)
declares the file size and pixel offset; its bytes and any intervening gap must
remain retained rather than silently removed.

[LoadImage](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-loadimagea)
distinguishes a file source from an embedded resource. The saved request profile
uses 2010 for file images and 2000 for embedded fallbacks. A new resource merge
must retain all previous owners and reject a conflicting same-name resource.
NULL image responses remain separate from successful input lookup.

The packet is `build/research/application-catalog-session-native-20260913/`.
`input-inventory1.json` records 665 original BMP files and four embedded DIBs;
`pixel-inputs1.json` pins each actual input. Twenty-two separately authored format
and file-header controls accompany the new reference; all eighteen old startup
controls remain unchanged. Complete RGB/mask results and Native ownership tests
are required before acceptance. RLE holes stay unknown, and source colors do not
claim final framebuffer, palette realization, color-key or Windows behavior.

## Reference and host comparison

The inventory covers 665 files and four embedded resources: 628,035,022 input
bytes and 227,762,176 pixels. Complete expected RGB and defined masks retain
227,759,411 written positions and 2,765 unknown RLE positions. The reference
transport contains 1,477 content-addressed blobs; its 48,082,802 packed bytes
restore the exact 66,335,316-byte JSON fixture. Every source file, PE range,
reference blob and all 298,469 row hashes passed independent review before Core
was changed. Six fixed positive controls and sixteen rejection controls are
separate from the original image corpus.

ImageIO's raw provider matched all defined pixels in 667 of 669 images, including
all 85 previously unsupported inputs. It differed at thirteen defined pixels in
`shadow1` and twenty-one in `back99_2`, after vertical RLE deltas. A separate
hand-authored RLE control reproduced two such host differences. The independent
reviewer's sparse-coordinate reconstruction matched the full expected RGB and
mask of all five RLE streams, including those two resources. Both host outputs
and every mismatch remain in `imageio-comparison1.json`; they do not alter the
expected colors or turn unknown positions into black.

## Native contract

`OriginalDIBPixels` decodes positive bottom-up BI_RGB4/8/24 and the retained RLE8
domain. Used palette indices are checked independently of unused half-nibbles
and DWORD padding. RGB24 table entries only advance the pixel offset. Explicit
offsets must follow the entire palette and remain inside the original DIB.
Maximum pixel count remains an explicit Native allocation budget.

`OriginalApplicationStartupInputs.Bitmap` has separate initializers for an
embedded DIB and a BMP file. The latter validates and retains all fourteen file
header bytes, the declared offset and intervening gap. It supplies owned BITMAP
metadata without taking an expected structure from the reference.
`OriginalApplicationBitmapInputs.addResources` stages a whole merge, preserves
existing image/surface/DC generations and rejects conflicting bytes or origins.
Successful 2010 and 2000 image requests require the matching origin. NULL results
retain the existing missing-file/fallback behavior; the actual source module
word 400000 is preserved for file requests.

The new comparator checks every original image's complete RGB, masks and
metadata against the fixed reference. The ownership test joins file loading to
GetObject, DC selection and a 1:1 surface copy, checks an invalid-copy rollback,
and retains copied pixels after image deletion. This is a logical source-color
consumer; actual Windows conversion and device lifetime remain outside its claim.

The first new preservation audit used a zlib-header decoder for the outer raw
DEFLATE transport and stopped with an incorrect-header error. That checker and
its failed report remain unchanged. Preservation2 uses the declared raw stream
format and verifies the same packed bytes, exact JSON and all 1,477 blobs; no
reference or Native byte changed for acceptance.

## Acceptance

Candidate2 passed all 21 release methods in 29.097 seconds; build time was
303.35 seconds. These include all 669 complete image comparisons, 22 new
controls, 18 unchanged startup controls, owner/consumer checks and the selected
startup, graphics and common-loading regressions. The first candidate stopped
at compile time because the new test called an internal reference-module helper.
Its files and error remain preserved. A test-local bounded Compression decoder
corrected that transport dependency; independent review also required the
explicit file-to-surface consumer check. Core and expected bytes did not change
between candidates. No test success is attributed to candidate1.

All 374 previous fixtures, 46 Startup files and 19 CommonSounds files remain
unchanged. The final 905 Native files, 375 fixtures, resource copies, raw and
packed transport, immutable inputs and separate archives are verified in
[the acceptance record](../evidence/application-catalog-dib-inputs.json). The
Native binary links; this does not establish window/device output.

The next task remains the actual [catalog session](APPLICATION_CATALOG_SESSION_PLAN.md)
from PendingCatalog. Its child records, allocation identities and parent store
phases need a whole-caller comparison before a catalog return is accepted.
Full loading, gameplay, network, Windows and clean-Mac verification remain open;
this prerequisite does not resolve any prior safety refusal.
