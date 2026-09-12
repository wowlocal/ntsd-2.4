# Saved startup bitmap and surface request inventory

The complete saved caller set is inventoried before adding Native surface color
ownership. The 48 primary attempts, 50 MenuInput chains and 12 LoadingPrefix
cases retain all parents and errors. This establishes the required requests and
resource relationships, not measured Windows pixels or a finished renderer.

The previous goal turn made progress: `7012f27` committed the original DIB
decoder and passed publication verification. This card advances its next
consumer under [WORKFLOW](WORKFLOW.md), toward the standalone native game.
The finite plan, jobs, failures and independent reports are in
`build/research/application-bitmap-surface-inventory-20260912/`.

## Reference and method

The pinned original EXE remains SHA-256
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.
Seven existing JSON corpora supply bitmap loading, settings, front screen,
screen body, menu return, menu input and loading prefix. Their original game
observations were recorded in Unicorn under declared platform replies.
This card reads completed JSON, compressed DIB blobs and producer source only.
No original executable, emulator, historical producer or historical auditor runs.

The new [data inventory tool](../../tools/inventory_application_bitmap_surfaces.py)
checks complete canonical JSON identities and content equality, with raw-file
SHA pins separately preserving the original bytes. There are 354 checked retained
parent entries and 224 selected stage identities:

| Stage | Distinct saved identities |
| --- | ---: |
| WinMain / message loop / dispatcher entry | 1 / 2 / 2 |
| Bitmap resources / settings / front screen | 7 / 19 / 40 |
| Screen body / first menu | 43 / 48 |
| MenuInput / LoadingPrefix | 50 / 12 |

Three selected settings identities do not occur in the older standalone
18-case settings corpus. They are retained from the later parent maps with their
exact origin; an invented standalone index or omission would lose required paths.
Repeated parents are explicit chain references, not new original experiments.

`inventory3.json` records exact request/response structures and defined masks,
40 distinct composed bitmap/front lifetimes, and image/DC/surface relationships.
`event-catalog4.json` retains all 41,658 original events across the 224 stages,
including events whose API payload does not use a `request` field. Its 2,117
front graphics records include 491 Blt calls, 276 GetDC, 273 each ReleaseDC,
background mode, text color and TextOut, 90 fills, 56 clears and 112 methods.
Their declared numeric replies are linked to the pinned producer and case spec;
they are not retroactively labelled sampled device replies.

## Actual copy requirements

The 7 bitmap and 40 front stages contain 205 CreateSurface requests, 201 copy
helper GetDC requests and 200 StretchBlt calls. Every StretchBlt has source and
destination origin zero, equal positive dimensions, the whole source and
destination extent, and SRCCOPY `0x00cc0020`. All 200 return declared result 1.
There are 13 geometries:

`11×19`, `106×91`, `198×54`, `251×257`, `419×552`, `597×265`, `704×444`,
`713×540`, `794×500`, `794×550`, `794×600`, `794×800`, `809×547`.

This proves that the entire saved bitmap-copy request set requires no scaling;
no scaled case was excluded. The separate 491 downstream Blt rectangles also
have equal source/destination extents, but include clipping, placement, flags,
NULL sources and other downstream contracts. They are not interchangeable with
the 200 GDI copies.

All 36 packaged resource names occur. They refer to 28 distinct original DIB
payload hashes because some resource names share bytes. Resource aliases and
individual image handles remain separate. The previously accepted full RGB/mask
expectations are joined by both resource name and original DIB hash; all
146,289 unwritten pixel positions remain unknown in the existing format profile.

The 40 composed bitmap/front lifetimes contain 992 copy occurrences. Across the
three root sets, copies occur 1,192 times in primary attempts, 1,243 in MenuInput
parents and 300 in LoadingPrefix parents. These are overlapping compositions,
not 2,735 independently captured new copies.

All error paths remain: two negative CreateSurface results, two positive results
with output surfaces that the loader does not use, one failed GetDC that skips
StretchBlt, and two negative color-key results followed by Release result 17.
Allocated surface descriptors, undeleted images and unused output tokens stay in
the inventory. A numeric success or ignored error is not proof of pixel content.

## Ownership and downstream use

The front-screen producer resets API counters while retaining resource maps.
Consequently source and target DC token values recur between the bitmap and
front phases. The inventory keeps every generation, acquisition, selection and
DeleteDC/ReleaseDC request; each copy points to the appropriate generation.
Selection is reconstructed from ordered requests and their declared replies.
The harness itself did not maintain a measured Windows DC selection state.

