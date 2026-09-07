# Original frame loader: recovered behavior and verification boundary

Baseline EXE SHA-256:
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.
Only this Windows binary supplies engine behavior. The Swift implementation is
`native/Sources/NTSDCore/OriginalFrameLoader.swift`.

## What runs in the reference test

`tools/oracle_frames.py` maps the original EXE's code/data into Unicorn, executes
the frame constructor at **0x40bbf0**, and executes the original frame-parser
branch from **0x4103f8** to **0x412277**. The latter boundary includes box-bound
postprocessing, before the outer file loop resumes. The EXE file is unchanged.

Inputs are complete decoded `<frame>` sections, extracted without rewriting their
contents. Definitions sharing an index are applied in original source order.
Each index group starts with a freshly constructed record and an empty sound
registry. This isolates per-record behavior; it does **not** execute the outer
file loader or establish whole-file equivalence. Synthetic cases also exercise
sound registration across several different frame indices.

Three imported functions are replaced at a documented boundary:

- `fscanf`: ASCII whitespace and `%s`, `%d`, `%d %d`; decimal conversions must fit
  signed Int32. Integer-prefix/matching-failure cases exercise the declared stub
  contract, **not the actual MSVCR80 implementation**. Overflow raises an explicit
  unsupported-domain result. It is neither clamped nor wrapped by the harness.
- `sprintf("%d")`: the parser's frame-index diagnostic string.
- `malloc`: bounded memory allocation, initialized with `0xa5` to expose untouched
  data. Numerical defaults come from original constructor instructions, not from
  zero-filled test memory.

The original sound-enabled flag at `0x44eecc` is set to zero. Original sound path
copying, registration and lookup still execute; audio-device loading does not.
No gameplay, graphics or Windows system emulation is supplied by these stubs.
Unicorn is a developer dependency, absent from the native application.

The harness records writes and compares **every defined numerical word** in each
frame, every Int32 in the allocated bdy/itr records, the frame name and the sound
path after each occurrence. Raw pointers, name bytes and uninitialized numerical
words are excluded from numerical comparison. Uninitialized words remain absent
in the Swift model. Actual sound paths are compared through their pointers.

Expected snapshots are produced from x86 execution before the independent Swift
checker runs. `NTSDFrameCheck` fails on any discrepancy or malformed fixture.

## Recovered rules

### Construction and repeated definitions

The object constructor calls `0x40bbf0` exactly 400 times at
`0x40efc3–0x40efe0`. Each frame occupies **0x178 bytes** starting at
`object + 0x7a4 + index * 0x178`.

The frame constructor `0x40bbf0–0x40bd83` initializes numerical words in these
record-relative byte ranges to zero:

- `0x04...0xc0`, `0xd8...0x12c`, `0x138...0x158`, in increments of 4;
- the presence byte at `0x00` and sound pointer at `0x170`;
- the sound registry index at `0x174` is **-1**.

It leaves `0xc4...0xd4` uninitialized, including cpoint `throwinjury` and `throwvz`.
Swift has no invented zero defaults for those words. Pointers at `0x130/0x134`
are not usable until their corresponding box count becomes positive.

At each `<frame>` entry, `0x41043b–0x41046e` resets **only** the itr count (`0x128`)
and bdy count (`0x12c`), and sets the presence byte to 1. The new name is copied.
Other numerical fields retain their previous values when omitted. Singleton
opoint/bpoint/cpoint/wpoint blocks update their existing record fields; repeated
singleton blocks do not become independent objects.

### Scalar and point fields

The scalar reads occupy `0x4104c0–0x4108e4`:

| Field | Record offset |
| --- | --- |
| pic, state, wait, next | 0x04, 0x08, 0x0c, 0x10 |
| dvx, dvy, dvz | 0x14, 0x18, 0x1c |
| hit_a, hit_d, hit_j | 0x24, 0x28, 0x2c |
| hit_Fa, hit_Ua, hit_Da | 0x30, 0x34, 0x38 |
| hit_Fj, hit_Uj, hit_Dj, hit_ja | 0x3c, 0x40, 0x44, 0x48 |
| mp, centerx, centery | 0x4c, 0x50, 0x54 |

Singleton point groups are read at:

| Group | Original branch | Numerical storage |
| --- | --- | --- |
| opoint | 0x410a9f–0x410cc4 | 0x58...0x74 |
| bpoint | 0x410cc4–0x410da6 | x: 0x80, y: 0x84 |
| cpoint | 0x410da6–0x41120b | 0x88...0xc8 |
| wpoint | 0x41120b–0x411459 | 0xd8...0xf8 |

Cpoint `injury` and `fronthurtact` share **0x94** (reads at `0x410e8f`,
`0x41110b`); `cover` and `backhurtact` share **0x98** (`0x410ec4`, `0x411140`).
Their last successfully parsed assignment wins, even when the spelling differs.
The complete offset map is explicit in the Swift source, not inferred from names.

### Hit and body arrays

`0x411471–0x411585` increments the itr count, allocates **400 bytes** on its first
block, and initializes the new **80-byte** record to zero. The fields are:

