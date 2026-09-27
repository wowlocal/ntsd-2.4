# Bound decimal text preparation in the loading path

2026-09-27. The [finite plan](APPLICATION_DECIMAL_MATERIALIZATION_PLAN.md)
continues the incomplete [audio loading composition](APPLICATION_LOADING_AUDIO.md).
The previous full Native catalog/pool/menu/Host comparison timed out at 3,600
seconds. That result remains immutable. This candidate changes one production
statement and adds one preservation test; it does not extend the accepted
decimal grammar or promote root Native. The first 20 methods pass; the full
loading method then rejects overlapping test allocations. Its 145 following
methods were not started. This is not an accepted complete loading handoff.

## Implementation and evidence

`OriginalFrameScanner.binary64` previously converted the complete remaining DAT
suffix into a String before an anchored decimal regex. It now materializes only
the contiguous prefix containing ASCII digits, plus, minus, period, e and E.
The unchanged regex can consume only this alphabet and has no lookaround or
end-anchor. Text following the first other byte cannot change its match.
The regex, Double conversion, finite-value check, position/EOF updates, observer
calls and errors are byte identical. Integer and token readers are unchanged.

The prior one-second Native sample and saved 863-read input count justify this
bounded change. They do not measure a shipping loading time or speedup ratio.
The previous test also invokes source comparators throughout its repeated
attempts. A new successful duration cannot provide an exact speedup over an
unfinished run.

The new test compares the frozen parent method, reindented without statement
changes, with the candidate on 553 strings. Two observer modes and two sequential
reads produce 2,212 paired observations of Double bits or errors, position, EOF
and complete observer history. Controls include all 256 byte values in two
positions, overflow, subnormals, signed zero, incomplete exponents, a rounding
boundary, long numeric strings and a long nonnumeric suffix. The parent Native
method is a preservation control, not an authoritative game reference.

The known CRT `1e+` discrepancy remains open: the original consumes three bytes,
while this Native regex consumes one. General decimal lexing/rounding and actual
Windows CRT binding remain open. Saved actual-DAT and complete caller comparisons
provide their existing, separately bounded source evidence. No original code,
Unicorn or Windows capture executes in this task.

## Validation state

Preparation 16217 completed with exit 0 in 13.404338208 seconds. Candidate manifest
SHA-256 is `e23c59520310c10f97d505eb10386d8dd04d92f77022414589be1a8ae8c937ce`:
2,291 files, exactly one modified production file and one added test file.
All 676 prior files under Tests, including fixtures, are unchanged. Author
inspection verified the 165 retained selected methods in 53 unchanged test files.
This is author inspection; independent review remains unavailable and open.

Release build 17481 completed with exit 0 in 311.808079125 seconds, peak sampled
process-tree RSS 7,063,486,464 bytes. All observed build processes are absent.
The package verifier passed with Core210/Reference61/Mac11/Tests292 sources,
385 fixtures and 1,301 runtime resources. Candidate membership, fresh compiled
outputs and all 1,686 packaged resource bodies were verified. The binary is
69,518,392 bytes. This task adapted the already corrected source counts before
freezing; the parent's earlier package-verifier failure is preserved separately.

Queue 29527 completed with exit 1 in 2,355.08874025 seconds and is absent.
It retains 166 fixed methods: the new preservation control, 14 existing numeric/
catalog methods and all 151 prior audio/application methods in their original
relative order. The full loading method keeps its 3,600-second limit and
3,000-request / 3,002-attempt bounds. No deadline or comparison changed.

The first 20 methods passed: the preservation control, 863 actual DAT numeric
reads at explicit 53-bit precision, complete catalogs, Object and Stage streams,
Frame snapshots, rollback, and the parent's five initial audio ownership/common/
registered/retry/source-caller groups. Historical isolated Frame exclusions remain
historical. The [live receipt](../evidence/application-decimal-materialization-live.json)
preserves the earlier checkpoint separately from the terminal result.

Full-caller PID34343 exited 1 at 05:30:01 UTC after 2,201.486271958 seconds with
`overlap(1358954528)` (`0x51000020`) at the unchanged CatalogSession range guard.
XCTest reports one unexpected thrown error, not a completed successful chain.
There was no guard timeout or signal; all 47 recorded process-presence checks
were absent, with no remaining process group or observed child. The queue stopped
at the first nonpass: 20 passed, one failed and 145 unstarted.

