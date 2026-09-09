# Whole Actor control with the installed library hook

[OriginalLibActorControl](../../native/Sources/NTSDCore/OriginalLibActorControl.swift)
matches7168 whole413080..4143cb/ret8 calls with the actual bundled
41408b->10001125 jump installed. Native compares all7569408 Actor bytes and
their masks, hashes of330760192 global bytes, and800 ordered events:
384 RNG and416 sound-accumulator requests. The old pristine control remains
available and its25795 cases still pass. This is a controlled function
comparison, not the initialized library-enabled game, a match or device output.

The original loaded catalog contains no state85/86, as detailed below. The
new branches are therefore tested here on explicitly supplied states; no
claim of natural reachability follows. Remaining library hooks and the fresh
application join take priority over expanding this synthetic matrix.

## Reference and environment

The reference EXE SHA256 is
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`;
bundled lib.dll SHA256 is
`28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba`.
Both come from the pinned original distribution. No on-disk game byte changes.

The source first runs the whole accepted445560..445565 entry/installer on
Unicorn2.1.4. Its installation result exactly reproduces the first accepted
[LIB_RUNTIME](LIB_RUNTIME.md) case, including complete image digests and all
thirteen actual patches. The same CPU then retains the installed code and
uses the declared stack20000000, controlled Actor arena22000000 and Object
backing50000000. Its two fresh Actor constructors reproduce the accepted a5/
ramp bytes and masks. Constructor memset remains an explicit adapter; input,
RNG, sound and new library helper bodies execute original instructions.

The7168 caller inputs and criteria were fixed in
[LIB_ACTOR_CONTROL_PLAN](LIB_ACTOR_CONTROL_PLAN.md):4096 new-state combinations,
384 routing controls,2304 same-call transitions and384 later-frame velocity
cases. The main corpus uses supplied CW023f; the final384 use037f. It does
not execute CRT initializer tables or recover that control word through a
new full startup. Both source and native setup bind only declared inputs;
no source after-state or caller-stack snapshot initializes Native.

Low-level register, x87, memory and helper observations recover values that
the inserted code consumes from earlier instructions in the same call. The
native implementation shares the existing whole control routine, adding the
installed rule through a separate public entry. It loads no DLL and changes
no executable memory at runtime.

## Recovered order and live values

The library forwards state5 to414099 and ordinary other states to414243.
States85/86 run10001178 twice, direction0 followed by direction1, then414243.
State85 supplies increment1; state86 supplies0. The helper still performs the
add/store when its predicate succeeds for state86. Source stores include1015
changed frame words and1015 unchanged frame words from this instruction.

For each direction value, the source changes facing if the right byte differs
from that value and the left byte equals it. This is not equivalent to testing
only boolean-exclusive directions. In particular, right2/left0 selects facing0;
right2/left1 selects facing1 on the second helper. The controlled matrix also
retains facing2/255 and all left/right pairs from0/1/2/255. Their natural input
provenance is not asserted.

After that facing update, the frame predicate requires facing equal to the
current direction and frame different from EDI. EDI is0 on all7168 hook entries,
with original producer paths413b3b/413d72. Frame0 therefore skips the FCOM and
frame store, while a preceding facing update can still occur.

Original413f90/413f97 leave ST(0)=1 and ST(1)=0. Every hook/helper/continuation
checkpoint retains those operands, TOP6 and tag4fff. The helper temporarily
exchanges them, compares zero with the current vx, and exchanges them back.
Direction0 advances only for vx>0; direction1 only for vx<0. Both signed zeros
do not advance. The tested numeric domain includes signed minimum subnormals
and signed largest finite binary64 values. NaN/infinity branches and hardware
exception/status equivalence are not claimed by this corpus.

The original restores ECX to the Object after the two calls. Common414243
consumes the two x87 values;414247 then rereads the newly selected frame for
dvx/dvy/dvz. Earlier blocks change the frame before this hook in1792 cases.
Those calls retain the earlier RNG, attacks, movement, costs and sound order.
At the hook,3136 cases have state85 and3136 have86;896 exercise other states.

Source executes1458 EXE and43 DLL instruction starts. All43 static starts of
10001125..100011b8 occur; this is not every branch outcome or whole-DLL coverage.
The source checks98720 helper returns and26880 hook/FPU checkpoints. Installer
instructions, constructor setup and the unexecuted terminal marker are not
counted as those1501 control-call starts. Native comparison covers semantic
storage/events; source FPU register/status history remains separate from
native process-wide x87/FPSW/tag equivalence.

## Storage checks and rollback

An independent verifier reconstructs every Actor byte/mask from its declared
constructor/input and111460 original stores, every complete global image from
declared input and2784 stores, and every unchanged262144-byte Object backing
hash from its input description. The extra zero-filled Object backing is
research storage, not a native allocation/ABI equivalence claim. The native
public operation uses its own supplied immutable header and400 Frame records.

The new native-only failure supplies frame41 in state85, facing1, right held
and positive vx, but omits frame42. The library rule stages facing0/frame42;
the later frame resolver rejects42. The entire Actor and globals roll back.
The retained pristine failure still rejects after an actual RNG draw and
rolls back both records. External callbacks must be buffered by the enclosing
transaction; storage rollback cannot undo already submitted external effects.
No source fault or safety refusal occurred in these7168 calls.

## Original DAT inventory

[inspect_lib_actor_control_catalog.py](../../tools/inspect_lib_actor_control_catalog.py)
independently verifies the accepted CW027f catalog transport, every complete
Object blob/mask and all137 original DAT hashes. All54800 inline state words
are defined;15363 slots have nonzero present flags. Neither state85 nor86
appears, including in the inactive slots. All42 type0 Objects are included;
duplicate IDs remain separate catalog entries.

[The inventory](../evidence/lib-actor-control-catalog-inventory.json) is static
data evidence, not a new game execution. It does not prove that later game
mutations can never create such a state. Preserve that distinction, and do not
invent original DAT modifications or a catalog-based85/86 trajectory merely
to exercise the new branches.

## Immutable artifacts and validation

Source: [oracle_lib_actor_control.py](../../tools/oracle_lib_actor_control.py).
Independent storage/ABI/FPU verification:
[verify_lib_actor_control.py](../../tools/verify_lib_actor_control.py).
Acceptance: [accept_lib_actor_control.py](../../tools/accept_lib_actor_control.py).
Complete packing/pin checks:
[verify_lib_actor_control_artifacts.py](../../tools/verify_lib_actor_control_artifacts.py).
Published report: [lib-actor-control.json](../evidence/lib-actor-control.json).

Raw111033202 bytes, SHA256
`e9401c809b578fbd4b47ac9ae47a57d2f060f39ef4bb74fb74b72173488c9fe1`.
Packed5591517 bytes, SHA256
`c490cdc1c1b745837047fdb889e892eaa37285243c356d2ac98f5ff6a6fe8016`.
Full restored bytes plus newline, complete JSON, lengths/SHA, all203 prior
fixture pins and ten codec vendor hashes verify;204 pins after publication.
Transport deflation does not replace the game's replay compressor.

The first raw four release tests pass15.865s/build174.66s:7168 library calls,
25795 pristine calls and both rollback trials. No game rule or source expected
result needed correction. Publication reuses that terminal run only after
checking its exact log hash and all516 isolated source pins.

The final523-file native-only export is based on acceptedfe20733 plus the same
three control files and the complete fixture. It includes the now-committed
stage-command/preparation work, and excludes unfinished transform work.
Its ten packaged release tests pass24.813s/build172.66s without raw overrides:
the preceding four tests plus4330 library commands,70 preparation/consumer
cases and retained command rollback tests. This verifies their coexistence,
not a newly composed initialized tick. NTSDNative linked; no app window or
device was exercised. Source and all owned SwiftPM jobs are terminal0.
Exact source/package/process evidence is in
`build/research/lib-actor-control-work.json`.

Six installed jump destinations, loading's two-byte companion, enclosing
library state, full CRT/application startup, full match/content, Windows,
window/audio/latency and clean-Mac validation remain open.
