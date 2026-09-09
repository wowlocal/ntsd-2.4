# Whole queued sound

`OriginalQueuedSound` implements419e60..41a043 and401a30..401a6f/ret4. All968
controlled original calls match the native raw comparison:952 whole queue drains
and16 direct playback-helper controls. The raw test passed0.563s. Alongside the
86-case result-recording comparison, two tests passed11.112s after a52.76s build.
The first two source calls had passed0.003s after a147.68s test build. This study
is now published after result-recording and preceding dependencies.

## Game behavior and environment

This is the enabled sound consumer required by the gameplay tail. The existing
`OriginalGameplaySound` producers already accumulate the same channel arrays.
Instruction/global-write traces are needed to preserve pending-flag ownership,
pan direction, integer overflow and device request order across the native port.
[oracle_queued_sound.py](../../tools/oracle_queued_sound.py) executes the pinned
original EXE atCW023f/FPSW0/tagffff with declared global queues and opaque COM
buffer words. Numeric HRESULTs are supplied; the actual game helpers execute.
No real audio device, Windows startup, private COM implementation, arbitrary
reentrancy or initialized whole tick is part of this comparison.

The global44eecc device guard precedes all queue accesses. With a device,400
catalog slots run before80 built-in slots. Signed nonpositive flags are left
untouched. Positive flags clear before the wrapped channel sum is tested. A sum
above100 clamps to100; a nonpositive sum skips requests after the clear. Source
slot counts are fixed and do not follow loaded-resource counts.

The source reads the **right-channel weight first**, then left. Pan is signed
`wrap(wrap(right-left)*1500)/100`, using division toward zero. Volume combines
`wrap(wrap(global44d000-100)*3800)/100` and
`wrap((clampedWeight-100)*2000)/100`, with a wrapped sum. Pan(offset40) and volume
(offset3c) requests happen even when master volume is nonpositive. Only the final
playback call is gated by a fresh signed-positive44d000 check. No extra clamp or
HRESULT-driven exit is invented. Exact arrays are in [QUEUED_SOUND_PLAN](QUEUED_SOUND_PLAN.md).

Whole401a30 rechecks device and buffer, then requests Stop(offset48),
SetCurrentPosition(offset34,0), and Play(offset30,0,0,loop!=0). The queue supplies
loop0; direct controls include zero/nonzero loop arguments, missing device and
null buffer. These leaf null guards do not protect the queue's earlier pan
pointer dereference. Null queue buffers on a positive-sum path remain outside
this successful-call corpus; do not call their absence a resolved fault domain.

## Comparison and provenance

Every one of480 queue positions is exercised. Additional controls cover signed
flag/weight/volume boundaries, overflowing sums/products, both group ends,
all480 pending slots at once and shared buffer tokens. Fourteen identical numeric
specifications were deduplicated before the full source run; its968 labels and
inputs are unique. The source and native preserve1410 global flag stores/5640
requested bytes and all8314 events:1410 queue writes,1128 playback-helper entries
and5776 COM requests. The requests include1214 pan,1214 volume and1116 each of
Stop/SetCurrentPosition/Play. No source expected after-state is injected.

2080 normal helper returns check saved registers and stack cleanup.11552 resource
reads remain inside declared COM buffer/vtable words. The173 actual EXE PCs cover
143/145 queue starts and all30 playback starts;419e78/419e7f are skipped alignment.
This does not establish every branch outcome or native private-object ABI.
CW/FPSW/tag are unchanged, and no DLL code executes.

The native caller stages globals until the complete drain succeeds. A thrown
observer on the second slot's volume request, after one complete playback and
two flag clears, restores all original global bytes/masks. Numeric method failures
are ordinary source results and do not trigger that rollback. External audio
requests must be buffered by the whole-tick owner; already performed platform
effects cannot be undone by restoring game records.

Both source captures and their SwiftPM jobs are terminal. Clarifying native local
names to match the producer's right/left channel convention changed no arithmetic
or expected output. [accept_queued_sound.py](../../tools/accept_queued_sound.py)
passes its independent `--verify-only` check: full raw JSON,2344 transport blobs,
all global writes/masks, helper ABI, resource reads and instruction inventories.
Raw9456172 bytes have SHA256
`83cf3d51097cc45e0c0254d3b6815a2b4c39b490aaa33f77065e942674c7aeb8`.
Publication follows181 fixture pins and adds the182nd. The shared raw acceptance
set passes this test in0.517s. All2344 inner blobs and the3916467-byte packed fixture
are independently verified; evidence is [queued-sound.json](../evidence/queued-sound.json).
Own initialized enabled
sound, macOS device playback, whole output order and actual422ab8/ret4 remain open.

Final packaged verification: the ten-test release set passes58.142s after a0.23s
resource-copy build, without raw-corpus overrides. This study takes0.563s. All
source and SwiftPM jobs are terminal; full artifact/pin/vendor checks pass. This
does not establish an app-window, Windows or actual device result.
