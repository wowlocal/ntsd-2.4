# Joining loaded ticks to the native runtime

This is a source/API audit and an acceptance plan. The initialized return is
now accepted in [GAMEPLAY_RETURN](GAMEPLAY_RETURN.md), commit `696e2a6`, after
the parent [GAMEPLAY_RESULT_LAYOUT](GAMEPLAY_RESULT_LAYOUT.md). Both runs reach
the actual match and dispatcher returns. [GAMEPLAY_BODY](GAMEPLAY_BODY.md) now
implements the reusable native unpaused body and verifies its complete state,
ordered events and enclosing rollback against those two accepted paths.
Repeated complete loaded calls remain the next comparison.

## Current runtime boundary

[NTSDApp/main.swift](../../native/Sources/NTSDApp/main.swift) launches
`MeleeScene` by default. Its
[update method](../../native/Sources/NTSDApp/MeleeScene.swift) calls
`OriginalMelee.tick`, advances background layers separately and submits a
selected sound list to AVFoundation. This remains the earlier Practice path.
Linking NTSDNative while testing the newer modules does not execute those
modules in the application window.

[OriginalLoadedMatchCycle.run](../../native/Sources/NTSDCore/OriginalLoadedMatchCycle.swift)
owns the loaded World2 prologue, phase/pause update, command buffers and
input/replay/round composition. It returns an
[OriginalMatchRoundResult](../../native/Sources/NTSDCore/OriginalMatchRound.swift)
at `.gameplay`, `.pausedRendering`, `.menu` or `.epilogue`. It does not return a
complete tick. The initialized reference checks currently compose subsequent
stages while checking each source boundary in
[MatchLaunchReference](../../native/Sources/NTSDReferenceChecks/MatchLaunchReference.swift).
The gameplay body is now an ordinary native operation in
[OriginalGameplayBody](../../native/Sources/NTSDCore/OriginalGameplayBody.swift).
The whole loaded call and its alternative continuations still need composition
before replacing Practice's update path. Expected snapshots and reference
resource addresses cannot become runtime inputs.

## Order to preserve

The [original caller inventory](TICK_PIPELINE.md) supplies the address order.
The table below maps its unpaused gameplay continuation to existing native
APIs. It is an API inventory, not a claim that all these APIs cover every input.

| Order | Native operation | Composition constraint |
| --- | --- | --- |
|1|`OriginalLoadedMatchCycle.run`|Use its actual round continuation and `stageDefeated`; phase and pause come from live globals.|
|2|`OriginalWorldControl.apply`|Complete the ascending slot control caller, including its surrounding transformations.|
|3|`OriginalWorldPhysics.apply`|Complete the live slot physics caller and its creation/revival rules.|
|4|`OriginalWorldLinks.apply`|First depth and held-object pass.|
|5|`OriginalWorldContacts.apply`|Preserve the caller's one-time contact suppression and reset.|
|6|`OriginalWorldHits.apply`|Type0 hits, actual item RNG/creation, then signed-positive-type hits; retain CRT RNG ownership.|
|7|`OriginalWorldCPoints.apply`|Actions, placement, reciprocal-link cleanup, then the second depth/held-object pass. Do not add a third links pass.|
|8|`OriginalWorldCamera.apply`|Bounds, camera and actual background drawing; retain mutations to backgrounds.|
|9|`OriginalWorldDrawing.apply`|Object drawing also advances hit effects before scheduling.|
|10|`OriginalPostDrawImpulses.apply`|Common diagnostic output and impulses; mode1/4 children are explicitly unrecovered in this API.|
|11|`OriginalPostDrawLifecycle.apply`|One live400-slot loop: each slot completes prefix, scheduler, opoint and creation/deletion before the next slot.|
|12|`OriginalPostDrawCommands.apply`|Retain the spawn word through the complete commands/cleanup caller.|
|13|`OriginalWorldHUD.apply`|Clear the two command flags before HUD, as the caller does.|
|14|`OriginalPostHUDNotices.apply`|Use actual caller backing if a string path accesses it.|
|15|`OriginalResultRecording.apply`|Preserve its actual `.resultLayout` or `.indicators` result, allocation ownership and ignored numeric IO/codec errors.|
|16|`OriginalResultLayout.apply`|Consume that continuation and the own round result; keep formatter/indicator inputs lazy.|
|17|`OriginalGameplayOutput.apply`|Mode label, notice/volume, present, enabled sound queues, in that order.|
|18|Enclosing dispatcher|Account for the original post-match held-input clear and actual dispatcher return, independently of rendering.|

