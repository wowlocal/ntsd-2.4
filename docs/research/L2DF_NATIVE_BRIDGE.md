# L2DF native bridge: owned storage foundation

Status: accepted within the owned Actor storage/C ABI foundation, 2026-09-12.
This stage does not initialize a match or execute a gameplay tick. The bridge
author owns `prototypes/l2df/native_bridge/`; root owns acceptance and commits.

The full-game goal needs the accepted general Actor/World implementations while
retaining their precision, storage and caller ordering. The chosen next consumer
is `OriginalLoadedGameplayCall`; constructing its catalog, globals, input context
and platform resources is a later stage. No missing startup provenance is filled
with zero or reference after-state to make that consumer appear ready.

Constructor dependency: [STATE_LAYOUT](STATE_LAYOUT.md),
[BOOTSTRAP](BOOTSTRAP.md), history 3099–3118. The existing 16-case constructor
comparison is retained; this wrapper does not claim a new original execution.
`OriginalStateRecord.swift` actual source SHA-256 is
`bccf50f3ca9f57fa18a8b4eb8bc9630ff47ff7bbfaa2687f63019ef23e51b49b`.

## Inputs and allowed operations

Read-only source is main `/Users/michael/Developer/ntsd-2.4` at `ab0db06c`, with
every actual file of `native/Sources/NTSDCore` and `NTSDReplayCodec` checked against
that revision and pinned by SHA-256 before building. Copies are byte-identical;
only a new isolated Swift package manifest and adapter target are added. The
worktree HEAD omits subsequent accepted changes and is not a source substitute.

`OriginalStateRecord.actor(over:)` is the existing public constructor. It copies
0x420 bytes of declared allocator backing, marks only original constructor writes
defined, and preserves unknown bytes as unknown. This is an unbound Actor record,
not a fighter spawn. The wrapper accepts no expected state, reference fixture,
World/global snapshot, original address or binary executable. This stage executes
only newly compiled Swift and the existing native LÖVE runtime; no original EXE,
DLL, captures, hooks or emulation are involved.

## API and ownership

ABI version 1 uses C fixed-width integers, caller-owned buffers and opaque UInt64
registry handles. IDs are never reused within the process; destroyed/invalid IDs
are rejected without dereferencing caller-provided object pointers. A lock guards
registry and session operations. A caller must supply valid C buffers of the
advertised length; arbitrary invalid host pointers are outside a C ABI contract.

Successful create reports `ACTOR_STORAGE`, with revision zero. No World, catalog,
input/RNG, presentation or match state exists; there is no tick symbol or tick
stub in the ABI. Snapshot returns bytes and explicit defined masks; typed reads
reject undefined bytes. `setup_apply_i32` is an explicitly named developer/setup
primitive, not a gameplay action: it can change only already
defined, aligned constructor words. A batch stages all writes and increments the
revision once only on success; any invalid/unknown access leaves bytes, masks and
revision unchanged. Empty batches are rejected. Destroy removes the owner.

Limits: 64 live sessions, 64 edits per batch, 1056-byte Actor backing/snapshot.
Error codes distinguish version, invalid argument/handle, bounds, provenance
and limits; errors do not escape Swift through C. No tick-success stub,
startup defaults or host pointer encoding is introduced.

## Finite verification and resources

One new isolated arm64/native-host build, 300 seconds and 2 GiB of build output;
one native LÖVE LuaJIT FFI test, at most 90 seconds. Before each operation verify
X5 APFS UUID `3A4F5FA6-DC86-4C6E-87E2-EAC2C2D72548`, mounted path, task symlink and
6 GiB reserve. New artifacts live under
`build/l2df-prototype/native-bridge-20260912/`; old apps/builds/captures remain
immutable. Each run gets a unique job directory, pinned inputs, command, PID,
start/cwd, output and terminal outcome. On a new error diagnose before another
run; no automatic retry. A size/time limit ends only the owned process group.

FFI cases: ABI/capabilities and lifecycle, wrong version/length/null input,
distinct simultaneous owners, caller-buffer mutation after create, constructor
defined/undefined reads, successful edit persistence, two-entry rollback after a
valid first write followed by undefined/out-of-bounds access, short output buffer
preservation, absence of gameplay capability, destroy/double-destroy/stale handles, registry
limit and release. Compare complete bytes, masks and revision for rollback.
The test is headless native LÖVE, not a physical keyboard/window/audio check.

Source/package pins and linked artifact inspection are separate from the FFI
assertions. Existing original comparisons are not rerun: Core/codec bytes remain
unchanged, and this wrapper adds no game rules. Parent's independent code/ABI and
artifact review remains a separate acceptance gate. Build success is not game
readiness, portable-package acceptance or clean-Mac acceptance.

## Commands and result

