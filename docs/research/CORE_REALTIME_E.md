# Core real-time, tier 3 step (e): compact Blt and fill commands

Design note before code ([tier-3 plan](CORE_REALTIME_TIER3.md), G3; the
pipeline design's step e). Game behaviour, every public value and every
error stay identical.

## Measured (rtg4-vs-dwarf, 6,360 main-thread samples, after G3a–G3c, d1, d2, g)

- Allocation and deallocation of arrays: `swift_allocObject` 4.78% of the
  main thread, `_ContiguousArrayStorage` deallocation 7.34% (inclusive).
- Per Blt, `OriginalApplicationGraphics.blitCommand` allocates the
  `bindings` array (0.86% under `swift_allocObject`); the command is a
  ~400-byte inline struct with 13 stored fields that every copy of a command
  list retains and every destroy releases.
- The runtime's replay copies each command's `event` (its destroy appears as
  a folded `outlined destroy of OriginalWinMainStartup?`, 0.52%) and switches
  on the event's kind string.

## Readers

Production reads only `event` (the runtime's replay of committed batches,
`OriginalMacRuntimeLoading.replay`) and `result`. Tests read every field
(`family`, `request`, `bindings`, `dependencies`, `sourceColors`, …) and
compare whole command lists with `==`; two tests build commands with the
memberwise initializer.

## Mechanism

1. `Command` keeps every public field, now computed from one stored value:
   - a Blt record: target reference, source reference (optional), the Blt,
     the result and the source colours;
   - a fill record: target reference, the fill request, the result;
   - any other command: a box holding the 13 fields as today.
2. The computed fields of a record are exactly what `blitCommand` and
   `fillCommand` store today: family `"front"`; no request, responses or
   output; `event` = `OriginalFrontScreenEvent(blit:)` / `(fill:)`;
   `bindings` = target (and source for a Blt); `dependencies` =
   `["nullSource"]` for a Blt without a source surface, else `[]`; no opaque
   references; rectangles from the Blt (source and destination) or the fill
   (destination only); colours from the record (nil for a fill).
3. Equality: two records of the same kind compare their stored fields; any
   other pair compares all 13 public fields. Exact because a record's
   expansion is one-to-one (target and source come back from `bindings`, the
   Blt or fill from `event`, the result and colours directly).
4. The memberwise initializer stays (it builds the box), so tests and the
   other command builders are unchanged.
5. Replay: `Command` exposes the record's Blt or fill (`replayBlit`,
   `replayFill`) and the runtime hands them to new display entries that run
   the same checks as `validateFront`'s `blit` and `fill` branches (split out
   so both paths share one body) without building an event. The display's
   operation log, kept only when `keepsOperationLogs` is set, builds the
   event when it records.

## Expected saving and risk

0.15–0.35 ms per tick (plan): one allocation fewer per Blt and fill, command
lists about a third of the size to copy and destroy, no event copy per
replayed draw. Risk medium-high: a public type's storage changes. Checks: a
twin test comparing every public field and `==` of record commands with the
boxed form over random Blts and fills (with and without source, bitmap and
plain sources, nil effects); every graphics, gameplay and runtime suite;
frames and scenarios identical; independent review.
