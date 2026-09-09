# Native composition of the unpaused gameplay body

Both initialized variants now match `OriginalGameplayBody.apply` across all19
semantic checkpoints and1012/1068 ordered events. It joins the native stages from
the own round's `.gameplay` continuation through output and the enclosing
dispatcher's held-input clear. One transaction owns World, Actors, mutable
Frame allocations, backgrounds, globals, replay ownership, saved playback,
CRT RNG and the supplied caller storage. This is the body of an already
entered call; input/round entry and paused/menu alternatives remain separate.

The implementation is in
[OriginalGameplayBody.swift](../../native/Sources/NTSDCore/OriginalGameplayBody.swift).
It adds composition and atomicity, without changing a child algorithm or using
source EXE/DLL code in the native operation. The full loaded call, repeated
gameplay, application integration and full game goal remain open under
[CONTINUOUS_GAMEPLAY_PLAN](CONTINUOUS_GAMEPLAY_PLAN.md).

## Native order and failure behavior

Control, physics, first links, contacts and the complete hit/item caller precede
cpoint actions, placement, cleanup and second links. Camera/background drawing
and object drawing precede diagnostics/impulses. Each live slot then completes
the entire post-draw lifecycle before the next slot. Commands, HUD, notices,
result recording, result layout and output follow in their original order.
The public operation exposes19 semantic checkpoints for comparison.

The recorder's own continuation feeds the result layout directly. Its
`stageDefeated` input comes from the actual preceding native round result.
Drawing phase and mode come from live native globals. Mode-label rendering,
notice/volume, presentation and enabled sound stay in the accepted output
composition, followed by457580's dispatcher clear. No expected continuation,
after-state or stack word selects a game path.

Each child continues to stage its own changes. The new outer transaction
commits only after the final output checkpoint; a later failure discards
earlier simulation changes too. Device and file observers still require
buffering until the enclosing loaded call commits. Native storage rollback
does not undo a request already submitted to a device.

## Caller and resource limits

The operation shares a known root44c..5bf formatter record between diagnostics,
notices and results. Own diagnostic bytes at root48c update that record when
backing is available; notices use its root46c suffix. Nil backing remains nil,
and an enabled child which needs unavailable storage explicitly fails. The
initialized comparison uses nil and does not establish the enabled formatter
domain or original stack bytes outside the observed writes.

The indicator target remains an optional, separately justified caller input.
The first own path does not consume it. Camera's target is the declared caller
surface, while HUD and other helpers retain their original global destination
rules. Catalog ordinals and opaque resource tokens use separate resolvers;
the comparison adapter checks their independently rebuilt owners.

Incoming full-pool item root4c, cpoint partner, lifecycle scratch and command
root34 lifetimes are not inferred from identical offsets or previous calls.
Their unrecovered entry values remain unknown. Native producers within the
live lifecycle and command loops retain values for their demonstrated lifetime;
a child fails when it actually needs a still-unknown value. The first own
path leaves the six lifecycle words and command root34 unaccessed. This
composition does not claim the other branches' missing stack provenance.

Mode1/4 post-draw children remain explicit errors in the existing impulses
API. A `.pausedRendering`, `.menu` or `.epilogue` round result is rejected by
this gameplay-only entry, not reported as a returned gameplay body. These
continuations must be composed by the full loaded-call dispatcher. The
[runtime audit](LOADED_TICK_PLAN.md) records the broader ownership requirements.

## Acceptance contract

[GameplayBodyReference](../../native/Sources/NTSDReferenceChecks/GameplayBodyReference.swift)
starts from the independently reconstructed native round state, then executes
the public body without importing source snapshots. The accepted source
sections from [GAMEPLAY_RETURN](GAMEPLAY_RETURN.md) and its complete parent
chain supply assertions and declared platform responses. Both existing
initialized variants are retained; no source capture or fixture is changed.
Their reference is the pinned NTSD2.4 EXE/VC80 on one Unicorn2.1.4 CPU with
explicit53-bit arithmetic, as documented by the parent study.

Every semantic checkpoint compares complete World/Actor/Frame/background/global
records and masks, native replay/resource ownership and CRT state. Ordered
render events are normalized only for declared catalog/resource identities.
Item RNG, diagnostic text, lifecycle sounds and final output are compared in
their stage order. The enclosing original reference chain also runs unchanged,
including all1614 source FPU checkpoints and actual normal returns.

A separate trial throws on the final dispatcher-write event after the entire
body's graphics and sound requests. Full native storage must still match its
pre-body snapshot. This first path changes simulation/globals but leaves replay
and CRT storage unchanged; it does not demonstrate rollback after every possible
writer or CRT mutation. The first body's unknown caller fields must remain nil.

Acceptance status and process handles are recorded in
`build/research/loaded-gameplay-composition-work.json`. The new tests are
[OriginalGameplayBodyTests](../../native/Tests/NTSDCoreTests/OriginalGameplayBodyTests.swift).
Both packaged release tests passed44.737s after a175.44s build, including both
complete parent/reference chains and the late whole-body rollback trials.
The preceding core-only release build passed61.57s. There was no compiler or
comparison failure in these runs. All188 existing fixture hashes are unchanged;
this composition adds no new source fixture or dynamic instruction claim.
The final comparison also pins the source stage stops and checks every event
against its current source stage, independently of the production enum order.
Both cases passed again45.395s/build70.81s. The retained default return API's two
packaged tests passed42.617s using the preceding built test bundle; their
577173records/912855320bytes+masks,703/711helpers,67state and1614FPU counts are
unchanged. All body build/test jobs are terminal. See the
[native verification record](../evidence/gameplay-body-native.json) for source,
fixture/vendor and log hashes. Local Markdown links and owned-file diff checks
pass. The separately running16-call source captures belong to the next study.
Native linking and reference tests are separate from an application-window,
Windows, pixel, audio or latency comparison.
