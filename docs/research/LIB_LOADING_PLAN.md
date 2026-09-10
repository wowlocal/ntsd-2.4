# Whole bundled-library loading progress — finite plan

Recover the animated loading screen4242e0..4246ad, including the installed
424352 jump/two NOP bytes, actual library label/text children and the tail
43d230 message pump. This is needed to connect real loading at elapsed times
above33ms; preceding catalog/initial-loading controls use the original no-draw
path and do not establish the animated screen.

Reference: pinned original EXE SHA256
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`, bundled DLL
`28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba`, and VC80
`c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d`.
Controlled Unicorn2.1.4 executes the complete caller and original bitmap/clip,
fill, text, sound, overlay/music/present and message-pump instructions. The
actual DLL installer executes after declared PE relocation/import binding;
its Windows allocation/copy/protection results remain research boundaries.

COM/GDI, clocks, Sleep, ShellExecute and message-queue results are declared
platform responses. Shell requests are recorded only; no URL is opened or
message sent to another application. DispatchMessage is an explicit boundary,
not an executed Windows window procedure or input-device measurement. All
control pointers bind declared records and ordinary platform adapters; no
control-pointer corruption, forced branch patch or protective-structure damage.

Low-level traces establish timer-read/write order, signed/wrapped animation
phase, selection of identical DLL strings with different colors, live target
and DC ownership, link hover/click ordering, and the exact tail transfer/return.
The whole caller replaces neither its children nor its original output order.
Native does not execute a DLL or patch executable memory.

Finite acceptance criteria before publication:

1. Whole calls cover no-draw delta0/33, draw34, catch-up100/101, changing clocks,
   zero initialization, uint32 wrap and signed Sleep calculations. Compare all
   global bytes and actual stores; retain chained timer/phase/DC/click results.
2. Phase inputs cover every remainder/color, negative and wrapped signed
   boundaries. Original caller text remains unread by the library label. Both
   direct label and later overlay use the installed transparent-text helper.
3. Eight link slots cover absent pointer, zero panel word, `?` skipped entries,
   each rectangle boundary, final-column extension, all-skipped/minimum marker,
   click/held/release gates, audio absent/present and ignored numeric failures.
   Bottom link and cursor clamp/wrap are included. All strings stay within
   declared source storage; no deliberate source stack overflow.
4. Actual bitmap/clip/fill requests, sounds, overlay formats/music, present modes
   and Peek/Get/Translate/Dispatch order execute. Fill's92 untouched DDBLTFX
   bytes are explicit helper-entry backing, distinct from recovered application
   stack provenance. Native receives that declared boundary, never expected
   global after-state. Raw source bytes/masks remain immutable.
5. Verify all reached instruction bytes, helper returns/stack/saved registers,
   FPU control/empty-stack preservation, complete resource/global/DLL state,
   and event order. Separate static instruction coverage and executed branch
   outcomes. An unexecuted stop is excluded from original-code counts.
6. Native composes the shared helpers and commits globals/library DC only after
   the whole call succeeds. Late platform-observer and missing-resource trials
   must roll back earlier timer/phase/click/DC writes. External effects are
   buffered until commit. Source errors and explicit rejections are distinct.
7. Raw and packaged release comparisons, retained text/overlay/loading controls,
   full raw/packed/JSON/SHA/blob checks, unchanged prior fixtures and codec
   vendor pins. Revalidate process handles and publish only terminal results.

This controlled study does not initialize the whole library-enabled loading
chain, execute asynchronous advertisement workers, real Windows raster/message
handling, app/device timing or a full match. Those joins remain required.
