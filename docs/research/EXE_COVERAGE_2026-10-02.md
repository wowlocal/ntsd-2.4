# How much of the EXE is studied, executed and ported (2026-10-02)

The user's question: what share of the original's code has been analysed and
exactly implemented. Computed in a separate worktree (branch
`analysis/exe-coverage-20261002`), reading saved records only. The original is
not executed. Evidence: [exe-coverage-20261002.json](../evidence/exe-coverage-20261002.json).

## Method

- **Denominator** (`tools/exe_coverage_universe.py`). A recursive-descent
  disassembly of the pristine EXE's `.text` (0x401000..0x44630a, 283,402
  bytes). It starts from the entry and follows direct calls and jumps,
  `jmp [reg*4+table]` jump tables, and code pointers in the data sections.
  Result: **72,199 instructions, 274,600 bytes, 373 functions**. The other
  8,802 bytes are padding, embedded data or unreached code.
- **Partitions.**
  - Game code (0x401000..0x43f37e): 63,694 instructions, 174 functions.
  - zlib 1.1.4 (0x43f400..0x4450a0, identified by its message strings):
    7,413 instructions.
  - MSVC runtime stubs and exception-unwind funclets (0x4450a0 to the end):
    1,057 instructions.
  - Import thunks: 35.
- **Executed by the original under study.** These are addresses recorded in
  saved oracle data that are real instruction starts of the denominator:
  - instruction lists and PCs (`tools/exe_coverage_executed.py`) in the 406
    Native fixtures, the evidence files and the raw corpora in
    `build/original` (23,092 files, read only);
  - entry, returnPC and pc fields;
  - every PC in all 42,318 parts of the nominal catalog-load trace
    (`tools/exe_coverage_traces.py`).

  Corpora that compare whole calls of a function often record calls and
  results, not instruction lists. For those, the functions named in the
  fixtures' `scope` fields count at the function level.
- **Cited.** EXE addresses and ranges named in the Swift port (NTSDCore,
  NTSDMacPlatform) and in the research documents.

## Result: game code (63,694 instructions, 174 functions)

| Measure | Instructions | Share |
| --- | ---: | ---: |
| Recorded as executed in any saved record (lists, PCs, entries, traces) | 32,735 | **51.4%** |
| … in the fixtures that Native tests compare | 29,965 | 47.0% |
| Functions with recorded execution or a compared corpus: 157 of 174 | 58,845 | **92.4%** |
| Cited in the Swift port: inside cited ranges only (lower bound) | 32,961 | 51.7% |
| Cited in the Swift port: plus whole functions cited by entry (upper bound), 151 functions | 60,164 | 94.5% |
| Cited in research documents or the port, 160 functions | 62,318 | 97.8% |

How to read it:

- **Executed instructions: between 51% and 92%.** 51.4% is a lower bound.
  Some corpora store calls rather than instruction lists, so a function they
  compare counts here only through the addresses that some other record
  saved. Examples: special moves 403a40 (7,770 calls), character AI 4094b0
  (3,770), Mission 437860 (2,960), War 43a860 (1,410). At the function level
  the corpora cover 157 functions, which hold 92.4% of the game's
  instructions. Inside those functions, branches no corpus exercised are not
  proven equal.
- **"Exactly" means equal on the compared cases.** The Native comparison is
  byte-for-byte (state, masks, events) for the recorded calls. It is not a
  proof for all inputs. Behaviour the EXE does not fix is declared, not
  recovered: Windows/DirectX answers, the font, heap addresses.
- **Port citations 52–95%.** A range citation is a lower bound. A citation of
  a function's entry ("Whole 43f010") counts the whole function, an upper
  bound for large functions ported in parts, such as the gameplay body 41bc90
  (6,810 instructions).

The 17 game functions with no record (4,829 instructions, 7.6%):

- **Ported and executed inside compared callers, 1,249 instructions:**
  - 408cb0, 4034f0 and 4061a0, inside the character-AI corpora;
  - 43e620, the replay loader, which has its own 27-call corpus;
  - 4389a0 and 438ad0, inside 438b40's calls.

  Their evidence is filed under the caller.
- **Developer modes, 2,106 instructions.** These are the top-level
  dispatcher's mode 1 (4151d0, a `data.txt` loader/editor) and mode 2 (414b70),
  plus 4143d0. They are reached only with the diagnostics flag 450bec set and
  F2/F3 held, and the docs list them as open dependencies. Not ported.
- **Undocumented or not ported, 1,474 instructions:** 40d0a0 (749), 414450
  (265), 4146b0 (157), 437220 (147), 406a20 (98; mentioned, not ported),
  40bfb0, 415140, 40d940. Whether play reaches them is not established. Some
  of them are next to the mode-1 helpers.

## Other code

| Part | Instructions | Recorded executed | Note |
| --- | ---: | ---: | --- |
| zlib 1.1.4 | 7,413 | 3,536 (47.7%) | The port vendors the same zlib 1.1.4 sources, deflate and inflate (NTSDReplayCodec) rather than citing addresses; the replay loader corpus compares its inflate results |
| Runtime stubs and EH funclets | 1,057 | 104 (9.8%) | Startup, security cookie, SEH, `_ftol2`; the conversions the game uses are compared (`original-coordinate-precision`) |
| Import thunks | 35 | 18 (51.4%) | Platform calls are answered by the Mac services, not ported |

lib.dll's installed patches (13 EXE sites) are listed with their compared
corpora in [LIB_RUNTIME](LIB_RUNTIME.md). They enter by patched jumps, so a
call-graph count does not apply, and they are not included above.

## Limits

These are static readings of saved records. The executed sets are lower
bounds: absent lists do not mean absent execution. Function-level evidence
from corpus scopes assumes that the corpus executed the named function, which
is what its cases are. Citations measure where the documentation and the port
point, not proof of equality. Independent review is not available. EXE
envelope: this is the first computed figure of this kind. No earlier value
existed to compare with.
