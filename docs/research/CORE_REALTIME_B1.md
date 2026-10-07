# RT B1 — the menu state's `full` record in parts (R3 stage 3)

Study: [CORE_REALTIME](CORE_REALTIME.md); design context:
[TIER2](CORE_REALTIME_TIER2.md) section B, [R3](CORE_REALTIME_R3.md) stage 3
(invariants I1–I6). An implementation plan by a read-only planner on
2026-10-07 at 3b3d7f5 (nothing built or run); estimates to be measured per
piece.

## Decision

A third representation inside `OriginalStateRecord` (next to flat and
paged): a stored `parts: Parts?` (a final class, copy-on-write by hand),
established explicitly by `MenuSession.State.init` for the 0xc3a8-byte
`full` record (not chosen by size in `init(bytes:defined:)`: the paging
tests use flat 0xc3a8 records). A slice or replace at one part's exact
extent is O(1) (shares the part's buffers); every other operation takes a
slow path with logical offsets and the flat record's errors; `bytes` /
`defined` are assembled on demand, cached per written version (as `Pages`
does), and counted by a probe (`partAssemblies`). A wrapper type used only by
`MenuSession.State` was rejected: `full`'s type flows into the dispatch
entry, checkpoints, observations and ~45 test files.

Layout (`MenuSession.partStarts`): P0 0x0000 globals · P1 0xb440 local · P2
0xb580 counter · P3 0xb588 saved playback · P4 0xb8a8 replay alias · P5
0xb8b0 · P6 0xbb00 world · P7 0xc2d8 (key-scan words, hostname) · end 0xc3a8.

## Operation semantics

- Invariants: parts are flat; starts strictly increasing from 0 to the
  total; total below the paging threshold; every mutation of the parts is
  preceded by making them unique.
- `byteCount` from the parts; `checkedRange` unchanged (logical offsets).
- `integer`: within one part, the definedness check throws
  `undefinedBytes(offset:` logical `)` and the value loads at the local
  offset; across a boundary, all bytes checked first, then assembled (the
  flat order). A part's own throwing API is never called (its errors would
  carry local offsets).
- `write`: within a part, the 2d no-op return (`flatHolds`) keeps sharing;
  otherwise unique then store; across a boundary, a no-op check then byte by
  byte.
- `overwrite(at:with:)`: an exact part extent installs the source (an
  identity no-op when already shared); inside one part as flat; across parts
  rebuilt per part; the flat target also gets a run-wise copy from a parts
  source.
- `extract(range)` (behind `State.slice`): an exact part shares it; inside
  one part a flat copy; spanning parts a gathered copy; a non-parts source
  exactly today's array copy.
- New range accessors `bytes(in:)`, `allDefined(in:)`, and `definedBytes`,
  `leadingBytes`, `readOnce` built from runs without filling the cache.
- `==`: parts vs parts with the same layout compares parts (identity fast
  paths); parts vs flat compares per part without assembling; else assembled.

## Production call sites that must stop assembling `full`

`full.bytes.count` / `.defined` on hot paths become `byteCount` or the range
accessors (identical values for flat records): `State.validateAliases`
(MS:65, ~12 times per tick and every iteration), `State.slice` (MS:72-75),
`replace` (MS:78), `checkMergeAliases` (MS:91), the dispatch entry's
`finishWorldCall` / `advance` (DE:16, :27) and its keyboard read (DE:35-36,
every dispatch), `Attempt.init` (LMS:185), the catalog session (:158, :204
on every global store, :339/:364/:374), the pool session (:167); optional:
the network-ready diagnostic (RS:461-462), bootstrap (:139).

## Pieces

- **3a** — the representation, its tests and the neutral call-site switches;
  no production record is split. Gates: equal everywhere; phone within
  noise (the extra field must cost nothing); independent review (storage
  model).
- **3b** — `State.init` splits `full`; the O(1) paths and the globals
  sharing go live (`store` installs `match.globals` as P0; `read` slices it
  back out; between ticks P0 and `loadedOwners.match.globals` are one buffer;
  the remaining globals copy per phase belongs to B2). Tests: an MS-level twin
  test (split vs flat over every production extent and invalid ones), the
  read/store oracle extended to the split state (errors, values, sharing),
  an assembly probe asserting no `full` assembly on production gameplay
  ticks. Estimate ~1.2–2.2 ms per tick (~760 KB of copies and ~10 large
  allocations removed).
- **3c** — the bindings' world pair cache (like `ActorPairs`) and `byteCount`
  shape checks (R3 stage 4). ~0.1–0.3 ms.

Tests (new `OriginalStateRecordPartsTests`): a seeded model test against a
flat record over the real layout, random layouts and 1-byte parts (reads,
writes incl. same-value and undefined, `binary64`, overwrites at exact,
inner, spanning, empty and whole extents, extracts and accessors, extreme
offsets), errors compared by description, earlier copies never changing;
explicit logical-offset errors at boundaries; sharing and copy-independence;
equality across representations; the assembly cache and probe.

Risks: a hot `.bytes` left on a split record (100 KB per written version —
mitigated by the table above and the probe), local offsets leaking into
errors, copy-on-write aliasing of the parts object, a flat-path regression
from the extra field (measure; fall back to one optional enum), the assembly
cache's thread safety (a lock, as `Whole`), rollback and retry (value
semantics; the Host retry tests).
