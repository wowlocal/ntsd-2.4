# NTSD 2.4 → 2.8.3.3: engine evidence pass

2026-10-17. Parent `6b24cd1f`; local `exp/ntsd-2.8.3.3` only.
User requested the bounded investigation described after the
[implementation plan](NTSD_2_8_3_3_IMPLEMENTATION_PLAN.md). Static pass and
controlled RNG pilot complete. No engine-wide reuse percentage is measured.

## Question, scope and consumer

Which existing mechanisms have comparable target code, what changes are visible
in that code, and which mechanism can test reuse with the fewest unknown inputs?
The consumer is the target startup/storage/gameplay work in M1–M3. Its concrete
blockers are unestablished target layouts, input provenance and missing content;
the existing Native handlers cannot be connected by replacing their address constants.
This request gathers evidence; it does not start the complete implementation queue.

Read WORKFLOW, PROGRESS_RULES, CURRENT_WORK, RESEARCH_MAP, TASK_TEMPLATE and the
archive's decoder/loader/storage constraints. Reuse the completed inventory and
dump validation, not their captures. Source artifacts and exact SHA pins are in
[run1 evidence](../evidence/ntsd-2.8.3.3-engine-diff-20261017-run1.json).

Frozen plan: `/Volumes/T7/ntsd-2.4-artifacts/version-diff-20261017/engine-diff1/plan1.json`.
Bounds: 90 minutes, 32 named entry/fragment anchors, first recorded main-code
section only, ≤8 MiB module reads per invocation, ≤16 KiB disassembly per candidate,
≤64 MiB new artifacts. T7 writable ExFAT/UUID and ≥40 GiB reserve were checked;
approximately 1.24 TiB free. No build or APFS-dependent output is needed.

