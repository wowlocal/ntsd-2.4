# Pending queued-sound consumer

This plan records **static findings**. The subsequent [QUEUED_SOUND](QUEUED_SOUND.md)
study now implements and compares whole419e60/401a30 in968 raw calls. Its own
initialized join and actual device playback remain open before a full tick return. [plan_queued_sound.py](../../tools/plan_queued_sound.py)
checks the pinned EXE hash and decodes145 queue instructions,30 instructions in
401a30 and15 in the actual gameplay output caller. The artifact is
build/research/queued-sound-static.json. Memory/global analysis is needed to retain
queue ownership, pending-flag changes, wrapped arithmetic and request order when
implementing native audio; no original EXE or DirectSound runtime will ship.

## Queue order and arithmetic

The device word44eecc gates the entire function. When zero, even pending flags
remain untouched. Otherwise the caller visits all400 catalog slots, then all80
built-in slots, regardless of the loaded-resource counts elsewhere in globals.
Each array uses four-byte slots:

| Group | Pending flag | First weight | Second weight | Buffer token |
| --- | --- | --- | --- | --- |
|Catalog,400|457588|452170|457bc8|452948|
|Built-in,80|453e10|4554c8|4527e8|451db0|

A slot is processed only for a **signed positive** pending flag. Its two weights
are added with32-bit wrapping and the flag is cleared before testing that sum.
Sums above100 clamp to100; sums at or below0 skip the device requests after the
clear. There is no invented lower clamp followed by a zero-volume play request.

Let `w(a)` mean32-bit signed wrap, `/` signed division truncating toward zero,
and `level=min(w(first+second),100)` on the positive-sum path. Static arithmetic:

- Pan is `w(w(first-second)*1500)/100`, sent through COM offset40.
- Base volume is `w(w(global44d000-100)*3800)/100`.
- Weight attenuation is `w((level-100)*2000)/100`.
- The two volume terms are added with32-bit wrap and sent through offset3c.

Only after both pan and volume calls does the caller reread44d000 and call401a30
when its signed value is positive. COM HRESULTs do not select an early exit.
Global reloads and buffer identities must remain live in the declared callback
contract; arbitrary COM reentrancy/global mutation is not yet a native domain.

401a30 rechecks44eecc and its buffer word. If both are nonzero, it requests
Stop(offset48), SetCurrentPosition(offset34,value0), then Play(offset30,0,0,
loopArgument!=0). It rereads the buffer word between requests. The queue caller
supplies loop0. A null buffer on the queue's positive-sum path is reached earlier
by the pan dereference; do not treat401a30's separate null guard as protection for
that earlier access. Actual source faults and native rejection need a separate
explicit comparison if included in the corpus.

## Composition boundary

422994 reads mode and450b84, calls whole41b130, calls4028a0 with455608, and calls
43e940 with458348. It removes the two cdecl arguments, calls419e60, then jumps
to422a95. The caller does not branch on queue output. Its final SEH/cookie/stack
restoration and422ab8/ret4 still require a whole original continuation.

The existing labels and presentation helpers do not prove this enabled sound
consumer. Controlled source probes should preserve all globals/masks, actual
normal helper returns and ordered COM requests, including negative/zero/positive
flags, both weight sums, wrapping products, volume gates, both array ends and
buffer aliases. Native observer failures need rollback after earlier flags have
cleared. Actual macOS playback, Windows/device behavior and the initialized own
join remain separate from numeric/request equivalence. See
[TICK_TAIL_PLAN](TICK_TAIL_PLAN.md) for the containing tick.
