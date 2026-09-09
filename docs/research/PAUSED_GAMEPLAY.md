# Own pause, single-step and resume

`OriginalLoadedGameplayCall` now continues its own paused round through direct
background drawing, World drawing, HUD, the PAUSE bitmap and common output to
the dispatcher return. Both fresh initialized variants match fourteen new
calls after the complete sixteen-call neutral parent: eight paused calls and
six transition, single-step or resumed calls. F1/F2 acquisition drives the
original pause latches; no pause flags or caller stack values are injected.

Each complete native comparison reports 3,000,280 records, 9,685,070,146 bytes
and masks, and 651 state checkpoints, including the accepted parent and rollback
checks. The new calls match 14,337/15,121 ordered native events and 3,490/3,602
source body/output helper returns. All 20,368 source FPU checkpoints retain
CW023f, with the complete 15,102-checkpoint parent reproduced. Raw native
acceptance passed in 72.131s/build173.90s. Final packaged verification passed
both release tests in 72.523s/build167.30s without the raw-fixture override.

The predecessors are [PAUSED_HUD](PAUSED_HUD.md), which compares the whole HUD
callee without the unpaused caller's command resets, and
[CONTINUOUS_GAMEPLAY_CAPTURE](CONTINUOUS_GAMEPLAY_CAPTURE.md). This own pause
join does not establish every paused branch, enabled playback startup, a full
match or the application's timed outer loop and devices.

## Compatibility purpose and reference

Recover the original input-driven pause, single-step and resume behavior for
the native macOS game. Research executes the pinned NTSD2.4 EXE and VC80 on the
same retained Unicorn2.1.4 CPU as the complete initialized startup, menu,
catalog, character selection, first gameplay return and sixteen neutral loaded
calls. The EXE SHA256 is
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.
The CRT identity remains the accepted parent's pinned DLL hash. Original match
precision is CW023f. Source EXE/DLL execution belongs only to development tools.

Only acquired F1/F2 keyboard bytes are supplied. The source continues its own
World, Actor pool, catalog, resources, recording, RNG and stack. The native
comparison independently reconstructs that parent and applies the same declared
keyboard changes; expected snapshots are assertions, never initial game state.
The established outer caller ABI and COM/GDI responses remain declared
boundaries. Saved registers, SEH restoration and cookies are source-side
execution checks; they do not establish a native Windows ABI or exception model.
This work does not execute the timed outer loop or verify an app
window, actual Windows output, hardware devices or a complete match.

## Required whole paused body

The [pinned-byte static inspection](../evidence/paused-gameplay-static.json)
identifies the paused caller at41d73b. It sets44d02c to1, calls background41a250
directly without the camera bounds pass, then draws the World using live phase
and mode. Background animation and any drawing-owned state updates retain the
original algorithms. HUD41ae60 preserves450bb8/450bc0. The PAUSE bitmap44ff8c
uses x360/y288, picture-1, key1 and destination455608.

The non-playback path joins common output422994. Enabled playback pushes the
own retained target and joins422952 before the recording indicator and optional
playback-information consumer. Native composition uses the existing result
layout dependency with that explicit target. This own capture exercises the
non-playback parent; it does not establish the whole playback prologue or all
enabled paused branches.

`OriginalLoadedGameplayCall.run` joins the own input/round continuation to
`OriginalPausedGameplay.apply`. The latter stages background, World drawing,
HUD, PAUSE bitmap, indicator and common output. The loaded call commits World,
Actors, resources, input/replay storage, CRT state and optional caller storage
after dispatcher output succeeds. External device events must remain buffered
until commit. Missing backing and unsupported children remain explicit errors.

## Capture and comparison contract

The fourteen-call sequence acquires F1, releases it, acquires F2 while
paused, releases it, then acquires F1 to resume and releases it. The original
phase and cached-pause timing determine each call's continuation. Both source variants execute eight paused and six transition, single-step or
resumed calls. Replay and elapsed counters remain19 through the first pause,
advance to21 for the two single-step phases, remain21 through the second pause,
and reach23 after resume.

Each completed source call receives an atomic, hash-verified checkpoint. The
comparison checks every input phase, full returned storage and masks, allocated
Frame heap at return, ordered drawing and output events, own stage result,
actual gameplay and dispatcher returns, register/stack restoration and the
complete parent FPU prefix. Paused local input skips its helper and pre-dispatch checkpoint; the other
five input checkpoints still compare. Five paused rendering checkpoints
precede common output. Global write replay independently verifies the final global bytes.
Native-only late observer failures on the first unpaused and first paused calls test whole
transaction rollback after input and output effects have already been staged.

Whole Object storage at every new return is outside this study's inherited
snapshot contract; the accepted catalog baseline and complete Frame allocation
heap remain separate from active-input work. Decoded block starts and broad
original-address inventories do not establish per-instruction execution.

## Work and failed attempts

The first new source attempt stopped in character selection because the pause
harness named its keyboard method `acquire`, overriding an inherited method
that takes tuples. Both processes exited before the pause sequence. Their logs,
producer hash and work metadata are preserved in
`build/research/paused-gameplay-attempt1/manifest.json`. The method was renamed
before fresh captures. Only missing FPU hooks are added for the new paused
points; common422994 already has an observer from the retained parent.
No accepted fixture, expected state or native game rule was changed.

