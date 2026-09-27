# Per-call startup audio candidate: compile and monitor failures retained

The candidate introduces separate DirectSound/WAV responses through the existing
startup journal, but its new test source has a compile error. None of the105
selected methods ran. The preceding [front raster correction2](APPLICATION_MAC_FRONT_RASTER_CORRECTION2.md),
with all95 methods checked, remains the validated Native frontier. This candidate
is not accepted sound playback, a completed startup integration or a playable game.

## Implemented boundary and intended comparison

The [preflight](APPLICATION_STARTUP_AUDIO_PREFLIGHT.md) found two concrete blockers:
aggregate future device outputs and copy events without PCM bytes. The candidate
uses one shared loader for legacy adapters and observed per-call replies. It
separates file/MMIO controls and initial Native storage from actual Create/Lock
responses. Each Lock snapshot is retained, including ignored lost-buffer outputs;
final regions are owned by token, equal-token aliases share writes, conflicting
backing rejects explicitly. Copy requests carry the actual source bytes/masks.
Create/Restore/Lock/copy/Unlock/message order and ignored numeric results remain
in the common algorithm. No mixer, actual device or new Windows execution is added.

MenuSoundStartup, InputStartup and WinMain select the new provider route. The
prepared provider consumes declared file/storage inputs and gets device responses
from the existing request exchange. The bridge records actual response operations
and non-device file/allocation events. Old prepared operation encoding remains.
The tests project the new operations to the old encoding using declared input
controls and separately check every actual response, copy payload and receipt.
No expected after-state initializes Native storage or the controlled service.

The [frozen plan](APPLICATION_STARTUP_AUDIO_PLAN.md) selects105 methods:100 retained
and five new groups. They cover431 WAV cases/409 sources and3 initial callers/54
loads,112 complete menu segments plus10 separate stops/590 loads,35 whole-WinMain
cases, protocol/region controls, and fifth-wave/publication rollback. Expected
bytes, masks and old test method bodies remain unchanged. The copied comparator
invocations and operation projection require independent review, which is
unavailable; author checks are not independent review. These are planned checks,
not passed results for this candidate.

Candidate2281 files include206Core/61Reference/9MacPlatform/288test Swift sources
and1686 unchanged resources. It clones the actual2278-file checked candidate,
including prior working inputs. The13-file patch modifies10 files and adds3.
Root Native is not promoted. Manifest SHA256:
`f4371c62781794d0da6f6bd29d06e17f29d9f682f4c1aa4878ad97e1e780e052`.

## Actual preparation and failures

Preparation21173 completed0 in13.552457208s. Swift syntax parsing succeeded; that
is not type checking. Before any Native execution, inspection found the old
runner read only two phase-number digits. The [runner amendment](APPLICATION_STARTUP_AUDIO_RUNNER_AMENDMENT.md)
preserves all first producers and generates separately named second producers
with105 verified indices, unchanged result predicates and the same monitor body
apart from the recorded versioned input filename. Its first generator attempt
stopped at an overly broad byte-equality assertion before writing generated files;
the exact assertion and diagnosis are retained. No build or test was restarted.

Build24626 started at2026-09-27T00:12:00.550787+00:00. The compiler produced this
new test diagnostic:

```text
OriginalStartupAudioTests.swift:430:51: error: global function 'XCTAssertEqual(_:_:_:file:line:)' requires that 'OriginalStateError' conform to 'Equatable'
```

The control must pattern-match `invalidStorage` and compare its String payload.
This is a test-source compile error, not a Native mismatch or original fault.
Core/App linked products are visible in the partial log, but the test package
and full build have no acceptance. One new deprecated trailing-closure warning
also points to the new MenuSoundStartup invocation; no behavior is inferred from it.

The monitor separately ended with `AssertionError('')` at its existing
`owned_cwd(where_now,pid,P)` assertion. The saved status is `monitor-error`, with
`leaderPoll:null`; the exact sampled PID is not recorded. It is unknown which
sample caused the failure or whether that process was exiting. The tool session
1153 returned1 for the monitor. The Swift build's terminal exit code is unknown
and is not reconstructed from its diagnostic. This is not a safety refusal.

A separate read-only observation confirms the monitor24475 and all14 recorded
build process identities absent, with no task command remaining. No signal or
restart was sent. The original monitor job and complete build log remain intact.
The last persisted monitor peak is3010854912bytes; it is an incomplete sample,
not a claim of final peak RSS or full duration. All105 methods remain unstarted;
no package check or test queue exists.

## Preservation and next action

The [publication](../evidence/application-startup-audio.json),
[close record](../evidence/application-startup-audio-close.json) and
[exact patch](../evidence/application-startup-audio.patch) identify this failed
round separately. Detailed process observations and both error diagnoses are
retained with its candidate and partial artifacts; the final archive result is
recorded below after verification.

The next permitted Native increment is a separately identified exact-clone
correction of the new assertion, followed by a fresh build, separate package-byte
verification and the same105 methods/limits. Preserve this candidate and its
failures; do not rerun or overwrite them. Review the monitor observation boundary
before that next build, retaining strict identity checks for any process action.

The host remains locked; existing Windows installation agreements are approved.
No blind guest input or host unlock was attempted. Actual Windows cursor/fonts,
audio output/latency, independent review, root integration, clean-Mac acceptance,
full match/game and earlier safety incidents remain open. Source59727 stays at
its terminal34-Object boundary, not137. NTSDApp remains Practice; no EXE-envelope
or completion estimate was recalculated.

Finalizer33386 completed0 in61.395346625s and is absent. The13-file patch
round-trips exactly. Root1034/prior2257/base2278/candidate2281 and55 source pins
verify unchanged. The regular APFS artifact archive has4654 files/202 directories,
no links and11090336139 logical bytes; member bytes, modes, nanosecond mtimes and
distinct inodes verify. The44-member PAX archive has4874240bytes, SHA256
`f89ac3ded4fde8e930087cbea939823348a9cc5e47f81e11611e0ff995b7b0c0`.
Closing X5 free146868412416bytes, observed decrease865062912bytes, preserves the
121GiB external and6GiB internal reserves. The task is frozen. Archive/preservation
passed; build/package/comparison/independent review remain unaccepted.
