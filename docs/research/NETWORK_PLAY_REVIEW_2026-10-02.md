# Independent networking review — 2026-10-02

User explicitly authorized one reviewer. `/root/network_review`, GPT-6 Astra
xhigh, reviewed HEAD `4f65fa40eba0099f88b51694b2256dfe611f8aff` read-only.
No original execution, captures, builds, fixture changes or repository edits
were performed by the reviewer. The implementation author owns corrections.

## First review: one P2 finding, N5 acceptance open

`OriginalMacRuntimeLoading.performControl` immediately presents error dialogs,
but returns from control `.method` and `.postMessage` without delivering them.
`finish()` delivers these effects only after the loaded batch commits.

The original order is message → sound/music release → free → close post →
subsequent checks/messages. The reviewer checked the preserved
`original-input-control.json`, case2384 `receive-1-[0]`: first message event6,
419 releases at7–425, frees and close post at428, second message at429.
The implementation instead shows the second dialog before the first shutdown
effects. On the recorded-match replay fault, `complete()` never reaches
`finish()`, so it loses those effects. Scripted process termination masks the
observable possibility of audio continuing at an interactive fault stop.

Required correction: methods and close posts must use the existing inline
receipt journal, in source order, without replay at commit. Check repeated
dialogs with intervening shutdown, retry without duplicate effects, and a
later recording fault without `finish()`. Preserve the original fault.

The reviewer also confirmed that updating the music graph model alone does not
stop the player: inline music methods must synchronize `OriginalMacMusicOutput`
within the same receipt. Do not pump graph events or the window queue there.
Observe the actual Player in tests; the existing virtual-clock report can still
say playing after `present(nil)` although the physical player is paused.

## Bounded conclusions from the first review

- N1/N2: descriptor cancellation barriers, observation identity, retained reset
  errors, partial reads and host receipts are consistent with declared contracts.
- N3: the selector4 comparator correction applies an explicit four-byte
  before-state stimulus at World address22000020, not an expected after-state.
  Source3 retains the client's own selector4 state and loading continuation.
- N4: both comparators and retained Actor records were inspected independently.
  All668800 Actor pairs across1672 cycles have0x420 bytes/masks; differences
  are only defined Actor4+370/+398 CRT spark coordinates. Drawing consumes these
  without changing gameplay. The specific match's replay bit0 reconstruction
  follows the local/remote contract.
- N5 logs distinguish role2 EOF, role1 receive error, normal pre-match quit and
  the recorded-match source fault. Cancel/reentry, FD_CLOSE and early sendto
  failure retain their stated scope. The P2 above blocks N5 acceptance.

Windows interoperability, clean-Mac/package/device acceptance and the previously
declared unknown partial-handshake caller backing remain separate boundaries.

## Correction and accepted follow-up

The author delivered control `.method`/`.postMessage` within the existing input
receipt journal. Music model and player presentation are serviced together;
callback failure terminates the journal. Commit skips only these delivered
control effects, retaining round/front effects. No Core rule, expected value,
mask or network comparator changed.

The reviewer inspected candidate2 and found no new issue. Source shutdown
ordering and the skip at commit are correct; the callback does not pump graph
or window events. No repeated full N4 capture is warranted by this adapter fix.

Run1 preserves a compile failure in the new test: MenuSession.State has `full`,
not `globals`. Candidate2 uses the existing State.slice on the owned startup
record, retaining defined masks. No application correction or weakened test
expectation was needed for this failure.

Run2 built in180.38 seconds and passed19 tests in43.858 seconds:
6 runtime-loading,7 music-output,6 sound. The two new tests use the shared
shutdown helper and actual `recordReplayPacket` null-pointer boundary. They
check live sound.voice and a fake Player's pause/playing state before the next
dialog, replay the same failed attempt without effects, and check terminal
failure of the player callback. The test does not call finish after the fault.

Four app scenarios on binary
`1ae78a5eded902c1c0236b285e8143aaef87ce4d6c5a8f7d195316d641a84c2a`
pass with unchanged UI inputs/outcomes: each role closing before a match gives
both quit0; during the recorded match the peer receives one Connection Lost!
then the original4588a8 recording fault. The reviewer checked raw role2 recv0
and role1 recv−1 traces. These are the preserved OS results, not an inferred
reset errno or a new Windows observation.

No-network and full offline VS pass (both commands exit0; vs.problems empty),
including milestones, progress, captures, replay/overlay and old reference
hashes. All643 current source pins match candidate2; all jobs are terminal.

**Final independent verdict:** P2 closed; N1–N5 review complete, no remaining
blocking finding in the declared native localhost/error/exit/offline scope.
Windows interoperability and clean-Mac/package/device acceptance remain open.
Unknown partial-handshake backing and the identified N4 CRT spark coordinates
retain their existing boundaries. The virtual-clock state.playing diagnostic
limitation is separate; muted app runs do not establish audible playback.

Scope, failed candidate, run logs, raw probes and review follow-ups are retained
under `/Volumes/X5/ntsd-2.4-research/network-review-20261002`.
[Machine-readable evidence](../evidence/network-review-20261002.json).
