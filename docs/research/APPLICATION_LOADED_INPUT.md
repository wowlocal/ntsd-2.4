# Current owned loading through input and round dispatch

Status: Native input join verified; whole loaded-return card remains open. This is the input join within the
still-open [loaded-return card](APPLICATION_LOADED_RETURN_PLAN.md), following
commit `3292f1b`. The complete game remains the objective.

`OriginalApplicationInputSession` continues the actual `PendingInput` at
`41c581` through the shared local/control/received/replay/round implementation.
It keeps the pending loading parent and operation journal. A returned child
still requires its menu, gameplay or rendering body, the loading/dispatcher
returns and the suspended outer iteration before any backend publication.

The pinned original EXE and unchanged saved studies
[INITIAL_MATCH_ENTRY](INITIAL_MATCH_ENTRY.md), [MENU_STARTUP](MENU_STARTUP.md),
[INPUT_CONTROL](INPUT_CONTROL.md), [REPLAY_TICK](REPLAY_TICK.md) and
[MATCH_ROUND](MATCH_ROUND.md) supply the contracts. Only saved data and Native
Swift are used. No original execution, historical producer/auditor or refused
operation is retried. Earlier incidents remain open.

## Current owners and reference translation

`OriginalApplicationMatchBindings` reads World from current full storage and
all 400 Actor records from the live application memory registry. It maps each
current World Actor-table value to its ordinal, preserving reordered and repeated
references. Actor `+368` maps the live Object token; World `+7d4` maps the catalog.
Ordinal zero denotes the first live owner, never NULL. No other word is normalized.
Unknown non-reference bytes retain their backing and masks. The Native-only
roundtrip changes the mask of World activity byte `+190` and Actor byte `+41f`;
it does not execute input using that deliberately unknown activity.

The new current-record initializer of `OriginalMatchPreparation` adopts these
records and the actual loaded catalog/interface without running constructors.
The input session uses one immutable loading parent to supply matching owners;
the public binding utility's count checks do not establish provenance for an
arbitrary externally supplied same-size catalog.

Saved playback uses current `full[b588..<b8a8]`: 800 decimal bytes (`0x320`),
including masks. On return, the merge starts with the returned input memory,
then installs translated current Actor records and writes World/globals,
saved playback and the adjacent eight replay-pointer bytes into a tentative
copy of full storage. Direct conflicting Actor writes in the resource registry
are rejected instead of silently overwritten. Remaining outer storage survives.

Each of the six semantic checkpoints receives a coherent projection of complete
World, Actor, globals and aliases. The final pending result retains that same
joined memory in its input context. This does not establish simultaneous mirror
updates at every internal API callback; wider phase0/shutdown/replay/AI and
graphics-owner coupling still need their own caller evidence.

The actual WinMain `output.music` now travels with `StartupSounds` through
catalog and pool into the input continuation. Its wide allocations also reserve
their logical ranges against later catalog/Actor/interface allocations. This
retains the actual buffer rather than constructing an empty music owner. COM
and device ownership are not established by an allocation-range check.

Arithmetic precision remains an explicit argument. The own Native test supplies
53-bit precision; historical MENU_STARTUP controls retain their declared 64-bit
context. Neither choice in a test establishes earlier pre-WinMain execution or
floating-point gameplay on the installed-library application path.

## Comparison scope

Four new test methods exercise the own complete catalog/pool/UI parent, all six
coherent snapshots, seven late exceptions with fresh retry, changed current
records, repeated/reordered Actor references, non-null Object zero, unknown
World/Actor bytes, returned replay-resource changes and thirteen binding guards.
The duplicate continuation guard is additional. Catalog and pool overlap tests
now include the retained music allocation.

Both historical MENU_STARTUP tests keep all original comparisons, including
six input checkpoints and subsequent music/resources. Their new binding check
starts from the Native loading/input parent, runs the shared input continuation
through logical identities and compares its full result to the independently
source-checked result. That result is only an expected value, never an input.
The control reverses logical Actor addresses. These are additional binding
checks; they do not add original branch or whole-application coverage.

The source's `local.phase` metadata retains an old default zero. Both actual
calls and live `450b90` have phase one; metadata must not replace them. Snapshot
differences also omit stores that write the same value. No delta-only replay
is used to claim a full write footprint or accept changed application inputs.

The first frozen candidate passed all26 bundled release methods in288.845s,
build318.42s. Four new methods and22 retained methods cover the declared
input, pool/catalog, loop, menu, music, local/control/replay/round contracts.
`NTSDNative` linked; no window/device or original execution occurred. An optional
Native profile precheck failed its identity assertion just before the same
job reported terminal success. The missing precheck output leaves its precise
cause unknown; no sample, signal or restart occurred. This observation failure
is preserved separately from the successful Native run.

All938 current/frozen Native files,457 packaged files and381 unchanged fixtures
passed byte/mode checks. The full Native archive was read back independently
of the source package. Candidate pins, independent reviews and publication gates
are retained under
`build/research/application-loaded-input-native-20260913/`.

## Next required join

Continue the returned menu child through the retained actual music, eleven
resource constructors, installed-library screen/panel and real loading/early
returns. The prepared `menu-inputs1` work package independently checks the
original PE resource tree, saved BMP payloads and RGB/written masks for all
11 DIBs (1,290,322 bytes, 582,632 pixels, 1,388 rows). All positions in these
particular images are written. This is source-color evidence, not measured
Windows/device pixels. It is not yet a tested or accepted runtime package.

The enclosing owner must finally pair the current child with its retained loop
ticket, merge the counter alias and publish once. Full original application
return, real window/input/audio, match, all content/modes/networking and clean-Mac
acceptance remain open.
