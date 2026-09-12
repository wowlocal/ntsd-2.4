# Owned loaded-session path

Status: finite implementation plan, 2026-09-12; execution not yet accepted.
The next executable unit is pristine boot storage followed by the original
front-resource/settings handoff. It starts the persistent owner needed by
`OriginalLoadedGameplayCall`; it does not expose a tick or claim a loaded game.

## Scope, inputs and ownership

Use immutable main `ab0db06c6f0a6162f1935a1badbfc2a750822096` Core/codec,
not the older worktree Core. Foundation `284d69dc` remains the accepted ABI
baseline. Sources are copied and individually SHA/Git-blob checked again before
the new isolated build. No EXE/DLL execution, captures or reference after-state
imports are permitted. Existing incidents and old apps/evidence remain unchanged.

The original EXE SHA is
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.
Read-only PE inspection establishes `.data` at VA `0x44d000`, file offset
`0x4d000`, raw length `0x2000`, virtual length `0xc724`. The owned global span
`0x44d000..<0x458440` consists of those 8192 original bytes followed by the
PE-defined zero tail. Its entire mask is known. Saved playback
`0x458588..<0x4588a8` and replay pointers `0x4588a8..<0x4588b0` are likewise
PE BSS, separately owned for the later input-context consumer. This evidence
does not initialize unknown heap/stack or establish full CRT/static-World startup.

Root owns `native_bridge/prepare_resources.py` and its output. Resource contract:
`manifest.json`, `static/globals-data.bin`, raw relative tree under `original/`,
and original embedded DIB plus derived BMP files with key/language, dimensions,
source offset, byte counts and hashes. The runtime consumes these data files;
EXE/DLL/reference fixtures are absent. Source copies are never edited. The
runtime verifies and owns the bytes it consumes, rather than retaining borrowed
Lua memory or treating expected metadata as a resource provider.

This unit needs `original/data/control.txt` (raw SHA
`cc7f84872d9b95fe64c1c95cc7895b3e2c0a52a3ae0f7f7970f0b3c56b7037c0`)
and 23 distinct embedded keys: LF2_CURSOR, MENU_CLIP, MENU_CLIP2–7, MENU_WAIT,
SLOGAN, ENDING, CS2–6, FRAME, WORDS0–5. The cursor is requested twice, yielding
24 separately owned bitmap wrappers. Pixel upload and macOS surface behavior
are not part of this headless constructor/device-response contract.

## Concrete public consumers

`OriginalStateRecord.worldPrefix(over:)` at `OriginalStateRecord.swift:114`
constructs the own `0x7d8` World prefix, defining only selector/activity bytes.
This is the accepted controlled allocator constructor, not static World458b00.
Two explicitly named developer platform profiles reproduce the retained declared
allocation inputs: A5 backing with ascending handles, and byte-ramp backing with
reverse handles. `oracle_front_menu_resources.py:62,117` specifies their recipe;
it is read as evidence only. Unknown backing bytes retain false masks. Runtime
handles are logical identities, never original/private host pointers.

Before these resources, only the typed front-device binding at `0x457578` is
written. `oracle_front_menu_resources.py:50` and the empty settings-parent hook
in `oracle_settings_loading.py:52` establish this boundary. The five additional
FrontScreenPrelude/EarlyMenus bindings belong to the next caller and are not
silently added to this earlier state.

`OriginalFrontMenuResources.load` (`OriginalFrontMenuResources.swift:29–34`)
uses that World/globals, independent allocation records and metadata parsed from
the original DIBs. Its existing shared bitmap constructor owns every wrapper and
all rectangle/glyph writes; the session does not supply finished records. Only
the returned `.settings` continuation advances to settings. Null/skipped paths
remain distinct outcomes, never implicit handoff success.

Settings uses `OriginalSettingsLoading.loadAndContinueStartup` at lines36–39,
with fresh private `0x1f4` scratch created from the same declared allocator
profile, entirely unknown initially, and `requireDefinedStrings:true`. This
preserves every byte of the unchanged retained comparison; `loadOwnStartup` at
lines24–33 uses a different zero/unknown backing recipe. CRLF translation comes
from the original raw control file. FILE/scratch/World identities are typed
declared platform tokens; close result is explicit. No original CRT FILE ABI or
stack snapshot is imported. Reading unknown private scratch rejects the call.

## ABI and transaction

