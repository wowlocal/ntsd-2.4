# Whole application surface recovery

[OriginalApplicationRecovery](../../native/Sources/NTSDCore/OriginalApplicationRecovery.swift)
implements whole43e890, including43e860, whole401ae0/401a80 destruction and
43bdd0 window/DirectDraw recreation. The shared
[OriginalDisplayDestruction](../../native/Sources/NTSDCore/OriginalDisplayDestruction.swift)
also serves the existing Alt+Enter lifecycle path, whose prior corpus remains
unchanged. This closes the controlled recovery-body dependency of the timer;
actual43e9a0 negative-result reachability and whole application composition remain open.

## Reference and comparison boundary

The [finite plan](APPLICATION_RECOVERY_PLAN.md) declares the game behavior,
low-level observations and failure boundary. The pinned NTSD2.4 EXE SHA256 is
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`;
bundled lib.dll is
`28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba`.
Unicorn2.1.4 executes the complete accepted installer parent, then the actual
recovery and display children. Caller inputs, Win32/COM responses and helper-entry
backing are declared. CW023f is supplied at the direct-call boundary, rather than
established by a full startup sequence. No replacement success return stands in
for a game helper.
This is not Windows device restoration, actual callback delivery, CRT startup,
full WinMain or macOS window evidence. Native ships no DLL/emulation/EXE patching.

The corpus has318 whole recovery returns and3 whole43bec0 initializations.
One additional call reads a null back surface after an earlier ordinary creation
failure; native explicitly rejects it and rolls back. These are321 successful
whole comparisons and one separate rejection, not322 successful matches.

Both modes cross draw/primary presence, first-restore HRESULTs and second-restore
boundaries INT32_MIN,-1,8876024b/c/d,0,1,INT32_MAX. Unused first responses when
primary is absent are not duplicated. Representative windowed/fullscreen and
fallback paths additionally vary each observed ordinary creation/release/API
result. Two initializations each continue six recovery calls using their own
surfaces, globals and stack. A third initialization produces the subsequent
creation-failure/null-back chain. All14 retained before-states and the576-byte
observed stack regions reproduce the previous call's own after-state exactly.
These are direct calls at a declared caller ABI, not WinMain/message-loop delivery.

All5113 requests compare, including604 Restore requests,566 Releases and214
DestroyWindow requests. There are2236 ordered global stores,840 structures/
65968 structure bytes and2431 observed helper returns. The full322-case source
storage audit covers14858368 global bytes;321 successful native after-states
cover14812224 bytes, with the separate failure retaining its native before-state.
Masks and object-release histories are compared as well. The576-byte stack
windows reconstruct from28955 CPU writes and116 API writes. They are a bounded
source provenance audit, not a native C stack/ABI equivalence claim.

565 actual EXE instruction starts execute after the parent; no DLL/CRT starts
are added by these calls. The restore/caller body covers32 of34 static starts.
43e8b1/43e8b6 emit a debug string only for negative43bdd0, but this entire
recreation helper returns0/1. All217 actual display returns retain that range.
The missing two starts therefore do not require a fabricated negative child
return. No all-application branch-coverage claim follows. The installed13 patch
spans do not intersect these executed instruction byte ranges.

## Original decisions and ownership

43e860 conditionally calls primary455634/vtable+6c, discarding its result. It
then reads back surface455608 and calls the same method without a null guard.
A nonnegative back result or exact8876024c becomes0. Every other negative result
is returned unchanged. A first-surface error alone never causes recreation.

43e890 returns that0 immediately on the normalized path, preserving the prior
458434 flag. Otherwise it stores458434=1 and destroys the display.401a80 checks
DirectDraw457578 first: if it is zero, even nonzero surface globals are skipped.
With a draw object, it releases and clears back455608, then primary455634, then
releases and clears457578. Numeric Release results do not change this order.
401ae0 next calls DestroyWindow only for nonzero live4546f4; it does not clear
that HWND itself. This complete behavior is shared with the lifecycle caller.

Next, actual43bdd0 recreates the window and surfaces in the existing mode.
Even its0 result proceeds to ShowWindow(live4546f4,5), including HWND0 after
failed creation. Finally458434 becomes0; the whole recovery result retains the
numeric ShowWindow result, including negative values. This is the recovery's
return value, not proof that the application dispatcher returns it.

Initial global backing is PE loader storage followed by the accepted installer's
normal cookie/complement stores at44eea4/44eea8. Those two words are retained
as declared parent output; this study does not implement native security-cookie
startup. The first verifier incorrectly assumed pure PE bytes, then was corrected
to reconstruct those unchanged observed parent stores. No protected storage was
corrupted, no source expected bytes changed and no protection check was bypassed.
Other own initializer/COM resource outputs are generated and retained by the
native test context rather than copied from expected after-snapshots.

## Ordinary failure and native rollback

The third own chain initializes a window, requests recovery with a negative back
result, and supplies CreateWindowExA result0. Actual destruction already cleared
both surfaces.43bdd0 returns0;43e890 still calls ShowWindow(0,5), clears the flag
and returns. The next recovery reaches43e876 with EAX0 and attempts a four-byte
read at address0. Unicorn records access19 and
`Invalid memory read (UC_ERR_READ_UNMAPPED)`. This follows an ordinary resource
failure; no pointer/control corruption is injected. Native rejects missing back
surface with an explicit error and preserves its already committed failed-
creation state. This call is outside the successful return count.

Six native trials fail after the second Release, second surface creation, final
ShowWindow, final flag clear, missing surface-description backing and final
observation. Globals, created/released object records and buffered request state
all roll back. Context must have value semantics; already submitted external
platform effects and reference-type internals cannot be rolled back by a copy.
Synchronous Windows callback reentrancy, actual driver ownership and own earlier
stack provenance are not inferred from the supplied helper backings.

## Reproduction and acceptance

[oracle_application_recovery.py](../../tools/oracle_application_recovery.py)
retains322 atomic cases and93 blobs.
[verify_application_recovery.py](../../tools/verify_application_recovery.py)
checks the complete installer parent, source instruction bytes, requests/stores,
structures, stack, masks, owned chains and the separate fault.
[accept_application_recovery.py](../../tools/accept_application_recovery.py)
publishes lossless evidence after completed isolated native acceptance.
The report is [application-recovery.json](../evidence/application-recovery.json).

The first four-case probe returned in the original but failed the new observer's
pending-helper assertion: caller return PCs were outside the inherited observer
range. The fixed observer records those actual returns. Its four completed cases
remain identical to the final corpus, and the first failed trial's requests/stores
are identical to the completed first case. Frozen producer, error and logs remain;
no live process was restarted for silence and no original rule was changed.

Raw release13 tests passed23.212s/build203.64s, including retained window
initialization, lifecycle, art setup and message loop. Raw11152693 bytes SHA256
`9169ba4a8fd81844fec810c5f2b500e33d94fbbabaa6871a26c71a0237888550`
pack losslessly to1368288 bytes SHA256
`6b0e131e5a14fe66dfe4262869dad62cf98a34487b9dfdf681cc06e2e368753f`.
All237 prior fixture pins remain unchanged;238 current. Full raw/packed bytes,
JSON/SHA,93 blobs,322 parts and10 codec vendor hashes independently verify.
Final packaged13release tests passed23.211s/build0.3s without raw overrides.
All source and owned SwiftPM jobs are terminal; NTSDNative linked.
Final packaged results and terminal job records are in
`build/research/application-recovery-work.json`. The isolated committedca2abac
export excludes the six foreign transform files. CUA inventory again failed
with native pipe startup unavailable; no window/input/device action was exercised.

Next remains actual whole43e9a0/static-World/worker composition, earlier CRT/NLS,
private stack provenance, library routing/transforms and the complete native
application. Full matches/content, Windows devices and clean-Mac acceptance stay
open. Recovery tests and a linked NTSDNative do not prove those requirements.
