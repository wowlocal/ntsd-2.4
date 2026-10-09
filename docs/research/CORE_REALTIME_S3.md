# RT tier 3 S3 — the actor table copied per chunk

A read-only design of 2026-10-09 on top of S2b ([tier 3](CORE_REALTIME_TIER3.md)
row S3, [S2](CORE_REALTIME_S2.md)). Profile `rts2b-vs-dwarf` (6,195 main-thread
samples, 1% ≈ 0.143 ms at 14.3 ms per tick).

## Measured

Two whole copies of the 400-record actor array per tick, each at the first
actor write under a value the Host keeps for a retry:

| Level | Held by | First writer | Copy |
| --- | --- | --- | --- |
| Loaded entry | the tier's array from `bindings.read` (LoadedCycleSession.model, the cycle's and the entry's candidates, the Host's pending input) | `localInputInPlace` (`actors[a].write`, OriginalLocalInput.swift:77) | 1.15% |
| Gameplay body | the array `bindings.store` installs in the Ready's state (GameplaySession's model, the body's `next`) | `WorldControl.applyInPlace` (`&pool[i]`) | 0.89% |

Their deaths: `[OriginalStateRecord]` array destroys 2.24% (99% releases, the
records live on), ≈2.0% for these two arrays. Target ≈4.0% ≈ 0.58 ms per tick.
WorldPhysics' record destroy (0.50%) is single-record temporaries (catalog
header/frame closures, `state(a)`), not array copies (row L).

## Design

`OriginalActorTable`: 25 chunks of 16 records (`[[OriginalStateRecord]]`, S1's
nested pattern), RandomAccessCollection + MutableCollection with `_read`/
`_modify` subscripts, `Indices = Range<Int>`, an iterator walking the chunks,
canonical chunking (so synthesized `==` equals the flat array's), `[]` without
allocation. A write after a copy duplicates the 25-entry table and each written
chunk (~110 references per level instead of 400). Call sites that only
subscript, count, iterate or map compile unchanged; ~22 `inout
[OriginalStateRecord]` pass signatures, 11 pass structs, ~15 read-only
parameters, the bindings tier and the tests' locals change type.

## Increments

- P0 (probe, not committed): distinct chunks written per level (expect 4–7 of
  25; stop at 15 or more).
- S3a: the type and its oracle (`OriginalActorTableTests`: a seeded twin corpus
  against `[OriginalStateRecord]`, copy probes per chunk), no production use.
- S3b: the switch (all suites, clean builds, phone A/B, a DWARF profile, an
  independent review). Paper ≈0.35–0.4 ms; conservative 0.12–0.2 ms.

Flags: no behaviour change (identity probes only); public API types change;
S3b edits NTSDReferenceChecks (outside the card's allowed paths, as R3 and B2
did). Design B (Q1) would remove one copy and death per tick (about 0.5% after
S3).

## Result (2026-10-09)

S3a+S3b measured and **not committed**: all behaviour gates passed and the
review approved, but the A12 showed no gain (vs and Demo within run
variation). The profile shows the actor-array copies gone and less reference
counting, offset by more record destroys and a heavier gameplay body: reads
through the nested chunks appear to retain and release records that the flat
array lent. Patch parked at X5 `logs/rts3-actor-table-parked.patch`; evidence
`docs/evidence/rt-s3-actor-table-parked-20261009.json`.

