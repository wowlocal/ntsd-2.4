# Whole camera, arena bounds and background drawing

Baseline EXE SHA-256:
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.
Only the original Windows NTSD distribution supplies engine behavior.

Follow-up: [COORDINATE_PRECISION](COORDINATE_PRECISION.md) now repeats all4742
controlled cases at explicitCW027f and compares Native. Every old case record,
1133 observed PCs and6898 ordered events reproduces. The direct coordinate
converter also has dedicated whole legacy/SSE2 tests. HistoricalCW037f evidence
below is unchanged; no24-bit whole-camera or device-output claim is added.

The native implementation is `OriginalWorldCamera` plus
`OriginalBackgroundDrawing`, composing the existing `OriginalBitmapDrawing`
and `OriginalSurfaceFilling`. The public camera call operates on its own
`OriginalMatchPreparation`, including live background records. It publishes
World, pool, globals and background counters together after successful drawing.
The application must buffer device requests until the enclosing tick commits;
an actual device side effect cannot be undone by rolling back these records.

## Source boundary

| Function | Source scope | Children |
| --- | --- | --- |
| Bounds/camera | `41b5d0..41bc87`, ret8 | `4450d0`, then actual `41a250` at `41bc7b` |
| Background layers | `41a250..41a590`, ret4 | `41a050`, `43f010`, `415160` |
| Built-in arena99 | `41a050..41a24d`, ret4 | `43f010`, `415160` |
| Bitmap drawing/clipping | `43f010..43f2fe`, `43ef70..43f000` | COM Blt output boundary |
| Filled rectangle | `415160..4151c2`, cdecl | COM Blt output boundary |

The gameplay caller is `41f484..41f496`: mode comes from `451160`, target
from retained `[esp+68]`, and World from EBX. The target originates at
`41bcd5/41bce4`, copying the real `41bc90` argument into that stack local.
The following `41a5a0` actor drawing call is a separate pending function.
The old `41bc74` stop precedes background drawing; its historical movement
fixtures retain their old, narrower scope.

## Bounds and camera rules

Slots are visited in ascending order, with any nonzero activity byte active.
World pointer aliases are resolved on each visit; deactivation changes that
slot's activity, not every slot referring to the same Actor.

* All active objects clamp binary64 z, then write integer z through the real
  source conversion. Type0 uses BG min/max; other types use min−1/max+1.
  Comparisons and individual stores preserve untouched bytes and signed zero.
* Type3 deactivates for x below −300 or above BG width+300. It still refreshes
  integer x after deactivation. Boundary equality remains active.
* Type0 slots20..399 clamp x to −100..width+100. Slots0..19 clamp to
  −300..width when Actor+364 equals5, otherwise to **0..width**.
* A positive `450bb4` adds an upper x cap for type0 only when Actor+364≠5
  and Actor+8=0. This cap is applied after the ordinary bounds.
* Other types with source ID122/123 clamp to **10..width−10** when Actor+344
  is positive, or when mode=1 and signed `450b94/10` equals5. The mode branch
  remains behind the ID122/123 gate. Other IDs do not inherit this exception.
* Other non-type0/non-type3 cases deactivate outside0..width only if integer
  y at Actor+14 equals0. Binary64 y is not consulted. All refresh integer x.

Camera targeting first scans eight active, living slots with positive
`450b4c+4*slot` input status. Current frame state14 contributes integer x;
other states contribute `x − signedInt8(facing)*260 + 130`. There is no Object
type gate in this first selection. If no slot qualifies, all400 active,
living type0 slots contribute integer x without look-ahead. If still empty,
the source uses sum800/count1.

The wrapped sum divided by positive count, minus397, is clamped first to a
minimum0 and then to width−794. The second clamp may produce a negative value
for a narrow arena. Nonzero `450bb0` adds an upper cap, including negative caps.

With wrapped Int32 arithmetic and division toward zero:

```
delta = (target - current) / 14
velocity = (oldVelocity * 6 + delta) / 7
```

If velocity is zero while target differs, it becomes ±1. Current then advances
by velocity. With both `450b74` and `450b84` nonzero, `450b7c` overrides current.
The final clamp again applies minimum0, then maximum width−794; with both flags,
the clamped value also writes back to `450b7c`. The velocity remains separately
updated even when replay overrides the position. Camera/background use no RNG.

## Background rules

