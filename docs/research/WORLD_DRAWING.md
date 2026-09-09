# Whole World and Actor drawing

Baseline EXE SHA-256:
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.
The only behavioral reference is the original Windows NTSD distribution.

## Source and native ownership

`OriginalWorldDrawing` implements `41a5a0..41ae50`, through the actual cookie
check and ret12 in the source comparison. It composes the entire Actor child
`40de30..40e160`, Object sheet selection `40be70..40bf1f`, picture width lookup
`40bf30..40bfa8`, bitmap/clip `43f010/43ef70` and direct rectangle
`43f310..43f37a`. These children execute real original instructions in the
reference tool; only COM Blt is a supplied device output boundary.

The caller at `41f496..41f4ac` supplies retained target, phase450bd8 and mode451160.
The whole World draw does not read its third mode argument. The native public
call therefore takes target and phase; it does not invent mode-specific rendering.

The public call stages `OriginalMatchPreparation` and commits it after success.
Rendering advances Actor spark storage, so this is not a readonly scene projection.
Device effects must be buffered until the enclosing tick commits. Catalog bitmap
references are index+1; global bitmap words retain opaque allocation tokens.
Those globals can alias catalog, initial interface or early menu resources.
The two providers preserve the reference representations and actual ownership. No Windows
EXE, emulation, source snapshots or expected renderer outputs enter the runtime.

## Ordering, shadows and sprites

The source collects all400 nonzero activity slots in ascending order and stably
bubble-sorts them by signed integer z at Actor+18. Equal z retains slot order;
World pointer aliases remain separate visits. Native sorting explicitly uses
slot number to break ties. It uses integer depth, not binary64 z or current y.

For each slot the order is shadow, Actor sprite/point, lives, name and sparks.
Shadow is skipped for negative Actor+98, current state3005/9997, source ID223/224,
Actor+8≤−70 or signed `wrappedAbs(Actor+8)%4≥2`. Its position is:

```
x = Actor+1c + integerX - BG.shadowWidth/2 - camera
y = integerZ - BG.shadowHeight/2
```

Halves divide signed integers toward zero. The BG+98c bitmap is drawn with
frame−1, key1, mirror0 and caller target. Main sprite drawing instead requires
Actor+8>−25 and the same remainder gate. Lives and sparks do not share that gate.

Actor+ b4<0 adds `phase*6−3` to sprite x, with original32-bit wrap. Normal facing0
uses x−centerX; facing1 uses x+centerX−pictureWidth. Both use
`integerZ−centerY+integerY`. State9997 clamps x first to0, then to714, and returns
before the point branch. Other facing bytes skip the sprite; ordinary states
can still draw the point using the nonzero-facing anchor.

The first Object sheet containing `Frame.pic+Actor318` wins. Each signed range
is `[first, first+rows*columns)`, with wrapped multiplication and addition.
Absent Frames and pictures with no matching range produce no bitmap call.
Normal pointers are Object+754, mirrored pointers+77c, both with4-byte stride.
These are separate already mirrored sheets; the bitmap child receives mirror0.
The facing1 width helper independently selects from the **unoffset Frame.pic**
and reads the **normal** bitmap width at+fb0+4*(pic−first).

For ordinary state, HP<maxHP/3 and positive Frame+80 draw a1×3 rectangle from
source0,20 of global44fd7c. Its anchor comes from Frame+80/+84 and centers,
including the same phase shift. Target is global455608. The direct helper uses
flags1000000, null effects and no clip/keying, preserving wrapped rectangles.
Do not generalize this source branch into an unproved status-effect visual.

## Text and sparks

Lives>1 draws `x` plus one or two decimal digits using font44faf4; values over99
retain only the last two digits. It centers using9 pixels per byte and sits at
`integerZ−centerY+integerY−7`. Names sit at integerZ+3. Their x is clamped to0,
then794−9*length, preserving a negative upper limit for long strings.

