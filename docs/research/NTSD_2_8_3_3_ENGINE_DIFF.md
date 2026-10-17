# NTSD 2.4 → 2.8.3.3: engine evidence pass

2026-10-17. Parent `6b24cd1f`; local `exp/ntsd-2.8.3.3` only.
User requested the bounded investigation described after the
[implementation plan](NTSD_2_8_3_3_IMPLEMENTATION_PLAN.md). Static pass complete;
controlled RNG comparison is next. No engine-wide reuse percentage is measured.

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

Next bounded task: compare both complete RNG routines on declared synthetic
tables/index/counter/range sequences, preserving cross-call state and recording
all side effects. It has no external calls or CRT/FPU dependencies. This tests
the reuse proposition without pretending the rest of the engine is equivalent.
Its execution needs a separate finite plan; original startup and arbitrary memory
are not part of that experiment. Target storage/init/caller integration remains open.