Build `foundation-01` returned normally in 80.91 seconds (Swift reports 79.94s);
artifacts at that point occupied 92,647,005 bytes. The dylib is arm64, 6,330,776 bytes,
SHA-256 `9a3cdc161f9ce4fe83c5d597cc40a228bf54d413054d55ee23d60d6390e6310b`.
The build has one existing Core compiler warning; immutable Core was not
edited to silence it. Host: macOS 26.6.2/25G83, Apple Swift 6.3.3.

Before the first FFI execution, independent reviewer `l2df_reference_review`
identified that the initial Lua test trusted the returned mask when selecting
unknown bytes. The strengthened test now writes whole actual constructor records
for both declared backing patterns; a Python comparator reuses the accepted
`check_actor_input.py:constructor` projection and compares all 1056 bytes and 1056
mask bytes, including 913 defined bytes. Expected values remain outside LÖVE and
the dylib. Additional checks cover partially defined word 0x80, signed Int32 limits
and both committed edits. Actual compiled package files and manifest are checked
against their frozen copies before and after FFI. Build inputs were not changed
while its job was live, and the existing dylib was not rebuilt. The old test and
plan remain in `foundation-01/wrapper-inputs/` and `foundation-01/plan.md`.

The public C header is the ABI contract. Initial architecture
is host arm64; x86_64/universal packaging and a loaded gameplay session are later
explicit stages. The next mandatory consumer is an owned initialized catalog and
session continued into `OriginalLoadedGameplayCall`. New ABI capabilities will
operate on the existing Swift owner; Lua will not reconstruct state per tick.
This storage editor is infrastructure, not the intended game interface.

`foundation-01/ffi/ffi-01` returned normally in 1.00s: 201 ABI assertions and two
independent complete constructor comparisons passed. Each compares 1056 bytes,
1056 mask bytes, 913 defined/143 unknown. The retained constructor projector SHA
is `bb4b6cc619c54f9ef7e1fe36091efdc1991eeb3ab3efac7e29d397b062ebac7c`.
All 185 actual package files and manifest matched frozen inputs before and after
the FFI run. `verification.json` and complete actual byte/mask files are retained;
`result.json` SHA is
`ad41b91607d12330fa2d64e47bd4d61a9a4d2a78ef18148dc1bf47d10840efa1`.
Runtime reports LÖVE 11.5.0 and LuaJIT arm64. No graphics/audio/device operations
were enabled. Nine C ABI symbols are exported; `ntsd_bridge_tick` is absent.

The dylib links only system/Swift frameworks. `codesign --verify --strict`
passed for its linker-generated ad-hoc signature; it has no TeamIdentifier or
release-signing claim. Existing app bundles and runtime remain unchanged.

Commands are in [native_bridge/README](../../prototypes/l2df/native_bridge/README.md).
Both owned jobs are terminal: build PID 99905/2026-09-12T09:33:01Z,
FFI PID 1225/2026-09-12T09:37:10Z, both exit 0. No build or FFI retry was needed.
Independent reviewer acceptance is recorded separately by the parent; author
checks and a process exit code are not substituted for that review.

## Independent acceptance and continuation

`l2df_reference_review` completed a read-only review of the final ABI, full
constructor comparator and package verification; no foundation blockers remain.
The reviewed FFI checker SHA is
`94f2b9ebe79ae4ba335b192d650e49721612ad04cd13bf34edcfb67b88fcfbac`, Lua test
`5e1cb02c006a3ff8a3dd2840baf984933fe52435a8945d84ebb0012c0c6bb8b8`, build helper
`eb2a1f414201da766e9d1678579fb74a89f7bbeb247e70e8a9ae3f5b45968ab9`.
The independent review rechecked all 185 compiled files and all nine FFI pins,
including copies. It did not rerun the original, build or FFI process.

Root's separate `foundation-01/root-audit-01.json` verifies 184 main Git files,
191 frozen copies, the exact 185 compiled inputs, nine FFI input pins, both full
constructor outputs and masks, nine C exports, system dependencies and signature.
The original build script/test/plan snapshots remain unchanged; four subsequent
authoring changes are recorded separately. No compiled Core or bridge changed.
Acceptance and artifact pins: [l2df-native-bridge.json](../evidence/l2df-native-bridge.json).

The next consumer has an existing whole-call comparison:
[ACTIVE_GAMEPLAY_CAPTURE](ACTIVE_GAMEPLAY_CAPTURE.md) retains 48 active calls
after 16 neutral calls on each initialized parent. Its own startup/catalog state
must be separated from reference assertions before it can serve the runtime.
These are pristine EXE controls without bundled DLL patches, and HP remains 500;
they establish neither a damaging match nor DLL-enabled application behavior.
This next stage must preserve that boundary while connecting a real owned game
session. The seven full-game criteria remain open.
