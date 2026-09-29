# Object header words the loader never writes — plan

2026-09-29. Task → contract → milestone: the Demo soak (after
[APPLICATION_OUT_OF_OBJECT_FRAMES](APPLICATION_OUT_OF_OBJECT_FRAMES.md)) stops
in its seventeenth match at body ≈32,500 with "State bytes have no recovered
initialization: 80, 8 bytes" → a declared answer for that read → Demo and every
mode keep running with Temari's wind. The original is not executed.

## Evidence

- A temporary stage/slot dump (not committed): after the impulses checkpoint,
  in the post-draw lifecycle, slot 52, Object 65 = `chars\wind.dat` (id 204,
  type 3), frame 211, wait counter 1; header bytes 0x48..0x67 undefined.
- wind.dat's "flying" frames chain 210 → 211 → 212 → 213 → 214 → 1000.
- The scheduler 40d960 (`OriginalActorScheduler`) treats any transition to
  frame 212 without an air return as a jump: it loads the header's binary64
  jump_height (+0x50) into vy, and with direction input jump_distance (+0x58)
  and jump_distancez (+0x60). It does not check the Object type.
- `OriginalObjectLoader` starts the header with every byte undefined (the heap
  backing is not recovered) and writes only the fields a DAT names; wind.dat
  names none of the jump fields. The original therefore reads bytes of its own
  0x25360-byte Object allocation (41265b..4126a8) that no loader step wrote:
  the allocation's initial content.

## Declared policy (not the EXE)

A jump-velocity header word whose eight bytes are all unwritten reads as zero:
the Object allocations come from the CRT heap while the catalog loads, and
freshly committed heap pages are zero. This is plausible, not recovered. Only
the scheduler's three jump reads are covered; a partly written word, and every
other unwritten header read, stay boundaries.

## Checks

A unit test on the scheduler: an Object header without jump fields, a frame
whose next is 212 on the ground → vy (and, with input, vx/vz) become +0.0;
a partly written word still stops. The scheduler, post-draw and gameplay
lifecycle corpora pass unchanged; the Demo soak past body 32,500; the e2e set.

EXE envelope not recalculated.
