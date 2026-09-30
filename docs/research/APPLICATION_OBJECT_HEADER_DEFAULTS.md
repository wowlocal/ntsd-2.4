# Object header words the loader never writes

[Plan](APPLICATION_OBJECT_HEADER_DEFAULTS_PLAN.md). The original is not executed.

## Finding and policy (2026-09-29)

After [frames outside the Object](APPLICATION_OUT_OF_OBJECT_FRAMES.md), the
Demo soak stopped in its seventeenth match at body ≈32,500 with an undefined
8-byte read at offset 80. A temporary stage and slot dump (not committed)
placed it in the post-draw lifecycle's scheduler: slot 52, `chars\wind.dat`
(id 204, type 3), frame 211 → next 212. The scheduler 40d960 treats every
transition to frame 212 without an air return as a jump and loads the Object
header's binary64 jump_height (+0x50), and with direction input jump_distance
(+0x58) and jump_distancez (+0x60), whatever the Object's type. wind.dat names
none of them, so the loader never writes those words and the original reads
its own 0x25360-byte allocation's initial content.

Declared policy (not the EXE): such a word, all eight bytes unwritten, reads
as +0.0. This is an arbitrary value, not a likely one: the Windows content is
unknown (see the review below; the plan's "zeroed heap pages" rationale is
wrong). Only the scheduler's three jump reads are covered; a partly written
word and every other unwritten header read stay boundaries.

**Checks:** a unit test (a frame-212 transition of an Object without jump
fields sets vy to +0.0; a partly written word still stops); the scheduler,
post-draw lifecycle, slot-prefix, gameplay-lifecycle and application-lifecycle
corpora pass unchanged. The Demo soak now completes 60,000 bodies — 27 Demo
matches with random characters — with no boundary. The whole e2e set passes
unchanged.

## Independent review (2026-09-30)

A review from static disassembly and the decrypted DATs found the code right
and one claim wrong:

- **The Windows content is not zero in general.** `chars\charge.dat`
  (catalog entry 64) loads just before `wind.dat` (entry 65) and registers six
  new sounds of 240–790 KB. The WAV loader allocates each data buffer with
  `new` (40175e) and frees it with `delete` (401930). Four of them are ordinary
  heap blocks larger than the 0x25360-byte Object that 412665 allocates next,
  so wind's header may reuse memory that held sound data. The policy value
  stays +0.0, now declared as arbitrary.
- **The boundary is as narrow as it can be.** The loader writes each of these
  fields with a whole 8-byte `fscanf "%lf"` store (40f934, 40f95b, 40f982), no
  integer field overlaps 0x48..0x67, and the constructor 40ef70 sets nothing
  below 0x90. Original data can therefore never produce a partly written word.
- **Coverage.** All 137 DATs were scanned: every type-0 DAT names all 16
  speed/jump fields. Only wind (204), 4TK_ball (446) and shadow (462), all
  type 3, have `next: 212` without jump fields, and the policy covers all
  three. The Swift matches 40dc92..40dcfc (frame 212 without an air return,
  no type check, the same input conditions and signs).
- **Known risk outside this card.** Actor control 413080 runs for every
  active slot and reads header movement words by frame state and direction
  input with no type check. `criminal.dat` (id 300, type 5) names no movement
  fields but has state-0 and state-301 frames. If a criminal ever gets
  direction input, the game would stop at the same kind of boundary. No soak
  has reached it; it stays a boundary until one does.

EXE envelope not recalculated.
