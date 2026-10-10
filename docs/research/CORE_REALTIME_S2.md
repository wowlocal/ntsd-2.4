# RT tier 3 S2 — record storage v2

A read-only design of 2026-10-09 at 8b98653 ([tier 3](CORE_REALTIME_TIER3.md),
row S2). Profile `rtd1-vs-dwarf` (6,784 main-thread samples, 1% ≈ 0.154 ms
at 15.38 ms per tick).

## Measured

`_ContiguousArrayBuffer._consumeAndCreateNew` is 9.40% of the main thread:

| Kind | Share | Of it |
| --- | ---: | --- |
| Record bytes and mask copied on `write` | 3.88 | mask memcpy 1.81, bytes memcpy 1.24, allocation ≈0.6 |
| `[OriginalStateRecord]` array copies | 3.01 | per-element `initializeWithCopy` 2.80 (mostly retains) |
| Not records | ≈2.5 | `Operation` 0.77, `RequestExchange` 0.71, `AnyObject` 0.24, … |

`destroy for OriginalStateRecord` adds 3.94% (`swift_release` 3.61). All
record traffic is ≈10.9%, ~1.7 ms per tick: memcpy 3.05, allocation ≈0.6,
retain/release ≈6.3, witness bookkeeping ≈0.6. Write callers (bytes / mask):
`InitialLoading.begin` 0.75 (0.40/0.35), `HitPass.advance` 0.63 (0.24/0.40),
`CharacterAIPass.draw` 0.65 (0.18/0.41), `WindowInput.receive` 0.38,
`LoadedMatchEntry.run` 0.31, `bindings.store` 0.29, `QueuedSound.drain` 0.25.
`localInputInPlace` (1.37) and `WorldControl.apply` (1.16) copy the 400-record
actor array (S3's target). Estimates: ~4–7 copies of the 0xb440-byte globals
and some dozens of actor records per tick; ≈1,000 record handle copies and
destroys (2 retains and 2 releases each).

## Representation (S2b)

One `ManagedBuffer<Int, UInt8>` per flat record: header = byte count n; tail =
bytes[n], mask[(n+7)/8] (bit i&7 of byte i>>3 = byte i defined; bits ≥ n
always 0), 8 zero bytes so wide unaligned loads stay inside.
As built (S2b): `OriginalStateRecord` = `flat: Flat?` (8) + `flatCount: Int` (8,
inline: byteCount is read everywhere, and the layout test's 40 bytes stay) +
`large: Large?` (24) = 40 bytes.
Paged records keep their Bool pages; parted records hold flat records.
Uniqueness by `isKnownUniquelyReferenced(&flat)`; no live local strong
reference before a write; pointer access only through
`withUnsafeMutablePointers` (no `.header`, which costs dynamic exclusivity
checks in test bundles; no `.capacity`). Bit helpers work on raw pointers
(one unaligned UInt16 for ≤8 bits; ranges by head byte, words, tail).

Operations keep today's errors and order: `integer` (range, then mask, then
load), `write` (range, then the phase 2d no-op return, then unique, store,
bits), `overwrite` (`flatHolds` no-op test by memcmp and bit compare), `extract`
(a new buffer; an exact part still shared), `zero`, `rawWord`,
`definedBytes`, `leadingBytes`, `==` (identity, count, memcmp of bytes and
mask; padding bits zero), `storageIdentity` (the object address),
`sharesStorage` (`===`), `vacant` (nil). `bytes`, `defined` and `readOnce`
are built on demand, with a probe (`flatWholeReads`) that per-tick paths read
0; `flatCopies`/`flatCopiedBytes` count copy-on-write.

## Increments

- **S2a** (no behaviour change): narrow accessors (`byte(at:)`,
  `isDefined(at:)`, with `bytes(in:)`, `allDefined(in:)`, `extract`,
  `byteCount`) at every whole-array read on a per-tick path, found by a
  temporary deprecation sweep and a call-site probe over a headless vs run.
  Menu and startup paths may keep whole reads (S2b builds them on demand;
  any per-element loop over a whole read must be converted or cached).
- **S2b**: the representation. Oracle (as built): a plain model of a byte
  array and a Bool array in `OriginalStateRecordStorageTests`, a seeded
  random-operations corpus
  over sizes {0,1,7,8,9,15,16,17,63,64,65,0x178,0x420,0x7d8,0x1f50,0xb440} and
  every offset mod 8; copy probes. All suites (storage model), clean builds,
  phone A/B, independent review, optionally a ThreadSanitizer headless run.
  Paper ≈ −4.9% of the main thread (~0.75 ms); expected 0.25–0.38 ms (vs),
  0.2–0.3 (Demo).
- **S2c** (if the profile justifies it): a conservative all-defined flag;
  a one-word record with S3; bit masks for replay pages (memory).

Flagged, not proposed: the layout test changes to 32 bytes; `storageIdentity`
changes type; `init(bytes:defined:)` no longer shares the caller's arrays
(visible only to identity probes); progress-event fields added.
