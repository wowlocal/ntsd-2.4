# Frames outside the Object allocation

[Plan](APPLICATION_OUT_OF_OBJECT_FRAMES_PLAN.md). The original is not executed.

## Finding (2026-09-29)

A Demo soak in the app (eight computers, random characters, `--virtual-clock
123456789 8`, `--script-clock gameplay`) stopped in its seventh match at body
≈12,620 with "Cpoint Frame outside known Object storage". The error now names
the stage, Object, frame and header size; a temporary actor dump (not
committed) showed slot 52, Object 81 `chars\ironsand.dat`, current frame 1000,
collision frame 211 ("life_heal"). Frame 211 carries a kind-8 heal itr with
`dvx: 1000`; the kind-8 hit (`OriginalHitSpecial`) sets the attacker's frame to
that dvx between contacts and the cpoint pass. The original then reads that
Frame unchecked in cpoint actions (418c7b, 4192e8), cpoint placement (4187ed),
the draw loop (41a6ae, 41a6d0, then the picture) and the post-draw slot prefix
and scheduler, before its opoint continuation deactivates frames outside
0..<400. Frame 1000 is +0x5c464 into a 0x25360-byte Object allocation (corrected below).

## Declared policy

Frames ≥ 400 read as zero bytes (an absent Frame): one static record
(`OriginalCPointPass.beyondAllocation`) returned by the shared Frame fallback
of the cpoint, camera and drawing stages and by the post-draw lifecycle's
composed lookup. Effects: no cpoint; the draw loop draws the shadow for that
tick but not the picture (40be70 skips absent Frames); the scheduler finds no
transition and the opoint continuation deactivates the actor in the same pass,
as when the scheduler itself reaches next 1000. Frames ≤ −6 stay a boundary;
−1..−5 keep their recovered header aliasing. Error messages for these lookups
now carry the Object and frame.

**Checks:** a unit test (frames 1000, 400 and INT_MAX leave an actor unchanged
through cpoint actions and placement; −6 still stops; frame 399 is still read
and an unlinked kind-2 actor falls to 212); the accepted corpora pass
unchanged (world cpoints, gameplay cpoints, camera, drawing, impulses, post-draw
lifecycle, slot prefix, opoint, commands, gameplay and application lifecycle).
The same soak now plays through twelve Demo matches (≈25,590 bodies) and
stops at a different place, "World links: Frame binding" (417f80, held
items) — the next card. The whole e2e set passes unchanged.

## Held items given up by a wpoint (2026-09-29)

The soak's next stop was World links 417f80, "Frame binding (Object 49, frame
1000)": Object 49 is `chars\weapon8.dat` (id 123, a drink). The links pass
sets a held item's frame to its holder's wpoint `weaponact` and reads that
Frame (centers, the held wpoint) unchecked. 41 wpoints in the loaded DATs use
a weaponact outside 0..<400 — 1000 in many characters' frame 274/279 and
others, 9998 (Nckakuzu frame 361), −888 (Sakon frames 235..239, 247, 248) —
to let the item go.

The declared rule is now stated for any Frame wholly outside the allocation:
f ≥ 400 or f ≤ −7 (frame −7 ends at −0x12c). Frame −6 straddles the
allocation start and stays a boundary. The World-links lookup and the
post-draw lifecycle use the same fallback; the item is then positioned from a
zero Frame for that tick and deactivated by the post-draw opoint continuation
(frame outside 0..<400). The unit test adds −7, −888 and INT_MIN. The links,
cpoint, post-draw, gameplay-lifecycle and drawing corpora and the whole e2e
set pass unchanged. The Demo soak now plays sixteen matches (≈32,400 bodies)
to a different stop: an 8-byte read of undefined bytes at offset 80 (next
card).

## Correction after independent review (2026-09-30)

An independent review of the policy commits found three errors, all
confirmed and fixed:

- **Geometry.** Frame f starts at Object+0x7a4+f·0x178 (the state word read at
  [obj+0x7ac] in 41a6ae and 40da97), so frame 400 starts at +0x25324 and its
  first 0x3c bytes are the Object's name tail inside the allocation; frame
  1000 starts at +0x5c464 (its cpoint kind at +0x5c4ec), not the +0x5c3e4
  stated above. "Wholly outside" is therefore f ≥ 401 or f ≤ −7; frames 400
  and −6 straddle the allocation's ends and stay boundaries. No shipped DAT
  refers to frame 400.
