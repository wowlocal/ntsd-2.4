# Post-draw item commands, resources and cleanup

`OriginalPostDrawCommands` implements the entire `4214d5..421a15` consumer:
requested items, resource commands, both healing timers and final per-slot
cleanup. It runs after [the live-slot lifecycle](POSTDRAW_LIFECYCLE.md).
It stops before the HUD caller; command flags clear later at 421a1c/421a22.

EXE SHA-256:
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.
The source corpus executes the original instructions, constructors, RNG,
coordinate conversions and entire 402000 music helper. Constructor memset and
an explicitly supplied COM response are platform boundaries. Controlled runs
use CW027f/53-bit precision and a declared legacy/SSE2 conversion selector.
They do not constitute a Windows run or a natural match.

## Requested items:4214d5..421799

Only global450bb8 exactly1 enters this pass. It scans the catalog in order,
collecting every Object whose source ID is100..<200. ID122 additionally draws
RNG208/range2 and is excluded for result0. ID123 has no exclusion here. The
candidate array is frozen before construction, and each candidate gets one
creation attempt; there is no random selection from that array.

Each attempt searches for the first inactive slot50..<400. If none exists,
original caller SP+34 retains its incoming value and the attempt continues.
The native optional `retainedSpawnSlot` represents this provenance. It is
required only when actually dereferenced, after all four coordinate draws.
A full pool therefore still consumes RNG and may reconstruct an active slot.
A missing native value raises an explicit error; no fallback is invented.

The arena index is global44d024. Width/minZ/maxZ are the first three words of
its original Background record. All arithmetic below wraps signed 32 bits,
and division by30 truncates toward zero:

```
x = RNG209(30) * ((width - 60) / 30) + RNG210(30) + 30
z = RNG211(30) * ((maxZ - minZ - 60) / 30) + RNG212(30) + minZ + 30
```

Reads and random draws retain the original order. The current Actor allocation
is reconstructed without erasing undefined backing bytes. The candidate
Object is bound, header+90 is copied toActor+31c, binary64X/Z use these integer
results andY becomes−500. The slot activates, then every nonzero-active Actor
clears its vrest byte for the selected slot. Physical aliases remain live.
Velocities become zero; ID122 sets onlyHP+2fc to 200. All three integer
coordinates are written by the real4450d0 conversion behavior. Actor+354 is
not set to 99 in this caller. The last selected/fallback slot remains inSP+34.

Other temporary stack outputs, including the candidate array and SP+44/4c/
50/6c, are outside this API's retained-state model. Full caller scratch
provenance is still a separate integration requirement.

## Resource pass:42179b..421a15

All 400 slots are inspected in ascending order. Every nonzero activity value
qualifies; physical Actor aliases are not deduplicated.

Global450bb8 exactly2 setsActor+31c to−1 for types1/2/4/6. Otherwise, mode 1,
team5, type0 and sourceID other than300 setHP and MP to 0. These are original
type/ID conditions, not a character support list.

Global450bc0 exactly1 refills resources. Mode1 additionally requires slot<8
and team1; other modes accept every active slot without an HP or type gate.
MaximumHP+304 is raised to at least500, redHP+300 andHP+2fc copy it, and
MP+308 becomes500. Every qualifying slot then calls402000, even when the
values were already full. That helper skips a null global44f044; otherwise
it invokes the control interface's method+1c to resume music. The HRESULT is
ignored by this caller. Native emits the corresponding request; the enclosing
tick must buffer it before any device action.

The two healing timers have distinct rules:

- Actor+E0: signed timer/1000 must equal1 andHP must be positive. Decrement;
  on a multiple of8, heal toward redHP using a comparison against wrapped
  redHP−8 before adding8. If HP was already at least redHP, clear the timer.
  Then clear it whenever its current value is a multiple of1000.
- Actor+E4: timer andHP must be positive. Decrement; on a multiple of8 with
  HP below redHP, add8 with signed 32 wrapping. Only a result greater than
  redHP clamps HP and clears the timer. Reaching redHP exactly retains the
  timer. Overflow can produce negativeHP and bypass that clamp.

After both timers, current frame state 1700 writesE0=1100, including for a
nonpositive HP. Still-active slots resetActor+2e8/2ec/2f0 to 1000 and+2e4 to 0,
then clear **only byte+EB**. The other bytes of+E8 and adjacent+EC survive.
The loop completes before 421a15, leaving both command flags unchanged.

