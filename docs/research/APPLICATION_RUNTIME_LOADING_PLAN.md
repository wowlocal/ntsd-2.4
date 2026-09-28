# START → loading and cached cycles in the app

2026-09-28. Parent: [live front menu](APPLICATION_RUNTIME_MENU.md) (a1c5f3c).
Rules: [WORKFLOW](WORKFLOW.md), [PROGRESS_RULES](PROGRESS_RULES.md). This plan
was written while the first candidate was being connected (same session); the
declared limits and checks below were fixed before the evidence run.

**Consumer and criterion:** clicking START in `NTSDNative --original` loads the
whole original catalog, pool and loaded menu on runtime providers and returns
to live iterations through cached loaded cycles, showing the next original
screen. **Proven blocker (parent card):** permit delivery re-runs an attempt per
request; the verified loading caller needs 2072 audio requests (≈45 min).
**Round:** 1. **Executor/reviewer:** Claude; independent review open.

## Finite changes

Core (additive): `OriginalRequestExchange.inlineCursor(serve)` — a missing
request is claimed and served synchronously through the same permit protocol,
its receipt recorded before the reply returns; retries reuse receipts; a failed
service leaves the exchange indeterminate. `OriginalApplicationObservedLoadingAudio.resumeInline`
uses it. Permit cursors are unchanged.

NTSDMacPlatform `OriginalMacRuntimeLoading` (declared runtime policies):
allocations from the runtime heap with zero backing (`allocationFill` 0);
catalog/pool/menu bitmaps as real display surfaces (replies carry result/output
only; Core derives BITMAP fields from original bytes); packaged catalog files
with the verified 65536/4096 stream values; live clock; loading PeekMessage sees
an empty queue; loading draw/present results 0 and not rendered; loaded-menu
GetDC E_FAIL; Winsock requests of cached cycles fail with SOCKET_ERROR (local
game, WSAStartup never called); Host tails answer time and record Sleep; the
committed loaded batch replays only draws after the input continuation (the
requesting iteration's staged effects were already performed through permits;
the blocking loading's progress frames are not shown). Runtime display budget
3 GiB (669 catalog images ≈228 M pixels at 5 bytes/pixel).

## Checks and limits

1. Inline cursor unit test (receipts, retry reuse, family rejection, failure).
2. Runtime startup → live menu → click START at the saved case-47 point →
   one-attempt loading with exactly 2072 audio requests, 621 files and 423
   buffers → Host tail → cached cycles returning with replayed draws; capture.
3. Regressions for the changed exchange: exchange/startup/loading-audio and the
   fast `OriginalMacLoadingAudioTests` methods, runtime startup/menu/iteration
   suites. The 45-minute whole caller is not repeated: its permit path is
   unchanged by the additive inline mode.
4. App (release build): scripted click on START, loading, capture.
Debug/release builds in `build/swiftpm-app`; each test ≤ 3600 s.
Out of scope: match launch/gameplay, text raster, music output, shutdown.
EXE envelope not recalculated.
