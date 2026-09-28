# Runtime WinMain providers for NTSDApp

2026-09-28. Parent HEAD `b55e8d9`; root `native/` equals the verified
candidate2291 ([promotion](../evidence/native-root-promotion-2291.json)).
Rules: [WORKFLOW](WORKFLOW.md), [PROGRESS_RULES](PROGRESS_RULES.md).

**Consumer in native/ and integration criterion:** NTSDApp gains an
`--original` launch path that runs the recovered WinMain through
`OriginalApplicationObservedStartup` with real Mac window/display/audio services
and new runtime answers for every other startup request, reaching `.started`
with no corpus reply, fixture or expected state. **Proven blocker after this
card:** front-menu iterations take message-loop replies (peek/get/translate/
dispatch/time/sleep) only as a prepared array (`OriginalApplicationHostSession.Inputs.queue`);
no permit-based loop driver exists, so live NSEvent/clock input cannot be served
without predicting Core control flow. That driver is the next card.
**Reason for new runs:** new runtime code; no previous pin covers it. The prior
167-method PASS is not repeated.
**Mechanism round:** 1 (new mechanism). Cheap checks first: compile, provider
unit tests, then the whole-startup runtime test, then an app launch check.

**Status:** implementation. **Game result / milestone:** the app starts the
original application itself, the first step of the native Naruto/Sasuke match.
**Reference:** `NTSD 2.4.exe` SHA-256
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.
**Executor / reviewer:** Claude (author). Independent review unavailable; open.
**Mutable paths:** this plan/study/evidence, `native/Sources/NTSDMacPlatform/`
new runtime files, `native/Sources/NTSDApp/`, one new test file, `native/Package.swift`
only if a dependency edge is needed, CURRENT_WORK/RESEARCH_MAP blocks.
Core rules, expected bytes, masks, fixtures and existing tests stay unchanged.
**Safety incidents:** existing register entries stay open; no original execution.

## Runtime contracts (declared, not Windows observations)

| Request | Runtime answer | Basis / open item |
| --- | --- | --- |
| milliseconds, filetime | existing `OriginalMacStartupClock` (monotonic ms, realtime FILETIME) | origin/resolution vs WinMM not claimed |
| initializeCriticalSection | 24 bytes: DebugInfo 0, LockCount -1, rest 0 | OS-private; recovered code only emits enter/leave on 4554a4 (no byte reads) |
| initializeCOM | S_OK (0) | first CoInitialize on the thread |
| timezone, zoneName | TIME_ZONE_INFORMATION derived from the macOS zone: standard bias, annual DST rule from this year's transitions as Windows "Nth weekday" SYSTEMTIME; names from the zone's English standard/daylight names, ASCII conversion into the requested capacity | Windows display names are not derivable; Bias/DST rule decides local time. Non-ASCII/unsupported rule → explicit boundary |
| allocateCalendar, music allocate | runtime logical heap: 16-byte aligned, disjoint, never reused, zero backing, arena `0x10000000..<0x40000000` | Windows heap addresses/backing not claimed |
| panel info/content | package bytes, overridden by the user overlay `~/Library/Application Support/NTSD Native/`; absent content stays absent | original writes beside the EXE |
| panelWrite/panelClose | staged; result = byte count / 0; applied to the overlay only after `.started` commits | no physical write inside an attempt |
| panelBitmap/panelDevice/allocatePanel | explicit unsupported boundary | unreachable with shipped `adinfo.txt` (content `data\ad0.txt` absent) |
| music (DirectShow) | success path: graph/interfaces as opaque runtime identities with COM refcounts, SetNotifyWindow/Flags/SetLogFile/RenderFile/Run/put_Volume S_OK, get_Volume S_OK, CreateFile handle, MultiByteToWideChar for ASCII paths, CloseHandle TRUE | **audio output is silent**: WMA decode/playback is a separate dependency; graph events not posted |
| cursor | LoadCursor(0,IDC_ARROW) returns the window backend's shared arrow token; SetCursor returns that class cursor | previous cursor is not stored by recovered code |
| joystick | no device attached: numberDevices 16, position 167 (JOYERR_UNPLUGGED) without output writes | standard WinMM driver assumption; controller support later |
| sound, waveAudio, window | existing Mac audio/window/display services | unchanged |
| startup WAV inputs | mmio results from original bytes (stream 1, descend 0, format read 18, data read = payload length, close 0) as used by the passing tests | well-formed PCM WAVs only; others → boundary |

## Finite checks and limits

1. `swift build` of NTSDMacPlatform/NTSDApp and the new test file (debug).
2. Provider unit tests: zone rules for UTC, Europe/Moscow, Europe/Berlin,
   America/New_York against their public Windows registry rules; name conversion
   and capacity; heap disjointness/alignment/exhaustion; COM refcount/identity;
   joystick/cursor/critical-section values; staging applied only after commit.
3. Whole WinMain with runtime providers and a pinned clock/zone: `.started`,
   exchange finished, every receipt answered by a Mac or runtime service, both
   formatted dates equal an independent calendar computation of the pinned
   instant (+4-day expiry), and the staged `adinfo.txt` bytes equal the
   source-recorded defaults write for the same info bytes in the saved startup
   corpus (read only as evidence, not supplied to Native).
4. App: `NTSDNative --original --exit-after-startup` prints one JSON summary
   (window token, request counts by kind, dates) and exits 0 on a real window.
Limits: debug build in `native/.build` (internal disk, 6GiB reserve kept);
each test ≤ 600s; three correction rounds, then diagnosis. Retained regressions:
`OriginalMacAudioBackendTests`, `OriginalMacWindowBackendTests` (changed
dependency: shared window/audio services), run once after the new tests.
Out of scope: front-menu loop, loading, text raster, music output, Windows/
device acceptance, full match/game. EXE envelope not recalculated.
