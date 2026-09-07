# Original Windows engine: evidence ledger

Baseline inspected on 2026-09-07. Only the original Windows distribution is a
behavioral reference. Nothing here treats another LF2 implementation as an oracle.

## Identity

| Property | Original value |
| --- | --- |
| Executable | `NTSD 2.4.exe`, pristine `NTSD 2.4_2.0a` |
| SHA-256 | `3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c` |
| File size | 31,715,328 bytes |
| Architecture | PE32, Intel i386, machine `0x014c` |
| Image base | `0x00400000` |
| Entry point | `0x00445560` |
| Code section | RVA `0x1000`, virtual size `0x4530a` |
| Resource section | RVA `0x5a000`, file offset `0x4f000`, size `0x1df0000` |

Generate the complete inventory with `python3 tools/inspect_original.py`.
`build/original/executable.json` includes sections, all 163 imports and 67
resources. 64 are bitmaps, including menus, health bars, character selection,
pause, scoreboards, cursor and effects. Extracted DIB data is unchanged; the
extractor adds a BMP file header for macOS readers.

## Evidence levels

- **Static**: directly observed bytes/instructions/data in the identified EXE.
- **Differential**: compared against execution of original instructions with
  documented test boundaries. This verifies only the tested function/domain.
- **Unresolved**: requires additional disassembly or a running original game.

## DAT decoding — differential verification passed

Original routine: `0x4148a0`. The test harness executes this x86 code from the
user's EXE with Unicorn. Its five C file functions are implemented as in-memory
byte streams: `fopen`, `fscanf("%c")`, `feof`, `fprintf("%c")`, `fclose`.
The CPU harness is **development-only** and is absent from the native `.app`.

Observed instructions:

- `0x4148d0`: loads the key string at VA `0x44892c`.
- Key: `SiuHungIsAGoodBearBecauseHeIsVeryGood`.
- `0x41493a`: initializes a 123-byte skip loop (`0x7b`).
- `0x414954`–`0x414966`: advances the key index while consuming header bytes.
- `0x414993`–`0x4149a6`: subtracts a key byte and adjusts negative results by 256.
- `0x4149bf`–`0x4149ce`: advances the key index for subsequent payload bytes.

Thus the payload starts at key index `123 % key_length`, rather than index 0
in the unrotated key. `tools/import_ntsd.py` uses this observed rule.

Run `uv run tools/oracle_dat.py`. Verified byte-for-byte on:

| Original file | Decoded bytes |
| --- | ---: |
| `chars/naruto.dat` | 129,655 |
| `chars/sasuke.dat` | 99,911 |
| `chars/flash.dat` | 6,852 |
| `bg/sys/Valley/bg.dat` | 934 |

The generated report `build/original/decoder-oracle.json` records EXE and decoded
payload hashes. This is not yet verification of the DAT parser or combat logic.

## Main-loop scheduling — static, not yet a complete timing model

`WINMM!timeGetTime` is imported at IAT VA `0x447250`; `KERNEL32!Sleep` at `0x447098`.

At `0x43d157` the main loop selects a branch using the global at `0x44d02c`, whose
initial file value is 1. In the nonzero branch:

- `0x43d160`–`0x43d167`: checks elapsed milliseconds against `0x21` (33).
  The branch is unsigned and requires **greater than** 33 before this update.
- `0x43d169`–`0x43d176`: bounds accumulated lateness to 100 ms.
- `0x43d17f`: advances its timing baseline by 33 ms.
- `0x43d182`: calls `0x43e9a0`.
- `0x43d193`–`0x43d19b`: calculates a sleep interval from that baseline.

The zero branch uses 3 ms (`0x43d1a4`, `0x43d1c0`). The flag is modified in several
other locations, including `0x416e3e`–`0x416e4b`.

**Unresolved:** exact relation of the dispatched update to combat ticks, input
sampling, rendering, pauses, network modes and speed controls. Do not turn this
finding into a universal `30 Hz`, `33 ms` or `wait+1` simulation assumption yet.