The saved `dcs` and `surfaces.released` fields record requests, not actual
destruction. DeleteObject's declared result controls its separate image-deleted
flag. All saved image/surface/DC maps compare at both lifetime stage boundaries.
Copied logical color storage must survive deletion of the temporary source image.

`downstream-ownership1.json` relates later graphics uses in all 110 chains to
the created bitmap surfaces. Three distinct MenuInput Release requests have
results 0, 0 and -1; they appear in three MenuInput chains and all 12 retained
LoadingPrefix parents. No later source use follows those Release requests in
this saved set. All nonzero downstream bitmap sources have a creation binding.
The 18 unbound source occurrences are explicitly NULL in the original error
controls; they are not unknown nonzero addresses or successful raster matches.
External drawing targets belong to the separate window/backbuffer owners.

Current Native `bitmapInputs` records resource-phase releases, while later
MenuSession method-8 releases are buffered without updating that map. The next
owner implementation must connect those later requests and extend the whole
caller comparison accordingly. Keeping the old map unchanged would miss a
required lifetime event; changing original expected bytes is unnecessary.

## Format and pixel boundaries

Every one of the 205 bitmap CreateSurface descriptors has flags 7 and 108 known
request bytes. Its zero pixel-format words have no validity flag. The harness
stores this request and returns it as GetSurfaceDesc; these zeros do not prove
a zero-bit, RGB8 or RGB32 device surface.

Both retained dispatcher-entry variants separately contain a declared primary
surface GetPixelFormat reply: DWORDs `[32, 0x20, 0, 8, 0, 0, 0, 0]` for token
`0x31002000`. This is a controlled 8-bit indexed format reply. It neither measures
the real device nor supplies palettes or the actual conversion of every created
offscreen surface. WinMain's primary/backbuffer descriptors and all their masks
remain in the event catalog.

Microsoft documents [StretchBlt](https://learn.microsoft.com/en-us/windows/win32/api/wingdi/nf-wingdi-stretchblt)
as copying between DC rectangles and converting differing bitmap formats.
[SelectObject](https://learn.microsoft.com/en-us/windows/win32/api/wingdi/nf-wingdi-selectobject)
replaces the selected bitmap. Those API contracts help interpret the recorded
requests; they do not supply this game's missing device palette or raster output.

The next permitted implementation is lossless logical source-color ownership
for the entire actual copy set: own RGB/masks, initially unknown destination
storage, full evidenced copy, image/DC generations and retained release requests.
Unknown source pixels must make destination pixels unknown, even if the latter
previously held a known color. Known black remains distinct from unknown storage.
Failed GetDC supplies no copy. This intermediate source-color representation
must not be exposed as proven DirectDraw conversion or final displayed pixels.

## Preserved failures and verification

An unexecuted first draft assumed every retained settings parent had a standalone
case index; review corrected that before execution. Inventory1 then failed on a
raw-deflate blob because it used a zlib-wrapped decoder. Inventory2 exposed actual
DC token reuse. Both frozen producers, failures and terminal jobs are retained.
Inventory3 uses the corpus's raw-deflate transport and explicit DC generations;
it completed in 10.594s. Its inputs and outputs were not changed for later review.

Review then identified a publication gap: categories alone did not preserve
non-request front graphics payloads. A separately planned event catalog reads
the completed inventory's exact stage pointers, without rerunning it or any
source. Catalog4 completed in 5.069s. The downstream association is a further
data-only check of the same complete events. No source expected/mask or Native
file changed. Native regression reruns are unnecessary for this data-only card;
the previous 20-method release result remains prior evidence, not a new test run.

The separate preservation check compares all 875 Native files, 372 fixtures,
46 package files and 90 plan input pins. Contract review, complete evidence
archive/member verification and actual Git publication are separate gates in
[the evidence record](../evidence/application-bitmap-surface-inventory.json).

Next: implement the complete logical surface owner above with independently
derived expectations, full 48/50/12 caller comparison and coupled late rollback.
Actual indexed conversion/palettes, DIB-hole initialization, NULL-source raster,
window/backbuffer composition, text, presentation, input/audio, full loading,
War gameplay, complete game and Windows/clean-Mac verification remain open.
All three safety incidents remain open; no affected operation was retried.
