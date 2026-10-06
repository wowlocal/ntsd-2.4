# RT phase 2 design note — the per-cycle data flow

Map of one gameplay tick on the runtime and in Core, made by a read-only agent
on 2026-10-06 at 35ec7a3 for [CORE_REALTIME](CORE_REALTIME.md) phase 2. File
abbreviations: RL = NTSDRuntime/OriginalMacRuntimeLoading.swift, RS =
OriginalRuntimeSession.swift, RM = OriginalMacRuntimeMenu.swift; in NTSDCore:
HS = HostSession, MS = MenuSession, BS = Bootstrap, LC = LoadedCycleSession,
GS = GameplaySession, LMS = LoadedMenuSession, MB = MatchBindings, GB =
GameplayBody. Line numbers are as of 35ec7a3 and must be re-checked before use.

## One tick

1. **Message loop** (`RS:297` → `RM:126` → `ObservedIteration.resume:103` →
   `HS.step:211`): copies of platform, application and session; the loop runs
   the dispatch entry on `full` (`MS:406`), slices world/globals and copies
   memory (`MS:412-415`); world+0 == 2 returns `.loading` (`FrontMenuLoop:22`)
   with state S1; nothing committed (`BS:121`). The whole `host.step` re-runs
   once per new platform request (`ObservedIteration:153-155`).
2. **Loaded cycle** (`RL:320` runCycle → `HS.prepareBoundary:301` →
   `MS.makeLoadedCycle:818` → `LC.init`, which rebuilds `MatchBindings`):
   `bindings.read` (`MB:36-67`) translates the world, copies all 400 actor
   records (each +0x368 write copies 0x420 bytes plus mask) and slices globals;
   nested candidate copies (`LoadedMatchCycle:16`, `LoadedMatchEntry:20`,
   input/replay/round layers); replay packet writes copy the whole allocation
   dictionary (shared with S1); `bindings.store` (`MB:78-107`) copies the
   dictionary, rewrites 400 actors, four `replace` calls → S2;
   `PendingContinuation` holds S2, model M2 and `loading` (S1). The Host also
   builds a throwaway `GameplaySession` to validate (`HS:321`).
3. **Gameplay** (`RL:389` → `HS.resumeGameplay:351` → `GS.advance`): a new
   `Attempt` (`LMS:147-189`) copies state, model, audio, resources and
   backgrounds, rebuilds `MatchBindings` again and collects address ranges over
   every live allocation, catalog allocation, stream, wave owner and audio
   record; `GB.apply` adds more copy layers; a second `bindings.store`
   (`GS:187-190`) → S3; `PendingReturn`.
4. **Finish** (`RL:450` → `HS.finishLoadedMenu:380` → `MS.finishLoadedMenu`):
   loop tail over S3, `mergeAliases`, commit S4 and the model M3; the runtime
   drains the committed batch (graphics replay, sounds, replay files).

## What needs the session form between ticks

- Production: the message loop reads/writes `full` every tick (keyboard bytes,
  the key scan, counter, world+0) and touches `memory` only to release replay
  buffers; gameplay reads bitmap wrappers, graphics, random and library owners
  from the state; rendering, audio, network and replay saving read no state.
- **The 400 actor records in `memory.allocations` are read only by the bindings
  and the Attempt's range collection; nothing writes them between a commit and
  the next read.** The session form is needed per tick for the globals, the
  world and the replay entries.
- Diagnostics/tests: `--stage-checkpoints`, `--network-ready-state`, and
  checkpoint snapshots compared by ~15 Active*/Gameplay* suites (checkpoints
  default to true in tests).

## Rollback

The Host contract keeps the old state on every failure (one attempt at a time;
`prepareBoundary`, `resumeGameplay`, `finishLoadedMenu` retry tests in
HostGameplayTests). The production runtime never retries a failed cycle (any
error stops the game, `RS:442` → stop `RS:663`), so the contract is exercised
by the Host API and the Core tests, not by play.

## Candidates (keep observable behaviour identical)

| ID | Change | Risk |
| --- | --- | --- |
| R1 | Cache `MatchBindings` (built twice per tick) and the Attempt's static ranges (catalog, files, wave owners) per session | low |
| R2 | Compute the Attempt's `ranges` lazily: only `claim` reads them | low–medium |
| R3 | Keep the model authoritative across ticks: globals shared as one copy-on-write record with `full`, the actor mirror out of `memory` while a match is loaded (materialized for observers), the gameplay path's first store deferred with its validation kept in place | medium; needs independent review |
| R4 | Replay buffers and actors out of the general allocation dictionary (slot table), so per-tick replay writes stop copying ~500 entries | medium |
| R5 | One transactional copy per Host attempt instead of nested candidate layers | medium–high |
| R6 | Move the committed state into the attempt (undo journal / no-retry mode) | high; breaks the Host retry contract: the user's decision |

Order: R1, R2, then R3 with R4 as one reviewed storage-model change, then R5.
