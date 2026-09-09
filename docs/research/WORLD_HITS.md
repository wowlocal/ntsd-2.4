# Hit resolution and the two World passes

Baseline: `downloads/NTSD_2.4_2.0a_clean/NTSD 2.4_2.0a/NTSD 2.4.exe`,
SHA-256 `3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.
CRT: the pinned VC80 DLL, SHA-256
`c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d`.

This study follows [contact collection](WORLD_CONTACTS.md). The whole hit
function and its two-pass caller now match native Core in 7,845 controlled cases
and both fresh own launch continuations. Three lossless fixtures are accepted.
It does not claim a complete tick, playable match, Windows output or application
integration. Static rules, synthetic differential checks and own launch captures
have separate scopes below.

## Source boundaries

| Original instructions | Responsibility |
| --- | --- |
| `41eefb..41ef55` | Ascending active-slot scan, item count, type-0 hit calls |
| `41ef55..41f276` | Conditional item RNG, candidate selection and construction |
| `41f276..41f2ac` | Ascending active slots with signed Object type > 0 |
| `42e100..42e61c` | Contact buffer, owner gates, raw/copied ITR and weapon strength |
| `42e61c..42e87d` | Guard and original ID-specific defense gates |
| `42e87d..42fdf2` | Damage, statistics, falls, impulses, reflection, effects |
| `42fdf2..43056e` | Blocked-hit reaction |
| `43056e..43187a` | Other ITR kinds, catches, pickups, forces and obstacles |
| `43187a..431ac4` | Hit sparks, CRT draws, next contact and ordinary return |
| `431ac4..431b64` | ID300 body-kind transition and second whole-function return |

All calls execute their actual original bodies: `417170`, `416fb0`, `417090`,
`4061d0` and `4450d0`. Constructor memset remains a declared storage boundary.
Spark rand uses the real pinned DLL's function with retained supplied PTD state
through the declared IAT bridge. It is independent of the game's table RNG.
These mechanisms are native arithmetic/data operations in the shipping Core;
the EXE/Unicorn/DLL execution is development reference tooling only.

## Contact and storage semantics

The attacker collision Frame is frozen at entry. Each defender collision Frame
is captured before its gates. Current-frame reads later in the function remain
live: damage/reflection can change the Frame or rebind the Object. World slots
can alias the same Actor; write/read order must survive that aliasing.

`Actor+2e4` is a live signed count. Targets start at `+280`, ITR indices at
`+2d0` are sign-extended Int8. An ITR index greater than count minus one ends
the entire function. Negative indices are not automatically zero or invalid;
the resulting raw address must resolve to known storage. Positive signed vrest
skips one contact. The EB gate against type0 and effect21 against states18/19
end the whole function. Caught-owner protection skips one contact.

Ordinary ITR records copy all20 words. For kind5 on a reciprocally held weapon,
positive owner collision `wpoint.attacking` selects the weapon Object's strength
block: preserve five geometry words, copy words5..19 from
`Object+b0+80*attacking`, set copied kind0. If attacking<=0 or the defender is
that owner, the original keeps the **raw ITR pointer**. A type2 defender then
halves its dvx/dvy in place, signed toward zero. Subsequent calls observe these
raw changes. Native `OriginalMatchPreparation.frameAllocations` owns this live
heap; the original loaded catalog remains the loading-time evidence.
`OriginalContactFrameMemory` preserves allocation order, opaque addresses,
interior offsets and initialization masks; it never dereferences host pointers.

Kind4 becomes0 only with positive `Actor+320`; its x impulse may reverse based
on exact facing bytes and velocity sign. Kind9 converts to0 for a character or
defender state1002/2000; conversion against a character also zeros attacker HP.
Reciprocal heavy-weapon drops keep their original partial link cleanup and RNG.

## Damage, guard and numeric behavior

Injury is ITR word17 (`+44`); word16 (`+40`) is bdefend. Positive `Actor+340`
scales injury using wrapped Int32 multiplication by100 followed by signed
division. Guard divides the scaled amount by10. Red HP loses injury/3 toward
zero. Statistics credit the attacker's `+354` slot, which need not be active;
the defender's `+344` selects the separate two-team global counters. Type6 skips
HP/statistic damage. Weapon durability uses unscaled injury and bdefend100
forces it to -1. These operations do not saturate to an invented HP range.

Fall accumulation, hit count, the20/40/60/80 thresholds and airborne reactions
are separate from damage. Guard uses its own hitstop, rest limits and impulses.
Guard vrest truncates to one byte **before** the signed12 cap. Guard ID gates
for6/37/52 and attack-ID bypasses are source branches, not character allowlists.

Type4/6 rebounds compare the incoming dvx with abs(vx)*0.55 using the original
extended intermediate. The ID100 held-weapon exception multiplies by2.5,
queues sound13 and enforces the original small nonzero impulse thresholds.
State1002 and2000 have distinct hit/guard rebounds and RNG streams.

Finite arithmetic retains x87's64-bit significand and explicit binary64 stores
under CW037f. The `4450d0` legacy branch consumes the extended value directly;
the SSE2 branch first stores binary64. The legacy integer-indefinite/zero
shortcut precedes its truncation correction. Other FPU modes, nonfinite
arithmetic, exponent overflow and actual Windows startup CW remain open.

## Generic kinds and original exceptions

Kinds1/3 establish reciprocal catches, facing and new frames from the ITR.
Both horizontal centers come from the **attacker Object**, including the one
indexed by the defender's catching frame; vertical centers use their respective
Objects. Binary positions are split by the extended half-distance, integer x
is refreshed, integer y is not. No inferred geometric correction is applied.

Kinds2/7 implement pickup and ownership by Object type. Source IDs120/124,
type6 HP and the original signed held-type values remain separate branches.
Kind8 writes the injury-derived effect timer and relocates its source; kind6
writes the contact flag. Kind14 sets directional obstruction flags. Kinds10/11
apply1.07 damping and kind15/16 attraction, with type2's2.3 vertical acceleration
instead of3. Kind16 character damage/freezing and reciprocal heavy-item drop
retain their original ordering. Unhandled kind values follow the original no-op
dispatch; they are not remapped to a generic attack.

Type3 reflection depends on current states3005/3006, ownership and source-ID
branches. IDs8/209/213 can replace reflectable Objects by ID209; lookup scans
the actual catalog and can fail. IDs201/214 have distinct attacker deletion/HP
effects against characters. ID300 reads the current first BDY kind; only values
strictly above1000 change frame/team, and its path returns from the whole hit
function before sparks and later contacts.

Hit sparks select the higher-depth slot, with exact ties and inactive-attacker
handling. Ten slots are available. The effect1 style and fall threshold select
the sprite counter. Position arithmetic wraps at32 bits and uses current Frame
centers. Two actual CRT draws, each modulo9, affect y then x in that order.

## Item creation and World ordering

The first scan counts types1/2/4/6 as encountered, while resolving type0 hits.
Consequently earlier hit effects can affect later count/type decisions. Count>=4
skips item RNG. Otherwise RNG146/200 decides whether to proceed. The first free
slot is50..<400. If none exists, the original keeps the caller's previous
stack `+4c` value; it does **not** silently skip creation. Native requires its
retained provenance on that path. Synthetic probes supply it explicitly; full
outer-tick provenance for that rare path remains open.

Candidates are catalog ordinals with source IDs100..<200, without a type gate.
IDs122/123 each draw147/2 before mode exclusions1/2/3/4. Coordinates retain
coarse/fine RNG148..153, signed division by30 and the optional global width
override. RNG154 chooses the candidate. No candidates means the original
division faults; native must not choose ordinal0 as a fallback.

Construction uses `4061d0`, source Object durability, binary y=-500, the computed
x/z, and exact activation. It clears every active Actor's vrest for the new
slot, zeros velocities, sets ID122 HP200, refreshes integer coordinates and
assigns credit slot99. The second hit pass then scans **all** active Objects
whose type is signed-positive, including newly created later objects. No new
contact collection is inserted.

## Verification and limits

`tools/oracle_world_hits.py` declares inputs, executes the whole function and
compares full400-Actor/World storage, masks, globals, the whole raw Frame heap,
ordered game RNG/sound/CRT events and retained CRT state. Guards check pool
extents, initialized reads, readonly Object/catalog data and helper ABI returns.
The accepted [synthetic report](../evidence/world-hits.json) contains 7,845 cases,
including 150 whole-caller cases, 19,211 actual helper returns and 16,750 ordered
events. Directed controls cover aliasing, consecutive raw ITR mutations, both
item passes, full-pool scratch, guard/fall/reflection/force branches, early exits
that must not read invalid Frames, CRT spark ownership and extended arithmetic.
All 400 Actor records plus World, masks and globals are compared, along with
the 262,144-byte raw heap. This is synthetic coverage with declared Objects,
not all DAT techniques or natural match sequences.

The instruction union contains 3,745 addresses including caller/helpers;
3,204 of the 3,216 instructions in `42e100..431b64` were reached. The remaining
12 lie behind contradictory Object-type gates under this storage contract:
nine at `430028..430053` test weapon durability inside a type-0 guard path;
three at `430e63..430e74` test a kind-9 character after the earlier character
branch already converted kind 9 to 0. Object headers stay readonly. This static
explanation does not prove all branch outcomes, arbitrary aliases/storage or
continuous gameplay. Empty item-candidate division faults and full outer-tick
provenance of the retained slot still need separate evidence.

`tools/oracle_gameplay_hits.py` independently reruns both complete own startup,
menu, selection, launch, control, physics, links and contact parents on the same
CPU/stack. Its new section continues41eefb..41f2ac with no gameplay-state stimuli.
Both fresh source runs completed with 3 helpers / 2 checkpoints / 98 instructions
each and no undefined catalog reads. Before/after snapshots include all 14,586
retained Frame heap records, allocation order, bytes and masks. Native uses its
own state and live heap from the full parent chain, never the expected snapshot.
Each continuation resolves slots 0 and 1 with contact count 0, then draws game
RNG 146/200 → 64. No item is created. The heap and CRT are unchanged; game RNG
advances from index/counter 39/0 to 40/1. Both fighters retain frame 219,
HP 500 / MP 200, and the source post-physics positions. All early resources,
854 bitmaps, 101 BG records, music and the full `630e18` replay buffer survive.
The same `4246b0` has not returned: PC `41f2ac`, SP `1000e9bc`, phase 1 / tick 1.

Both native continuations report 163,328 records / 732,256,514 bytes and masks,
926 helper returns and 72 checkpoints across the retained launch/gameplay
sections and a rollback trial. Earlier startup/menu/selection parents are also
revalidated by their nested runners; their counters are not included in these
totals. The trial throws after actual item RNG and checks the unchanged public
World/pool/globals/heap/CRT. Public calls publish all storage only on success;
external observers must buffer effects until the whole tick commits.

`tools/accept_gameplay_hits.py` verified raw/parent/blob hashes and ran all three
new release XCTest before publishing fixtures: 44.422s, build 111.55s. The
synthetic comparison took 7.081s; both own chains took 37.341s. Earlier directed
native comparisons also passed without changing expected source output.

| Capture | Raw bytes | Raw SHA-256 |
| --- | ---: | --- |
| [world-hits](../evidence/world-hits.json) | 8,102,507 | `8e0fbc32f446f4f73b22e7b321a6d3d2bb1821267616c55cc26a54e8e45785a8` |
| [gameplay-hits](../evidence/gameplay-hits.json) | 9,166,150 | `3728afc3aa66956a85c4cfb10af5b9e11f71412ef9fa4bb2d0b612aa3c8cdf49` |
| [gameplay-hits-control](../evidence/gameplay-hits-control.json) | 9,177,921 | `0e29721be6be9561eeded4950298566df9682447e2d93f5f58a90b1e94cbc460` |

The reports also pin packed fixture SHA/size. Historical parent fixtures remain
unchanged; their earlier comparison stops retain their original scopes.
All 123 existing fixture hashes are unchanged; all three new packed envelopes,
full JSON payloads, blob hashes/sizes and parent hashes were independently
verified. The 126 current pins are saved in
`build/research/gameplay-hits-fixture-pins.json`.

The final packed release regression passed all 22 XCTest in 262.730s
(build 111.11s), covering Actor/World physics, World links/contacts/hits,
Gameplay control/physics/links/contacts/hits and MatchLaunch. The build also
compiled and linked `NTSDNative`; this is not an app-window or device-output
check. Python compilation and `git diff --check` passed. All source capture,
acceptance and SwiftPM processes were terminal before the milestone commit.

## Next source boundary

The next own boundary is41f2ac before `418c30`, `4187b0`, remaining links, the
second417f80, rendering/camera/scheduling/recovery and whole4246b0 return.
Static inspection establishes the next bounded caller `41f2ac..41f484`:
`418c30..419373`, `4187b0..418c2f`, an ascending 400-slot held-owner cleanup,
then another complete `417f80`. The first helper retains ECX for the second
call; the caller does not reload the World receiver between them.

`418c30` starts from collision Frame `+7c`, while `4187b0` requires current
Frame `+70` cpoint kind 1 / state 9. These cannot be collapsed into one snapshot.
At `418c4e`, the first helper reads its entry stack pointer minus 4 into ESI;
valid reciprocal-link branches later replace it. An invalid-link branch can
still reach a nonzero throw using that retained slot. The next study must keep
both this caller storage provenance and ESI's lifetime across the 400 slots.
It must not silently choose the current `Actor+8c` when reciprocity fails.
The following cleanup clears only owner `+98` when a positive held link has an
invalid signed slot, inactive target or nonreciprocal target `+a0`. These are
source observations, not an accepted native cpoint implementation.

The first complete Naruto/Sasuke District match, application UI, Windows runs,
clean-Mac validation and the full-game goal remain open.
