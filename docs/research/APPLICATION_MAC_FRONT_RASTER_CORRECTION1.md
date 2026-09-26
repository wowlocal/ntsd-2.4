# Front raster guard correction: caller diagnostic boundary retained

The missing `try` is fixed in a separate exact clone. Its build and package-byte
checks pass, but the first whole-menu test stops at an unsupported Window-family
`debug` request. No raster/menu acceptance follows. The previous all89 ordered-
graphics candidate remains the latest checked Native frontier. See the
[correction plan](APPLICATION_MAC_FRONT_RASTER_CORRECTION1_PLAN.md) and
[preserved first build failure](APPLICATION_MAC_FRONT_RASTER.md).

## Exact correction and observed outcome

One occurrence in OriginalMacDisplayBackend.swift adds `try` before the second
throwing guard condition. Every other byte of the2278-file base is unchanged.
All95 method names, selection bytes and per-method limits remain byte-identical
to the failed task. No test body, expected value, source mask, raster algorithm,
Core/shared-exchange code or resource file was changed.

Preparation57171 finished0 in13.302s. Fresh build58566 completed0 in304.053s,
sampled peak tree RSS6774226944bytes, without guard stop or remaining processes.
There are no warnings from the changed/new raster files;19 historical warnings
remain. Separate package verification checks205Core/61Reference/9MacPlatform/
286test sources, the67432024-byte test binary, fresh outputs and all385 fixture/
1301 runtime resources. This proves the package gate, not Native behavior.

Queue71174 then stopped after its first selected method. Test71198 failed1 in
5.292s (XCTest3.529s), sampled peak RSS786432000bytes. The other94 methods were
never started. The exact error is:

```text
OriginalMacFrontService.swift:31: failed: caught error: "unsupported("debug")"
```

This is an unsupported Native caller dependency. It is not a source fault,
pixel mismatch, safety refusal or successful comparison. The unchanged source
contract in OriginalApplicationArtSetup emits `LoadGameArt: Art loaded.\n` after
a nonnegative clear result. OriginalApplicationDispatchEntry carries that request
through its surface/Window family; the result is ignored by source control flow.
The new service routed it to the Window backend, whose contract deliberately
does not implement diagnostics. The failure is retained without skipping the
request or weakening its full-journal comparison.

## Required continuation

Add an explicit diagnostic callback to the front service for the recovered
Window `debug` shape: no words/structure, one raw byte string. Without a consumer,
reject before beginService. With a consumer, retain its actual reply through the
same journal; a callback failure after begin is indeterminate and retains owners.
The whole-menu control must supply the original declared diagnostic response,
compare its exact bytes and prove that late retry does not repeat delivery.
Add finite missing/malformed/foreign/duplicate/cancelled/throwing callback checks.

This is a separately identified service/test-adapter extension. Do not change
the raster, Core, any prior expected pixels/masks or any accepted old test body.
Retain this failed candidate and its test body verbatim. The original three-round
bound leaves one next Native candidate before another contract diagnosis.

Independent review remains unavailable. Actual Windows/font/cursor/device,
complete menu pixels, other IO/loading, root promotion, input/audio/clean-Mac,
full match and full game remain open. Host is locked and installation approvals
persist; no blind guest input, restart or unlock is attempted. NTSDApp stays
Practice; source59727 terminal34Objects, not137. Existing safety incidents remain
open, and the EXE envelope is not recalculated.

## Preservation and publication

[Publication](../evidence/application-mac-front-raster-correction1.json),
[closing receipt](../evidence/application-mac-front-raster-correction1-close.json)
and [exact correction patch](../evidence/application-mac-front-raster-correction1.patch)
retain the failed comparison. Finalizer76110 completed0 in70.071s and is absent.
The frozen2278-file manifest SHA-256 is
`dc22b1e70981ea8362a0e5cd8a7f25b3e1701b20f48500997a71a46727bf2a0e`.

The artifact archive verifies4974 regular files,213 directories,0 links and
11425577686 logical bytes, including membership, bytes, modes, nanosecond mtimes
and distinct clone inodes. The131-member metadata archive is6092800 bytes,
SHA-256 `aaeb3f4c3a1cc1bb52f41f59e388894df9d88bce3d0b5a4671d7c01d54c4016b`.
Root1034/prior2257/base2278/source55 inputs and the instruction archive remain
unchanged. X5 closes at148944904192 free bytes; observed decrease1202933760 bytes.
No task restart, source execution, root Native promotion or evidence deletion.
The task is frozen; the diagnostic consumer belongs to a separate correction.
