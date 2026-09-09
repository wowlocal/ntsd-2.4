# Complete post-draw slot lifecycle

`OriginalPostDrawLifecycle` implements the entire live 400-slot loop
`41f550..4214cf`, stopping before `4214d5`. Each slot completes transformations,
recovery, the scheduler, opoint and its selected creation/lifetime continuation
before the next slot is inspected. Newly active later slots run in this same
pass. Earlier slots are not revisited, and Actor aliases are not deduplicated.

The implementation composes [the slot prefix](POSTDRAW_SLOT_PREFIX.md) and
[opoint/early lifetime](POSTDRAW_OPOINT.md), adding `4203b4..4213a4` and the
original slot advance. An opoint attempt, including a failed one, bypasses the
weapon/command block and reaches late effects. Early lifetime bypasses both.

EXE SHA-256:
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.
Source checks execute the original instructions, constructors, scheduler, RNG,
both sound helpers and conversions. Constructor memset retains its established
host boundary. The CPU explicitly uses CW027f/53-bit arithmetic; legacy and
SSE2 conversions are separate declared inputs. This is controlled instruction
evidence, not a full Windows run or natural initialized match.

## Weapon destruction and fragments

Types 1, 2, 4 and 6 with signed Actor+31c below zero set it to zero and enter
weapon destruction. Header+ac requests catalog sound when nonnegative.
The original source ID determines the fragment count:

| Source ID | Count |
| --- | ---: |
| 100, 213, 217 | 5 |
| 101, 218 | 7 |
| 120, 124, 201 | 3 |
| 121 | 4 |
| 122, 123 | 9 |
| 150 | 13 |
| 151 | 15 |
| All others | 0 |

Each iteration finds the first free slot 50..<400 and searches for ID999.
Construction preserves the allocation's backing and defined mask, binds the
selected Object and loads header+90. RNG streams 166/167 set wrapped integer
X/Y to parent coordinates plus a draw in 0..<7 minus 3; Z is copied. The three
integer coordinates are converted to binary64. Streams 168..196 supply the
original velocity and frame groups. The detailed ID/ordinal rules are directly
transcribed in `weapon`, `frameDraw` and `velocityDraw`; no character handler
registry or allowlist is involved.

The count uses the original parent ID. Subsequent independent ID checks reload
the parent after construction and child writes, so an aliased free allocation
can change which rules execute. The parent slot is deactivated even when the
count is zero or no slot is free. Late effects still execute afterward.

## Team commands

For slots below 10 with positive HP and type0, Actor+40c/410/414/418 sequences
`9,0,9,0`, `9,9,9,9` and `9,5,9,5` select commands 100, 102 and 104.
The five words +418/414/410/40c/408 clear before slot/catalog failures.
The first free slot and first ID998 produce an effect with frame 0, 2 or 4,
parent integer X/Z, Y0 and horizontal/vertical velocity0. Constructor depth
velocity0.1 is retained.

The original then inspects all 400 slots in order. Only activity exactly1,
positive HP, type0 and the parent's freshly re-read team qualify. Command100
uses RNG197/198, range81, to write +3fc/+400 destinations around the effect's
current integer X/Z minus40. Commands102/104 set or clear Actor+404. The
created effect can itself qualify if its Object is type0.

## Late effects and retained caller words

A previous state13 or previous frame200, followed by neither current state13
nor current frame200, requests built-in sound15. A successful ID999 lookup
creates up to15 effects, with frames120/130/125/135 by ordinal. RNG199..202
sets binary64 X/Y, vertical velocity and horizontal velocity incorporating
half of the parent's pending velocity at +28.

Previous states18/19 create seven fire effects on leaving those states.
Remaining in either state draws RNG203/range4 and creates one effect only for
result0. Each creation searches ID999 and uses RNG204..207: binary64 X/Y
offsets, vertical velocity−1, horizontal velocity incorporating the parent's
current +40, and frame140. The range1 call still advances RNG.

Both effect paths copy parent integer coordinates and binary64 Z first.
Later binary64 X/Y randomization does **not** reconvert integer X/Y. Finite
arithmetic preserves each x87 rounding step and separate binary64 stores.
Common completion copies current frame+70 to previous frame+78, even for a
slot deactivated by weapon destruction.

`OriginalPostDrawScratch` carries six retained caller words in SP offset order:
fire slot+44, fire Object+50, death slot+5c, weapon slot+60, weapon Object+6c,
and prefix particle Object+70. Slot words retain their incoming value on a
full pool and otherwise hold the last selected slot. Failed weapon/fire
catalog searches consume their retained Object index. A missing optional
index fails only when actually dereferenced; a full pool avoids that read.
Command and death-effect lookup failure instead skips creation.

