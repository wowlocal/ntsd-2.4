# Bundled library hit resolution

`OriginalLibActorHits` and `OriginalLibWorldHits` compose both installed
42fcb1/430c8c hooks with the existing whole native hit pass. All18137 controlled
original calls match full World/400Actors bytes and masks, globals, mutable ITR
heap, CRT state, library target storage and38384 ordered events. This includes
300 complete two-pass World callers. It is not an initialized library-enabled
match, Windows run or application/device check.

Of15690 retained pristine inputs,15526 outcomes remain equal and164 change.
Fresh execution of those164 pristine calls recovers their exact old bytes:
only164 binary-Z words differ,1148 bytes total. All old masks/globals/heap/CRT/
events reproduce unchanged. Do not call these164 unchanged pristine matches.

## Reference and source execution

The [finite plan](LIB_HIT_EFFECTS_PLAN.md) precedes capture and records the
later bounded164-case delta audit before its execution. Reference artifacts:

| Original artifact | SHA256 |
| --- | --- |
|NTSD2.4 EXE|`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`|
|bundled lib.dll|`28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba`|
|VC80 CRT|`c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d`|

[oracle_lib_world_hits.py](../../tools/oracle_lib_world_hits.py) executes the
actual DLL installer at declared relocated base36000000, with76HIGHLOW entries,
104 installer instruction starts and all13 actual copies/62bytes. Windows
allocation/protection/copy responses remain declared research adapters. Complete
DLL bytes and the unused4000-byte allocation remain unchanged during hit calls.
The second20000-byte allocation is initially zero in this controlled loader.
No expected patch bytes or helper success stubs replace the library instructions.

The same World source CPU then executes whole42e100/ret4 or41eefb..41f2ac.
The existing constructor memset boundary remains explicit. Sound queues,
game RNG, conversions, constructors and the source hit/spark bodies execute;
actual VC80 rand runs on the separate retained declared PTD through the existing
IAT bridge. The instruction counts below concern the World CPU's EXE/library
hooks, not a new per-instruction inventory of the separate CRT CPU.

Inputs derive from original a5/ramp constructors, explicit four-Object records
and bounded ITR/BDY storage. Full source Objects remain read-only; native builds
its own corresponding headers/400 Frames and heap. There is no source
after-state or unknown caller-storage import. All source calls return normally;
no source memory fault or safety refusal occurred in this stage.

## Effect hook42fcb1

42fcaa/42fcae load **ITR.effect**, not Actor state, into EAX. The hook executes
after the original damage, knockdown and reflection operations. Effects3/30
resume42fcbb and retain the old type0/previous-state13 freeze gate, frame200,
wait reset and sound14. Other signed values below6000 resume42fd1d.

Effects>=6000 inspect the current defender Object category. Nonzero types
resume42fd1d. For type0, the exact read is four bytes at
`Object + 0x7ac + previousFrame78 * 0xb2`. It is **not** a Frame-state read
with stride0x178. If this word differs from effect, source writes
`currentFrame70 = effect - 6000`; it does not reset wait or add a new sound.
All other preceding damage/reaction changes survive. Then it resumes42fd1d.

The read can cross two inline Frame records: previous95/283 read the last two
bytes of one Frame and the first two of the next. Native resolves individual
mask-checked bytes from its own header/Frame storage. Previous188 instead reads
state bytes from inline Frame89. No source frame pointer is imported.

The apparent MP branch1000138d..100013cb is unreachable from the installed
entry: reaching the comparison against5999 already requires effect>=6800.
The preceding signed `effect<5000` and following `effect<5999` tests cannot
reach that branch. All12 starts in this block remain unexecuted; neither source
nor native forces EIP/gates to manufacture coverage or implements imagined
5000-range mana behavior.

## Movement hook430c8c

At this hook EBX is attacker slot, EDI defender slot and ESI World. The ITR
pointer at currentSP+0xc and EDX kind come from the original enclosing caller.
Both hooks preserve SP at caller-entrySP−0x80 and all three live role registers.
These relationships are verified at15749 entries. Native uses its own slots
and records, not sampled registers or stack words.

