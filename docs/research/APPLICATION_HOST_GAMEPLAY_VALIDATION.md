# Host gameplay validation — compile failure preserved

2026-09-22. Under the [frozen validation plan](APPLICATION_HOST_GAMEPLAY_VALIDATION_PLAN.md),
the fresh build failed in the test target. **All69 selected methods remain
unstarted; no complete package or Native comparison is accepted.** The
[publication](../evidence/application-host-gameplay-validation.json),
[closure](../evidence/application-host-gameplay-validation-close.json),
[runner controls](../evidence/application-host-gameplay-validation-runner.json) and
[documentation checks](../evidence/application-host-gameplay-validation-docs.json)
preserve the actual result. The failed task is frozen; no retry or code correction
was made inside it.

## Analysis and diagnosis

Base HEAD `066f8c2fe917c0eeb8ad04dbb176488e11f44aa4` supplied the frozen
[1040-file candidate](APPLICATION_HOST_GAMEPLAY_CANDIDATE.md), including its actual
dirty baseline and previously syntax-checked19-path change. All69 exact method
definitions were present, but syntax and comparison-line preservation did not
establish type correctness. This validation advances the host gameplay/paused
continuation toward the first complete Naruto/Sasuke District match by identifying
the concrete remaining compilation defect. Full game scope is unchanged.

OriginalApplicationActiveOutputTests.swift declares
`func sequence(_ reverse: Bool) throws`, but its call to the Layout wrapper already
forwards `driver:driver`. Unlike the ten other active wrappers, Output has no
onBody parameter. The candidate edit matched declarations containing onBody and
therefore missed this declaration while adding its forwarding argument.
The compiler reports exactly two errors:

- ActiveOutputTests.swift:20:76 — `cannot find 'driver' in scope`.
- HostGameplayTests.swift:88:80 — `extra argument 'driver' in call`.

The latter is the consumer of the same missing parameter, not a second independent
defect. The saved failure-diagnosis1.json pins both diagnostics, the complete log,
job and affected file, and records all eleven wrapper signatures. The other ten
already declare the optional driver. Existing unrelated compiler deprecation
warnings remain in the full log. No source fault, Native assertion mismatch,
resource guard or safety refusal occurred here.

The next correction is one test-file declaration: add
`driver: OriginalApplicationLoadedTestDriver? = nil` to ActiveOutputTests.sequence.
Retain its existing body/forwarding call, the caller, all other candidate files
and all69 methods. The default preserves the old Bootstrap route. Make this in
a separate candidate, preserve this failed tree and fresh-build before claiming
it fixes compilation. No expected, mask, resource, gameplay rule or Core change is
needed for the diagnosed defect. Later failures, if any, remain separate evidence.

## Implementation and execution

This task changed no candidate code. Preparation PID83704 exited0 in2.822s,
APFS-cloning all1040 regular files with distinct inodes and verifying root1034,
source55 and prior candidate preservation. The manifest remains SHA256
`4deadc3ce77d2151662b41df365e9ca2c9c4c6ab1da7f8eb0161ec11a0b282cc`.

Fresh Apple Swift6.4 (swiftlang-6.4.0.34.1), Swift5/macOS14 release/WMO, native
SwiftPM jobs2 and enable-testing used new scratch/cache/config/security directories
and the declared minimal environment. Exact source inventory was191 Core,
61 ReferenceChecks and270 Tests. These input counts do not establish a completed
build or package. Native game/XCTest execution never started.

Build PID83817 ran19:46:51.195999–19:49:25.232157 UTC, exited1 in154.046s and is
absent. Sampled aggregate peak RSS was2,823,176,192 bytes, below12GiB; observed
logical peak9,340,940,019 bytes. No guard or signal was issued, no process group
or observed descendant remained, and the test binary was absent. The queue and
package checker were not invoked. All69 methods, including every old regression
and new whole17/48/14 host sequence, remain unstarted on this candidate.

The monitor's ownership/transition/guard/reap code matches the previous accepted
runner except for task identity and the finite69-method phase range. Read-only
controls passed: cwd1 positive/4 negative, compiler transition1/2, transient XCTest
exit1/1, phases72/8. The exact named-result parser and complete one-test/zero-failure
requirements remain unchanged. No monitor result is substituted for a Native pass.

Only Native compilation was executed against the declared saved data and candidate.
No new original run, capture/auditor replay, device IO, package install, result-file
provider execution or refused operation occurred. Existing synthetic source
mappings/API/keyboard responses, FPU/ABI, installed-library and unknown-storage
boundaries remain as declared in the plan/preflight. Windows/device, installed
whole-application and complete-match equivalence are not inferred from compilation.

## Preservation and publication

Finalizer86322 exited0 in122.743s at19:53:23.351659 UTC and is absent. It verified
protected inputs, root1034, both1040-file candidates, source55, full membership and
file bodies/modes. The partial build copied487 expected resource payloads; their
bytes were checked, but this is explicitly not complete package acceptance.
The full failed log, job, diagnosis, unchanged candidate and partial products remain.

The regular artifact archive has2180 files,145 directories (143 traversed plus
two parents), and9,721,789,027 logical bytes. Its manifest SHA256 is
`a6691e6d22a8d5b0fc8981f645eda538ea3dddc3c157e0f5bbf5b0d06d7c6bf7`.
Readback verified exact bytes, modes, nanosecond mtimes and membership. The separate
22-member metadata archive is1,331,200 bytes, SHA256
`e564a4f3beace0709b7dd2e87e9396c62697d53a50291b4bcc9b26824351be40`;
PAX member bodies/modes/mtimes/membership were verified. The candidate/task are
frozen. Archive success closes neither package nor Native comparison gates.

Final observed free-space decrease was927,735,808 bytes including concurrent source,
within the24GiB allowance. External156,937,142,272/internal66,446,749,696 free bytes
preserve original40GiB/6GiB reserves and source17GiB gross commitment. X5 APFS UUID
was verified before dependent IO; no evidence was deleted and no reserve reduced.

A functions orchestration cell for writing the finalizer failed with the exact
`SyntaxError: Invalid or unexpected token` before nested shell execution. That
tool error and its corrected composition are distinct from the compiler failure.
The archived tool-diagnostic1 record inaccurately said the build was live at its
recorded time; the build had already terminated. The separate
[diagnostic note](../evidence/application-host-gameplay-validation-diagnostic-note.json)
preserves the old record and corrects that timing claim using the terminal job.
Neither operation restarted or changed the build.

Source59727 was revalidated by PID/start/full command/cwd/job at19:53:23 UTC:
3719 chunks,24 Objects,911,835,263 stores,33667.13s. It remained live, incomplete
and untouched. No root Native promotion or live producer modification occurred.

## Next gate

Create the separately bounded one-signature correction described above, retain
all69 exact methods and current limits, then fresh-build and run the complete
selection with package/archive checks. This supersedes the initial validation
NEXT without rewriting the failed result. Independent review remains unavailable;
author diagnosis is not independent review. Full catalog source/comparison, root
promotion, installed application trajectory, native app/window/input/audio,
Windows/devices, first complete match, full game and existing safety dependencies
remain open until their actual criteria pass.