These fields describe the words at stage boundaries, not all temporary stack
contents during construction. Other caller temporaries and opoint slot arrays
remain outside this API. Their provenance in the initialized parent has not
yet been connected. No default Object index is invented for shipping use.

## Differential evidence

The corpus contains 5,432 cases: 921 entire live-slot loops and 4,511
post-scheduler single-slot continuations. It includes all 897 accepted prefix
inputs and all 1,991 accepted opoint inputs, reconstructed from their declared
inputs only. Old expected outputs are never injected. The acceptance script
checks input translations and both original capture/fixture hashes.

New controls cover source-ID/type gates, all weapon counts and frame groups,
full/partial pools, catalog misses, parent/free and free/free aliases, command
target filtering, previous/current state transitions, RNG wrapping, finite
numeric extremes and newly created later slots. Inputs explicitly supply
Actor+31c where needed; the constructor does not define this field.

Native independently constructs every input and compares all 424,408
World/Actor bytes and defined masks, all 46,144 global bytes, all six retained
words, the selected exit and 25,638 ordered events: 6,360 constructions,
18,116 RNG calls, 974 catalog sounds and 188 built-in sounds. The source
checks 71,283 helper returns, stack restoration, preserved registers, canaries,
defined-byte reads, immutable Object storage, CW and empty x87 tags.

| Range | Executed / disassembled instructions |
| --- | ---: |
| 41f550..4214cf complete loop | 1,885 / 1,892 |
| 4061d0..4064cc constructor | 151 / 151 |
| 40d960..40de20 scheduler in these callers | 164 / 316 |
| 416fb0..417082 catalog sound | 56 / 58 |
| 417090..417162 built-in sound | 41 / 58 |
| 417170..4171bc RNG | 26 / 29 |
| 4450d0..44517a conversion region | 47 / 55 |

The seven unexecuted loop PCs are the negative-created-count adjustment
42030a/b/e and alignment instructions 420da4/420dab/420dad/4213cd. The former
cannot be reached with the nonnegative created count; jumps bypass the latter.
The [scheduler study](ACTOR_SCHEDULER.md) covers its wider standalone domain;
this caller corpus does not inherit those execution counts. Instruction counts
do not prove every branch outcome or natural DAT sequence.

One source-observer defect was found during comparison: nested sounds in
40d960 were labelled with its temporary EDI instead of the saved caller slot.
Pool, masks, globals and retained words already matched at that failure.
The observer now reads the pending scheduler call's saved slot, and the entire
source corpus was rerun. No original instruction or native game rule changed
to resolve that metadata mismatch; the earlier unpublished capture is retained
as `build/research/postdraw-lifecycle-initial-events.json`.

All World/Actor/global/scratch changes commit atomically. A rollback test throws
on the second effect constructor after an earlier slot and four RNG calls;
all state returns to its original value. Another tests missing retained fire
Object provenance versus the no-dereference full-pool path. Event consumers
must buffer external effects until the enclosing tick commits.

## Reproduction and remaining work

```sh
uv run --script tools/oracle_postdraw_lifecycle.py
python3 tools/accept_postdraw_lifecycle.py
swift test --package-path native -c release --filter OriginalPostDrawLifecycleTests
```

Run SwiftPM commands sequentially. The raw comparison passed all three tests
in 7.818s after a 23.09s release build. Acceptance passed nine release tests
in 10.454s after a 127.58s build, including both retained component suites,
before publishing the new fixture. The final packaged run passed all three
tests in 8.156s after a 129.66s build, without a raw-corpus override.

The [evidence report](../evidence/postdraw-lifecycle.json) pins the
12,872,805-byte raw capture and 410,044-byte lossless packed fixture.
Independent decompression verifies complete JSON equality, lengths and SHA-256.
All 159 old fixtures remain unchanged; all 160 current hashes were verified.
The local records are `build/research/postdraw-lifecycle-fixture-pins.json`
and `build/research/postdraw-lifecycle-artifact-verification.json`.
NTSDNative linked; no app window was tested. Python compilation, 570 local
documentation links and diff checks passed. Source and SwiftPM processes
were terminal before the milestone commit.

Next connect this entire pass to the two initialized own chains ending at
41f550/SP1000e9bc, preserving their own stack words, pool, loaded DAT and
53-bit context. Then continue from 4214d5 toward the first complete tick
return. That parent connection, complete tick, app integration, natural
Naruto/Sasuke District match and broader game coverage are still open.

General nonfinite effect arithmetic, invalid Frame/catalog references and
pathological caller-stack overflow are not claimed as native-equivalent.
Windows runs, device timing/image/audio and clean-macOS delivery remain open.
