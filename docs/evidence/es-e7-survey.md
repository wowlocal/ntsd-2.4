# E7 survey: the engine stand-alone (2026-10-21)

A read-only survey by a separate agent at `d4335ab6` with E4c-2 staged
(nothing built or run; no original content bytes read, only names, sizes,
code and manifest key structure). Paths under `engine/` unless stated.
Recorded in substance; the loop's decisions are in the card's E7 note.

## 1. Building `engine/` alone

- **Nothing in the build leaves `engine/`.** `Package.swift` has no path
  dependency and no resources; its `exclude:` names files inside `engine/`.
  The tests use `#filePath` only as XCTest's `file:` argument
  (`OriginalRandomTableTests.swift:10`, `OriginalIDSetTests.swift:7`), no
  `Bundle.module`, no fixtures. Mentions of `tools/` or `native/` are
  comments. One doc link dangles in a copy:
  `Sources/NTSDReplayCodec/README.md:27` →
  `../../../docs/research/REPLAY_COMPRESSION.md`.
- **Environment switches** in the manifest: `NTSD_PORTABLE` (`:13`; always on
  off macOS), `NTSD_UNCHECKED_EXCLUSIVITY` (`:31`), `NTSD_FREETYPE_PREFIX`
  (`:50`), `NTSD_WEB` (`:61`), `NTSD_SDL`/`NTSD_SDL_PREFIX` (`:70-71`, default
  `/opt/homebrew/opt/sdl3`), `NTSD_IOS` (`:82`), `NTSD_ANDROID` (`:91`). The SDL
  host reads `NTSD_FONT` and `NTSD_ORIGINAL_WINDOW` at run time.
- **unsafeFlags** (`-cross-module-optimization` in release, the opt-in
  exclusivity flag, `-Wno-deprecated-non-prototype` on NTSDReplayCodec, the
  SDL/FreeType include flags) are fine for a root package; they matter for E8
  (a version-pinned dependency).
- **Vendored code:** CALAC (Apache-2.0, `vendor/LICENSE`, `upstream.json`
  with per-file hashes); zlib 1.1.4 (licence in `vendor/zlib.h`, three files
  altered and recorded in `upstream.json`); `CAndroidNative/sha256.c` is the
  project's own (the FIPS K table). No top-level LICENSE or README (E8).
