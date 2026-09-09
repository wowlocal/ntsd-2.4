# Cpoint actions, placement and the second attachment pass

Baseline: `downloads/NTSD_2.4_2.0a_clean/NTSD 2.4_2.0a/NTSD 2.4.exe`,
SHA-256 `3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.
This continues [hit resolution](WORLD_HITS.md) on the same own World.
The whole functions and caller match native Core in 2,681 controlled cases
and both own launch chains. Three lossless fixtures are accepted. This is not
a complete tick or application integration.

## Source boundaries

| Instructions | Responsibility |
| --- | --- |
| `41f2ac..41f2b3`, whole `418c30..419373` | Actions, exhaustion, throws, transformation and caught-link release |
| `41f2b3..41f2b8`, whole `4187b0..418c2f` | Current-frame cpoint placement and injury |
| `41f2b8..41f47d` | Ascending 400-slot held-owner cleanup, unrolled five slots per iteration |
| `41f47d..41f484`, whole `417f80` | Second depth and held-object pass, using the shared [WORLD_LINKS](WORLD_LINKS.md) mechanism |

Both cpoint helpers retain ECX. The caller sets the World receiver before the
first call and does not reload it before the second. They preserve EBX/EBP/ESI/
EDI and return without arguments to pop. No character-ID allowlist is involved.
References remain World-slot/Object bindings into native storage, not host pointers.

## Cpoint actions: collision Frame first

`418c30` scans active!=0 slots in ascending order. It captures the collision
Frame at Actor `+7c`. Cpoint kind 1 and hitstop `+b4>=0` enter the captor path;
the partner named by `+8c` must have reciprocal `+90` and collision cpoint kind 2.
These checks do not require partner activity or a character Object type.

The local partner slot survives all 400 iterations. Entry `418c4e` reads it
from entry-SP minus 4. A successful reciprocal comparison replaces that slot
before checking the partner's cpoint kind. A failed reciprocal comparison does
not replace it, yet can still reach the throw path. Native takes optional
`retainedPartnerSlot` provenance and throws only if a path needs a missing value;
it does not silently substitute current `Actor+8c`. Synthetic probes explicitly
supply this storage and test both initial and earlier-slot retained values.
Full outer-tick scratch provenance remains open; the first own continuation
does not dereference this entry value.

Positive cpoint `decrease` (`+30`) subtracts from Actor `+94`. Negative decrease
adds to it and, if the wrapped result is negative, sets both current Frames to
0 and both impulse flags `+20` to 1. The partner receives pending x impulse
-4 when the captor's integer x is greater, otherwise +4; pending y is -3 and
partner frame becomes 181. The captor resets frame 0 and still proceeds to the
original throw/direction-control tail. Positive decrease alone has no equivalent
immediate exhaustion branch.

On a valid pair, actions run sequentially:

- Attack requires `d1!=0`, signed byte `be>0` and nonzero `aaction`. A held
  horizontal direction suppresses it only when `taction` is nonzero.
- Directional attack then requires any of `cd/ce/cf/d0`, the same attack gates,
  and nonzero `taction`; it can overwrite the first action.
- Jump then requires `d2!=0`, signed byte `bf>0` and nonzero `jaction`; it can
  overwrite both attack actions.

Each transition writes the captor frame, negates a negative frame with Int32
wrap and flips facing as byte `1-facing`. The partner frame comes from the
**new captor Frame's** vaction. Both `+88` latches reset. Original collision
cpoint fields remain frozen through all these changes and World aliases.

## Throw, transformation and release

Nonzero original cpoint throwvx (`+24`) runs even after invalid linkage.
Positive throwinjury (`+3c`) writes partner `+320`. Exactly -1 instead saves
the captor's source ID at `+324`, the partner's ID at `+33c`, replaces the
captor's Object with the partner's and resets frame 0. It then scans every
active slot whose `+2f4` equals the captor slot and replaces that Object too.
The partner Object is read live for each write; duplicated World bindings and
earlier writes must not be flattened into a copied list of Objects.

Partner integer y/x use the original cpoint position and the captor's **current**
Frame centers. Binary y/x are refreshed immediately after their respective
integer writes. The captor advances through its current Frame `next`, copies
that to collision Frame `+7c` and resets `+88`. Partner vx uses the original
throwvx and current facing; its current/collision Frames become raw vaction and
vy becomes throwvy. Exclusive up/down chooses negative/positive throwvz; both
or neither preserve the old vz. Integer arithmetic wraps before binary stores.

Direction control runs afterward when cpoint dircontrol is exactly 1 or -1
and the captor `+88` is exactly 2. Exclusive horizontal directions set facing
with the source's two different mappings. It is not a general turn-to-target rule.

When the captor entry gates fail, a **current** cpoint kind 2 checks `+90`,
reciprocal owner `+8c` and that owner's current cpoint kind 1. Invalid linkage
sets frame 212 and vy=-3, and caps binary y at -2 when y>-2. Integer y and the
link fields are not refreshed. Only finite height inputs are currently covered.

## Placement and injury use current Frames

`4187b0` independently scans all active slots after the complete action pass.
The captor's current cpoint must be kind 1 and its state exactly 9. Reciprocal
`+8c/+90` and partner current kind 2 are checked without an activity/type gate.
Vaction replaces the partner's current frame when hurtable (`+2c`) is 0, or
when it is 1 and partner hitstop is 0. Negative current frame then flips facing
and is negated, including when vaction was not assigned by this call.

Nonzero injury (`+0c`) applies only when captor `+88==0`. Positive input is
scaled with wrapped multiplication by 100 and signed division if partner
`+340>0`. Lethal damage credits the captor's `+354` slot only for partner
`+2f4==-1`; no character-type test is added. Damage/red HP/statistics retain
the original signed thirds and two-team global counters. Captor latch becomes
1 and hitstop 2; partner hitstop becomes -3. A negative **input** injury instead
adds that negative value to HP and injury/3 to red HP, sets only the captor
latch and does not update the positive branch's statistics or hitstop.

The captor anchor uses its current center plus the frozen cpoint x/y. Partner
centers use its current Frame, but its cpoint x/y come from the partner Object
indexed by the captor's **raw signed vaction**, even after current-frame negation.
For controlled negative vactions -1..-5 this points into the Object header.
Native exposes only a complete known header extent with its initialization
mask; unknown backing is not replaced with zeros or an invented Frame.

Cover is a signed decimal field: nonzero remainder by 10 gives z+1/y-1;
zero remainder gives z-1/y+1. Quotient 1 copies captor facing; quotient 2 flips
it as a byte; other quotients preserve partner facing. This facing update is
**after** geometry. Binary z/x/y refresh in that order.

## Held-owner cleanup and composition

The caller checks active owners with positive Actor `+98`. A target `+9c`
outside signed 0..<400, inactive target or target `+a0` unequal to the owner
slot clears **only owner `+98`**. Validity can differ between neighboring slots
because the pool is live. The following whole `417f80` is mandatory and uses
the shared implementation, including depth, held-item consumption, throws and
ordered RNG. No new contact collection or scheduling is inserted here.

`OriginalWorldCPoints.apply` publishes its state only after all four stages
succeed. Observers must buffer their effects until the whole tick commits.
The comparison includes an explicit public rollback trial on the own loaded
state: an invalid positive held link clears in the candidate state, then the
stage observer throws and the original public Actor/global state must survive.

## Evidence and limits

`tools/oracle_world_cpoints.py` captures 2,681 declared input cases,
978 actual nested helper returns, 176 RNG events and 1,274 unique instructions.
The entire 400-Actor pool, World, initialization masks and globals are compared;
Object/catalog/BG storage stays readonly. The source captures reached all 446
instructions of `418c30`, 266/267 of `4187b0` (only alignment `4187c9` skipped),
and all 118 instructions of the caller before `41f484`. This does not establish
every branch outcome or natural gameplay sequence.

`tools/survey_world_cpoints.py` inventories all 137 loaded Objects and 15,363
present Frames with pinned DAT/catalog hashes. There are 775 kind-1 and 650
kind-2 cpoints; all observed vactions are within the 400-frame array. Unknown
throwinjury/throwvz words remain null in the inventory. This is loaded data,
not execution or proof that every action/throw is reachable and safe.
One loaded kind-1 Frame with nonzero throwvx has undefined throwvz:
`chars\chiyo_kunais.dat`, source ID419, frame49/state9. The original would read
that word on an exclusive up/down throw. Its reachability and Windows backing
remain open; the native storage must not invent a zero. The survey also records
undefined words in cpoints whose current branches do not use them.

Both fresh own startup/menu/selection/launch/control/physics/links/contacts/hits
chains reproduce their complete pinned parents on the same CPU and stack.
The four new sections have 5 helper returns, 2 depth checkpoints and no
undefined catalog reads per chain. All before/after state records, including
14,586 retained Frame allocations, are identical: no own first-tick cpoint or
held link is active. The second depth pass retains frame 219, HP500/MP200,
positions, game RNG40/1, CRT, all resources/music and the full replay buffer.
PC is `41f484`, SP `1000e9bc`, still the same unreturned `4246b0`, phase1/tick1.

The first combined native release comparison passed all 3 XCTest in 40.063s
(build 111.04s): synthetic probes 2.083s, own chains 37.980s. The latter report
418,964 records / 1,013,531,154 bytes and masks, 936 helper returns and 88
checkpoints in the launch/gameplay continuation, with earlier startup/menu/
selection independently revalidated by nested runners. Their counters are not
included in these totals. Both public rollback trials after actual held-link
cleanup passed. No expected source-state output was edited to obtain parity.

| Capture | Raw bytes | Raw SHA-256 |
| --- | ---: | --- |
| world-cpoints | 2,435,820 | `0abd54986fe3825fbb75397d7de719fa3011b2dcb22738b87efb265b328f7c6a` |
| gameplay-cpoints | 35,225,105 | `09bf43cc9d5f4bee3acadd1b3580bb6d3f886b5432aa266f835883d7fa0070a0` |
| gameplay-cpoints-control | 35,236,880 | `522f9e9c74ad642b6c448df419537ee974d63d8d386be39be611a9947c53b192` |


`tools/accept_gameplay_cpoints.py` independently checks raw/parent/blob hashes
and runs all three release comparisons before publishing packed fixtures.
Acceptance passed in 40.005s (build 115.00s). All 126 previous fixture hashes
are unchanged; the three new envelopes, raw/full JSON, all blob sizes/hashes
and parent identities were independently verified. Current 129 pins are saved
in `build/research/gameplay-cpoints-fixture-pins.json`. Reports:
[controlled cases](../evidence/world-cpoints.json),
[own launch](../evidence/gameplay-cpoints.json),
[control launch](../evidence/gameplay-cpoints-control.json),
[DAT inventory](../evidence/world-cpoints-dat.json).

Final packed release regression passed all 25 XCTest in 303.164s
(build 113.91s): Actor/World physics, World links/contacts/hits/cpoints,
Gameplay control/physics/links/contacts/hits/cpoints and MatchLaunch. This also
compiled and linked `NTSDNative`; it does not verify an app window or device
output. Python compilation and the staged diff check passed. All source capture,
acceptance and SwiftPM processes were terminal before the milestone commit.

## Next source boundary

Next is actual `41b5d0` camera/background handling and `41a5a0` actor drawing
from this own state, then remaining mode branches, scheduling, recovery,
creation/deletion and the full tick return. Practice integration, continuous
DAT sequences, Windows/device comparison, clean macOS and the first complete
Naruto/Sasuke District match remain open.

Static inspection of `41b5d0` shows a full 400-slot bounds/deactivation pass
before camera targeting. It handles Object types differently, updates integer
x/z through actual `4450d0`, prioritizes the eight positive input seats with
living Actors, and falls back to all living type-0 Actors. The entire function
continues into the real `41a250` background draw at `41bc7b`; stopping before
that call is only the older camera slice. `41a5a0` then builds its own active
list and sorts stably by signed integer z before shadow/sprite/effect drawing.
These are starting observations for the next study, not a new native draw claim.
The whole camera function ends at `41bc87/ret8`; background `41a250..41a590`
returns with ret4, dispatches arena ordinal99 to `41a050`, and calls actual
`43f010` bitmap drawing or `415160` fill. Background layer counters can change
even when their current animation gate suppresses drawing. These child bodies
and retained draw-target provenance belong to the next comparison boundary.
