# Production menu-to-loading continuation

Status: accepted in the finite production common-loading scope. Reference, input
package, code review and Native comparison passed. Complete application execution
remains open.

The next production consumer takes the actual
`OriginalApplicationMenuSession.PendingLoading` and performs the already recovered
loading prologue, MENU_WAIT draw, 18 common sound loads and presentation. It
returns a tentative catalog entry with its own state and resource owners. The
previous committed menu iteration remains unchanged. This removes orchestration
previously implemented only in `OriginalApplicationLoadingPrefixTests` and advances
the standalone application toward its full loading and first-match milestones.

The previous goal turn made verified progress: commit `7638dc0` connected the
startup graphics owners and passed 32 release methods. The working tree was clean
at this card's start. The full game goal remains open.

## Evidence and choice of dependency

The authoritative reference is the pinned original NTSD EXE
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`
and original resource files. The existing
[loading prefix](APPLICATION_LOADING_PREFIX.md) has twelve complete saved cases:
nine reach the catalog allocation boundary and three reject the retained failed
CreateSoundBuffer continuation. Original code ran in the declared controlled
Unicorn environment. This card reads its immutable records as data and runs Native
Swift; it does not execute the original or any historical producer/auditor.

The [graphics owners](APPLICATION_GRAPHICS_OWNERS.md),
[source colors](APPLICATION_SURFACE_COLORS.md) and
[inventory](APPLICATION_BITMAP_SURFACE_INVENTORY.md) establish requested graphics
operations, identities and source RGB. They do not supply actual device formats,
palette realization, GDI conversion, text raster or Windows pixels. The reviewed
Windows preparation has no device response. Those dependencies remain open;
production loading is the next independent consumer with sufficient evidence.

Plan, amendment, pins, jobs and reviews:
`build/research/application-loading-session-native-20260912/`.
The base is `7638dc02d6fcbd31cd7d5a35dd7af3f3bf1668c6` with 881 Native files.
X5 UUID and free space were checked before creating this task's directory.
The plan limits each new reference job to 600 seconds, each Native validation to
2400 seconds, and the initial correction cycle to three candidates. Task storage
is bounded to 24 GiB with the existing 6 GiB internal reserve retained.

## Contract

The production owner retains the incoming full 0xc3a8 record, current bitmap
wrappers, display/DC owners, library state, RNG, target and tentative batches.
Only its globals slice changes while common loading runs; the outer/caller and
World bytes, masks and aliases remain owned and preserved. Newly loaded WAV
results retain their PCM, format, descriptor, temporary storage and liveness.
Two distinct ten-byte command arrays and pause come from the recovered prologue.
No saved private source stack or expected after-state becomes Native input.

All 18 common WAV files are bundled as a separate immutable original resource
package. The existing 46-file startup package remains unchanged. Declared platform
response prefixes have only the calls actually supplied: failed CreateSoundBuffer
cases may end after 1, 9 or 18 replies. The implementation must not require or
invent responses after that boundary. Missing-file and short-read false returns
remain ignored by the caller; short-read temporary storage stays live. The third
parent's presentation result is -1 and remains ignored but recorded.

An optional attempted-WAV observation exposes each actual child result before
the existing invalidCreateContinuation guard. Existing successful afterWave
callbacks retain their ordering and domain. This allows the rejected child to be
checked from the single production invocation, without rerunning it in the test.

A late observer or handoff failure publishes no prepared state or batch. Successful
common loading produces only `PendingCatalog`; it does not commit the pending
menu/timer iteration or pretend to return from the complete loading function.
Inherited operations and new terminal operations preserve order. A graphics
command remains a resolved view of its corresponding operation, not a second IO
request. Original helper/read/store observations remain diagnostic only.

## Reference and first production candidate

The first new data-only reference stopped at an incorrect graphics-prefix
assertion: it used full commandCount (501/502) to slice the sparse relations
array (76/77). The corrected second producer uses the independently fixed parent
relation count and verifies the full command count separately from stage commands.
Both original records and the first producer/job/log are unchanged.

Reference2 completed in 8.343 seconds. It verifies twelve exact parents, 190
complete WAV file/input/result joins, 187 returned children (181 true/six false),
three rejected children, three retained short-read temporaries, 9,251 events,
29,913 writes and 456 retained-region checks. Both fixture envelopes omit exactly
one final LF; restoring it reproduces the complete original raw bytes. Every
14,664 blob entry remains hash verified. These are saved-data checks, not new
source execution or additional Windows evidence.

The immutable input package has 19 regular files / 353,249 bytes, including
351,078 WAV bytes. Its 18 filenames retain 16 distinct payloads without filename
deduplication. Manifest SHA-256 is
`b1a519e2db09f18aa0d2bbaf29aa44226fba6a04852f8a4062778ae7d8e8a2f3`.
The new packager verifies an existing package without rewriting it. Git's scoped
-text attribute preserves all package bytes. Core checks exact names, ordered
manifest entries, lengths, digests, regular files and package composition before
an attempt. An app bundle must provide its own package; it cannot silently use
the SwiftPM test module as a fallback.

Candidate1 contains 903 Native files. OriginalApplicationLoadingSession owns the
orchestration from actual PendingLoading; the existing loading comparison calls
that production API. It no longer invokes the rejected WAV child a second time.
All previous expected fixtures remain unchanged. The new tests also compare the
complete returned staged operation batch, preserved parent prefix, graphics,
canonical state, retained sound records and repeated-prepare rejection. Three
package methods check owned snapshots, missing/corrupt/extra/symlink inputs and
app-resource lookup. No app window/device run follows from these checks.

## Verification and remaining boundaries

All 19 selected bundled release methods passed in 155.354 seconds; build
316.59 seconds. The production path compares all twelve cases: nine tentative
catalog entries and three explicit rejected CreateSoundBuffer continuations.
The five retained late failures preserve the prior committed parent. All WAV
results are observed exactly once before the existing rejection guard; the nine
returned pending owners also compare their retained PCM/storage/masks, complete
canonical state, ordered operations and graphics. Repeated prepare rejects before
any observer runs. No Core/expected correction was needed after candidate1 froze.

Required regressions include the retained full initial-loading controls, WAV
corpus, complete Bootstrap/menu/input and graphics comparisons. All 374 existing
fixtures and all 46 OriginalStartup files are unchanged. The 903 Native files
match the frozen candidate. New CommonSounds input bytes remain identical to the
originals. The Native archive has 903 members / 4103688297 payload
bytes; the evidence archive has 116 members / 323048000 payload
bytes. Every member name, byte, hash and mode is verified. Failed reference1,
corrected reference2, original base versions and all input pins remain retained.

[Machine-readable acceptance](../evidence/application-loading-session.json)
pins the results. Independent archive/publication reviews and exact prospective
Git/commit verification are retained separately after the evidence snapshot.
No app window or sound/raster device was exercised; completed sources and
successful tests are not restarted.

The actual catalog allocation is 81,273,768 bytes. Its own catalog/pool/UI join,
loading return and following held-input clear remain open; historical catalog
addresses cannot overwrite retained common WAV storage. Actual framebuffer,
AppKit delivery/input/audio, full CRT/NLS, War gameplay, the complete match/game,
network, Windows and clean-Mac verification remain part of the active goal.
All three cyber_policy incidents and the separate Windows download refusal remain
open; no affected operation is retried by this card.
