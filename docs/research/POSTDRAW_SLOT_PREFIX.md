# Original post-draw slot prefix

`OriginalPostDrawSlotPrefix` implements `41f550..41fb0b` for one live World
slot, including the entire `40d960` scheduler and real `416fb0` sound behavior.
An inactive slot exits at `4214c6`. This is one part of the interleaved
400-slot loop, not a separate pass over all Actors. The caller must finish
this slot's post-schedule actions, opoint, other creation and deletion before
advancing to the next slot.

EXE SHA-256:
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.
The source harness executes the pristine EXE with explicit CW `027f`, status0
and empty x87 tags. Game helpers are not replaced. Constructor `memset` remains
the previously declared host boundary.

## Recovered order

1. Any nonzero activity byte selects the slot. Type0 in state9995 searches the
   catalog for the first sourceID50. A match replaces its Object; either way,
   the current frame resets to0.
2. The new current frame is read again. State8000 through8999 searches for the
   first sourceID equal to state minus8000, for every Object type. A miss still
   resets frame0 and writes Actor+318=140. This can chain with the first rule
   and expose state9996 in the same invocation.
3. Type0 in state9996 with wait exactly1 creates up to five particles, each
   using the first currently free slot in50..<400. The first four search for
   ID217; the fifth searches for218. No free slot ends creation immediately.
4. Type0 resource updates run after creation, re-reading the current Object.
   A newly constructed Actor can alias the parent, affecting these conditions.
5. The whole scheduler runs for this same slot, receiving global451160 and
   the slot ordinal. Its usual early gates do not suppress preceding resource
   updates or transformations.

The only ID rules added here are the ones at the original instructions above
and the51/52 MP rule below. No character or technique registration is added.

## Particle creation and caller scratch

At `41f730`, a successful ID search stores its catalog ordinal in the caller
word at SP+70. `41f734` reads that word unconditionally, including on a failed
search. A miss therefore consumes the retained index; it neither skips the
particle nor supplies a default. The public API carries an optional
`retainedObjectIndex` inout. It requires a known value only on a dereference
without a successful search. Finding no free slot does not read it. Its actual
provenance in the initialized outer caller remains to be connected.

Each selected Actor runs the full original constructor over its existing
backing. Untouched bytes and their initialization masks survive. Object binding
and header+90 determine the new record; placeholder coordinates are580,−200,300.
The selected World slot activates before its first random draw. Reloading
parent coordinates afterward preserves aliases between the parent and free
slot, as well as multiple free slots sharing one Actor allocation.

RNG requests preserve stream labels and order:155/7 for integerX−3,
156/7 for integerY−9,157/15 for vertical speed;158/2 or159/2 for depth speed;
160/3,161/3 or162/7 for horizontal speed;164/4 for frame and165/2 for facing.
Stream163 is not called. IntegerZ is parentZ+1 with32-bit wrapping. The fifth
particle has depth speed1 and therefore omits its depth RNG call. Coordinates
convert to binary64 in original Z,Y,X order. These floating calculations use
small exact integer-derived values and exact constants under53-bit precision;
they do not approximate a rounded general x87 expression with host arithmetic.

## Resource updates before scheduling

For type0, positive HP below redHP gains1 when global450bd0 is0. Then a negative
Actor+320 at that same global phase subtracts damage from HP and damage/3 from
redHP. Damage is900 divided by a positive Actor+340, otherwise9. Division is
signed truncation toward zero. Both subtractions wrap; only negative results
then clamp to0. Actor+34c always gains9, including when the actual damage is0.

MP regeneration requires MP<500, global450bd4==0 and nonnegative Actor+8. If
Actor+2f4 differs from−1 it also requires MP<150. The amount is
`((500 - adjustedHP) / 100) + 1`, preserving signed32-bit wrapping and signed
division. HP is capped above at500; sourceIDs51 and52 halve it before the
subtraction. There is no final MP clamp. These tests occur before the scheduler
moves Actor+8 toward0. The scheduler then consumes the resulting frame, Object,
HP and MP, including same-call frame/MP redirects.

