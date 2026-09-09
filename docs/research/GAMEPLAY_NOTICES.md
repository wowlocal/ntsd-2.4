# Initialized match through post-HUD notices

This study continues both [GAMEPLAY_HUD](GAMEPLAY_HUD.md) chains through the
entire421a2d..421cdc caller. The original source starts again at445a31/CRT,
reproduces all pinned startup/menu/loading/selection/launch/gameplay parents,
and resumes on the same CPU, stack and retained allocations. No diagnostic,
exit or function-key flag is changed to choose a convenient path.

The native consumer calls the public `OriginalPostHUDNotices` mechanism on its
own state after the complete public HUD pass. The mechanism's enabled branches
are separately documented in [POSTHUD_NOTICES](POSTHUD_NOTICES.md), with819
direct comparisons,8 explicit Unicorn signaling-NaN discrepancies and4 source
cookie-overwrite controls rejected by native. Those scopes remain unchanged.

Both source captures completed at421cdc/SP1000e9bc. The entire before/after
state is identical to the pinned HUD exit in both backing variants. The
original flags450bec/450c2c/450c28/451160 are all0, so this first own tick
performs no formatting, platform call or caller-local access. These values
come from the uninterrupted initialization, not injected stage inputs.

The stage executes10 original instruction starts; the11th observed PC is the
unexecuted stop421cdc. It retains EDI0 and loads the actual sprintf address
7817775d intoESI. One new checkpoint at421a2d retainsCW023f/FPSW4000; all1603
parent FPU checkpoints reproduce exactly. Explicit entry/exit reads also
retainCW023f/FPSW4000/tagffff. This is an original-instruction observation,
not a Windows/hardware FPU check.

This work does not establish the full tick return, a native app session, a
completed match, Windows pixels/audio, or hardware floating-point exceptions.

## Preserved ownership and execution boundary

`tools/oracle_gameplay_notices.py` derives from the whole HUD source capture.
It verifies the complete newly reproduced parent JSON and fixture hash before
installing new-stage observations. Original helpers are executed if their
branches are selected; the existing GDI/COM/PTD responses remain explicit
boundaries. The source does not replace sprintf with host formatting.

Before and after the continuation, capture retains World/400Actors and masks,
globals, all14,586 Frame allocations,854 source bitmap wrappers,101 Background
records,11 menu bitmaps, early resources, music, recording and the prior CRT/FPU
state. The native reference compares these with the independently rebuilt
ownership. Expected state is used to compare outputs, not to feed the engine.

Both full native comparisons pass: each checks481,245 records and806,849,858
bytes with defined masks across61 state checkpoints. The whole chain retains
536/544 helper returns and1,604 FPU checkpoints with one initialization
transition. The new notice stage adds no helper/event or undefined bitmap read;
the preceding HUD's differing backing and outputs remain exactly reproduced.
Naruto/Sasuke sourceIDs17/21, District, mode0, tick1 and the unreturned gameplay
caller are retained. No per-character branch was added to the native engine.

The new source hook records all accesses to rootSP+46c..<5c4: the340-byte
caller-local region plus the four-byte cookie. It also captures the unchanged
raw backing as evidence. The mask is explicitly **writes during this stage**,
not proof that earlier execution never initialized any of those bytes.

## Unresolved caller strings

The public native API now accepts an optional retained local record. When the
original path does not access strings, nil stays nil. The first actual string
write requires the caller's owned backing and otherwise throws an explicit
`Caller string backing unavailable` error. This is the same generic caller
implementation used by the known-backing API and its controlled comparisons;
there is no separate implementation for Naruto, Sasuke or disabled diagnostics.

The own reference must not copy source `localBefore` bytes into native storage
just to obtain identical unused bytes. It instead checks the source access
trace and calls the public API with unresolved native backing. A separate
native failure trial enables the locked-key writer on a copy of the own state
and verifies that it fails without manufacturing backing or publishing an event.
This trial is distinct from the original uninterrupted match, whose flags are
not modified.

The340-byte source region may contain earlier caller text or arbitrary retained
stack contents. Recovering its complete lifetime is still required before an
own continuation can select a branch that writes it. Nil is not a zero-filled
buffer, a promise that diagnostics can be omitted, or a general solution for
all later result strings.

## Reproduction

```sh
uv run --script tools/oracle_gameplay_notices.py
uv run --script tools/oracle_gameplay_notices.py --control
python3 tools/accept_gameplay_notices.py
swift test --package-path native -c release --filter OriginalGameplayNoticesTests
```

SwiftPM processes run sequentially. Source captures may run independently;
never restart a live capture because it has not produced a new log line.
Acceptance verifies both complete parent/state/FPU identities, local-access
provenance, helper/event/PC inventories, all transport blobs and170 old fixture
hashes before running native comparisons and publishing two lossless fixtures.
Raw and packaged native runs remain separate evidence.

## Acceptance evidence

The retained HUD and controlled-notice regression passed4 release tests in
41.975s after a141.41s build. This includes all819 direct notice comparisons,
8 separately classified NaN-companion comparisons,4 cookie-overwrite rejections
and the late-bitmap rollback check. Both new raw own-chain comparisons passed
in40.138s after a141.27s build, before their fixtures were published. No original
result or old fixture was changed to make those comparisons pass.

The new source/native reports are [primary](../evidence/gameplay-notices.json)
and [control](../evidence/gameplay-notices-control.json). All170 old fixture
hashes remain unchanged among172 current pins in
build/research/gameplay-notices-fixture-pins.json. Independent verification
compares complete inflated bytes and JSON, lengths, SHA256, all2,756/2,757
internal blobs and the complete parent state. Raw/packed sizes are
9,252,118/1,278,795 bytes and9,268,428/1,290,383 bytes. Its report is
build/research/gameplay-notices-artifact-verification.json.

Final packaged verification passed the same2 release tests in39.808s after
a139.74s build, without the raw-corpus override. NTSDNative linked. Python
compilation,653 local Markdown links across9 edited/new documents and diff
checks passed; both source captures and all SwiftPM jobs were terminal before
the milestone commit. No app window was tested.

After this stage, continue the whole result-recording caller421cdc..422218.
[RESULT_RECORDING_PLAN](RESULT_RECORDING_PLAN.md) records the static dependency:
real43dd60 saving/freeing, the1.1.4 compression interface and the retained
`OriginalMatchRoundResult.stageDefeated` producer. The latter still needs its
intervening caller-stack lifetime audited. Then implement result layout,
bitmap-font labels, presentation, enabled queued sound and the actual422ab8/ret4.
Continuous original DAT-driven sequences, the first completed Naruto/Sasuke
District match, app integration and the full-game goal remain open.
