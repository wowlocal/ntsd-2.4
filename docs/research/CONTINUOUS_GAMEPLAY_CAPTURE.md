# Successive loaded gameplay calls on retained own state

Both initialized variants now match sixteen successive native loaded calls.
The raw release comparison passed61.109s after a163.45s build. Two lossless
fixtures are published; all188 previous pins are unchanged. Final packaged
verification passed61.572s/build173.90s in an isolated snapshot of the accepted
body commit, excluding concurrent paused-HUD edits. Process handles and results
are tracked in `build/research/continuous-gameplay-work.json`.

The game behavior under study is repeated entry into the loaded match after
its first actual return: input phase, command/replay handling, round entry,
ordered simulation, rendering, sound queues and both normal returns. Both
fresh chains use the pinned original NTSD2.4 EXE and VC80 dependency under
Unicorn2.1.4. They reproduce the complete accepted
[GAMEPLAY_RETURN](GAMEPLAY_RETURN.md) parent before continuing on that CPU.
The EXE SHA256 is
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`;
the VC80 SHA256 is
`c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d`.
COM/GDI responses and the established enclosing caller ABI are declared
research boundaries. EXE/DLL execution remains development tooling.

The finite acceptance target is sixteen successive4246b0 calls per initialized
variant. Original keyboard storage remains the300 bytes of117 written by the
actual launch reset. No key stimulus, game-state replacement, forced phase,
RNG reset, sound replenishment or expected stack word is supplied. The capture
stops before an unrecovered actual AI/object-input child can reach an older
controlled adapter. A failed or partial call is retained as such, never as a
successful native return.

The calls alternate phase0/1. The actual replay tick450b8c and elapsed counter
450bbc advance2..17, while recording flag450b80 remains1. The source progress
log mistakenly labels that flag as `tick`; the immutable log and capture tool
are retained, and independent verification reads the correct counter. Early
analysis repeated that label before the replay implementation and complete
state exposed it. No source snapshot or expected byte was changed.

The real outer43e9a0 loop and its clock pacing remain a necessary separate
join. Neutral keyboard memory does not prove keyboard-device acquisition,
input latency, wall-clock animation cadence, audio timing or a complete match.

## State and low-level observations

Memory snapshots establish ownership and alias continuity; original writes
reconstruct the complete globals independently. Each whole-call return retains
complete World/Actor bytes and masks, allocated Frame heap, backgrounds, menu and
catalog bitmaps, music, replay allocations and liveness. Eighteen intermediate
body boundaries retain the same state except the complete Frame heap array;
that array is compared at whole-call returns. Object headers and inline frame
tables retain the accepted catalog baseline; this continuation does not add
a fresh complete byte snapshot of those packed catalog tables at every return.
Intermediate snapshots therefore
do not claim a full heap observation at every stage.

The `continuous-gameplay-components-v1` format hashes and deduplicates whole
JSON snapshot fields. Every array element and every byte/mask reference is
retained. Canonical component JSON and every raw-deflate binary blob have their
own SHA256. This is lossless research transport, unrelated to the game's
private replay compression algorithm. Partial files are atomically replaced
only after completed calls; their proof records include call count and hash.

Read/write observations cover actual root34..73 and root44c..5c3 backing.
They recover scratch and formatter lifetimes without copying those bytes into
native state. Original saved registers, stack movement, SEH restoration and
normal cookie checks establish the two actual return frames. No protection
structure is corrupted. The broad late code-hook inventory is labelled
observed original addresses: inherited boundary hooks and stopped addresses
are not per-instruction execution evidence. The output helper instruction
inventory retains its stronger, separately checked execution contract.

The inherited initialized FPU history is reproduced in full and extended by
new call/stage observations. Native arithmetic remains explicitly53-bit;
source observations are not Windows/host hardware FPU measurements. Bitmap
Blt responses alternate0/1 within each observed rendering stage, as in the
accepted helper adapters. Sound remains enabled and uses owned loaded buffers.

## Native transaction and acceptance

[OriginalLoadedGameplayCall.swift](../../native/Sources/NTSDCore/OriginalLoadedGameplayCall.swift)
composes actual native input/round entry and
[OriginalGameplayBody](GAMEPLAY_BODY.md) under one transaction. It commits
World, actors, owned resources/replay memory, CRT RNG and caller storage only
after output and the dispatcher's held-input clear. Its operation receives
platform responses and resource resolvers, never expected snapshots. The
reference starts from independently reconstructed native parent state and
carries each returned native state into the next call.

Menu, paused rendering and early epilogue continuations are explicit unsupported
boundaries of this gameplay entry, with rollback. It is not the complete
loaded-call dispatcher. Call-local scratch starts unknown on each new frame;
this study must not infer cross-frame provenance from reused addresses. Device
and file effects require buffering until commit, since storage rollback cannot
undo a request already sent to a device.

Acceptance requires exact complete return snapshots and masks, ordered events,
all declared intermediate state, parent identities, source FPU/frame evidence,
and a late native failure after the whole first new call. That failure must
also undo its preceding input/round changes. Raw comparisons precede fixture
publication; packed comparisons follow it. All188 accepted fixture pins remain
immutable. The full match, native application engine integration, real outer
loop, Windows/device comparisons and clean-macOS goal remain open.

## Compared sequence and retained evidence

| Observation | Primary | Control |
| --- | ---: | ---: |
| Successive complete calls |16|16|
| Compared records, including parent and rollback/body trials |2050892|2050892|
| Compared bytes and masks, including those comparisons |6526992869|6526992869|
| State checkpoints in the joined reference |442|442|
| New ordered native events |16400|17296|
| New body/output helper returns |4400|4528|
| Complete source FPU checkpoints |15102|15102|
| Source stack accesses |33960|33960|
| Observed original-address inventory |3983|3991|
| Complete JSON components |205|205|
| Binary byte/mask blobs |2955|2956|

The helper counts above exclude input-prefix helpers; each complete prior
chain still checks703/711 helpers. The event totals include16 item RNG events
and64 input/replay/round events in addition to16320/17216 captured graphics,
diagnostic and output events. First-body comparison is also retained across
all19 stages and1012/1068 events. Low-level source evidence and native event
comparison keep their separate observation boundaries.

The native reference checks the prologue plus six input boundaries, then19
body boundaries. Full return snapshots carry owned native state into the next
call. The allocation/mask inventory retains14586 Frame allocations and the
accepted loaded resources. All16 source returns restore both actual frames;
all new843-per-call FPU checkpoints preserve CW023f and the entire1614 parent
history. Parent control-word transitions and watched-instruction bytes match.

Naruto and Sasuke start in frame219. The second new call moves both to frame0;
by the last they occupy frames3 and2 respectively, previous frames agree and
wait counters are2. Both retain500HP and reach205MP. The actual replay tick and
elapsed counters are17. There are16 writePacket events per variant; neutral
packets overwrite already-zero bytes, so full recording bytes and liveness
remain unchanged. The late rollback proves complete call storage atomicity
on this path, not rollback after every possible changed replay payload.

Only41d7d7 writes root64 in each new call; result/indicator paths do not read
that word. Native retains its own round result. Camera reads the target written
by the actual prologue to root68; the HUD caller passes it but the HUD callee
still does not consume the argument. Six lifecycle scratch words and command
spawn storage are not read by their respective consumers on these paths.
Formatter writes at root48c come from actual diagnostic sprintf; Native keeps
its unavailable caller backing nil and compares diagnostic output separately.
The33,960 stack observations also contain other earlier users of reused words;
identical offsets do not justify importing or retaining unrelated lifetimes.

Enabled sound drains all16 times per variant. No new queue is replenished on
this neutral series, so those drains have no play requests; this is distinct
from the actual play in the accepted parent. Each output still performs the
mode label, recording notice, original presentation and dispatcher clear in
order. Recording notice timer and repeated truncation writes remain live.

Independent checks verify both entire raw byte sequences, packed restoration,
complete JSON, all410 component hashes,5911 binary blobs and10 vendored codec
hashes. Primary raw/packed sizes are19682761/3072348; control sizes are
19871067/2759528. The source capture tool and logs are retained unchanged,
including the documented progress-label error. Source, native and expected
game rules required no adjustment for the first raw comparisons. Only reference
coverage and metadata assertions were extended during preparation.

The two reports are [primary](../evidence/continuous-gameplay.json) and
[control](../evidence/continuous-gameplay-control.json). The next finite work
is bounded directional/attack/guard/jump input and paused/menu continuation
composition, followed by the original timed outer loop and application engine
join. Neither this neutral sequence nor native linking completes a match or
the full original-game/macOS goal.

The final packaged tests use an export of only `native/` from f98c5ab plus the
scoped new implementation, reference, tests and two fixtures. Every copied
file hash agrees with the main workspace; the prior HUD source is unchanged
in that export. An initial full worktree checkout was cancelled during unrelated
historical LFS archive downloads, before it reached any build. Its process group
terminated and the incomplete worktree was removed by Git. No source capture or
build was restarted for silence. The successful native-only export requires no
raw overrides and links NTSDNative. No new app window/device run was performed.
All owned source/build/test jobs are terminal; concurrent paused-HUD work is
separate. Python compilation,113 local navigation/document links and scoped diff
checks pass. See [native verification](../evidence/continuous-gameplay-native.json).
