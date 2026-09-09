# Whole original Actor frame scheduler

`OriginalActorScheduler` implements all of40d960..40de20 and calls the existing
native catalog-sound accumulator corresponding to416fb0..417082. Original
instruction comparisons cover both complete functions. This replaces no
existing Practice pipeline yet: the new component belongs in the interleaved
400-slot lifecycle loop being recovered after41f550.

EXE SHA-256:
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.
The source run pins this pristine EXE and uses explicit CW027f, FPSW0 and empty
tags for each complete call. Neither scheduler nor sound helper is stubbed.

## Caller and order

The ordinary caller41faf8..41fb06 passes global451160 as the first argument
(mode), and the current slotEDI as the second. The helper returns with `ret 8`.
Caller41fb0b reloads the current Actor and frame, overwriting EAX before using
it; the scheduler's incidental EAX is not part of the native interface. The
other static call site4153d9 passes zero/zero and also overwrites EAX at4153de.
That surrounding415xxx path is not claimed as implemented by this study.

The scheduler runs after drawing. Recovery/transform/spawn work precedes it
for the same slot; post-schedule actions, opoint and deletion follow that slot
before the loop advances. Do not replace this with a separate scheduling pass
over all Actors. A later free slot created during the loop can still be visited
in that same pass. The surrounding caller is the next task, not part of this
standalone comparison.

## Recovered rules

The implementation reads raw Actor/header/Frame records and preserves signed
32-bit wrapping and byte signedness. Frame metadata is re-read after transitions.
The rule order is:

1. Nonzero Actor+b4 skips the function unless Object type is3. Otherwise the
   positive+ec counter decreases, even when a negative+98 or Frame+88==2 then
   skips the rest. These exits do not update previousFrame.
2. Type3 with positive Frame+24 subtracts that value from HP with wrapping.
   A nonpositive result becomes0 and currentFrame becomes Frame+28.
3. Actor+8 moves one step toward zero, while positive+b0/+b8 decrease. The+ea
   byte decreases only when positive as **Int8**, not merely nonzero.
4. If currentFrame differs from previousFrame, its nonnegative Frame+174 sound
   is queued, then wait resets. Wait always increments afterward, with wrapping.
5. A nonnegative Object type in state0 and integerY<0 changes to frame212.
   Type2/state2000 on integerY==0 changes to frame20 only for strict
   `-0.1 < vx < 0.1`. These transitions retain the just-updated wait.
6. State14 with nonpositive HP clears wait. If Actor+2f4>=0, Actor+364==5 or
   slot>=20, nonpositive Actor+8 becomes30. State2000 sets facing0 for vx>0,
   facing1 otherwise, including zero and the tested unordered comparison.
7. If signed wait exceeds the current Frame wait, wait resets and nonzero next
   is written. Negative next flips facing with byte wrapping and negates next
   with Int32 wrapping. Next999 becomes212 only for type0 with integerY!=0;
   otherwise it becomes0. A resulting frame outside0..<400 returns immediately,
   preserving the written frame/facing and the **old previousFrame**.
8. When previous state14 enters a state other than13, Actor+8 normally becomes15.
   Actor+364==5 or nonzero+344 suppresses this when global450c30==2. In modes1/4
   those same Actor categories also suppress it for sourceID/10==3, except38.
   This ID rule comes from40dc6a..40dc89; it is not a new character allowlist.
9. Entering212 through an explicit next, rather than the airborne999 path,
   loads jump velocity from Object+50. Right1/left0 and left1/right0 select
   ±Object+58. Nonzero up with zero down selects−Object+60; zero up with nonzero
   down selects+Object+60. Noncanonical input bytes matter to these conditions.
10. The newly selected frame queues its own nonnegative sound. Thus a single
    scheduler call can queue two sounds, even the same index twice.
11. Negative Frame MP with enabled global44d034 applies the original signed
    comparison `currentMP >= negativeCost`. The taken branch adds the negative
    field to MP and subtracts it from Actor+350, both wrapping. The other branch
    changes currentFrame to Frame+28. The newly current frame's positive+28
    can then redirect once more for grounded left/facing0 or right/facing1.
12. Common tail sets+c1=3 for frames110/114, Actor+8=20 for202, then copies the
    final currentFrame to previousFrame. The earlier invalid-next return skips
    this tail; a zero next reaches it without jump/sound/MP transition work.