Arena ordinal99 dispatches the entire built-in scene, independent of ordinary
layer count. It draws one bitmap at `250-camera/100,120`; eight keyed tiles at
`x-(camera*7)/10+30,175` for x=0..3500 in steps500; the original gray bands and
fence rectangles; then ten foreground tiles at `x-camera+10,390` in steps320.
The fence starts at the signed remainder `(900-camera)%70`; negative starts
and original overlapping rectangles are retained. Embedded bitmap references
occupy BG+914/918/91c and normalize to catalog index+1, zero null.

Ordinary layer arrays have these record offsets, plus4*layer:

| Field | Offset |
| --- | --- |
| Color key | 3ec |
| Width / x / y / height | 464 / 4dc / 554 / 5cc |
| Loop step | 644 |
| Animation start / end / period / counter | 6bc / 734 / 7ac / 824 |
| Rectangle color / bitmap reference | 89c / 914 |

Nonzero rectangle color bypasses bitmap/parallax/animation handling and calls
real415160. Four exact color remaps are source behavior:
175317→104f10, 575347→5a4e4b, 977757→9a6e5a, 473f1f→423818.
Fills target global455608, while bitmaps use the caller's target argument.
Rectangle additions wrap; the fill helper does not perform clipping.

For nonlooping bitmap layers, the offset is0 when BG width≤794, otherwise
`-((layerWidth-794)*camera/(BGWidth-794))`, with wrapped product and signed
source division. This division happens **before** animation gating.
For looping layers the animation gate comes first, then the division runs
unconditionally, even if the initial x already prevents any draw.

A positive period increments the counter with wrap and signed remainder,
writes it immediately, then tests inclusive start/end. The changed counter
survives a skipped layer. A nonpositive period leaves the counter untouched.
Looping layers draw from their x while x<layerWidth, adding the signed loop
step with wrap after each call. A negative step can terminate through overflow;
it is not rejected just because it is negative.

Bitmap calls preserve frame−1, layer color key, no mirroring, and source order.
The real bitmap helper can read untouched frame-count storage and perform a
second negative-frame branch. Each read, its initialization mask, both clipping
results and actual Blt requests are compared. Failing device HRESULT does not
suppress later source drawing.

415160 writes only DDBLTFX size and fill color. The other92 bytes retain stack
backing, captured **before** each original helper call and supplied explicitly
at the native boundary. Their Windows provenance and raster interpretation are
not established by the controlled corpus.

## Verification and limits

`tools/oracle_world_camera.py` executes the source bodies first.
`OriginalWorldCameraTests` independently reconstructs declared inputs and
compares the complete400-slot pool, World, masks, globals,101 backgrounds and
ordered renderer events. Bitmap records remain unchanged in the source.
Input presets use real original Actor/World constructors and declared metadata;
they are not natural character sequences or Windows allocator observations.

The first4737-case corpus passed native comparison in4.007s, release build
113.66s. It contains4079 complete camera calls and658 standalone background
calls,25947 nested helper returns,6889 renderer events:873 bitmap calls,
4173 reads,876 clip results,669 bitmap Blts and298 fills. Eleven bitmap reads
explicitly retain undefined provenance. All491 camera instructions,209/211
background instructions and144/146 built-in instructions were executed; the
four missing instructions are skipped alignment. The1133 observed PCs also
include one supplied COM boundary. This is an instruction-address union,
not proof of every branch, all possible storage or full-game equivalence.

Finite coordinates use the existing CW037f legacy/SSE2 conversion contracts.
Original IDIV zero/overflow faults, nonfinite coordinates, out-of-record data
and nonterminating layer loops are outside this accepted successful corpus.
Native code reports unsupported storage/faults; it does not supply guessed
coordinates, repair the DAT or silently skip drawing. Pixel output, audio,
physical input latency and Windows/clean-macOS runs remain separate open work.

The final4742-case corpus adds five source-checked unused-field controls and
compares all101 background initialization masks. Both the new corpus and the
retained3971-case bitmap suite passed2 release XCTest in5.527s/build120.80s.
Its total is25950 helpers/6898 events; the original instruction union is unchanged.

## Own launch continuation

`tools/oracle_gameplay_camera.py` freshly reproduces every pinned parent through
GAMEPLAY_CPOINTS on the same CPU/stack, then executes41f484..41f496 without new
gameplay inputs, outer entry, state replacement or device-vtable rebinding.
Both source runs completed at PC41f496/SP1000e9bc. The retained draw target is
28002020, mode0. Each has22 nested helper returns and64 ordered renderer events:
8 draw calls,40 bitmap reads,8 clipping returns and8 bitmap Blts, no fills.
The509 source PC observations plus one supplied COM boundary are not pixels.