Actual operation: read saved standard MDMP metadata and NTSD's already-recorded
x86 instructions; compare against the pinned 2.4 EXE using `inspect_original.PE`
and configured Capstone 5.0.7. The new
[reader/comparison adapter](../../tools/compare_ntsd_engine.py) handles a memory
snapshot, which the existing file-layout PE reader cannot address directly.
It does not execute code, rebuild an EXE, extract resources, inspect arbitrary
heap contents or unpack/devirtualize another region. Missing pages stay unknown.
The earlier packed-content incident and its exact-unknown trigger remain open
under [the plan](NTSD_2_8_3_3_IMPLEMENTATION_PLAN.md#inputs-and-evidence-limits).
No affected operation is resumed by this static instruction comparison.

Writable paths: this study, its dated evidence, the comparison adapter, task-owned
T7 directory and CURRENT_WORK. Original distributions/dumps, Native, old evidence,
expected/masks, plans, archive instructions, unrelated work and live jobs are protected.
Author owns all task paths; independent contract review is unavailable and open.

## What was actually established

The live dump contains readable code for the PE32/x86 NTSD module. Its lowest
executable section spans `0x401000..<0x497000`: **614,400 recorded bytes**, SHA-256
`9364fc67c15991140a8d379987c23e70bb33660f104a1d6e9203a056a1079eb0`.
That span is not a measurement of unique game logic or behavioral coverage.
Other sections also have executable flags; they were not searched here.

The MDMP has 16 directory entries, including five empty unused entries, and 11
nonempty streams. Its module list has 93 entries, including two identical NTSD
records at `0x400000`, SizeOfImage 4,591,616. Preserve the duplicates; these are
not 93 proven unique dependencies. The saved Windows ARM64 observation and its
limitations remain in [the capture card](NTSD_2_8_3_3_WINDOWS_MEMORY.md).

### A concrete reusable candidate: game RNG

Both complete routines occupy `0x417170..<0x4171bd`: **77 bytes, 29 instructions,
two returns**. Every instruction, register, branch and numeric constant agrees;
the five different instructions reference these relocated state identities:

| State | 2.4 address | 2.8.3.3 address |
| --- | --- | --- |
| Table | `0x44ff90` | `0x49ff90` |
| Index | `0x450bcc` | `0x4a0bcc` |
| Counter | `0x450c34` | `0x4a0c34` |

All five reference changes are `+0x50000`. Reversing only those observed address
changes reproduces all 77 baseline bytes exactly. Constants 3000 and 1234,
signed division, nonpositive-range return and update/store order remain intact.
This supports reusing the algorithm in
[OriginalRandom](../../native/Sources/NTSDCore/OriginalRandom.swift); it does not
prove seed/table initialization, callers, RNG consumption order, whole-match
equivalence or target Native state ownership. No captured state is imported into Native.

### Concrete changed instructions: candidate camera/World path

The known baseline camera entry and target candidate share a distinctive prefix
at `0x41b5d0`; the target's complete surrounding caller has not been compared.
Static range observations:

| Instruction | Baseline | Target |
| --- | --- | --- |
| `0x41b617`, table address | `lea edi,[edx+0x194]` | `lea edi,[edx+0x3ec]` |
| `0x41b8d7`, loop bound | `cmp ecx,0x190` (400) | `cmp ecx,0x3e8` (1000) |
| Terminal `ret 8` | `0x41bc87` | `0x41bc97` |

The ranges contain additional changed accesses, calls and instruction sequences;
this is not only an address relocation. The loop-bound observation supports the
documented larger live-object capacity, but does not establish every pool layout,
actual 1,000-object play or allocation/error behavior. A field offset is evidence
for its particular access; it is not a complete World/Actor storage specification.

### Purpose-selected sample of 32 entries/fragments

Three sampled prefixes are byte-identical at their baseline VA; five retain the
same instruction/operand shape with changed numeric operands. The other 24 have
**unresolved identity at that VA**. These are not counts of unchanged/changed
functions. For example, the baseline match entry `0x41bc90` now falls in another
routine's tail; a unique 12-instruction candidate prefix appears at `0x41c3d0`.
Likewise, an old physics address can land inside an instruction. A raw same-address
diff would incorrectly classify such cases as new gameplay behavior.

The candidate search ignores numeric values only to find matching shapes. All
operand changes remain in the raw result. Generic SEH prologues match several
unrelated functions; these ambiguous hits are explicitly retained. Linear
disassembly can miss real starts or decode data. No global similarity percentage
or implementation-hour estimate follows from this sample.

## Checks, preserved failures and reproduction

`availability-command1.json` retains a reader error: duplicate kind-0 directory
padding was incorrectly rejected. Correction1 accepts only canonical empty unused
entries. `availability-command2.json` retains a second reader error: assuming a
unique NTSD basename. Correction2 selects the saved base/size and requires all
matching records to agree, while preserving the full list. Third availability
run succeeds. These are harness errors, not source crashes or altered captures.
No completed successful source capture was repeated.

Checks: baseline full SHA; reused previously verified dump SHA/size; mapped-range
bounds; nonempty-stream/module accounting; missing-memory rejection; full RNG
byte/operand audit; retained loop-bound bytes; frozen artifact/tool hashes.
There is no original execution or Native test in this static stage. Author
checks are not independent behavioral review or full contract acceptance.

From the worktree, repeat only when new evidence or a reader correction justifies it:

```sh
python3 tools/compare_ntsd_engine.py --plan /Volumes/T7/ntsd-2.4-artifacts/version-diff-20261017/engine-diff1/plan1.json --anchors /Volumes/T7/ntsd-2.4-artifacts/version-diff-20261017/engine-diff1/anchor-cases1.json --output NEW_RESULT.json
```

The range comparison uses `--ranges .../range-cases1.json`. Exact commands,
versions, stdout/stderr, failures, raw differences and SHA pins are saved in
the external task directory and linked from the dated evidence. Original bytes
and historical expected/masks remain unchanged. No Native change or push.

The static checkpoint's next task, now completed below: compare both complete RNG routines on declared synthetic
tables/index/counter/range sequences, preserving cross-call state and recording
all side effects. It has no external calls or CRT/FPU dependencies. This tests
the reuse proposition without pretending the rest of the engine is equivalent.
Its execution needs a separate finite plan; original startup and arbitrary memory
are not part of that experiment. Target storage/init/caller integration remains open.

## Controlled RNG pilot and frame-storage observation

Parent `71a69488`. [Pilot evidence](../evidence/ntsd-2.8.3.3-engine-diff-20261017-rng1.json).
Frozen `engine-diff1/rng-pilot-plan1.json` declares 24 cases, 12 calls per chain,
20-minute budget, 1,000-instruction/one-second per-call limits and ≤16 MiB output.
T7 identity, writable state and 40 GiB reserve were rechecked before this stage.

This stage **executes the two unchanged 77-byte RNG routines in Unicorn 2.1.4**,
with Python 3.11.15 and explicitly supplied synthetic memory/registers. It reuses
the existing reference tools' stack/return convention. Their frame/movement
initialization cannot admit a captured target leaf and relocated state without
unrelated 2.4 side effects, so the adapter adds this finite leaf case. It does not
run either game's startup or read a table/after-state from the captured game.
No Windows/device, CRT, FPU, file or network responses are simulated: this leaf
uses only integer instructions and its three declared data identities.

Inputs: four declared 3,000-byte nonzero table patterns and six valid index/counter
pairs, including independent and simultaneous wrap boundaries. Each chain applies
`0,-1,Int32.min,1,2,3,255,1234,3000,Int32.max,0,17` without resetting RNG state.
Natural startup reachability of those exact tables is unestablished. Scratch
memory is explicitly filled `0xa5`; hooks reject undeclared code/data accesses,
so allocator fill is not promoted to original initialization. The stack argument,
register seeds and cdecl return contract are declared in the plan.

**Result: 24/24 cases equal, 288 returned calls per version, zero mismatches.**
All 29 instruction addresses and both returns were exercised. Per version there
were 192 updating calls and 96 nonpositive-range calls. EAX, all recorded general
registers/flags, final ESP, live index/counter and normalized ordered writes match;
raw storage addresses remain in the results. Tables stayed unchanged. Positive
calls store counter before index; nonpositive calls leave both untouched.

The successful source run took 0.262 seconds; that is execution time, not the
investigation or future mechanism cost. Post-run audits also compare the observed
results/state to the documented existing Native formula, verify saved registers,
table hashes and artifacts. The Native executable was not run. The conclusion
is limited to this controlled source/source domain and does not accept seed/table
generation, caller RNG consumption, target ownership or whole-match equivalence.

One setup assertion is retained: an offline uv command's temporary interpreter
had expired before use. The diagnosed correction invokes the cached configured
Unicorn environment through uv itself; no source run was repeated. The executed
producer snapshot is preserved. The delivered module description was corrected
to name its new optional executed mode; its executable AST is otherwise identical,
so a further source run was unnecessary.

A final bounded static check inside the selected special-AI address fragment
`0x403a40..<0x4061a0` confirms two same-address instruction correspondences:

| Instruction | Baseline | Target |
| --- | --- | --- |
| `0x4045c0` | `imul ecx,ecx,0x178` | `imul ecx,ecx,0x1b0` |
| `0x404cd0` | `imul edx,edx,0x178` | `imul edx,edx,0x1b0` |

The retained contexts load the frame index at Actor `+0x70`; the Actor's object
reference remains at `+0x368` in both versions. Actual frame-access code uses a
**376→432-byte multiplier**, while object-relative field accesses change
`0x7ac→0x838` and `0x7d0→0x85c`. This is
stronger than inferring capacity from a manual, but it is not a complete target
Frame/Actor/Object specification or an accepted whole-AI mapping.

The delivery audit rejected an earlier interpretation that the Actor reference
offset changed. Its exact failed assertion and raw contexts are preserved in
`delivery-validation1.json`; a [separate correction](../evidence/ntsd-2.8.3.3-engine-diff-20261017-rng1-correction1.json)
supersedes that statement in the first pilot receipt and draft text. Source bytes,
comparison output and the passing RNG verdict are unchanged; no source rerun.

The evidence supports keeping `OriginalRandom`'s arithmetic. Its production
target consumer still needs owned state initialization and recovered callers.
M0 remains the ready application integration task; the first changed engine
contract to recover is Frame/Object construction/loading and its consumers.
The new stride and pointer accesses explain why replacing resources or globally
changing `400` would be insufficient. Continue by proving those storage contracts,
not by estimating the whole engine from 32 prefixes or one simple leaf.
