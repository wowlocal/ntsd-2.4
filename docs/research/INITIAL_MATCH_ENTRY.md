# Initial match entry retains native loading resources

`OriginalInitialMatchEntry` continues an actual native loading result through
local input, control/received commands, replay bookkeeping and the round
dispatcher. Its result retains the current game/input state, both command
buffers, pause, round result, interface and common/registered sound owners.
The [finite plan](INITIAL_MATCH_ENTRY_PLAN.md) defines the comparison boundaries.

## Reference and recovered behavior

The reference is the unchanged pinned NTSD2.4 EXE and VC80 with original
DAT/BMP/WAV resources in the controlled Unicorn environments described by
[MENU_STARTUP](MENU_STARTUP.md) and [LOCAL_INPUT](LOCAL_INPUT.md). No original
execution or expected-state changes were made for this composition.

Both historical MENU_STARTUP parents enter41c581 naturally with phase1, pause0
and menu10. They execute419a60/ret12, control/received4198f0/ret12, replay
bookkeeping and round dispatch to4229cc, then music and eleven menu resources
through429e5a. The six retained checkpoints compare full World/400Actor/globals,
command buffers and replay ownership. Both actual round results retain
`stageDefeated = 0`; zero must not become an absent result.

The source pre-first-menu458588..4588a7 saved-playback bytes remain a declared
initial input. They are neither an after-state import nor a recovered application
default. Early live/dead resources come from the preceding native menu chain.
CRT, allocation, frozen-clock and supplied bitmap-device boundaries remain as
declared in the historical studies. These captures do not prove the pending
installed-library application catalog path, full Windows execution or devices.

## Native composition and ownership

[OriginalInitialMatchEntry](../../native/Sources/NTSDCore/OriginalInitialMatchEntry.swift)
uses the existing `OriginalLoadedMatchEntry` rules. It does not rerun the loading
prologue, reset commands, assume a menu result or skip an enabled child. The
caller explicitly supplies arithmetic precision and its saved-playback/resource
context. A reached AI/object child still requires its actual implementation.

The platform environment, observations and resulting input state are staged
until every operation and the final observer succeed. Platform effects must
remain buffered in the value-semantic environment. A throw publishes no entry
result and retains the original environment and loading/input values.

The shared `OriginalMatchPreparation(loading:arithmeticPrecision:)` transfer
also fixes a resource omission in `LocalInputReference`: its previous manual
initializer omitted the loaded interface and selected the empty default.
The reference now retains all ten original native wrappers throughout every
case. No source expected record or global value was changed to fill that gap.

MENU_STARTUP now executes this public entry before its existing music/resource
continuation. It retains every earlier comparison and checks the committed
six-checkpoint environment against the actual source order. Game rules remain
in the shared native operation.

## Comparison and rollback

Both complete MENU_STARTUP controls still compare22 checkpoints,68 events,
3412 records and5,948,634 bytes plus masks each after their complete historical
loading parents. Their following music and eleven resource constructors remain
in the comparison, so the new result must support the next consumer.

Both303-case LOCAL_INPUT corpora retain all original World/Actor/global/command
and dispatch comparisons. Additionally, each case retains the ten native UI
wrappers' inputs, flags, complete bytes and masks:6060 native resource-retention
checks. These extra checks do not add source branch coverage. The controlled
AI/object dispatch cases retain their explicit no-effect child boundary; the
natural first-loading path has no active tail children.

Two native ownership checks compare all836 common/registered wave results and
twenty interface wrappers against the preceding native loading outputs. Wave
checks include every optional record, raw PCM/descriptor bytes and masks,
temporary lifetime, return status and output token. These are retention checks
on independently loaded native resources, not extra original wave executions.

Three additional native-only trials throw after local input, after round dispatch
and after the final observer sees the completed entry. Each retains the caller's
environment, original globals/saved-playback/resource allocation records and
previous completed entry. They are rollback controls, not original fault matches.

## Verification and remaining work

The independent package exports accepted87859ce plus five owned code/test files.
All630 archived native inputs are independently hash-verified;625 base files
remain unchanged. Build/test and preservation evidence are recorded in
[initial-match-entry.json](../evidence/initial-match-entry.json).

All12 release tests passed in150.070s, build222.81s. The two MENU_STARTUP tests
took15.691s, local input15.155s, control24.033s, replay31.578s, round38.397s
and repeated menu25.216s. This includes the two2993-case control,1134-case replay
and2074-case round corpora through their retained parents. All247 fixture pins
remain unchanged; no fixture was added. NTSDNative linked and all native-study
processes are terminal0. No application window or device was exercised.

```sh
swift test --package-path native -c release --filter 'OriginalMenuStartupTests|OriginalLocalInputTests|OriginalInputControlTests|OriginalReplayTickTests|OriginalMatchRoundTests|OriginalMenuCycleTests'
```

This first-entry result still requires its real menu/render/gameplay continuation
and caller epilogue. Application-catalog captures remain separate: primary1
ended at a research WAV allocation-guard assertion; its data are retained and a
separate corrected-allocation primary4 is running. Other parent20 native checks
pass while their full trace audits continue. Own catalog return/pool/UI/41bc90,
application window and latency,
sound, Windows/devices, full match, all content and clean-Mac acceptance remain
open. Reference EXE/DLL execution and emulation stay outside the native runtime.