## DAT frame storage — differential verification within a defined domain

`OriginalFrameLoader` now reproduces the frame branch and constructor in native
Swift. Original-code comparison passed on **15,044 original frame definitions**
and 12 synthetic definitions, including retained fields, all six block kinds,
aliases, signed/wrapping bounds and overlapping sound-cache entries.
See [the frame-loader evidence and boundaries](FRAME_LOADER.md) and
`docs/evidence/frame-corpus-oracle.json`. 349 groups remain explicitly outside the
test domain; whole-file loading and gameplay equivalence are still unresolved.

The parser recognizes `<frame>` at `0x4103f8`. It reads an index, multiplies it by
`0x178`, and writes fields into indexed records rooted at the object pointer in
EBP. Observed field locations relative to EBP:

| Field | Address expression | Read/store sequence |
| --- | --- | --- |
| frame present | `index * 0x178 + 0x7a4` | `0x410464`–`0x41046e` |
| pic | `index * 0x178 + 0x7a8` | `0x4104d4`–`0x4104f0` |
| state | `index * 0x178 + 0x7ac` | `0x410509`–`0x410525` |
| wait | `index * 0x178 + 0x7b0` | `0x41053e`–`0x41055a` |
| next | `index * 0x178 + 0x7b4` | `0x410573`–`0x41058f` |
| dvx | `index * 0x178 + 0x7b8` | `0x4105a8`–`0x4105c4` |
| dvy | `index * 0x178 + 0x7bc` | `0x4105dd`–`0x4105f9` |
| dvz | `index * 0x178 + 0x7c0` | `0x410612`–`0x41062e` |

Frame entry resets the itr/bdy counts (`0x41043b`–`0x41046e`) and sets the presence
byte. Other omitted values survive, including singleton points and aggregate
bounds when the new box list is empty. This is now verified against original
instructions; a “last dictionary wins” loader is not equivalent.

Concrete source example: Naruto has two definitions of frame 123. The first has
`dvy:550`, `hit_d:370`, `wpoint.y:-999`; the second has `dvy:0`, `hit_d:0`,
`wpoint.y:51`. Both are preserved in `frameOccurrences` and exposed by Native Lab.

## Asset audit

`python3 tools/import_ntsd.py` creates `build/imported/game.json` and `audit.json`.
It records source hashes and the actual DAT literals. `originalText` preserves
the complete decoded text, including parts not interpreted by the inspector.

- 137 registered objects; 42 have type 0 (not all are selectable fighters).
- 17 registered backgrounds.
- 15,368 unique frame IDs across objects, plus source duplicates.
- Duplicate frame IDs in 17 object files.
- 364 out-of-Int32-range field occurrences in the convenience last-occurrence
  view. No clamping or cleanup is applied to the source data.
- Extended state/effect values require investigation. Their mere presence does
  not prove a particular implementation or compatibility with standard LF2.

`frames` is a convenience lookup for analysis, not the original loader's output.
The `--inspect` laboratory displays `frameOccurrences` in source order. The default
app now runs the separately verified Naruto movement slice; see [MOVEMENT.md](MOVEMENT.md).

## Next original-code targets

1. Extend verified frame loading to the outer file stream and remaining 349
   groups; recover actual MSVCR80 overflow and overlapping frame-name writes.
2. Extend the verified Naruto frame scheduler/input/movement routines to combat.
3. Recover collision collection and hit resolution (`0x419380`, `0x42e100`).
4. Compare one melee exchange and obtain full-match Windows reference captures.
5. Expand to all NTSD-specific mechanics; keep unsupported behavior explicit.

Disassembly can be regenerated locally with Xcode's tool:

```bash
mkdir -p build/research
xcrun llvm-objdump --disassemble --x86-asm-syntax=intel \
  'downloads/NTSD_2.4_2.0a_clean/NTSD 2.4_2.0a/NTSD 2.4.exe' \
  > build/research/original.asm
```

No original EXE modifications or Windows application launches are needed for the
static inventory and bounded decoder test. Full-match fidelity is still unverified.
