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
0..<400. Frame 1000 is +0x5c3e4 into a 0x25360-byte Object allocation.

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

EXE envelope not recalculated.