## Differential evidence

All 3,898 whole original passes match native state and ordered events.

| Group | Cases |
| --- | ---: |
| Command/catalog/source-ID/RNG selection | 840 |
| Full/partial pools, retained slots, aliases, legacy/SSE2 | 72 |
| Arena coordinates and signed overflow | 180 |
| Destruction/type/team/mode gates | 576 |
| Refill gates and maximumHP | 720 |
| Independent timers and HP/redHP boundaries | 1,320 |
| Aliased two-slot healing | 30 |
| State1700, including dead Actors | 9 |
| Joined command/refill/timer/state/COM-result paths | 144 |
| All 400 slots with five activity values | 5 |
| Empty pool and null music control | 2 |

Every comparison independently constructs the inputs and checks all 424,408
World/Actor bytes and defined masks, all 46,144 global bytes, retainedSP+34 and
3,252 ordered events:2,436 RNG,566 constructors and 250 music requests.
The source checks4,951 helper returns, preserved registers, stack restoration,
canaries, defined-byte reads, immutable Object/Background storage, equal CW
and empty x87 tags. The retained slot changes in 330 cases.

| Range | Executed / disassembled instructions |
| --- | ---: |
| 4214d5..421799 item pass | 172 / 173 |
| 42179b..421a0f resource pass | 146 / 154 |
| 4061d0..4064cc constructor | 151 / 151 |
| 417170..4171bc RNG | 26 / 29 |
| 4450d0..44517a conversion region | 42 / 55 |
| 402000..402011 music helper | 8 / 8 |

All 545 executed PCs are inventoried. The nine missing caller instructions
are three alignment instructions4214fa/4217a7/4217ae and two negative-remainder
adjustment sequences4218d7/d8/db and 421963/64/67. Positive timer gates and the
subsequent decrement preclude those negative-remainder arms in this declared
pool. Instruction coverage does not prove every branch or natural DAT sequence.
The wider [coordinate conversion study](COORDINATE_PRECISION.md) remains
separate; this pass only converts integer-derived values and does not establish
arbitrary nonfinite or24-bit arithmetic support.

Atomic failure checks cover the second constructor after eight RNG calls,
the second music request after earlier recovery/cleanup, and a full pool whose
retained slot is unknown. World, Actors, globals and the retained value roll
back together. The no-candidate control confirms unknown provenance is harmless
when unused. These injected observer errors exercise the native transaction;
COM HRESULTs are separate source inputs and remain ignored by this caller.
Observer events are provisional until the enclosing tick commits.

## Reproduction and remaining work

```sh
uv run --script tools/oracle_postdraw_commands.py
python3 tools/accept_postdraw_commands.py
swift test --package-path native -c release --filter OriginalPostDrawCommandsTests
```

Run SwiftPM sequentially. Acceptance passed all four release tests in 3.041s
following an 88.38s build before publishing the fixture. The first attempt
failed to compile because the new test compared a non-Equatable error type;
pattern-matching the error fixes that test without changing engine behavior.
The final packaged run passed four tests in 3.051s after a 139.21s build,
without a raw-corpus override. NTSDNative linked; no app window was tested.

The [evidence report](../evidence/postdraw-commands.json) pins the 2,776,979-byte
raw capture and 201,611-byte lossless fixture. Independent decompression proves
full byte/JSON equality, lengths and SHA256. All 162 old fixtures remain unchanged;
all 163 pins are checked in build/research/postdraw-commands-fixture-pins.json.
The artifact audit is build/research/postdraw-commands-artifact-verification.json.
Both [own initialized consumers](GAMEPLAY_COMMANDS.md) now continue this pass
through 421a15, comparing independently rebuilt native state. Their unchanged
first-tick inputs/events do not replace the controlled branch coverage above.

Next: retain the actual HUD argument at
SP+68 (the HUD never reads it; rendering uses global 455608), clear command
flags at their original positions and recover whole
HUD 41ae60..41b12d/ret4. Then continue421a2d..422994 diagnostics/results and
full tick return. Full match, app integration, Windows comparison, device
latency/image/audio and clean-macOS delivery remain open.