The [diagnosis](../evidence/application-decimal-materialization-failure.json) and
[separate static witness](../evidence/application-decimal-materialization-overlap.json)
pin the actual error and its input provenance. The retained catalog fixture's
95,289,959 raw bytes reproduce SHA-256
`8ff43ea70036d84dbbea5309387176595658b0246aa3ff5773e8e22d08f12dee`.
Its Object64 (`chars\charge.dat`, ID203) uses declared address `0x51000020` and
size `0x25360`. The Native bitmap test helper chooses 25 wrapper slots spanning
`0x51000000..<0x51030ed0`. The entire 152,416-byte Object lies inside that arena,
intersecting 20 slots. The full test composed two synthetic environments that
were not disjoint; the production overlap guard correctly rejected them.
This is not a Windows heap observation, original fault or demonstrated Native/
source byte mismatch. The log does not publish final request or buffer counts.

The first witness inspected child allocations and separately located Object64,
but omitted Object extents from its collision loop. Its zero child-allocation
intersections remain preserved; the second witness explicitly includes all 137
Objects. An unmatched shell-glob read error is also retained. No old expected
value, fixture, candidate or range check was edited to diagnose the failure.

A separately recorded one-second, 10 ms interval sample at 04:59:22 UTC found
all 33 sampled main-thread stacks inside the catalog attempt: file preparation,
parsed content consumption, text conversion and child comparison. No binary64
frame appears in this single snapshot; that is not evidence of zero cost or
absent calls. `test-21-native-sample1{,-result,-analysis}.json` and the original
text profile retain the operation, revalidated identity/cwd, binary/source pins
and exact line anchors in the [profile receipt](../evidence/application-decimal-materialization-profile.json). The sample does not establish a full-run speedup,
shipping latency or completion within the unchanged deadline.

## Environment and open work

The 04:52:15 UTC host observation reports a locked console. CUA selecting UTM
returned `Computer Use server error -10005: cgWindowNotFound`. This is a window
availability error, not a safety refusal. No UI input was performed. Windows
installer approvals remain valid; installation resumes when the window is
observable. Existing Ghostty and other safety incidents stay open.

The [publication](../evidence/application-decimal-materialization.json),
[close receipt](../evidence/application-decimal-materialization-close.json) and
[exact two-file patch](../evidence/application-decimal-materialization.patch)
separate build, package, comparison and archive gates. Finalizer12918 completed
with exit 0 in 86.66434225 seconds and is absent. It verifies root1,034/prior2,257/
parent2,290/candidate2,291 files, 55 source pins and the patch round-trip.
The artifact archive contains 5,000 regular files, 213 directories, no links and
11,462,018,279 logical bytes; manifest SHA-256 is
`6ff225d80acdd416fa64a5e9fe40e35a25c5cc54c541af7a92ebb310b62932c2`.
The 284-member, 8,622,080-byte PAX metadata archive has SHA-256
`a20c2c7910c551a981acbad78148eca90f181ff47b10f7ef27f0244794aba0d9`.
Bodies, membership, modes, nanosecond mtimes and distinct regular artifact inodes
were verified. The task is frozen with 139,814,252,544 bytes free on X5 and the
121 GiB combined reserve retained. The documentation receipt records the terminal
finalizer and final repository files separately.

Root implementation, independent review, whole application integration, runtime
playback/device behavior, Windows font/cursor, clean-Mac acceptance, full match
and full game remain open. The EXE envelope is not recalculated. Source59727
remains terminal at34 Objects; this does not become a whole137 source return.

Next: preserve and commit this failed comparison, then declare a separate test-
environment correction. Audit a disjoint front-wrapper arena against the complete
startup/catalog/pool/menu lifetimes before choosing it. Keep the existing default
bitmap tests, source addresses/bytes/masks and all production range checks intact;
change only the new composition's declared test storage. Add a fast collision/
disjointness control, retain all166 methods and run the complete caller in a fresh
candidate under its unchanged hour bound. Do not restart this frozen task.
