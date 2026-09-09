# Original catalog numeric reads at explicit 53-bit precision

The separate scanner boundary identified in [COORDINATE_PRECISION](COORDINATE_PRECISION.md)
has now been exercised through the whole original text catalog. All loaded
records, masks, allocations, events and scan observations reproduce the historical
capture byte-for-byte when both EXE and scanner CPUs explicitly select 53 bits.
This establishes the catalog's results under this supplied precision contract;
it does not turn the separate scanner into the original Windows thread.

EXE SHA-256:
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.
MSVCR80 SHA-256:
`c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d`.

## Original execution and inputs

`oracle_catalog_precision.py` runs all of `4122f0` through its actual `ret 8`,
including the real Object, BG, Stage, bitmap and sound-registration children.
It uses the original registry and all 137 Objects, 17 backgrounds and the
original stage.dat (25 stages / 138 phases), with the historical text/a5 backing.
Device/file/allocator/thread boundaries remain those of [LOADED_CATALOG](LOADED_CATALOG.md).
No source DAT or expected result is modified.

The main EXE CPU and its separate `CRT()` CPU each receive explicit CW027f,
FPSW0 and empty FPU tags before loading. This selects the same nearest/53-bit
arithmetic precision as the original startup's CW023f, without claiming execution
of that startup in this standalone catalog run. Every non-decoder `fscanf` runs
the actual pinned DLL. Before and after each scanner call, CW027f is checked;
the returned x87 stack and tags are empty. Decoder `%c` retains the previously
declared byte-input boundary.

| Original format | Calls |
| --- | ---: |
| `%s` | 510,027 |
| `%d` | 408,268 |
| `%lf` | 863 |
| `%d %d` | 523 |
| `%d %s %d %s %s` | 137 |
| `%d %s` | 60 |
| `%d %s %s` | 17 |
| `%s %s %d %d` | 17 |
| Total | 919,912 |

For every actual `%lf` invocation, the tool saves the complete decoded source
file, its consumed offset, original caller PC and output destination. It does
not extract a numeric token with a host parser. The complete remaining file
suffix is then passed to two additional persistent CRT CPUs: one with unwritten
FPCW0 and one with explicitly written CW037f/64 bits. These controls execute
the real scanner for the same input; they do not affect the main load.

There are 672 Object header reads at 16 caller PCs (40f7e1..40fa57, 42 original
files) and 191 Stage reads at caller40cf81, for 863 calls from 43 decoded files.
Each succeeds with one eight-byte assignment, no other output writes, errno0
and EOF false. All three modes agree on complete outputs, return, consumption,
EOF and errno. As established previously, reading unwritten FPCW0 alone does
not identify an effective precision; this result is only the observed equality
for these actual DAT inputs.

## Full catalog and independent native comparison

The full 95,289,959-byte raw capture has exactly the historical SHA-256
`8ff43ea70036d84dbbea5309387176595658b0246aa3ff5773e8e22d08f12dee`.
There are no changed top-level fields, including all 919,912 scan observations
and the complete resource events. The historical fixture is retained unchanged.
The new transport keeps all records, allocations and blobs, pruning only the
same non-native scan/device observations as the historical catalog transport.
Full `%lf` observations are separately retained in the new numeric corpus.

`OriginalCatalogPrecisionTests` reconstructs the complete native catalog from
the original source bytes through `LoadedCatalogReference.compare`. Expected
loaded values never seed the native loaders. The comparison includes 137 Objects,
17 backgrounds, all 60 Stage storage records, 15,388 frame occurrences, 829
bitmaps and 14,586 Frame allocations: 112,063,739 bytes with defined masks,
checksum31,475,378, and the original shared sound/resource order.

Its second test gives `OriginalFrameScanner.binary64()` each complete decoded
file suffix. It compares the exact eight output bytes, scanner position, EOF
and assignment result with the original DLL, checking the entire accepted
return/errno domain. All 43 source blobs are decompressed and SHA-verified.
The native decimal implementation is unchanged; no tolerance or expected-value
substitution is used. This corpus establishes the original DAT numeric reads,
not arbitrary decimal strings, incomplete exponents, overflow or failure lexing.

## Reproduction and boundaries

```sh
uv run --script tools/oracle_catalog_precision.py
python3 tools/accept_catalog_precision.py
swift test --package-path native -c release --filter 'OriginalCatalogPrecisionTests|OriginalLoadedCatalogTests|OriginalCRTTests'
```

The source run requires the pinned historical full catalog capture. Acceptance
checks the complete historical equality, the scalar observations against the
actual whole-loader scan sequence, decoded source identity and every blob. It
then compares native results before publishing two lossless resources, checking
all 154 earlier fixture hashes. SwiftPM commands and publication are sequential.

Both native acceptance tests passed in11.501s (release build122.80s) before
publication. The final packaged regression, without raw-corpus overrides,
passed all six tests in23.811s (build125.47s), including all three retained
catalog variants and the original integer scanner. NTSDNative also compiled
and linked; this is not an app-window or device-output check.

Reports: [whole catalog53](../evidence/loaded-catalog53.json) and
[actual DAT numeric53](../evidence/dat-numeric53.json). The new raw/packed sizes
are9,906,624/4,724,335 and842,956/417,654 bytes respectively. An independent
unpack verifies complete raw JSON, length and SHA for both envelopes and all
3,366 catalog /43 numeric-source blobs. All154 historical hashes are unchanged;
the inventory is156 fixtures. Verification and current pins are retained in
`build/research/catalog-precision-artifact-verification.json` and
`build/research/catalog-precision-fixture-pins.json`. Source and both SwiftPM
processes are terminal; Python compilation, links and diff checks pass.

The [initialized own chains](INITIALIZED_GAMEPLAY.md) retain their historical
separate scanning boundary. This new whole-catalog result resolves the question
of changed DAT values for explicit53 under that boundary; it is not a new
same-thread CRT integration or a full Windows startup/device capture. General
CRT decimal parsing and actual Windows DLL binding remain open.

The next [ACTOR_SCHEDULER](ACTOR_SCHEDULER.md) study now implements whole40d960
with actual sound behavior. Its enclosing interleaved400-slot loop41f550..4214cf
remains the next task, preserving recovery, creation, deletion and per-slot
ordering. The first initialized tick still ends at41f550 without
returning. App integration, a finished Naruto/Sasuke District match, other
modes/AI, real device output and clean-macOS delivery remain required.