Slots below20 enter the primary label branch regardless of Object type.
Higher slots require type0 and Actor364≠5. Labels require Actor+8>−25.
Slots0..9 read raw NUL-terminated bytes from44fcc0 with11-byte stride; stride
is not a string limit. Status−1 wraps the name in brackets. The original local
buffer is20 bytes followed by a cookie. Native rejects bracketed names longer
than17 bytes rather than truncating or guessing cross-cookie stack behavior.
Other primary labels say `Com`. Team values1/2/3/4 select globals44f888/44fcbc/
44fb68/44faf8; others use44faf4.

The alternate label branch covers slots≥20, type0, Actor364=5, Actor+8>−25.
It says `Com` using44fd80, except source IDs30..<50 other than38 are suppressed.
All text bytes sign-extend Int8 into bitmap frame indices; there is no Unicode
conversion. Text targets global455608, independently of the caller target.

Sparks use live signed count Actor36c and raw parallel words at370/398/3c0.
The four source frame intervals are `<5`,10..<15,20..<29 and30..<39. Pictures are
respectively f, f−5, (f−20)/2+10 and(f−30)/2+15. First/third use x−51,y−40;
second/fourth x−30,y−24. Add Actor1c−camera to stored spark x. IntegerX/Z/Y are
not added. Valid entries draw global44f8fc to caller target, then increment f.
An invalid entry decrements count only when it is the last live entry. There
is no compaction or deletion of expired middle entries. Reaching the end frame
removes the last entry on its next visit. Aliased slots can advance an effect
more than once per World draw. No RNG is consumed by this pass.

## Evidence and remaining limits

`tools/oracle_world_drawing.py` creates source output before native comparison.
The source executes real constructors and controlled Object/Frame/bitmap/BG
metadata. Native reconstructs those declared inputs independently and compares
full World/400 Actor bytes and masks, globals, all101 BG records and masks,
ordered bitmap requests, actual word reads/masks, clips and Blts. The source
also asserts every Object, bitmap and background unchanged and verifies nested
ABIs, callee-saved registers, final ESP, x87 control word and empty x87 stack.

The first2671-case comparison passed in9.957s after a118.42s release build.
It included all instructions of the Actor, Object sheet/width and direct
rectangle bodies. The final2679-case source corpus has55874 nested helpers and202262 events:
21441 draw requests,228 width reads,139494 metadata reads,21557 clips,
19518 Blts and24 direct rectangles. Eleven metadata reads retain undefined
provenance. Follow-up controls cover alternate-label clamps, point coordinate
wrap, the tenth sheet, overlapping ranges and a nonzero presence byte255.
All251 Actor/61 sheet/43 width/38 rectangle instructions execute; World reaches
648/663. The15 remaining World addresses are11 alignment instructions, one
unreachable jump and three negative-remainder corrections behind the earlier
Actor8>−70 gate: wrapped abs can only remain negative for Int32.min, which that
gate excludes. This does not prove arbitrary mutable external callback storage.
Standalone final acceptance passed in10.039s/build18.84s. The preceding expanded
2675-case and retained3971-case bitmap suites passed together in10.199s/build126.05s. Instruction-address coverage is not every branch outcome,
every possible backing allocation or full-game equivalence.

Unchecked/out-of-record storage, bracket-buffer overflow and original memory
faults are outside the successful native domain and must fail explicitly.
Untouched bitmap metadata instead preserves its supplied bytes and defined mask,
including real+0c reads and width lookup. Unknown words are not silently zeroed.
Synthetic metadata, COM requests and matching storage are not raster output,
physical input latency, audio, Windows allocator provenance or a complete match.

## Original DAT inventory

`tools/survey_object_drawing.py` separately verifies the pinned loaded-catalog
corpus and original file hashes. Its [inventory](../evidence/object-drawing-dat.json)
covers137 Objects,15363 present Frames and362 sheets, including one Object with
all10 sheets. Every surveyed picture/state/center/point/selected-width field is
defined. Eight positive Frame+80 values occur in Itachi frames0,1,2,3,5,6,7,8.
This is an inventory, not proof of those frames reaching the low-HP draw branch.