| Kinds | Ordered operations |
| --- | --- |
|8,808,809,810,817|Timer/frame, X, Z|
|80,86,802,811,818|Timer/frame|
|81,87,803,812,819|X, Z|
|82,88,804,813,820|Y, Z|
|83,89,805,814,821|Timer/frame, Y, Z|
|84,800,806,815,822|X, Y, Z|
|85,801,807,816,823|Timer/frame, X, Y, Z|
|824,825|Target gate, then timer/frame, X, Y, Z|
|Other values|Resume the original430ceb dispatch|

Timer/frame means write defenderE0=`ITR.injury+1000` with signed32 wrap, then
attacker70=`ITR.dvx`. X/Y copy defender binary58/60 to attacker. Z adds the
literal binary64 datum at DLL+3014 and stores to attacker68. Integer coordinates
are not refreshed here. Repeated reads after each write preserve aliases.

The Z datum is eight bytes `087a4400cb764100`, bits`004176cb00447a08`, about
`1.942938392704127e-307`. They are adjacent numeric address literals in DLL
data. The actual FADD reads those bytes directly; it does not dereference
447a08 or add the pristine EXE's1. This changes the existing kind8 behavior,
including original DATs. The native constant preserves these pinned bytes.

For824/825, the first word of target-buffer row`attackerSlot*8` is compared
with defender slot. Value777 first binds that word to defender. A matching word
allows the operations; a mismatch skips them and resumes43187a. The other row
word and all remaining allocation bytes survive. This is separate native
`OriginalLibHitState` ownership. Five retained calls start with a declared777
control and independently carry source/native target results. Native process
initialization may create zero storage; callers must not reset it each tick
or round without recovered original lifecycle evidence.

## Original resource presence and unknown backing

[inspect_lib_hit_effects.py](../../tools/inspect_lib_hit_effects.py) verifies
all137 DAT hashes and the accepted full loaded Object/ITR bytes/masks. Among
4384 ITR records,42 have effects>=5000:29 in5000–5999 and13 in6000+.
The latter use12 distinct effects6067,6118,6155,6165,6245,6255,6260,6291,6346,
6365,6370,6399. The earlier contact census finds402 original kind8 records;
new movement kinds remain absent from the loading-time catalog.

Across42 type0 Objects and400 possible previous-frame indices,14625 of16800
stride words are defined and2175 contain unknown bytes. There are84 cross-Frame
reads. These are **static potential reads**, not2175 executed source faults.
The [complete catalog report](../evidence/lib-hit-effects-catalog.json) retains
raw bytes and masks without assigning semantic values to unknown words.

The controlled dynamic matrix explicitly initializes its Object backing and
does not prove those2175 natural storage cases. Native rejects unknown bytes
and rolls back; a test exercises unknown Frame89 byte8 after earlier damage.
Reachability and actual initialized allocator provenance remain open. Likewise,
the successful type0 matrix keeps changed target Frames within recovered
0..<400, or uses an equal raw word so no new out-of-range Frame is installed.
Other high-effect/type combinations remain governed by real storage resolution,
not an invented clamp or a fabricated successful match.

## Verification

Both7845 pristine precision corpora are reexecuted with the installed hooks.
New cases cover800 stride inputs,900 effect/category/previous combinations,
18 equality controls,2 cross-Frame equalities,20 high-effect category bypasses,
630 movement cases,72 target-buffer controls and5 retained-buffer calls.
Precision contexts are9010 calls atCW037f,9010 atCW027f and117 atCW023f.

| Compared evidence | Count |
| --- | ---: |
|Whole pool bytes and separately equal mask bytes|7697487896 each|
|Globals bytes|836913728|
|Mutable heap bytes|4754505728|
|Library target bytes|362740000|
|Real helper returns|42891|
|Ordered events|38384|
|EXE instruction starts|3723|
|Library instruction starts|238|
|Effect/movement hook entries|9806/5943|
|Actual stride reads / new Frame stores|898/878|
|Target-buffer accesses / stores|152/47|

