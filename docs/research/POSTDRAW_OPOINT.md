# Original post-scheduler lifetime and opoint

`OriginalPostDrawOpoint` implements the complete `41fb0b..4203b4` body and
its early lifetime paths at `4213a9..4214c6`. It runs for one slot after that
slot's scheduler. It returns the original continuation:4203b4 for the following
weapon/creation block,420e93 after an opoint attempt, or4214c6 after early frame
lifetime handling. These destinations are distinct; an unsuccessful opoint
attempt still bypasses the weapon block.

EXE SHA-256:
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.
All game code and coordinate conversion helpers execute in the original VM.
Only constructor memset retains its established host boundary. The controlled
source CPU uses explicit53-bit precision/CW027f, with both legacy and SSE2
conversion paths supplied separately. No native engine behavior is taken from
the earlier Practice projectile allowlists.

## Lifetime and ground correction

Signed frame/100 equal to11 or12 takes the special lifetime path before the
ordinary frame-range check. Each World slot with activity **exactly1** and
Actor+2f4 equal to the current slot receives Actor+8=`1100-currentFrame`.
The parent receives the same counter, then frame0. It stays active. Other
negative frames or frames>=400 reset frame0 and deactivate the parent instead.
The implementation preserves ascending slot order and Actor aliases.

For type0 with nonpositive HP, frames below12 or110/111 become186 with
vy/pendingY=−3, y=−1 and integerY=−1. A second correction applies to type0
at integerY0 with all three y/vy/pendingY values equal to zero, for frames
180..189 except184 and212..214. It makes those same writes. Signed zero is
equal; unordered NaN comparisons bypass the correction as the original does.
FPU exception/status flags are not part of native comparison.

## Generic opoint

The corrected current Frame is retained as the caller's SP+38 reference.
Creation requires positive opoint kind and object ID, plus wait0. A nonzero
freeze only suppresses type0. Packed facing greater than10 supplies count
by signed division10 and direction by remainder10; all other values request
one object with the raw direction value. Direction0 copies the parent's byte,
direction1 computes `1-parentFacing` with byte wrapping, and every other value
writes0.

Each iteration searches the first free World slot50..<400 and the first catalog
entry with the requested ID. Failure stops the attempt. Both searches are
performed even when the free slot is missing. Unlike the earlier state9996
particles, these search results reset to−1 on every iteration; there is no
retained Object index fallback.

Creation uses the original Actor constructor over the selected allocation's
existing backing, binds the new Object, loads header+90, and writes the original
placeholder coordinates. It copies Actor+354 from the reloaded parent, clears
every currently active Actor's vrest byte for the new slot, then activates it.
The parent can alias this allocation: its newly current frame supplies centerX/Y,
while the saved original Frame supplies opoint X/Y, action and velocities.
Parent fields are re-read after writes at the original dependency points.

The child gets wrapped integerX/Y, the parent's team, parent binary64Z+1,
opoint action, dvy and initial depth speed0. Child states3000/1002/3006 use
exclusive up/down input for depth speed−2.5/+2.5, except sourceIDs223/224.
SourceID211 scales that speed by0.25. Type0 children inherit the parent's
nonnegative owner or the parent slot, then its Actor+8. These ID rules come
directly from41ffaa..42001a; no character-specific handlers are registered.

Facing selects ±opoint dvx. Multiple objects receive an extended intermediate
spread `ordinal*10/(requestedCount-1)-5`, added to depth velocity. Horizontal
velocity subtracts the spread when their signs agree and otherwise adds it.
Every arithmetic operation rounds at the selected x87 precision, and binary64
stores round separately. The spread is retained across the depth-velocity store
for the following comparison and horizontal adjustment; it is not reloaded
from a rounded host Double. Partially full pools retain the **requested** count
for this spread and use the **created** count for the following delay pattern.

Type3 parent/state3003 writes reciprocal vrest10 between the new slot and the
parent's Actor+0 owner. SourceIDs5/52 receive HP/maxHP/redHP10 and MP5. All three
stored binary64 coordinates pass through4450d0. Opoint kind2 sets the parent/
child holding flags and slot links, with team re-read afterward.

Multiple created slots receive the original symmetric+ec delays: even counts
keep two center records untouched, odd counts keep one. Every pair receives
reciprocal vrest40, in original pair order. Shared Actor allocations preserve
later overwrites; there is no deduplication by physical Actor identity.

## Source inventory and comparisons

