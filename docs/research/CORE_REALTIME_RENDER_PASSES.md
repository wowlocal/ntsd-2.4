# RT render passes — removing whole-frame passes on the render thread

Study: [CORE_REALTIME](CORE_REALTIME.md); background: [RENDER](CORE_REALTIME_RENDER.md)
(phase 1c pipelining), phases 1g (known-mask full flag), 1i (crop buffer
pool), 1j (keyed copies without known-bit work). A static plan by a
read-only planner on 2026-10-07 (nothing built or run); DB =
`OriginalMacDisplayBackend.swift`.

## Measurements behind it (A12)

- Render thread 17.5 ms per tick after 1j (tier 2 needs ≤16 ms).
- Standalone benchmark (`blitbench` in the session scratchpad, results in
  the 1j evidence): one 794×550 frame costs ~1.69 ms for a channel swap, an
  alpha-only copy or a plain copy alike (memory-bound); the black side bars
  0.25 ms. A BGRA window format would save nothing; removing a whole pass
  saves ~1.7 ms.

## Passes per gameplay tick (windowed, Android; from the code)

Present mode 3 (OriginalWindowInitialization.swift:208); the back buffer is
the 794×550 viewport, the primary is screen-sized with a clipper limiting
delivery to the client rectangle (DB:404-414).

1. The dispatch entry's back-buffer clear (OriginalApplicationDispatchEntry:55-58,
   served inline, queued as whole-surface `fillRows`, DB:539-545, 1083-1094):
   one full write.
2. The camera stage: background fills and layer blits into the back buffer
   (OriginalGameplayBody:130, OriginalBackgroundDrawing:15-80; key 0 layers are
   unkeyed, OriginalBitmapDrawing:96; known rows take the memcpy path,
   DB:1122-1128): stage-dependent.
3. Sprites, impulse text, HUD, notices (keyed copies on the 1j path): partial.
4. `presentSurface`: back buffer → primary Blt (method 0x14,
   OriginalMenuPresentation:140-143 via OriginalGameplayOutput:46-49) served as
   an unkeyed full copy (DB:1194-1198): one full memcpy.
5. The same closure crops the primary's client rectangle into a pooled
   buffer (DB:442-461): one full memcpy.
6. Android `show` keeps the frame for redraw and draws it: black bars,
   channel swap, post (NTSDAndroidHost:79-124): one full read and write plus
   bars.

Only the 0x14 copy presents during gameplay; the replay flushes before each
batch (OriginalMacRuntimeLoading:558). Memcpy on the phone (24.5% of the
render thread, ~4.3 ms) ≈ 2.5 passes: the crop, the 0x14 copy and about half
a frame of background rows (the Mac split overstates it: its crop reads
cached data).

## Mechanisms

- **P1 — fuse the 0x14 copy and the crop.** On the render thread, when the
  copy is unkeyed, not mirrored, the source rectangle is the whole source,
  region = destination = delivery rectangle and the source mask is full: the
  delivered frame is one contiguous copy of the back buffer, and the primary
  gets a deferred write "rectangle ← frame, known over it" (one slot next to
  `pending`, DB:140-148), applied before any read or write of the primary
  (`values`/`known`, `pixels`, `observation`, `framebuffer`, fills, text); a
  new deferred write replaces the old only when its rectangle contains it.
  Identical because today's copy writes every value and bit of the region
  and the crop then copies those bytes as they are. ~1 pass (~1.7 ms).
- **P2 — lend the back buffer as the frame.** After P1 the frame is the back
  buffer's bytes: wrap them (`Data(bytesNoCopy:)` with a deallocator that
  returns the buffer to a pool), split the storage's pixel access into
  readers and writers, and give the first write to a lent storage a pooled
  buffer without copying when it is a full overwrite (the next clear), or a
  copy otherwise. No frame holder may ever see its bytes change. ~1 more pass.
- **P3** — a whole clear overwritten by row-covering opaque copies before any
  read is skipped for those rows (≤0.35 ms; only if a counter shows it).
- **P4** — per-batch overdraw skipping (only if a counter shows >½ frame).
- **P5** — black bars only where `ANativeWindow_lock`'s dirty bounds say
  (~0.25 ms, device-dependent).

## Order, tests, review

A scratch counter per operation class and overdraw first; then P1 and P2
(each an independent review: storage model; P2 also threading and a
ThreadSanitizer run as in 1c); P3/P4 only if the counters justify them; P5.
Tests: a side-by-side oracle with the fast paths off over seeded sequences
(fills, keyed/unkeyed/mirrored copies, unknown sources, 0x14 presents with
moved rectangles, flips, stretches, text) comparing every delivered frame
and every surface's pixels and masks; lent-frame immutability (byte copies
checked after later ticks); a digest of every present over the 10 scenarios;
the existing gates (headless with and without frame digests, AppKit,
emulator with FreeType text, redraw after a surface comes back).
