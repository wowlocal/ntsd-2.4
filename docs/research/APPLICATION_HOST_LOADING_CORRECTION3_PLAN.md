# Host loading presence assertion — round3, 2026-09-22

Follow [WORKFLOW](WORKFLOW.md), the [round2 diagnosis](APPLICATION_HOST_LOADING_COMPLETION.md)
and [round1 candidate](APPLICATION_HOST_LOADING_CORRECTION1.md). The game contract
is unchanged: actual loading owners, precise host ticket identity, retry/rollback
and one loaded commit, with complete saved parent comparisons. Base HEAD
`69f7a824c72f4be1ddf25d8fd3654324764a631d`; actual input is the frozen corrected1037-file
tree, including its dirty baseline, not a HEAD-only checkout.

## One test correction and required cases

Round2 timed out at600s with no complete method result. A declared1s/5ms native
stack sample put144 main-thread samples at HostLoadingTests:275 in XCTest
XCTAssertNotNil and recursive value formatting. It does not establish all-runtime
attribution or assertion success. Preserve that sample, timeout and prior RSS
termination, as well as the original fresh/cached assertion failure.

Clone round1 candidate into a new task, verify every byte/mode/membership and
independent regular inode, save before/after manifests and exact patch. Change
only this line in OriginalApplicationHostLoadingTests.swift:
`XCTAssertNotNil(alternate)` → `XCTAssertTrue(alternate != nil)`.
This retains the required existence predicate while passing only Bool to XCTest
formatting. Keep the adjacent nil check, expected throw, all payload/state/owner/
platform comparisons, selector and method body otherwise unchanged. Keep the
round1 fresh/cached wrapper correction. No Core, fixture, mask, original expected
result, lifecycle cleanup or method splitting is introduced.

Reference EXE SHA256 `3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`,
lib.dll `28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba`,
VC80 `c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d`.
Existing original records/control replies and declared Native composition remain
the behavioral basis. No new original execution, Windows/device observation or
refused operation. Author comparator correction still lacks independent review.

Fresh installed Swift6.4 build, Swift5/macOS14 release/WMO, native SwiftPM, jobs2,
`-Xswiftc -enable-testing`, new scratch/cache/config/security and minimal environment.
Run all42 frozen methods, one named XCTest process each, packaged385 fixtures/
102 runtime resources, no raw override. Prior27 successes cannot replace checks
on this newly compiled test module. Preserve all names/cases/comparators. Verify
exact method and three full zero-failure suite summaries plus actual exit0.

Stop on first failed build/method/guard or monitor error. This is the final of
three declared correction rounds. Further failure requires a diagnosis and a
revised continuation contract, not an automatic extra round. Save all results;
never skip a mismatch, rewrite a prior expected value or overwrite a failed tree.
The new code changes no timing/RSS ceiling: build3600s/12GiB; methods600s each,
12GiB only for method28 and8GiB for all others; queue3600s. Poll1s/RSS2s/size15s.
Short process RSS0 means no sample. Reuse unchanged runner/ownership predicates.

## Storage, processes and publication

Task `/Volumes/X5/ntsd-2.4-research/01a0c7b2-a956-7760-950e-ecf7dceaaa20/application-host-loading-correction3-20260922`,
alias `build/research/application-host-loading-correction3-20260922`. Verify X5
APFS UUID `3A4F5FA6-DC86-4C6E-87E2-EAC2C2D72548`,81GiB external/7GiB internal at start.
Budget24GiB observed decrease including concurrent source growth, stop22GiB,
2GiB terminal/archive margin,150GiB logical. Keep original40/6GiB reserves and
source17GiB gross allowance. No deletions, reserve cuts or source restart.

Revalidate PID/start/command/cwd/job before any signal. Only declared owned Native
processes may receive guard signals; never source59727. Minimal environment:
HOME/USER/LOGNAME/LANG/LC_ALL/PATH/TMPDIR. Preserve complete/partial logs and every
failure; keep all source55/root1034/candidate1037/baseline/expected inputs immutable.

Root mutable paths: this plan, APPLICATION_HOST_LOADING_CORRECTION3.md,
docs/evidence/application-host-loading-correction3*, preparation/runner/finalizer
helpers ending application_host_loading_validation4.py, package helper ending
application_host_loading_package4.py, queue ending application_host_loading_tests4.py,
and own CURRENT_WORK/RESEARCH_MAP paragraphs. New task owns its candidate/build/
results/archive; closed tasks remain frozen. Root author owns edits; no independent
reviewer. Verify patch roundtrip, full package/source membership, archive bodies/
modes/mtimes/membership and process terminal/absence. Publish partial failure if
acceptance is not reached. Separate Native, package, archive, review, promotion
and device gates; commit the coherent checked increment with existing hooks.
Full catalog source, later typed child retention, live providers/timing/devices,
existing safety dependencies, full game and clean-Mac acceptance remain open.