- **What breaks in a copy:** the Linux runners (`tools/crossplatform/run_linux_suites.py`,
  `linux-test-run.sh`) live in the repository's tools and mount the whole
  repository; the cross-build needs the Mac's generated SDK
  `ntsd-6.4.0-ubuntu24.04-aarch64`; `OriginalPosixFileFactsTests` fails as
  root (a container's default) and passes as uid 1000.
- **Proposed scope:** macOS: the default products and `NTSDEngineTests`
  (with `Mac/`), debug and a clean release. Linux: a native build and test of
  the copied folder inside `swift:6.4.0-noble` as uid 1000. Compile-only rows
  outside E7's gate: SDL3+FreeType, wasm (wasip1), UIKit, Android.

## 2. A synthetic content pack

- **What the hosts take:** an `OriginalGame` (identity and content location)
  and an `OriginalContentIdentity` (the EXE SHA string, catalog/startup
  digests and counts, five other manifest digests, the `rules`). Nothing in
  `engine/` pins an EXE SHA any more; a test computes the identity from its
  own generated manifests.
- **Startup package** (`OriginalApplicationStartupInputs.swift:139-202`):
  `manifest.json` (`globalAddress` 0x44d000, `globalCount` 0xc3a8,
  `exeSHA256`, `absentFiles`), `initial.bin` of 0xc3a8 bytes with an all-ones
  `initial.mask`, `bitmaps/*.dib`, `data/control.txt`, `adinfo.txt`, the
  menu WAVs.
- **Catalog:** `data\data.txt`, `data\stage.dat`, object and background DATs
  (encrypted with the engine's DAT key) and their bitmaps; the four built-in
  bitmaps `shadow1` and `back99_1..3` (`OriginalCatalogRegistry.swift:95-102`);
  `music` entries.
- **Other packages:** the loading interface, common sounds, character menu,
  War menu, arenas, a music `manifest.json` (`sampleRate`, frames per entry;
  silent music needs no audio bytes).
- **Profile:** a synthetic `OriginalGameRules`; `EngineTestRules.swift` is the
  start, but its interface lists are empty (the slot counts are engine
  layout, the names free).
- **Where a synthetic pack meets engine constants:** names (`MENU_BACK%d` and
  its count 13, `OriginalMenuBackground.swift:18-20`; `bgm\*.wma`,
  `OriginalMusicPlayback.swift:75-76,137`; the built-in background names; the
  `data\` file names); record words the engine checks (e.g.
  `0x44dce8 == 0x44a2b4`, `OriginalReplayWriter.swift:85`; the version word at
  0x44d03c); the test rules copy some NTSD values (`weaponBreak` 100:5,
  `frames10`).
- **Proposal:** a Swift generator in the engine's tests writing a temporary
  folder (no binary files committed); every DIB, WAV, DAT and the record
  authored in code; record words zero unless a documented table names the
  offset, value and the engine check needing it, non-original values where
  the engine allows. Proof ladder: (1) every package through the public
  loaders and `OriginalLoadedCatalog.loadWithFiles`; (2) a headless start
  (`--exit-after-startup`); (3) a scripted VS match of N bodies with frame
  digests equal on macOS and Linux.

## 3. An original-bytes scan

- **Originals:** `downloads/` (3,555 files, 2.0 GB: the EXE, `lib.dll`, DATs,
  `bgm`, `sprite`, `bg`, `vcredist_x86_2005sp1.exe` for the VC80 CRT table);
  `NTSDContent/Resources` (8 packages, about 1 GB, with `initial.bin`/`.mask`);
  `Fixtures` (408 files, 4.3 GB, mostly zlib: inflate before scanning); the EXE
  and `lib.dll` per section.
- **Method:** a tool the loop runs (`tools/scan_original_bytes.py`) that
  prints paths, lines, offsets, lengths and hashes, never bytes: (a)
  winnowing fingerprints (k≈12, w≈8) over `engine/` sources, a generated pack
  and the release objects, streaming the originals (DATs raw and decrypted)
  and skipping low-entropy windows; (b) Swift/C literals (integer arrays as
  u8/i16/i32/f64, hex strings, strings with and without NUL) searched as exact
  substrings per section; (c) literal sequences of four or more as
  subsequences of `.text` immediates (`tools/inspect_original.py`'s PE parser;
  capstone is not in the system python3).
- **Expected hits the policy has to name** (`Sources/NTSDCore` unless marked):
  the DAT key (`OriginalDATDecoder.swift:34`, 37 B; also the moved test
  `OriginalCatalogChecksumTests.swift:14`); DirectShow GUIDs
  (`OriginalMusicPlayback.swift:116,160`, `NTSDRuntime/OriginalMacRuntimeMusic.swift:20`,
  16 B); the VC80 power-of-ten table (`OriginalDiagnosticNumber.swift:165-211`,
  42×12 B as hex strings); PST/PDT (`OriginalCalendarTime.swift:24`); the CRT
  `rand` constants (`OriginalCRTRandom.swift:16`); three binary64 constants
  (`OriginalStateRecord.swift:1017`, `OriginalWorldBootstrap.swift:44,46`); EXE
  strings (credits and links `OriginalFrontScreenBody.swift:39-47`, `<No name>`
  etc. `OriginalSettingsWriting.swift:13`, network errors
  `NTSDRuntime/OriginalMacRuntimeNetwork.swift:88-92`, "Little Fighter 2" and
  "Marti" `OriginalWindowInitialization.swift:110`, about 117 `Array("…")`
  literals in 45 Core files); engine names and tables (music paths and labels
  `OriginalMusicConfiguration.swift:47,50`, cheat key sequences
  `OriginalWindowInput.swift:146-147`, key labels `OriginalKeyName.swift:24-33`,
  key-to-character maps `OriginalMenuCharacter.swift:35-37`, the DAT field
  vocabulary `OriginalFrameLoader.swift:134+`, `OriginalObjectLoader.swift:375-381`);
  zlib 1.1.4 (the EXE links it statically: `trees.h`, `inffixed.h`, version
  strings; licensed upstream code); about 969 source lines with 0x44xxxx
  addresses among roughly 2,200 address constants (single words excluded,
  only sequences flagged).

## 4. Proposed increments

| Step | What | Needs D1 or the user |
|---|---|---|
| E7a | `git archive engine` to `/Volumes/NTSD-Builds`; clean macOS build and tests (debug, release); native Linux build and tests in the container as uid 1000; the optional host rows recorded; 136 tests as in the repository | no |
| E7b | the scanner and a policy file naming every expected class; a first report sorting hits into policy and unexpected | the tool no; the policy the user's, with D1 |
| E7c | the synthetic pack generator and loading tests on macOS and Linux; the generated pack's scan clean but for policy hits | no |
| E7d | a synthetic headless start, then a match of N bodies with frames equal on macOS and Linux (an executable or `NTSDHeadlessHost` in the tests) | no |
| E7e | compute the power-of-ten table instead of copying it (derivable; compared with a digest) and move the strings likely NTSD's; keep or remove the DAT key, GUIDs, EXE strings and zlib per the user's policy | partly before D1; the rest waits |

Risks: any change to `engine/Package.swift` brings the full mlgate set (a
nested synthetic-game package would avoid it); menus may need more art or
record words than expected (found by iteration); original values coincide
where the engine checks them; inflating the fixtures for the scan costs time
and space; container memory may limit release builds there.
