# Observed startup — first build failed before tests

The2254-file candidate was preserved unchanged. Fresh build84305 exited1 after
151.238 seconds while compiling the new test file: `no such module NTSDReference`
at OriginalApplicationObservedStartupTests.swift:3. The intended existing module
is NTSDReferenceChecks, imported @testable by the prior test. Core and helper
executables compiled, but there is no complete package or XCTest result. All25
selected methods, including actual Mac clock observation, remain unexecuted.

[Plan](APPLICATION_OBSERVED_STARTUP_VALIDATION_PLAN.md),
[implementation](APPLICATION_OBSERVED_STARTUP.md). Preparation82588 completed with
2254 verified regular clones and25 selected methods. Two initial launcher argument
errors happened before any build job/child existed: task directory was passed where
the runner expects a config path, then phase name was passed where it expects the
config SHA256. The corrected invocation used the preparation's verified hash.
Both diagnosis records are retained; only one actual build ran. This is neither
an original-source error nor a safety refusal, and no automatic rebuild ran.

Build is terminal; leader and observed children absent, no guard/signal/residual
process. Sampled peak2,932,146,176bytes. Full log and failed candidate remain immutable.
No old source expectation, mask, algorithm or comparator changed. Package byte
acceptance remains false even where copied resources individually verify.

A separate failure finalizer reuses the existing APFS artifact/PAX metadata archive
procedure. The prepared successful-test finalizer remains unexecuted and retained;
its prerequisite test results do not exist. Independent review remains unavailable.

NEXT: one separately cloned correction for the test imports, followed by a fresh
build/package and the same25 complete methods with unchanged limits/assertions.
Match the prior module import and explicitly import Foundation used by the test;
change no test body/Core/expected. Preserve this failure and every original input.
Root promotion, physical window/resources/callbacks/input/audio, remaining prepared
constants/aggregate WAV, initialized loading, Windows/clean-Mac/full match/game
remain open. No actual Mac clock test, original/emulator/capture/Windows/refused
operation ran. Source59727 stays terminal at34 Objects; full137 and existing safety
incidents remain open. EXE envelope not recalculated; full goal remains active.

Verified closure: finalizer92639 terminal0/absent, task frozen. Full regular archive
4601files/199directories/11060588753logical bytes, metadata
28members/4014080bytes verified by complete membership/bodies/modes/
nsmtimes. Root1034/prior2249/both2254 candidates/source55 preserved.
[Publication](../evidence/application-observed-startup-validation.json),
[closure](../evidence/application-observed-startup-validation-close.json).