With Actor318=0,1579 present Frames have no matching picture range.1116 of these
use pic999. The native selection retains the source no-draw result; no missing
picture is replaced. Dynamic picture offsets, natural reachability and visible
results remain separate execution checks.

## Own launch continuation

Both fresh `tools/oracle_gameplay_drawing.py` runs reproduce the entire pinned
GAMEPLAY_CAMERA parent byte-for-byte, then continue the same CPU/stack through
41f496..41f4ac. No outer entry, gameplay stimulus, copied expected state or new
device vtable is introduced. Each source pass returns6 nested helpers at
PC41f4ac/SP1000e9bc, phase1/tick1, target28002020, mode0. Before/after full state
is identical, including the complete mutable Frame heap and retained resources.

Actor8 remains75, so the source blink gates suppress shadows and Actor sprite
children on this first own tick. There are exactly20 events: two glyph requests,
14 defined bitmap reads, two clips and two Blts. Glyphs49/50 display the own
names `1`/`2` at437,507 and284,522. The full Actor child, shadows, lives and sparks
are exercised by the separate controlled corpus, not falsely attributed to this
initial natural rendering pass. No undefined catalog reads are observed here.

The native resource resolver retains early menu allocations, initial-interface
bitmaps and catalog globals on the same owned state. A separate rollback trial
adds two sparks only to its trial state, lets the first advance and throws at
the second Blt; it does not alter the source run or real native continuation.

## Following source boundary

After World draw,41f4ac tests mode1/4 and calls437860/43a860 respectively.
Then41f4d3 formats six signed Actor10 input bytes with actual CRT sprintf and
passes the text to401290;4196f0 follows at41f540. The active400-slot loop starts
at41f550, with source-ID substitutions, creation, scheduling and later recovery.
Those bodies, their mode-dependent children and whole tick return remain open.
The first complete Naruto/Sasuke District match, app integration, continued DAT
sequences, Windows/device output, clean macOS and full-game goal are not complete.

The retained30-test release regression passed in370.989s/build0.19s, covering
Actor hits/physics, bitmap drawing, World links/contacts/cpoints/camera/drawing,
all earlier own gameplay continuations and MatchLaunch. The new own drawing
comparison is a separate acceptance gate. The rebuilt NTSDNative binary links;
this is not a macOS window or pixel-output check.

The own integration exposed a distinct resource owner: SPARK comes from the
11 wrappers loaded by4297ae..429e5a for the character menu, outside both early
menu allocations and initial-interface/catalog bitmaps. The native resolver now
uses that retained OriginalMenuResourceLoading instance and its original device
bindings. New source snapshots explicitly include all11 menu wrappers before
and after the World draw; prior parent fixture scopes remain unchanged.

Final paired acceptance passed3 release tests in49.052s/build124.79s before
publishing the three lossless fixtures. Each own Native chain compares305377
records/612506511 bytes with masks,496 helpers/50 checkpoints in launch/gameplay.
Both total610754 records/1225013022 bytes,992 helpers/100 checkpoints; earlier
startup/menu/selection parents are revalidated separately by nested runners and
are not included in those counters. New-stage source totals are12 helpers and
40 renderer events; trial-only sparks are excluded from those source counts.
Both exact own states match through41f4ac, including all11 menu wrappers before,
after and on rollback. Source v2 retains every v1 value and event; only the new
menu record snapshots and their blobs were added. Neither v1 was published.

All132 prior fixture SHA values remain unchanged. The new raw/packed sizes,
SHA values, complete unpacked JSON, every content-addressed blob and pinned
parent identities were independently verified.135 current fixture pins are
saved in `build/research/gameplay-drawing-fixture-pins.json`. All source and
Swift processes are terminal; Python tools compile and whitespace checks pass.