`survey_postdraw_opoint.py` reads all137 Objects from the accepted original
53-bit loaded catalog. It verifies that capture, the fixture, every decoded
storage blob and the current original DAT hashes. Among present Frames it
finds2,454 positive kind/ID opoints, with no unknown field bytes or actions
outside0..<400. Requested counts are1..10 and35; the distribution and identity
are in the [static survey](../evidence/postdraw-opoint-dat-survey.json).
This inventory is not an execution of those2,454 frames.

The controlled original-instruction corpus has1,991 cases: lifetime/ownership,
ground corrections with finite/nonfinite comparison operands, gating, packed
facing and byte wrapping, type/ID/direction/owner rules, partially full pools,
parent/free aliases, held links and vrest, coordinate overflow/conversion,
nonzero selected slots and every original DAT multiplicity, including35.
There are2,291 actual constructors and6,873 coordinate helper calls,9,164
verified helper returns in all. These cases execute786 instruction addresses:

| Range | Executed / disassembled |
| --- | ---: |
|41fb0b..4203af corrections/opoint |519 /522 |
|4213a9..4214bf early lifetime |69 /70 |
|4061d0..4064cc Actor constructor |151 /151 |
|4450d0..44517a conversion region |47 /55 |

The three unexecuted opoint instructions42030a/b/e are the negative-count arm
of the compiler's signed remainder adjustment. The created count starts0 and
only increments, bounded by available slots on these paths.4213cd is alignment
padding bypassed by explicit jumps to4213d0. The eight unexecuted conversion
instructions belong to the remainder of its surrounding region; the separate
[coordinate study](COORDINATE_PRECISION.md) verifies both whole entry paths.
Executed instruction coverage does not prove all conditional outcomes.

Native reconstructs each full input pool independently from its own constructors
and the declared patches. It compares hashes of all424,408 World/Actor bytes
and masks, all46,144 global bytes, ordered constructor requests and the exact
continuation. Global state is unchanged by this block. The source additionally
checks defined-byte reads, Actor canaries, unchanged Object storage, helper ABI,
stack restoration, CW and empty x87 tags at each exit.

World and Actors commit only on complete success. Observers must buffer effects
until the enclosing tick commits. Rollback checks cover a second constructor
observer failure after an earlier aliased spawn/holding-link update, and an
unavailable nonfinite depth arithmetic operand after earlier pool writes.
Nonfinite ground **comparisons** are supported here; general nonfinite depth
**arithmetic**, corrupt catalog/Frame/owner references and caller-stack overflow
from pathological inputs are not claimed as native-equivalent.

## Reproduction and integration

```sh
uv run --script tools/oracle_postdraw_opoint.py
python3 tools/survey_postdraw_opoint.py
python3 tools/accept_postdraw_opoint.py
swift test --package-path native -c release --filter OriginalPostDrawOpointTests
```

The initial1,862-case comparison passed in1.443s after a120.52s release build.
The final corpus adds coverage prompted by the DAT multiplicity survey and the
previously unexecuted ownership slots. Acceptance passed six release tests
in2.274s (build127.35s), including the retained897-case slot prefix and the two
new rollback checks, before publishing a lossless fixture. All158 previous
fixture hashes remain unchanged. The [evidence report](../evidence/postdraw-opoint.json)
pins the2,452,941-byte raw capture and111,787-byte packed fixture. Independent
decompression verifies complete JSON equality, both lengths and SHA-256.
The159 current pins and artifact checks are retained in
`build/research/postdraw-opoint-fixture-pins.json` and
`build/research/postdraw-opoint-artifact-verification.json`.

The final packaged run passed all three tests in1.573s after a127.12s release
build, without a raw-corpus override. NTSDNative linked successfully; no window
or device comparison is implied. Python compilation, local research links and
diff checks passed. Source and all SwiftPM processes were terminal before the
milestone commit.

Next implement the alternative4203b4..420e93 weapon destruction/creation path,
then the common420e93..4213a9 late creation/deletion path. Preserve each returned
continuation and complete all actions for this slot before advancing EDI. Then
join the entire41f550..4214cf loop to its initialized parent and continue the
first actual full tick. Early lifetime handling in this study does not recover
all other incoming register contexts at4213a9.

The own initialized chain remains at41f550/SP1000e9bc, before its first tick
returns. The new core is still separate from Practice. Full match/application
integration, natural DAT sequences, Windows/device output and clean-macOS
delivery remain open.
