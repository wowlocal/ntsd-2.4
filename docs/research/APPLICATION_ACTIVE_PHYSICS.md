# Active physics on current owned control output

Status: finite physics endpoints and current owners verified. This extends [the active body plan](APPLICATION_ACTIVE_BODY_PLAN.md)
and follows [finite active control acceptance](APPLICATION_ACTIVE_BODY_CONTROL.md).
The [physics plan](APPLICATION_ACTIVE_PHYSICS_PLAN.md) fixes both48-call schedules,
owners, required comparisons, limits and independent review.

## Calculation and composition

The test reads the actual control snapshot from the same Bootstrap invocation,
after the accepted control comparison. It computes physics in separate test
storage and compares the following complete physics snapshot. Expected values
never become application input. Current positions, velocities and resources are
used; a saved source delta cannot describe a different own trajectory.

The finite equations preserve x/z obstruction predicates, flag clearing, friction
using the OLD integer y, sequential positive/negative friction branches, stored
y+=vy, binary64 gravity1.7, coordinate truncation and clearing Actor+320. Negative
friction compares its intermediate against positive epsilon. Arithmetic is
limited to the accepted zero/normal53-bit domain, far from exponent/Int32
boundaries; this does not replace the general extended-exponent Core contract.

Only two distinct live type0 fighters occur in these physics passes, with states
0/1/3/4/7. There is no physics Frame transition or primitive effect in the saved
schedules. Sasuke is airborne on calls42..48. The final Frame and reversion ID
are reread for caller predicates. Landing, death, spawn and reversion effects
remain unaccepted here; the unchanged Core supports their previously recovered
contracts. Later transient Actor creation/deletion belongs to its actual stage.

The independent saved-data formula first reproduces every whole physics pool and
mask, including World and398 retained inactive Actor allocations, and complete
globals/recording/resource references. It validates definedness on each actual
operand read. Swift independently compares all saved Actor return checkpoints
at41e657 and the40e490 helper identity/stack/return/Object-result joins. Full
helper ABI and instruction-store equivalence are not claimed. The formula's
writes, including idempotent writes, are not an observed source store trace.

At each own physics endpoint, full match bytes/masks, current Actor allocations,
Object/Frame/BG owners, globals, music/graphics/library/CRT state, caller journal
and local record are compared from the current control predecessor. Whole input/
body preflight, rollback/retry and control comparisons remain required parents.

## Boundaries

Source physics stages omit middle Object/Frame heap snapshots; acquired immutable
records supply the reference inputs, not an interior-write proof. No unknown
constructor backing, expected after-state or source lifetime is imported.
The bounded coordinate domain makes legacy/SSE2 truncation agree; the actual
Windows conversion flag and device behavior are not established by that fact.

Control plus physics is not the complete active tick. The remaining17 stages,
later transient lifetime, damaging outcomes, paused paths, full round/match/game,
app integration and device/Windows/clean-Mac acceptance stay open. Existing safety
incidents are unchanged. No original code, emulator or historical capture/auditor
was executed by this card. EXE envelope estimates were not recalculated.

## Validation and preservation

Four release methods passed in148.355s/build356.77s. The new methods
reproduced192 source Actor checkpoints and96 full physics endpoints, then compared
96 own physics snapshots with no primitive effects. Eight negative trials reject
unknown velocity, live alias, unmodeled reversion and landing. Accepted control
methods were rerun; the same48-call schedules repeat, adding no distinct cases.
147 inherited methods remain exact and were not rerun (151 unique retained with
the four selected here).

All997 Native files,383 fixtures/102 resources and485 package files were checked
against frozen inputs.993 prior Native files are unchanged. Both Native and
evidence archives were read back, separately from the five publication files.
Independent contract, candidate and final publication review are linked from
the evidence. No new runtime handler or source expected value was changed. The task's evidence is retained in
`build/research/application-owned-active-physics-native-20260914/` on verified X5.
Core, source fixtures/resources and historical evidence remain unchanged.

A separate saved-data inventory prepares the next seven contact/cpoint stages:
per backing, depth/attachments changes five calls, contacts29 calls, hits/items
has48 RNG events, and the four cpoint endpoints do not change. These are only
record differences and do not prove the rules or Native equivalence. The
unaccepted inventory is retained separately in the task area for continuation.

[Machine evidence](../evidence/application-active-physics.json) retains commands,
terminal jobs, exact file/archive hashes, reviews and open gates.
