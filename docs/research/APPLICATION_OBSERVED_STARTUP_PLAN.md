# Resumable external startup observations — finite implementation plan

Status: implementation, comparison and independent review open. Owner: Codex;
no separate reviewer is available, author review is not independent. Base HEAD
e55e473, actual candidate is the frozen2249-file prepared-startup validation tree,
including accumulated inputs absent from root1034. WORKFLOW/TASK_TEMPLATE apply.

## Game result and consuming caller

Remove the prepared-only nonwindow boundary in the production whole WinMain startup.
The same Host must suspend at each external request, retain its actual answer and
resource owners across retries, and publish only after every answer is consumed.
Milliseconds precedes window initialization; FILETIME is acquired after the window
responses, not precomputed at the beginning. This enables the actual app startup
needed before the Naruto/Sasuke District match, without claiming a playable game.

Use one ordered exchange for both window and nonwindow requests. Extract the existing
window exchange's owner/cursor/permit/lifetime mechanism into a generic implementation;
retain its public window alias and response behavior. Startup requests validate typed
response families before consuming a permit. Preserve identity-error precedence,
cancellation's late answers, unknown-outcome failures and atomic finish/publication.
The production Prepared provider routes all16 throwing nonwindow families and window
through the new cursor when installed; its prepared mode remains supported exactly.
Prepared files, panelIO, environmentTZ and aggregate sound remain explicit inputs.
Music helper/format notifications do not manufacture terminal platform requests.
Actual host IO never runs inside Core attempts. Copies own cursor positions; no
expected state, source private ABI, undefined backing or simulated success is imported.

Add an external macOS clock producer using integer clock_gettime observations:
CLOCK_MONOTONIC_RAW for wrapped milliseconds; CLOCK_REALTIME for FILETIME100ns from
1601 UTC. Use integer conversion with explicit invalid/range errors and errno failures.
This is macOS observation, not proof of Windows boot-origin/precision/suspend behavior.
Preserve source calendar arithmetic unchanged. Other APIs still require externally
supplied responses; sound/WAV remain aggregate and are not a live audio backend.

## Evidence and finite checks

Only original NTSD is behavioral reference: EXE
3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c;
lib28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba;
VC80c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d.
Read saved WINMAIN_STARTUP, WINDOW_INITIALIZATION, prepared-platform/Host studies,
calendar/panel/output/input/WAV dependencies and archive1174–1235,1650–1831,
3337–3349,3428–3455. No new original/emulator/capture/Windows or refused operation.
Existing incidents remain open; source59727 stays terminal at34 Objects, not137.
Host-clock API references (not game rules):
https://developer.apple.com/documentation/kernel/1646199-mach_continuous_time
https://learn.microsoft.com/en-us/windows/win32/api/timeapi/nf-timeapi-timegettime
https://learn.microsoft.com/en-us/windows/win32/api/minwinbase/ns-minwinbase-filetime
SDK clock definitions are pinned with the implementation review.

Four new complete methods, plus21 unchanged methods (current11 and prior window10):
1. All35 WinMain parents through the actual unified exchange/production provider/same
   Host: retain23 whole/5 stops/7 provenance outcomes,6325events119WAV650window replies,
   full stores/masks/operations/owned state and publication. Count new nonwindow
   receipts from actual requests; do not label35 matches. Existing reference audit
   only observes actual Native calls/stores; production responses alone feed Core.
2. Six late failures plus publication-copy failure, same-owner retry and resource
   lifetimes. Fulfilled answers cannot be acquired twice. Preparation and committed
   state remain unchanged on failure; independent staged copies retain positions.
3. All17 request families including window, typed mismatches before permit consumption,
   owner/permit/cursor/closed/cancel/indeterminate boundaries. Retain entire old10
   exchange/window/WinMain tests because their common owner implementation changes.
4. Integer clock boundaries (epoch,100ns floor,32bit wrap,range errors) and actual
   macOS clock reads serviced only at whole-caller permits, FILETIME after window,
   with a late failure/retry proving samples are retained. Other responses in this
   control stay explicitly supplied. No old expected clock is compared to live time.

Only two existing candidate files change: OriginalWindowRequestExchange.swift and
OriginalApplicationPreparedStartupPlatform.swift. Five new files: generic exchange,
startup exchange, observed coordinator, Mac clock producer and new test class. Old
algorithms/tests/fixtures/expected/masks stay exact. Author review checks ownership,
request payloads, operation order and numeric conversion; unavailable independent
review stays open. At most three correction rounds before contract diagnosis.

## Storage, execution and acceptance

Task application-observed-startup-20260926 under the existing task-owned X5 parent
01a0dc49-738f-7972-8fb0-e98fb2f34408. Verify writable APFS UUID
3A4F5FA6-DC86-4C6E-87E2-EAC2C2D72548,65GiB external/9GiB internal before clone.
Keep40/6GiB reserves plus17GiB source commitment. Implementation allowance4GiB,
stop3584MiB decrease,16GiB logical,7200s,metadata16MiB,root2MiB. APFS work stays
on X5; T7 is separately authorized for artifacts. Reuse preparation/parse/archive
procedures; full regular clone with byte/mode/nsmtime checks, patch roundtrip and
metadata archive. Verify root1034/base2249/source55 and every old test preserved.
Revalidate PID/start/command/cwd/job before process action; never duplicate live jobs.

This increment's gates: concrete implementation, all7 Swift files parse, declared25
methods exist unchanged where retained, patch roundtrip/preservation/full archives.
Fresh build/package/all25 comparisons (including actual Mac clock control) are
mandatory subsequent gates on the frozen candidate with separately bounded storage.
No acceptance claim from parsing alone. Update study/CURRENT_WORK/map and commit.
Independent review/root promotion/physical window+resource mapping/callbacks/live
input+audio/initialized loading messages+fills/Windows/clean-Mac/full match/full game
remain open. EXE envelope is not recalculated. Full goal remains active.