## Evidence and boundaries

The source corpus contains897 controlled calls on four declared Objects and
400 original-constructed Actors. It includes inactive/noncanonical activity,
type and catalog-count gates, duplicate IDs, chained transforms, signed
HP/MP limits and overflow, partially full pools, parent/free aliases, retained
index lookup misses and scheduler transitions after transformations.

Every one of the329 prefix instructions executes, together with all151 Actor
constructor instructions. The combined corpus executes714 instruction addresses
and checks3,227 helper returns, including ABI stack cleanup and saved registers.
It records273 constructions,1,878 RNG requests and183 catalog sound calls.
This invocation exercises164/316 scheduler instructions,44/58 sound and26/29
RNG instructions. Their full behavior has separate established studies; this
corpus does not claim all helper branches or natural DAT sequences.

Native independently constructs each input pool and applies only declared
input patches. Comparison covers SHA-256 of all424,408 World/Actor bytes and
their masks per case (380,693,976 bytes across897 calls), all46,144 global
bytes per case, ordered construction/RNG/sound events, exit selection and the
retained caller word. Original reads check Actor/World byte provenance;
Object bytes, Actor canaries, stack, CW and empty FPU tags are checked.

The API stages World, Actors, globals and retained index until successful
completion. Observers must buffer external effects until the enclosing tick
commits. Failure during particle creation must roll back the aliased parent,
the whole pool, RNG globals and retained lookup result. Unknown retained-index
provenance is an explicit unsupported boundary, not a substituted game rule.
Invalid catalog/Frame storage and prior scheduler numerical limits also remain
explicit; arbitrary corrupt addresses are not a native memory model.

## Reproduction and next work

```sh
uv run --script tools/oracle_postdraw_slot_prefix.py
python3 tools/accept_postdraw_slot_prefix.py
swift test --package-path native -c release --filter OriginalPostDrawSlotPrefixTests
```

The harness initially stopped because its constructor instruction whitelist
ended at40649f. Disassembly establishes the actual final instruction `ret` at
4064cc; extending that bound allows the full real constructor to run. No native
expectation or original instruction was changed. Its optional header-input
extension also reproduces all1,491 historical WorldControl and515 WorldPhysics
cases and their complete instruction inventories unchanged.

The initial native comparison passed all three tests in0.691s after a121.73s
release build. Acceptance then passed six tests in3.160s (build125.38s),
including the retained6,084-case whole scheduler comparison, before publishing
one new lossless fixture. All157 previous fixture hashes remain unchanged.
The [evidence report](../evidence/postdraw-slot-prefix.json) pins the918,456-byte
raw capture and59,242-byte fixture. Independent decompression verifies complete
JSON equality, lengths and SHA-256, with158 current fixture pins in
`build/research/postdraw-slot-prefix-fixture-pins.json`. The artifact and
historical source regression checks are retained in
`build/research/postdraw-slot-prefix-artifact-verification.json` and
`build/research/postdraw-prefix-source-regression.json`.

The final packaged run, without a raw-corpus override, passed all three tests
in0.712s after a125.61s release build. NTSDNative compiled and linked; this is
not a window/device test. Local research links, Python compilation and diff
checks passed. All source and SwiftPM jobs were terminal before committing.

The next [POSTDRAW_OPOINT](POSTDRAW_OPOINT.md) study now implements the entire
41fb0b..4203b4 body and early frame lifetime paths, preserving its three distinct
continuations. Next recover the alternative4203b4..420e93 weapon/creation block
and common420e93..4213a9 late creation/deletion, then advance EDI in
the original live-slot order through4214cf. A later slot created earlier in
the pass can be processed during that same pass. Do not split the scheduler
into an all-Actor phase or skip surrounding blocks absent from one test match.

The initialized own chain still stops at41f550/SP1000e9bc; this study does not
extend it or the Practice UI. The entire returned tick, complete Naruto/Sasuke
District match, application integration, Windows/device comparison and clean
macOS delivery remain open.
