# Frames outside the Object allocation — plan

2026-09-29. Task → contract → milestone: a Demo soak (eight computers, random
characters) stops in its seventh match at body ≈12,620 with "Cpoint Frame
outside known Object storage" → a declared answer for the cpoint pass's
out-of-allocation reads → Demo, VS and every mode keep running with
characters whose heal balls use this path. The original is not executed.

## Evidence

- Reproduced deterministically (`--virtual-clock 123456789 8`, Demo from the
  main menu, `--script-clock gameplay`): Object 81 = `chars\ironsand.dat`
  (id 222), frame 1000, in cpoint actions 418c30.
- Actor dump at the failure: slot 52, active, Object 81, current frame +70 =
  1000, collision frame +7c = 211 ("life_heal"). Frame 211 has a kind-8 itr
  with `dvx: 1000`; hit resolution (`OriginalHitSpecial` kind 8, between
  contacts 419380 and the cpoint pass) sets the attacker's frame to that dvx.
  Contacts had copied a valid +70 into +7c; the post-draw lifecycle deactivates
  frame-1000 actors (4213a9) only after the cpoint pass. The state is the
  compared ports' own; nothing in it is substituted.
- The original reads without a range check: 418c6c..418c7b the collision
  frame's kind (`[data + f·0x178 + 0x82c] == 1`), 4192d7..4192e8 the current
  frame's kind (`== 2`), and in the linked checks the target's collision kind
  (`== 2`) and the owner's current kind (`== 1`); placement 4187b0 then reads
  the current frame's kind (4187ed `== 1`) and the partner's (`== 2`) the
  same way (found by the soak after the first four were declared). Objects are 0x25360-byte
  allocations (41265b..4126a8); frame f's kind word is at +0x82c + f·0x178, so
  f ≥ 400 or f ≤ −6 lies outside the allocation (f = 1000: +0x5c46c). Those
  bytes are other Windows heap memory whose contents are not recovered.

## Declared policy (not the EXE)

A Frame ≥ 400 lies wholly beyond the Object allocation (frame 400 starts at
+0x253a4 > 0x25360) and reads as zero bytes — an absent Frame. One rule in the
shared Frame fallback (`OriginalCPointPass.headerFrame`, used by the cpoint,
camera and drawing stages): the cpoint kinds are then 0 (no cpoint); the draw
loop 41a5a0, which also reads such a Frame unchecked (41a69f..41a6d0 state
3005/9997, then the actor's picture), sees state 0 and presence byte 0, so the
shadow is drawn for that tick and the picture is not (40be70 skips absent
Frames). The post-draw lifecycle (41f550..) then reads the same Frame in its
slot prefix and scheduler (state 0, wait 0, next 0: no transition) and its
opoint continuation deactivates the actor because its frame is outside
0..<400 — the same end as when the scheduler itself reaches next 1000. The
lifecycle's composed Frame lookup uses the same fallback. Rationale for zero: if the Object allocations lie back to back, frame
1000 of Object 81 falls inside an undefined, zeroed Frame of a neighbouring
Object; this is plausible, not recovered. Frames ≤ −6 overlap the allocation
start and stay a boundary; −1..−5 keep their recovered header aliasing.

## Checks

A unit test on `OriginalCPointPass`: frames 1000 and 400 leave the actor
unchanged through actions and placement; −6 still stops; frame 399 (inside the
allocation) is still read (kind 2 with an unlinked owner falls to frame 212).
The accepted cpoint, camera, drawing and impulse corpora pass unchanged. The
Demo soak past the failure point; the e2e set.

Extension (same day): World links 417f80 reads a held item's Frame chosen by
its holder's wpoint weaponact (1000, 9998, −888 in the loaded DATs). The rule
covers every Frame wholly outside the allocation (f ≥ 400 or f ≤ −7) in the
shared fallback, the World-links lookup and the post-draw lifecycle; −6
straddles the start and stays a boundary.

EXE envelope not recalculated.
