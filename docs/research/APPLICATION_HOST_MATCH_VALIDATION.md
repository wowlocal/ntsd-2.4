# Typed host validation: compiler failure retained

**2026-09-22: fresh build failed before tests.** The Swift compiler reported
signal6 while type-checking `OriginalApplicationHostSession.finishLoadedMenu`.
No test binary was accepted and all53 selected methods remain unstarted.
This is a Native compiler failure, not an original-game fault, runtime mismatch,
resource guard or safety refusal. The complete native game remains open.

The [frozen validation plan](APPLICATION_HOST_MATCH_VALIDATION_PLAN.md) follows
the [syntax-only candidate](APPLICATION_HOST_MATCH_CANDIDATE.md). Base HEAD:
`a77db6602338ee208f87a97ac74948a77ced4ef7`. Actual input is its frozen1039-file
tree, including the existing host changes and dirty baseline. No root Native,
original expected bytes, masks, resources or earlier candidate was changed.
Reference EXE SHA-256 remains
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.
No original execution, historical producer/auditor, device IO, install or refused
operation was attempted.

[Publication](../evidence/application-host-match-validation.json),
[closure](../evidence/application-host-match-validation-close.json) and
[documentation verification](../evidence/application-host-match-validation-docs.json)
link the exact candidate, configuration, terminal log, static diagnosis, partial
artifacts and integrity checks. The external task is
`build/research/application-host-match-validation-20260922`.

## Failure and diagnosis

Preparation PID56746 verified and independently cloned1039 regular files.
Fresh release/native-SwiftPM build PID57019 exited1 after4.192s, with sampled
aggregate peak RSS217,628,672 bytes. The monitor sent no signal and recorded no
guard. Its leader and observed compiler descendants57066/57067 are terminal and
absent. The compiler's own report says signal6; that is distinct from a monitor
termination. Full stderr/backtrace and job metadata remain unchanged.

The installed compiler is Swift6.4 (`swiftlang-6.4.0.34.1`, clang2100.3.34.1),
effective language version5.10, target arm64/macOS14, release/WMO with testing
enabled. It reports `Querying VarDecl's type before type-checking parent stmt`
at TypeCheckDecl.cpp:2766 and names the local `platform` binding at
HostSession255:61 inside `finishLoadedMenu`. The five-file syntax parse in the
previous task did not typecheck this code and could not establish build success.

Static inspection identifies a concrete owner-assignment defect. The new enum
pattern introduces immutable local `platform`; the unchanged final expression
`platform = candidate` now names that local instead of the host property. The
intended successful transaction must install `self.platform`. The backtrace
locates this binding/region, but no corrected compilation has yet established
that this change eliminates the compiler assertion or that the remaining
candidate builds. Do not treat diagnosis as a successful correction.

Next correction: use a separately identified candidate, rename the returned-case
binding to `preparedPlatform`, copy that value, and explicitly assign
`self.platform = candidate` at final commit. Preserve the exact failed tree/log,
all game children, original expectations and53 selected names. Review the actual
corrected inputs and run a fresh build; do not reuse partial products or rerun
this frozen failed candidate.

## Validation and preservation

The complete53-method selection was checked against candidate source before the
build. The queue was never started and no test job or package-check receipt was
created. Copied resources are checked only as partial build artifacts; they do
not constitute an accepted package. Earlier42-method passes belong to the older
loading candidate and cannot validate this changed host.

The existing runner's process identity, resource guards and reap logic are
byte-identical apart from task identity and allowed method extent. The new
queue requires exact named pass, three complete one-test/zero-failure summaries,
Selected-tests pass and exit0, matching the existing final publication criterion.
That queue remains unexecuted. All configured time/RSS/storage bounds and
protected producer pins are retained in the task metadata.

The finalizer verifies root1034, original candidate1039, copied candidate1039,
source55 pins and all partial archived bodies/modes/mtimes/membership. The failed
candidate and compiler products are archived with the same clone/readback
procedure used by prior studies; the metadata archive preserves the full failure
and producer/configuration records. Archive success is separate from the failed
Native/package gates. Exact counts, storage use and final source observation are
in the publication/closure; reserves remain40GiB external and6GiB internal.

Finalizer57553 exited0 in140.599s and is absent. Its archive contains1645 files
and74 directories (72 traversed plus2 parent directories),8,961,888,416 logical
bytes. All487 copied fixture/runtime files match their candidate inputs, without
promoting the package gate. The separate25-member metadata archive is1,116,160
bytes. Observed external decrease158,892,032 bytes stays within24GiB; the task is
frozen. Source was revalidated17:58:01 UTC at2997 chunks/20 Objects, still live.

Independent contract review is unavailable. The source capture remains the
same live PID59727 and was neither restarted nor signaled. Whole initialized
catalog comparison, corrected Native validation, root promotion, later gameplay
retention, actual host delivery, window/input/audio, Windows/clean-Mac/full-match
and full-game acceptance remain open. Existing safety incidents remain unresolved;
this Swift compilation did not retry those paths. The EXE envelope was not
recalculated.
