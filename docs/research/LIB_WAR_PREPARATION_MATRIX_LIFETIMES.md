# War matrix: correction to the synthetic bitmap allocation reserve

This supplements the frozen [matrix inputs](LIB_WAR_PREPARATION_MATRIX_INPUTS.md)
and [finite plan](LIB_WAR_PREPARATION_MATRIX_PLAN.md). Recover the original War
arena load/release/reload and recording lifetime order using pinned NTSD EXE,
lib.dll, VC80 and original BG files, Unicorn2.1.4/CW023f/C locale. Allocation,
memory and instruction traces distinguish new owners from retained freed bytes.
The allocator is a declared research boundary, not Windows or host behavior.

Capture1 completed25 whole calls, then stopped at the synthetic4450ac allocator
assertion on the31st accumulated arena wrapper, during arena1 reload. The source
did not receive that allocation and did not reach a memory fault. This was a
test-reserve error, not an original allocation failure or safeguard refusal.
PID83187/session31910 ended with exit1 at2026-09-11T22:49:45.943315UTC; its
662 pins, full failure trace and25 atomic completed parts remain unchanged.
The review is retained as war-preparation-matrix-capture1-review.json under
build/research/lib-war-preparation. Never resume that terminal process.

The defined original BG+1c values for arenas0..16 are
15,27,13,23,9,17,8,20,27,25,5,21,6,30,8,26,22. A single load needs at most30;
two loads with dead owners retained need60. The frozen inputs' earlier statement
“at most30 across load/99/reload” is incorrect and remains preserved as history.
Arena1 needs54 retained wrappers; arena13 needs60. Arena99 loads none.

Capture2 reserves60 wrappers at76004020+index*2000, following the existing two
War wrappers. The extra disjoint76040000..7607ffff mapping extends the existing
76000000..7603ffff arena reserve. Allocation size1f50, guard bytes, unknown
initial backing masks, address formula and all original call/return checks stay
the same. Actual surface Release precedes wrapper free. Freed allocations,
bytes and masks remain recorded; no live owner is replaced. Original resources,
instructions, participant inputs and the256-case manifest remain unchanged.

Freeze the corrected producer, this supplement and all25 completed old parts
before a fresh capture. Require exact full-part bytes for those25 calls and
the same40 old resource/ready parent calls. Do not import a failed after-state.
Stop and preserve any source fault or safeguard refusal. Source success alone
does not establish Native equivalence, played-battle reachability, Windows,
device or full-game completion. The finite resource-error study remains open.