- **The absent Frame.** All-zero bytes gave sound index 0, so the scheduler
  (40da50..40da6b) queued catalog sound 0 whenever such an actor's frame
  changed. The declared record is now the EXE's own Frame constructor state
  (40bbf0: presence 0, sound −1) with its untouched bytes zero — an absent
  Frame as the loader makes them.
- **Effects.** With that Frame's state 0, the scheduler sends an airborne
  actor (y < 0) to frame 212 (40da86..40daa5) instead of letting it be
  deactivated; only an actor on the ground keeps 1000 and is deactivated by
  the opoint continuation. Both follow from the declared Frame, not from the
  earlier claim that every such actor is removed in the same pass. A
  scheduler test covers both cases and the absence of a sound.

After the fixes the world-cpoint, links, scheduler, post-draw, gameplay
lifecycle, drawing, cpoint-chain and camera corpora pass (21 tests), the
whole e2e set passes and the Demo soak runs 60,000 bodies (27 matches)
without a stop.

## Contacts (2026-09-30)

A Stage 4-1 soak with three computer allies and `--virtual-clock 987654321 8`
stopped at body ≈23,700 in the contact pass (419380, `OriginalWorldContacts`):
`chars\chakra.dat` (id 437, type 1, catalog Object 109) at frame 1000
(temporary diagnostic, removed). 419380 reads the frame's state (+7ac), bdy
count (+88c) and itr count (+8cc) at Object + f·178 with no range check, like
the cpoint sites. Its Frame lookup now falls back to the same
`OriginalCPointPass.headerFrame`: a Frame wholly outside the Object reads as
the absent Frame (no itr, no bdy, so no contact), frames −5..−1 read the
header's bytes, and 400 and −6 stay boundaries.

**The other Frame lookups (static trace, 2026-09-30).** Frames ≥ 401 arise
only between the hit pass (kind-8 dvx 1000), the links (weaponact 1000/9998/
−888) or the scheduler (next 1000/1250) and the post-draw opoint continuation.
At 41fb26..41fb48 that continuation sets frames 1100..1299 to 0, and sends
frames < 0 or ≥ 400 to 4213a9 (frame 0, deactivated). Every frame write after
it is small: opoint child actions 0..396, Object 998's 0/2/4, particles, and
the constructor's 0. Control writes only constants or counters, and 40e2d0
commits only present targets and maps 999 to 0. Hence:

| Lookup | EXE | Unchecked | Frame ≥ 401 reachable |
| --- | --- | --- | --- |
| contacts (`OriginalWorldContacts`) | 419380 | yes | yes, right after the links 41eed3 (this soak) |
| physics (`OriginalWorldPhysics`) | 41e634, 40e490 | yes | no: only control runs before it in the tick |
| control (`OriginalWorldControl`) | 41e339, 413080, 412800..412f40 | yes | no: first gameplay stage |
| commands | 4214d5..421a15 | yes | no: after the lifecycle |
| post-draw slot prefix | 41f550..41fb0b | yes | yes, but the gameplay path already uses the fallback (`OriginalPostDrawLifecycle`); the throwing public overloads have no callers |
| post-draw opoint | 41fb0b..4203b4 | parent range-checked at 41fb26..41fb48; child unchecked | no: the child's frame is an opoint action |
| character-AI special | 403a40 | yes | no |
| object input | 419dfb gate, 406ba0 | yes | no: slots 10..399 of type ≠ 0 |

These stay boundaries: reaching one would mean the trace missed a writer.
Applying the fallback there would not be neutral, because the absent Frame's
state 0 is the standing state. Control would run standing input and physics
would land an actor instead of dropping it. The character-AI and local-input
lookups (`OriginalCharacterAI.swift:61`, `OriginalLocalInput.swift:105`) run
at the start of the tick and are likewise not reachable. The lifecycle and
links fallbacks use `outsideAllocation` only, so frames −5..−1 still stop
there.

EXE envelope not recalculated.
