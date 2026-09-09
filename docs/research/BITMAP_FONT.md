# Mutable bitmap-font helpers — raw comparison complete

`OriginalBitmapFont` implements whole423940 and its four-pass423a70 caller.
All2450 controlled original calls match the native raw comparison. The corpus
is not yet published: the priority result-recording and own continuation
acceptance must finish first. This helper does not execute the whole41b130
mode label,41b390 playback information, result layout or a returned tick.

## Recovered behavior

423940 consumes a mutable NUL-terminated byte string. It writes NUL at the
consumed position, including empty strings and signed nonpositive line limits.
Characters advance X by8; newline10 or column wrapping advances Y by16.
Columns and lines use signed comparisons. Styles0/1/2 select44faf4/44f888/44fcbc;
other styles still consume bytes and advance without drawing a glyph. Nonzero
cursor draws `_` from style0 at the final position. Character bytes are promoted
as signed8-bit values, preserving43f010's negative-picture behavior.

423a70 executes four passes at(-1,+1),(-1,0),(0,+1),(0,0). Each sees the string
as modified by the preceding pass. The native implementation stages the entire
text record until all passes finish; a thrown observer at the third pass after
two earlier truncations verifies full byte/mask rollback. External effects must
be buffered by the whole-tick owner. Numeric Blt failures remain ordinary source
responses and do not abort rendering.

## Original execution and comparison

[oracle_bitmap_font.py](../../tools/oracle_bitmap_font.py) executes the pinned
EXE atCW023f/FPSW0/tagffff, including actual43f010/43ef70. Only COM Blt responses
are supplied. Source instructions, full string bytes and masks, NUL-store masks,
all ordered pass/draw/read/clip/Blt events, unchanged globals/bitmap backing,
saved registers and normal helper returns are checked. The source text, globals
and three bitmap records are declared independent backing; arbitrary aliases
between them and their actual allocation provenance are outside this contract.

The2450 calls produce35720 helper returns and143462 events:6125 font passes,
6125 string writes,14215 draws,91871 bitmap reads,14155 clips and10971 Blts.
555 bitmap reads retain undefined provenance. The394 actual EXE instruction PCs
include103/104 font starts (42395d alignment is absent), all63 wrapper starts,
171/214 bitmap and57/57 clip starts. These are executed instruction addresses,
not all branch outcomes or Windows/device pixel evidence. No DLL code executes.

Controls cover signed limits, embedded NUL, newlines, cursor/style selection,
all nonzero bytes, wrapping coordinates, bitmap counts and font aliases,
viewport edges and undefined bitmap fields. Bytes128..255 use a declared
INT_MIN bitmap count in the full-byte controls. Twelve additional FC..FF controls
use count500 and exercise whole-picture drawing plus the indexed fallthrough.
Every effective indexed read is checked to remain inside its declared bitmap
record; mapped guard bytes are never silently promoted to source backing.

Initial2438 raw calls passed in0.674s after a148.41s release test build.
The earlier core release build passed115.98s and linked NTSDNative. After both
source and native jobs were terminal, twelve fresh controls were appended while
preserving every complete previous case and blob unchanged. All2450 calls then
passed in0.674s without a rebuild. No implementation correction or expected
fixture rewrite was needed. Both source and SwiftPM jobs are terminal.

The final raw file has24631768 bytes and SHA256
`a4402582f4cacb1e421534ebe9856e036a62a4223a8bede407a32d77c3a3aef7`.
[accept_bitmap_font.py](../../tools/accept_bitmap_font.py) independently verifies
the full JSON and all SHA-addressed zlib-framed transport blobs, source writes,
four-pass composition, bitmap-read provenance and coverage. `--verify-only`
passes; details remain in build/research/bitmap-font-verification.json.
The publishing path requires the preceding178 result/own fixture pins, which
are not yet accepted. These checks introduce no EXE, DLL or transport codec into
the native runtime. See [RESULT_LAYOUT_PLAN](RESULT_LAYOUT_PLAN.md) for the
remaining actual callers and retained-stack constraints.