`kind, x, y, w, h, dvx, dvy, fall, arest, vrest, respond, effect,
catchingact[0], catchingact[1], caughtact[0], caughtact[1], bdefend, injury, zwidth`.
The twentieth word remains zero. `pickingact` aliases `catchingact[0]`;
`pickedact` aliases `catchingact[1]` (`0x4119e9–0x411b0f`). Two-number scanf calls
are preserved, including the possibility of assigning only the first number.

`0x411b53–0x411cff` similarly allocates **200 bytes** for bdy and zeros each new
**40-byte** record. Its first five words are `kind, x, y, w, h`; the rest stay zero.
Both allocations fit five records. The new code rejects a sixth record instead of
reproducing a heap overrun. This is a declared domain limit, not a new game rule.

Postprocessing `0x411ef0–0x412274` stores aggregate itr bounds at `0x138...0x144`
and bdy bounds at `0x148...0x154`. It takes signed minima of x/y and signed maxima
of x+w/y+h, then subtracts the minima to obtain width/height. ADD/SUB wrap at
32 bits **before** comparisons, reproduced using Swift `&+` and `&-`.
If a list is empty, its old aggregate bounds are retained even though its count
is zero. The constructor, duplicate and integer-boundary fixtures verify this.

### Sound registration, including overlapping cache entries

At `0x41098e–0x410a99`, the cache starts at **0x455638**, advances by **20 bytes**
per entry, and copies each complete NUL-terminated path. The original distribution
contains 21-byte paths, e.g. `data\SNDDATA_1869.wav`. A later cache entry can
therefore overwrite the end of a previous path and change later lookup results.

Swift preserves the cache bytes and stride within a bounded array. A differential
fixture registers a long path, a short path, then the long path again: the latter
gets a new index because its earlier cached spelling was overwritten. This is
sound **registration** equivalence with the device disabled, not audio playback
or timing verification. Writes beyond the cache/count boundary remain unsupported.

## Results and reproducible commands

```bash
python3 tools/import_ntsd.py
uv run tools/oracle_frames.py
swift test --package-path native
uv run tools/oracle_frames.py --corpus
```

The small run refreshes `native/Tests/NTSDCoreTests/Fixtures/original-frames.json`
with original x86 snapshots for selected Naruto/Sasuke frames and synthetic edge
cases. Ordinary Swift tests can use those fixtures without Windows files or
Unicorn. Fixture refresh deliberately requires the exact baseline EXE.

The complete corpus run verified **15,044 original source definitions**, including
all 25 additional repeated definitions, plus **12 synthetic definitions**: **15,056
snapshots in 15,025 groups**. It compared all defined numerical words and box arrays.
The corpus input/snapshots remain in ignored `build/original/frame-oracle.json`;
`docs/evidence/frame-corpus-oracle.json` records the EXE hash, fixture hash and every
excluded group. These counts refer to frame data, not implemented game mechanics.

349 original groups remain outside this verification domain:

| Reason | Groups |
| --- | ---: |
| Out-of-Int32 decimal conversion; actual MSVCR80 required | 290 |
| Names exceed the original 20-byte frame-name storage | 54 |
| Unclosed itr block runs past the isolated frame boundary | 5 |

The five unclosed blocks are frame 48 in `weapon4.dat` and `heart{,0,2,3}.dat`.
They contain `itr:` but no `itr_end:`. Continuing the original file stream may
consume subsequent frame definitions inside that block. The isolated test stops
explicitly; it does not fix the source or guess whole-file behavior.

## Remaining work

- Identify and execute the Windows MSVCR80 version used by the original setup for
  integer-overflow conversion; no such DLL is supplied by this distribution.
- Extend the harness to the outer file stream, including malformed sections and
  frame-name writes that overlap following storage.
- Recover object/header loading, sprite-sheet metadata, movement parameters and
  resource initialization. Preserve distinctions between those steps and frames.
- Recover frame scheduling, input transitions and movement. This loader does not
  implement gameplay, frame timing, combat, AI, or a playable native arena.

Native Lab continues to display the raw source occurrences. Its convenience
`frames` JSON dictionary is still not the original loader output. The new Swift
loader is an independent core component and is exercised by the native checker.

## Continuous Object stream follow-up

[OBJECT_LOADER.md](research/OBJECT_LOADER.md) now executes the complete Object
loader for Naruto, Sasuke and kunai, plus a control stream. It reuses this native
frame parser with a continuous scanner and a sound registry shared across objects.
In kunai, frame 48's unclosed itr consumes frame 49; the latter remains absent.
That whole-file result does not change the 349 exclusions of the isolated corpus.
All 15,056 isolated definitions were compared again after the parser refactor.
Four other malformed heart files, long names and overflow groups remain open.

The new native DAT decoder also exposes a limitation of the old decoder oracle:
its stdio boundary did not translate CRLF. Both contracts now have retained full
Object comparisons; their EOF tails/checksums differ. This does not establish
actual MSVCR80 `%d`/`%lf` or Windows equivalence. The old import is unchanged.

[BACKGROUND_LOADER.md](research/BACKGROUND_LOADER.md) reuses the same scanner.
Its original-instruction controls exposed missing EOF on a numeric conversion
with no remaining input. The shared integer scanner now sets EOF without assigning
a value; it no longer counts a stale outer token twice in that path. Full Object
and isolated-frame comparisons are repeated after this change.