Native core compilation passed in 58.42s. An initial reference build encountered
concurrent active-input edits, so validation uses a native-only export of
commit5a0916a with 492 committed files independently verified before applying
the paused changes. The isolated reference target compiled in 133.67s. A later
test build reused release modules without testing enabled and failed; the
failure is preserved and the corrected build enables testing explicitly.
The corrected test bundle build passed in 173.26s. These are compilation
observations, not new source/native match evidence.

Both fresh source runs then completed. Independent verification checks each
whole parent, all component/blob hashes, every original global write, saved
register/stack restoration and20,368 FPU checkpoints per variant. The raw
captures are14,074,938 and14,300,406 bytes. Each records12,811 relevant stack
accesses and921 actual paused-body/helper instruction starts, excluding the
stopped422994 and COM boundary. The first native attempt failed during fixture
decoding because the reused menu-local type required a helper call and
pre-dispatch snapshot. Original paused input skips both. The pause-specific
reference now models these as optional and expects five paused input
checkpoints; unpaused input retains six. The two failed tests took 3.661s and
are preserved in `build/research/paused-gameplay-raw-attempt1`. Source captures
and the native game implementation were unchanged by this correction.

The corrected raw comparison passed both release tests in 72.131s after a
173.90s build. It also repeats the accepted sixteen neutral calls, the complete
initialized parent and the nineteen-checkpoint unpaused body in each variant.
Late whole-call rollback passes on the first unpaused and first paused call.
The native pause algorithm required no correction after source comparison.

Current process identities, owned files and validation package provenance are
in `build/research/paused-gameplay-work.json`. Live captures must be revalidated
before any restart; silence alone does not indicate failure.

Implementation: [OriginalPausedGameplay.swift](../../native/Sources/NTSDCore/OriginalPausedGameplay.swift),
[OriginalLoadedGameplayCall.swift](../../native/Sources/NTSDCore/OriginalLoadedGameplayCall.swift).
Source: [oracle_paused_gameplay.py](../../tools/oracle_paused_gameplay.py).
Comparison: [PausedGameplayReference.swift](../../native/Sources/NTSDReferenceChecks/PausedGameplayReference.swift),
[OriginalPausedGameplayTests.swift](../../native/Tests/NTSDCoreTests/OriginalPausedGameplayTests.swift).
Verification: [verify_paused_gameplay_source.py](../../tools/verify_paused_gameplay_source.py),
[accept_paused_gameplay.py](../../tools/accept_paused_gameplay.py),
[verify_paused_gameplay_artifacts.py](../../tools/verify_paused_gameplay_artifacts.py).

## Source and artifact details

The source executes921 actual paused-body/helper instruction starts across
both variants; this is not every branch outcome. The common output stop and
COM boundary are excluded. The eight paused rendering bodies have512/576
complete helper returns and1,872/2,320 events:200 draws,1,144/1,464 reads,
200/264 clips,264/328 Blts and64 rectangles. All320/576 deliberately undefined
read events retain their original bytes and masks under the inherited backing
contract. Different wrapper backing explains the variants; actual Windows
allocation provenance remains separate.

Each new unpaused call adds843 FPU checkpoints; each paused call adds26.
There are12,811 relevant stack accesses in each fourteen-call sequence. The
own paused target supplies the indicator join, while stageDefeated remains
unknown and unread on pause. Caller formatting backing remains nil. Own pause
uses no background fill, playback indicator or playback-information path.
The six unpaused recording packets are neutral; this sequence does not prove
rollback after a changed replay payload. Sound queues retain their own state
and the enabled output drain still executes, without newly queued sounds in
these pause calls.

Both raw byte sequences and complete decoded JSON reproduce independently from
the lossless fixtures. Primary raw/packed sizes are14,074,938/2,064,088 bytes;
control sizes are14,300,406/2,062,640. All2,861/2,862 inner blobs and107 components
per variant pass length and SHA checks. All192 prepublication fixture pins
remain unchanged, including the concurrently accepted timer fixture;194 are
current after publication. The10 replay codec vendor hashes are unchanged.
Fixture compression is transport only and does not replace native game output.

Reports: [primary](../evidence/paused-gameplay.json),
[control](../evidence/paused-gameplay-control.json). Independent verification is
recorded in `build/research/paused-gameplay-artifact-verification.json`.

All owned source and SwiftPM processes are terminal. NTSDNative linked, but no
application window was tested. Python compilation, 435 local Markdown links and
owned-file diff checks pass. Six owned implementation/test/fixture files in the
stable validation package match their workspace counterparts exactly. The two
shared reference files use the compiled pause-only integration; concurrent
active-input edits remain in the shared working tree and are excluded from
this milestone's commit. The original 492-file export provenance and all failed
attempts remain in the work metadata. Full enabled pause/playback domains,
other loaded continuations, actual Windows/files/devices, timed app integration
and the complete-match/full-game goal remain open.