There is no floating arithmetic in this scheduler: only binary64 loads, x87
comparisons, sign changes and stores. Finite values, signed zero, subnormals and
infinities are compared exactly in the captured domain. The velocity comparison
includes a quiet NaN input, but does not claim FPU exception/status equivalence.
Header NaN load/store payload handling remains explicitly unsupported by native;
no scalar clamp or replacement is introduced to hide that boundary.

## Differential evidence

`oracle_actor_scheduler.py` executes original Actor constructors on a5/ramp
backing, then supplies explicit raw Object/Frame/global controls. All400 Frame
records have declared initial bytes; subsequent patches do not alter the EXE
or original game assets. The constructor's memset remains its established host
boundary. Each call checks Actor read provenance, full returned Actor bytes and
masks, unchanged Object bytes, both Actor canaries, callee-saved registers,
return stack, unchanged CW and empty x87 stack/tags.

| Controlled input group | Calls |
| --- | ---: |
| Early gates and partial counter updates | 320 |
| Signed counter/byte and wait boundaries | 168 |
| Next/sign/999/type/Y transitions | 2,208 |
| Type3 HP updates | 48 |
| State2000 velocity comparisons | 156 |
| State14 HP/counter/slot conditions | 192 |
| Previous-state recovery, mode/category/source-ID conditions | 448 |
| All four direction bytes, including2/255 | 256 |
| Jump velocity bits and direction combinations | 128 |
| Negative MP and subsequent redirects | 1,728 |
| Common tail frame conditions | 18 |
| Repeated sound with stereo/wrapping controls | 378 |
| Airborne state0 followed by frame212 metadata | 36 |
| Total | 6,084 |

All316 scheduler instructions and all58 sound instructions execute, with no
missing instruction address in either function. This does not establish every
conditional outcome or all possible caller inputs. The source records30,189
Actor writes at35 instruction addresses; their order is retained as source-only
evidence. Native compares all6,424,704 Actor bytes and defined masks, SHA-256 of
the whole46,144-byte globals record per case, and all756 ordered sound requests.
The sound helper actually executes in the source VM, including its global
accumulation; no expected sound globals seed native. All378 sound controls
queue twice. These are queued sound values, not DirectSound output/mixing.

Native starts from its own constructors and declared input patches. The public
API accepts any `OriginalLoadedObject`; rules use its header and Frame storage.
No per-character registration is added. Atomicity tests fail after an earlier
sound/counter update and, through the public API, after the second sound observer:
both Actor and globals remain exactly unchanged. Observers must buffer external
effects until their enclosing tick commits.

## Acceptance and next work

```sh
uv run --script tools/oracle_actor_scheduler.py
python3 tools/accept_actor_scheduler.py
swift test --package-path native -c release --filter OriginalActorSchedulerTests
```

The first comparison invocation used an incorrect relative corpus path and
failed before loading source results. With the absolute path, all three tests
passed in2.462s (release build19.37s). Source expectations were unchanged.
Acceptance verified corpus identities/counts/instruction inventory and all156
previous fixture hashes, then compared native before publishing a new lossless
resource: three tests passed in2.481s (build123.29s). The final packaged run,
without a raw-corpus override, passed the same three tests in2.460s
(build124.29s). NTSDNative compiled and linked; no window/device check is implied.

The [evidence report](../evidence/actor-scheduler.json) pins the30,408,268-byte
raw capture and338,300-byte lossless fixture. Independent decompression verifies
the complete JSON, lengths and SHA. All156 old fixture hashes remain unchanged;
157 current pins and artifact checks are retained in
`build/research/actor-scheduler-fixture-pins.json` and
`build/research/actor-scheduler-artifact-verification.json`. Python compilation,
local research links and diff checks pass. Source and all SwiftPM processes are
terminal before the milestone commit.

Next recover the enclosing41f550..4214cf loop. Its prefix includes original
state9995→sourceID50, state8000..<9000→sourceID(state−8000), state9996 particle
creation and HP/MP recovery41f994..41faf8. Subsequent scheduling/opoint/deletion
must retain live slot aliases, allocation reuse, resource/RNG order and the
original caller scratch provenance. Do not bypass those blocks merely because
the first Naruto/Sasuke call does not enter them.

The initialized own chain still ends at41f550/SP1000e9bc in its first unreturned
tick. Natural DAT sequences, whole caller integration, other modes, Practice/app
wiring, full match, Windows/device output and clean-macOS delivery remain open.