Both original runs change camera450bc4 and velocity450bc8 from0 to1, and increment
nine District layer counters from0 to1 (BG+838/83c/840/844/848/850/854/858/85c).
The whole Actor pool remains unchanged: Naruto17/Sasuke21 in slots0/1,
current/collision frame219,HP500/MP200,x/z442.1/504.1 and289.1/519.1.
Game RNG40/1, CRT, all854 bitmaps,101 backgrounds, early resources, music,
full630e18 replay buffer and14586 Frame allocations remain owned and compared.

Bitmap+0c is read with undefined provenance at43f04b and43f183; all16 such
actual reads in each run are retained in the40 read events. Native drawing
uses its own constructor backing and exposes the same mask; it does not mark
this word initialized or replace it with zero. The full Windows origin of
these allocator bytes remains outside this evidence.

`GameplayCameraReference` continues its independently rebuilt own state through
`OriginalWorldCamera.apply`. It compares all events and complete before/after
records, including mutable BG counters, the DAT heap, resources, CRT and replay.
Its extra rollback trial throws at the last bitmap Blt after animation counter
updates have begun and verifies all stored state against the before snapshot.
Device effects are only recorded during this trial.

The first own native comparison passed in19.340s/build73.16s:
257413 records/559503780 bytes with masks,490 helpers/47 checkpoints.
These counters include launch/gameplay continuations; startup/menu/selection
parents are also revalidated by their nested runners but are not included in
these counters. Paired acceptance passed3 release XCTest in43.507s/build118.45s and then
published the3 lossless fixtures. Both own passes together compare514826
records/1119007560 bytes with masks,980 helpers/94 checkpoints. All129 previous
fixtures retain their SHA; the new raw/packed SHA, size, full JSON,2746 blobs
per own corpus and parent hashes were independently checked.132 pins are kept
at `build/research/gameplay-camera-fixture-pins.json`.

Final packed-fixture regression passed29 release XCTest in347.048s, build
117.82s, covering Actor hits/physics, World physics/links/contacts/cpoints/camera,
bitmap drawing, all own control/physics/links/contacts/hits/cpoints/camera
continuations and MatchLaunch. NTSDNative also compiled and linked. Python
source tools compile. All source/Swift jobs are terminal; no UI or Windows
output check is implied by these results.

Next is the whole actor drawing41a5a0..41ae50, including40de30 and actual
bitmap children, followed by remaining mode branches, scheduling, recovery,
creation/deletion and full tick return. Practice/UI integration, continuous
DAT sequences, a full match, Windows/device output and clean macOS remain open.

## Original DAT inventory

`tools/survey_background_drawing.py` verifies the pinned whole-background-loader
corpus SHA before reading the17 original parsed arena records. Its separate
[data survey](../evidence/background-drawing-dat.json) retains all302 layers,
175 positive animation periods,31 distinct loop-step values including0, and
all14 distinct arena widths. The surveyed drawing fields are fully defined.
All302 are bitmap layers; rectangle-color cases and built-in99 are separate
source branches exercised by controlled captures.

Ramen Place (ordinal10) is width750, with a looping first layer of width750 and
step380. Therefore a negative camera limit and a negative parallax divisor
are relevant to original content, not just integer-boundary probes. No source
arena width equals794, and all nonzero surveyed loop steps are positive.
This inventory is not a new drawing execution for every arena and does not
establish Windows pixels or arbitrary camera arithmetic domains.

## Next source boundary, static observations only

41a5a0 ends at41ae50/ret12, before the separate41ae60 function. It builds the
active list in ascending slot order and bubble-sorts by signed integer z, with
stable ties. Its Actor child40de30..40e160 is not just a43f010 forwarding call:
it invokes40be70 (sheet selection),40bf30 (unmodified frame-picture width) and,
under the HP<maxHP/3/current-frame-point gate,43f310..43f37a (direct rectangle
Blt without43ef70 clipping or a color-key flag).

40be70..40bf1f checks raw Frame presence, searches the original sheet ranges for
Frame.pic+Actor318, and selects the normal754 or mirrored77c pointer array.
It passes mirror0 to43f010 because the source selects an already mirrored
wrapper.40bf30..40bfa8 searches using Frame.pic without that Actor offset and
reads the selected bitmap's per-picture width. These distinctions and all
remaining World draw branches must be recovered/tested before claiming the
whole actor renderer; none is part of the new camera implementation.