Add a create operation accepting only resource-root bytes and a named declared
platform profile. It returns an opaque session handle with `PRISTINE_BOOT`
lifecycle after its owned resource/static initialization succeeds. The existing
Actor-storage create, read, setup and destroy APIs remain supported unchanged.
Their operations reject a session of the wrong kind.

A single `load_front_settings` operation runs the real two consumers on a staged
copy and commits one revision plus `FRONT_SETTINGS_READY` only at successful
handoff. It owns World/globals, front wrappers, raw resource identity, settings
scratch/result and BSS input regions across calls. Repeat loading in a wrong
lifecycle rejects without mutation. A read-only export provides full bytes,
masks, input metadata and ordered events from the actual ABI owner for external
comparison. It is an observation API, not a state-loading API. No arbitrary
globals/Actor/World/saved-playback initializer is exported.

On invalid input, resource failure, unknown read, or unsupported continuation,
state, masks, revision and pending effects remain unchanged. Diagnostic errors
remain separate from successful source return or original fault. External
effects are buffered until commit; this stage uses only declared headless device
replies and performs no graphics, audio, thread or original-file writes. A failed
native transaction is not evidence of reproducing an original fault.

## Verification and limits

Freeze the plan/code and obtain the independent read-only review before running.
One new build, at most 300 seconds and 2 GiB, and one native LÖVE LuaJIT FFI run
at most 90 seconds. Use unique jobs under
`build/l2df-prototype/loaded-session-20260912/`, verify X5 UUID
`3A4F5FA6-DC86-4C6E-87E2-EAC2C2D72548` and preserve 6 GiB reserve. Resource export
has its own root-owned manifest/budget. Do not restart completed builds. A new
error gets diagnosis and a separately named repair run, preserving the failure.

Compare the **actual ABI session** for both first natural settings trajectories
against immutable `original-settings-loading{,-control}.json`: raw PE recipe
versus the initial globals, World constructor, every front event and retained
wrapper byte/mask, every settings event/checkpoint, final globals/World/private
scratch and continuation. Expected data stays in the external comparator.
The profiles determine inputs from source recipes, not expected records. Full
settings/front corpora remain lower-level accepted regressions; this new session
claims exactly two composed natural trajectories, not all145/94 cases anew.

Selected fixture SHA-256:

- settings: `b0c95deb903f0ec03b6cd15a8dad8186433ece4616e75912ecee49d09c852517`
- settings-control: `0440f022b596e9cd7618b891f60a4bba28b8b74a648a5cdff4188af0c9411443`
- FrontMenuResources.swift: `6b610aa2842a1b8b5a58eb2e0c86b16084c985cf9c1c0478d06960a3dbbfc3a0`
- SettingsLoading.swift: `e3c0f8f85af682c5f03d348efe88c89a9775e9bf54287ed591890f509d6ee32e`

FFI also verifies resource/input ownership, lifecycle, no gameplay capability,
wrong-kind calls, transactional late failure, subsequent valid continuation,
release/stale handles and existing Actor-storage assertions. Verify complete
compiled source/manifest bytes separately from process exit and FFI assertions.
No window, physical keyboard, audible output or clean-Mac claim follows.

## Required continuation in the same owner

Next execute front-screen/early-menu callers and genuine catalog loading via
`OriginalLoadedCatalog.loadWithFiles` (`OriginalLoadedCatalog.swift:84`), with
own raw DAT/BMP resources, internal temporary-file lifetime and complete catalog
comparison. Continue common/registered sounds, 400-slot pool and UI through
`OriginalInitialLoadingContinuation.complete`, `OriginalInitialMatchEntry.run`,
menu/selection/prelude/prepare/music/recording into `OriginalLoadedGameplayCall`.
Do not rebuild mutable state from Lua snapshots between these operations.

The retained target is `ACTIVE_GAMEPLAY_CAPTURE`: 16 neutral then 48 active
pristine calls, both controlled profiles. It excludes full lib.dll/CRT/static
World and actual device behavior. Persist state/input context/CRT/memory; create
a fresh `Caller()` for each loaded call (`ContinuousGameplayReference.swift:191,
307`). Input acquisition precedes tick staging and survives tick rollback.
Resolve resources from the live owner, not a stale entry snapshot; publish
external effects only after commit. Do not freeze the live clock to avoid the
old no-draw loading-progress boundary: use accepted full progress composition
when adding live loading. AI/unhandled World branches and complete game/device
acceptance remain explicit dependencies.
