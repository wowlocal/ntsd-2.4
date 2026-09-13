# Saved gameplay source reader

This checkpoint finishes the pending test-only reader under the
[owned gameplay comparison plan](APPLICATION_LOADED_GAMEPLAY_COMPARISON_PLAN.md).
It makes the saved observations available to that comparator. It does not
compare the application's own gameplay state or accept the full gameplay card.

## Scope and contract

`OriginalApplicationGameplaySource` reads32 immutable bundled sequence fixtures
plus two initialized-gameplay parent bridges:15 first-body files, one16-call
continuation and one bridge for each of two backing variants.
Each sequence exposes17 calls with19 stages. EXE and VC80 hashes,400 Actor
identities,137 Object identities, World address, backing selection, parent
links, stage order and stop addresses are checked. The first launch parent is
covered by the existing launch acceptance; this reader starts at gameplay entry.

Reference EXE SHA256 is
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`, VC80 SHA256
`c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d`.
The input is saved Unicorn observations from the pinned original NTSD game.
Only the Swift decoder, integrity checks and native test build execute here;
the EXE, emulator, historical producers/auditors and refused operations do not.

Outer fixture hashes come from the verified `c3db73d` input manifest. Existing
decoders verify packed payload and continuous component hashes. The new reader
checks first-stage continuity over every shared snapshot field, then exact
continuous references, neutral keyboard/input history, FPU counter continuity
and whole-return boundaries. Five explicit input handoff equalities connect
each continuous call to its cycle and round snapshots. Lifecycle's declared
parent is the initialized-gameplay aggregate, whose identity, parent, complete
impulse before/after snapshots, events and stop are checked against the separate
impulse capture. The bridge explicitly preserves historical reported FPCW0
versus initialized FPCW023f, as established in
[INITIALIZED_GAMEPLAY](INITIALIZED_GAMEPLAY.md). All other impulse fields must
match; this does not assert equality of the two execution environments.
Optional heaps absent from a capture remain
unobserved; comparing shared fields does not fill missing records.

Pool normalization changes only known Actor/Object/catalog identity words.
Tests restore these identities and require complete original byte/mask equality
at646 before/after endpoints per variant. All distinct merged blobs are inflated
and SHA-verified. Replaying576 ordered global stores per variant must reproduce
the complete saved whole-call globals across all16 continuation calls. This
includes stores whose value does not change. First-body ordered global stores
are not supplied by this reader; its first call explicitly exposes an empty
write list. PC inventories are sets of observed instructions, not ordered traces
or proof of complete Actor/Frame store coverage.

## Verification and handoff

The finite execution gate is two release tests in
`OriginalApplicationGameplaySourceTests`, one per backing variant. Core, all
previous tests and all383 fixtures/102 runtime resources remain unchanged.
Earlier successful gameplay/provider tests retain their original evidence and
are not new executions for this checkpoint. Candidate inputs, Native job/log,
read-only reviews and separate archive/package checks live in
`build/research/application-loaded-gameplay-projection-native-20260913/`.
Candidate1 failed to compile because the new test lacked its testable reference
module import. Candidate2 adds that import and explicit input handoffs, but
retains an incorrect direct-parent assumption at lifecycle. The separately
reviewed correction reads and verifies the existing initialized-gameplay bridge.
Both frozen candidates and their terminal logs are retained; expected data and
Core do not change. Measured results are published in the
[evidence manifest](../evidence/application-gameplay-source-reader.json).

Candidate3 passes both release methods in10.956s, build339.52s.
All985 Native files,383 unchanged fixtures,102 runtime resources and485 packaged
files match the frozen candidate; Native/evidence archive bodies and modes are
verified separately. The141 prior successful methods are retained through983
unchanged files and their existing evidence, not rerun or counted as new matches.
All three Native jobs are terminal; the first two candidates remain preserved.

The independently reviewed rendering projection notes are retained as research
inputs. They establish saved-data formulas and footprints, not own-position
Native acceptance. Next work remains the full source-first19-stage comparator:
input carry, typed writes, numeric intermediates, own camera/draw order,
clipping/text/sound, complete owned records/masks and whole-caller rollback.
The full match/game, device/Windows/clean-Mac checks and historical safety/source
fault dependencies remain open.