All238 reachable starts of these two statically250-start hook bodies execute;
the12 missing starts are the unreachable MP block. This is not every branch
outcome or all DLL behavior. Continuations are8970 to42fd1d,836 to42fcbb,
5172 to430ceb and771 to43187a. All hook entries/returns retain source live
ST0=0,TOP7/tag7fff and their CW/FPSW; final whole calls have empty FPU stack.
Vacated FPU-register payloads remain separately recorded. This is source FPU
history, not native process flags, hardware or Windows equivalence.

[Source verification](../../tools/verify_lib_world_hits.py) checks all4334
whole-call blobs, reconstructs every observed stride read from declared Object
inputs, replays target-buffer reads/stores and verifies full old/new deltas.
[The paired source tool](../../tools/oracle_lib_hits_pristine_changes.py) runs
the164 pristine calls on a fresh explicitly unloaded-library VM, reproducing
all accepted outcomes and retaining13 additional full-byte/mask blobs. It does
not remove hooks from an installed VM to obtain acceptance.

Public native Actor APIs commit World/Actors/globals/heap/CRT/library state
together. A second native-only test binds a target and changes the attacker's
frame on its first contact, then throws from a later sound observer. Every
owned record rolls back. Buffer external effects until the whole tick commits.

Raw5 release tests passed31.397s/build44.10s. The initial175.77s build already
passed18137 library and both7845 pristine comparisons; one new rollback test
incorrectly expected sound2 atfall60. Its terminal failure/log/test-source hash
is preserved. Only that native test expectation changed to sound0; no game
algorithm or original expected byte was changed. The subsequent whole5-test
run passed. Raw export contains528 files from834b36a plus five owned native
files and excludes unfinished concurrent transform work.

Publication adds two fixtures to205 immutable prior pins,207 at publication.
The second is explicitly a source-only paired delta artifact. Main raw
121499571bytes SHA256`acf47aa8521cc6264ce3c3eab401643319fdebc216f8da7bb41c869f3688e908`,
packed7282505bytes SHA256`4b84dc082ebe7e99aa3fb01a04c3145c473238f796cac77a6c616ede31936ba5`.
Paired raw122683bytes SHA256`bb9f3b99679f74c11d7e691d5c1907e173fc8804962f7dfbf3502259d1845114`,
packed22074bytes SHA256`094add3751a4a641eccb0e86c0c12a664785b08e2268d7ee843d1ea1fcce7325`.
[Acceptance](../../tools/accept_lib_world_hits.py) verifies exact tested files
and terminal logs before publication. [Artifact verification](../../tools/verify_lib_world_hits_artifacts.py)
checks complete raw/packed bytes/JSON/SHA, all4347 blobs, prior pins and10
vendored codec files. Fixture compression is separate from the game codec.

Final packaged7 release tests passed68.432s/build175.93s without raw overrides:
library18137 and rollback17.335s, both7845 pristine corpora13.856s, and both
retained pristine initialized gameplay-hit chains37.242s. The530-file export
uses the same834b36a base/five native files plus two new fixtures and excludes
unfinished concurrent transforms. All owned source/SwiftPM jobs are terminal;
NTSDNative linked, with no app window or device exercised. Exact process
handles, test logs, source/native manifests and failures are retained in
`build/research/lib-world-hits-work.json`. No completed source corpus is restarted
or overwritten; the producer's partial checkpoint remains explicitly incomplete.

```sh
uv run tools/oracle_lib_world_hits.py
uv run tools/oracle_lib_hits_pristine_changes.py
python3 tools/verify_lib_world_hits.py
swift test --package-path native -c release --filter 'Original(LibActorHits|ActorHits|GameplayHits)Tests'
python3 tools/verify_lib_world_hits_artifacts.py
```

Reproduction requires fresh output locations/workspace because source producers
reject existing completed raw files. Loading/transform dependencies and full
library-enabled initialization/routing, actual Windows, full match/content,
application controls/output/audio and clean-macOS verification remain open.
