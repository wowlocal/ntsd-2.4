# Typed host platform assignment — correction1, 2026-09-22

Follow [WORKFLOW](WORKFLOW.md) and the preserved
[compiler failure](APPLICATION_HOST_MATCH_VALIDATION.md). Base HEAD:
`4d1ff161d801334831f96645e2e5964adcca12d3`. Actual baseline is its frozen1039-file
candidate, including the earlier dirty inputs. Fix the host's final platform
installation so the retained Start/launch transaction can compile and be compared
through the enclosing application return. The complete native game remains open.

## One bounded correction

Clone the failed candidate to the new task below. Change only
OriginalApplicationHostSession.finishLoadedMenu: rename the `.returned` pattern's
local platform to `preparedPlatform`, clone that binding, and explicitly install
`self.platform = candidate` at final commit. The previous local binding shadows
the host property; its compiler report points to this binding during typecheck.
Whether this removes that compiler assertion is still unverified until a fresh
build. No other Core/test/fixture/resource/expected/mask change in this task.

Pin before/after manifests and the exact patch; round-trip it against the failed
source. Preserve the failed candidate, signal6 report, full log and partial
archive bytewise. This is the first correction after the initial typed-host
validation; up to three separately diagnosed correction rounds, not automatic
retries. Stop on the first new build/test/guard/monitor failure and retain it.

Reference EXE SHA256
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`,
lib.dll `28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba`,
VC80 `c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d`.
Use unchanged saved source comparisons and Native controls. No original execution,
historical producer/auditor, device IO, install, refused operation or root promotion.

## Validation and limits

Retain all53 exact method names/cases/comparators from the failed selection.
Fresh installed Swift6.4, Swift5/macOS14 release/WMO, native SwiftPM, jobs2,
`-Xswiftc -enable-testing`, new scratch/cache/config/security and minimal
HOME/USER/LOGNAME/LANG/LC_ALL/PATH/TMPDIR. No prior build products reused.
Verify fresh Core/ReferenceChecks/Tests membership and products, all385 fixtures/
102 runtime resources as regular packaged files, exact named test result and
three complete one-test/zero-failure suites, actual exit0 and no guard.

Keep the original validation resource contract: build3600s/12GiB RSS;
methods1–50 at600s, new51–53 at900s/16GiB;12GiB for28,35–37,43–50 and8GiB for
remaining older methods; queue7200s. Poll1s/RSS2s/size15s. A short process's
RSS0 means no sample. The whole parent/comparison scope is unchanged.

Task `/Volumes/X5/ntsd-2.4-research/01a0c7b2-a956-7760-950e-ecf7dceaaa20/application-host-match-correction1-20260922`,
alias `build/research/application-host-match-correction1-20260922`. Verify X5
APFS UUID `3A4F5FA6-DC86-4C6E-87E2-EAC2C2D72548`,81GiB external/7GiB internal at
start. Retain24GiB observed decrease including source growth, stop22GiB with2GiB
closure margin,150GiB logical; original40GiB/6GiB reserves and source17GiB gross
allowance unchanged. No deletions or reduced reserves.

## Ownership and publication

Reuse existing clone/pin/job/runner/package/archive procedures. Revalidate
PID/start/full command/cwd/job before actions; never restart or signal source59727
for silence. Only this task's verified Native descendants may receive declared
guard signals. Monitor errors do not prove the child stopped.

Root author only; independent review remains unavailable. Protect root1034,
old1039 candidate and all frozen tasks/producers/expectations, source55 pins and
unrelated dirty files. Mutable root paths: this plan, APPLICATION_HOST_MATCH_CORRECTION1.md,
docs/evidence/application-host-match-correction1*, prepare/run/finalize helpers
ending application_host_match_validation2.py, package helper ending
application_host_match_package2.py, queue ending application_host_match_tests2.py,
and own CURRENT_WORK/RESEARCH_MAP paragraphs. One corrected Swift path in the
new candidate only. No promotion into root.

Verify exact code delta, before/after preservation, terminal processes, package
bytes and artifact/metadata archive membership/body/mode/mtime separately.
Publish and commit the checked outcome, including failure and unstarted methods
if needed, with hooks intact. Native comparison, independent review, promotion,
Windows/device/clean-Mac/full-match/full-game and existing safety dependencies
remain separate open gates. The EXE envelope is not recalculated here.
