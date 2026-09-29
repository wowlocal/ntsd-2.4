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
as +0.0 — the allocations are made while the catalog loads, from freshly
committed (zeroed) heap pages; plausible, not recovered. Only the scheduler's
three jump reads are covered; a partly written word and every other unwritten
header read stay boundaries.

**Checks:** a unit test (a frame-212 transition of an Object without jump
fields sets vy to +0.0; a partly written word still stops); the scheduler,
post-draw lifecycle, slot-prefix, gameplay-lifecycle and application-lifecycle
corpora pass unchanged. The Demo soak now completes 60,000 bodies — 27 Demo
matches with random characters — with no boundary. The whole e2e set passes
unchanged.

EXE envelope not recalculated.
