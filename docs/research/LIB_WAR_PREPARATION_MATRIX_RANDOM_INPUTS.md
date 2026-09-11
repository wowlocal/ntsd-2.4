# War matrix: music consumes RNG before the random arena

This corrects the declared Random inputs in the frozen [matrix input plan](LIB_WAR_PREPARATION_MATRIX_INPUTS.md).
Preserve that plan, both old manifests/producers and every completed source part.
The game behavior is whole War Start: music selection precedes preparation's
random arena, participant placement and replay creation. Pinned NTSD EXE/lib.dll,
VC80 and original resources run under Unicorn2.1.4/CW023f/C locale with declared
normal APIs. Instruction and memory traces establish the shared RNG's actual
consumer order; this is not Windows/device or Native-equivalence evidence.

Capture2 completed245 whole returns before its post-return assertion rejected
case244's arena expectation. PID84389/session10260 ended with exit1 at
2026-09-11T23:06:12.116475UTC after554.329s; all693 pins stayed unchanged.
There was no source memory fault or safeguard refusal. Case244 normally returned
through ret1c/ret4 with arena9, while the declared expectation required0.
All245 atomic parts and their hashes remain in the capture2 review.

The input index13/counter0 first reaches music stream1/range8, return40232d,
which produces7 and advances index14/counter1. Preparation's stream123/range15,
return43a2d9, then produces9 and advances index15/counter2. The initial plan
incorrectly treated the arena as the first RNG consumer of the whole Start.
Native OriginalMusicConfiguration already retains this music-choice operation;
do not remove it, change source expectations or force the arena after selection.

Keep the20-chain/256-call/56-preparation finite acceptance target. Retain the
first234 completed calls, covering all18 fixed load/99/reload chains, bytewise.
Execute only two new11-call Random chains, each from a fresh original401-
constructor parent. Their first ten ordinary-chain calls must exactly reproduce
capture2 cases234..243. The control Random chain has no completed capture2 parent.
The failed-expectation case244 stays separately retained and is not a successful
match to the old declared expectation. No failed state supplies a new chain.

Generate the same original3000-byte VC80 table from seed17/controlffffffff.
With before-Start counter0 choose the first index i such that
`(table[(i+2)%3000]+2)%15` is0/14. Observe music at index i/counter0/range8 and
arena at index `(i+1)%3000`/counter1/range15. Actual result14 must map to99.
Both calls execute original417170; no return hook supplies these results.
Freeze the corrected manifest2 and new producer before executing the22 calls.

Assemble the234 retained and22 fresh calls without rewriting old bytes. Report
their different provenance explicitly:40 old resource/ready parent reproductions,
25 unchanged capture1 parts,234 retained capture2 calls and10 fresh prefix
reproductions. All original masks, freed owners and helper histories survive.
Keep6GiB free. A source fault stops its call; a safeguard refusal stops automatic
retries. Independent full audit and Native comparison remain required, followed
by ordinary resource-error contracts and the rest of the full-game goal.
