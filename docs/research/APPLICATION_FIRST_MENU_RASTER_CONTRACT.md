# Whole first-menu raster contract: saved inputs verified

2026-09-26, base HEAD cff421e. [Plan](APPLICATION_FIRST_MENU_RASTER_CONTRACT_PLAN.md),
[publication](../evidence/application-first-menu-raster-contract.json),
[close](../evidence/application-first-menu-raster-contract-close.json).

This data-only increment identifies the exact first-menu work still required by
physical rendering. It does not implement a rasterizer or establish actual
Windows/device pixels. The previous [geometry candidate](APPLICATION_MAC_WINDOW_GEOMETRY.md)
remains the latest Native frontier: 76 methods passed, including whole Host
WM_MOVE followed by menu presentation geometry.

## Evidence and finite inspection

The pinned original EXE/DLL, accepted APPLICATION_GRAPHICS_OWNERS,
APPLICATION_SURFACE_COLORS and APPLICATION_DIB_PIXELS inputs are preserved in the
nine-file input archive (71,453,103 bytes). No original, Native, pixel decoder or
historical producer/auditor ran. Every consumed RGB/mask range and SHA was checked;
rectangular mask totals were cross-checked by row slices and flat coordinates.
Those are source-mask footprints, not observations of device sampling.

All 224 stages and 110 composed chains remain present: 48 menu, 50 input and 12
loading chains. The finite corpus has 5,612 unique commands and 53,265 commands
across overlapping compositions; 491 unique Blt commands occur 901 times in those
compositions. Counts must not be added as independent coverage. Of these 901,
883 have positive in-bounds source rectangles and 18 retain an explicit NULL
source. All have equal source/destination extents. Flags are 0x1008000 for 874
occurrences and 0x1000000 for 27. Fifteen distinct mask footprints were evaluated.
All 883 non-NULL occurrences have recorded successful color-key requests, flag8
and key [0,0]. These are declared harness replies, not device verification.

The lack of inverted/out-of-bounds/stretch requests here is not an original game
restriction. The separate BITMAP_DRAWING corpus includes unusual rectangles and
mirror paths. Resource generations, raw payload identities and original image
records remain authoritative. Asset names in the join are descriptive labels:
some payloads have aliases. The five case0 names below were additionally checked
against each surface's copied source-image token and agree exactly.

## Complete case0 command sequence

The first menu contains 472 graphics commands, including 425 bitmap commands
(408 front assets and 17 background) and 22 front commands. The front sequence has
one fill, five Blts, three acquire/set-background-mode/set-color/text/release
sequences, and one presentation. The complete ordered data is in first-menu1.json,
SHA256 87245df0ba78b2141b84a318eb6fdc3d4aba89a82db52bab3f34f2c158ceddb7.

The initial fill requests [0,0,794,550] and raw color 0x10206c. Its 100-byte
DDBLTFX backing has only eight known bytes (size and color); other backing must
not be invented. All five Blts below request keyed flag 0x1008000.

| Asset | Source rectangle | Destination rectangle | Known / unknown footprint positions | Known RGB zero |
| --- | --- | --- | --- | --- |
| MENU_BACK9 | [0,0,794,547] | [0,0,794,547] | 434318 / 0 | 0 |
| MENU_CLIP7 | [648,5,710,18] | [725,5,787,18] | 806 / 0 | 662 |
| MENU_CLIP | [0,41,496,121] | [155,96,651,176] | 39680 / 0 | 32471 |
| MENU_CLIP5 | [0,0,282,181] | [263,202,545,383] | 51042 / 0 | 46805 |
| LF2_CURSOR | [0,0,11,19] | [0,2,11,21] | 108 / 101 | 19 |

The cursor's 101 unknown positions are not known black or transparent. Even known
RGB zero counts do not prove the device color-key conversion or final compositing.

TextOut uses x591, y491/511/531, COLORREF 0xd07750, and these exact saved byte
strings (ASCII display below), with explicit lengths 27/30/28:

- `by Marti Wong, Starsky Wong`
- `1999-2008, all rights reserved`
- `http://www.LittleFighter.com`

The installed lib.dll replacement at 0x10001298..0x10001309 for 0x401290 calls
SetBkMode(DC,1), transparent. Its background argument 0x602010 is ignored; the
pristine SetBkColor implementation is not this installed contract. Exact raw
strings and declared API responses are preserved in the publication/full sequence.
Actual font/glyphs, charset/codepage, DPI and default DC selection remain unknown.
Choosing a macOS font would not establish fidelity.

The historical presentation retains its 16 zero destination bytes and NULL
source rectangle. The separately verified Native WM_MOVE rectangle
[1107,317,1901,867] is a different observation and does not rewrite that history.

## Renderer dependencies and next work

| Operation | Existing evidence / owner | Still required |
| --- | --- | --- |
| Allocation / clear / bitmap copy | Native owned surfaces and observed bitmap Host candidate | Actual device format, conversion and errors |
| Five source Blts | Exact identities, rectangles, flags, known RGB/masks | Common raster, key conversion, clipping and unknown cursor pixels |
| Three text rows | Exact bytes/order/transparent mode/color | Windows font/DC/DPI observations and faithful glyph raster |
| Presentation | Whole Host request order and owned Native WM_MOVE geometry | Physical consumer, clipper/format and actual presentation comparison |

On 2026-09-26 the user authorized setting up Windows through UTM in response to
the request for a reference environment. NEXT: prepare that environment using an
official Windows image, record guest/UTM/device provenance, then bound original
cursor and GDI observations. A VM is a research reference environment; it is not
part of the shipping native application. Its specific Windows/virtual-device
results must not be generalized to unobserved platforms. Existing safety incidents
stay open; this preparation does not retry or clear any refused operation.

## Process, correction and preservation

Inspector1 PID57956 failed with exit1 in 10.041s at cross-device clonefile, errno18
(EXDEV), copying the internal-volume graphics publication to X5. Six prior X5
input clones, the job/error, producer and failure diagnosis are retained. The
producer copy was saved after the failure with no intervening producer edit;
this is not described as a prelaunch pin. No analysis had begun.

Inspector2 corrects only input storage: same-device clonefile, cross-device copy2,
verification of bytes/modes/ns mtimes and reuse of verified partial copies. All
analysis/assertions and expected inputs are unchanged. PID60710 completed exit0
in 20.786s. Finalizer65998 completed exit0 in 9.882s. All three processes are
terminal and absent; the task is frozen. No source capture was restarted.

Archive verification separately checked nine regular input files and 19 PAX
metadata members, including membership, bytes, modes and ns mtimes. Metadata tar
SHA256 ec7cc9875f476e3c5fd5fd9ab2984815e7ffbc1e8bcd039017cc585f603275b1;
input manifest SHA256 b14bd524c78f9b59f0df10eb42b2fcdf4f239d9b2f10bc14ce57b487dd8595f9.
The frozen task is build/research/application-first-menu-raster-contract-20260926
on the existing task-owned X5 volume. Publication schema detail: `chains` pins
the full chains file; the numeric count 110 is retained in inspection1.json.

Root1034/prior2257/baseline2272 Native files, source55 pins and the immutable
AGENTS archive remain unchanged. No Native build/tests were needed for this
saved-data inspection. Independent review is unavailable; author consistency
checks do not count as independent review. Native raster, full first-menu frame,
root promotion, actual Windows/device comparison, input/audio, clean-Mac,
complete match and game remain open. NTSDApp remains Practice; no EXE envelope
or completion estimate was recalculated.