Paused rendering and menu are different continuations. The round `.epilogue`
also bypasses the gameplay body. None may be treated as an ordinary gameplay
pass or silently returned as a successful whole tick. The existing local-input
API's default AI/object dispatch throws; supplying a no-op to get a return
would omit an original child. Recover any newly reached child before accepting
the dependent trajectory.

## Ownership and caller storage

The transaction must include `OriginalMatchPreparation`,
`OriginalInputControlContext`, CRT RNG state and all mutated presentation,
music/resource and caller storage. A successful stage currently commits its
own value types; composing those calls without an outer transaction would
retain earlier-stage mutations after a late failure. Buffer externally visible
render/audio/file requests until the whole native operation commits, while
preserving the declared boundary responses and request order.

Catalog bitmap ordinals and opaque interface resource tokens are distinct.
Resolve them through their live owners, including released bitmap/allocation
checks. Neither `28002020` nor a fixture's synthetic COM token is a native
device resource. `OriginalWorldCamera` requires the caller's target and actual
fill-helper backing; HUD instead reads its destination global455608.

The following inputs require particular care when removing the reference-only
composition:

| Input | Current contract and next requirement |
| --- | --- |
|Round `stageDefeated` / rootSP64|The round is an own semantic producer, already preserved by `MenuCycleReference`. Both initialized result continuations retain it; never obtain it from an expected stack snapshot.|
|`OriginalWorldCPoints.retainedPartnerSlot`|Optional boundary input; a local successful search can replace it before use. The API does not export a complete caller-stack image. Audit newly reached failed-search reads against their producer.|
|`OriginalPostDrawScratch`|Six optional words at root44/50/5c/60/6c/70. The accepted first own loop leaves all six unread and unwritten. This does not establish their values in subsequent calls.|
|Command `retainedSpawnSlot`|Separate root34 lifetime. Full-pool paths can consume it after RNG. It is not one of the six lifecycle fields.|
|Notice and result formatter storage|Notice root46c..5bf lies inside result root44c..5bf. Independent blank buffers lose shared writes. Preserve overlapping storage when either path has a recovered producer; keep it unknown while genuinely unused.|
|Indicator target / rootSP68|Static41bcd5/41bce4 copies the actual caller argument. The first own HUD does not consume that argument and the first own indicator branch skips it. Audit its intervening lifetime before enabling it as a native result input.|

Low caller offsets have multiple lifetimes. Result-layout writes at
root34/44/50/54/58/60 do not automatically preserve preceding creation scratch.
Likewise, a new41bc90 call does not imply that an old native scratch value is
still the corresponding original stack value. Audit writes, reads and pending
arguments using actual ESP at each instruction; equal textual `[esp+offset]`
operands can refer to different root words. Do not zero or carry these fields
across calls merely to make a continuation run.

## Finite next acceptance

1. Finish and publish both fresh initialized output/return comparisons,
   preserving their complete accepted parents, actual return/stack/FPU checks
   and sound ownership. Do not restart a live capture for silence.
2. Compose the native loaded operation without expected after-state inputs.
   First compare its result and ordered events to those same own returned
   states, with one outer rollback test after earlier simulation and queued
   sound mutations. Existing per-stage failure tests do not establish this
   enclosing transaction.
3. Continue the original VM from its returned dispatcher state into a second
   and then subsequent calls. Keep globals, allocations, live World/Actor
   aliases, resources, RNG, replay memory and CPU state. Drive input only at
   the established acquisition boundary. Never start each call from a saved
   expected boundary or force a gameplay continuation.
4. Compare complete state/masks and ordered effects after each return, plus
   phase/pause and recording counters, sound flags, native scratch producers
   and the source FPU/stack observations. Cover both input phases before
   extending through movement, contacts, creations and a naturally ended
   round. Preserve the first new mismatch or unsupported dependency as the
   next concrete work item; do not edit old expected fixtures.
5. Only then connect the operation to the application clock, input and device
   resources. Check the actual window and sustained native play separately
   from reference tests. A full match, result recording, all game content,
   Windows/device comparisons and clean-Mac packaging remain parts of the
   full game goal.

This audit changes no source fixture, native game rule or executable behavior.
