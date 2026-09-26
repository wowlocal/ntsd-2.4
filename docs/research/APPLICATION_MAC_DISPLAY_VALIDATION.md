# Native display validation — first build failure preserved

The fresh build stopped before package verification or XCTest. The new display
adapter's observation method supplies an optional pixel count where an Int is
required. No physical allocation/clear/readback behavior or any of the34 selected
methods is accepted by this run. Prior29 window comparisons remain separate evidence.

[Validation plan](APPLICATION_MAC_DISPLAY_VALIDATION_PLAN.md),
[implementation](APPLICATION_MAC_DISPLAY.md). Input HEAD739ac2e, exact2261-file
candidate c6077a1eeaec431860dc58930ac8eed593faba350870bc597cf256383bc5905f.
Preparation19085 terminal0. Build20523 terminal1 in81.261 seconds, sampled peak
tree RSS2,886,795,264 bytes, no guard/signal/residual. The process is absent.

The compiler reports in OriginalMacDisplayBackend.swift observation():
`value of optional type 'Int?' must be unwrapped to a value of type 'Int'`.
The chained `s?.storage.map { ... } ?? 0` remains optional in this expression;
Observation.knownPixels requires an Int. This is a Native compilation error,
not a source fault, comparator mismatch, device observation or safety refusal.
The full diagnostic/build log, failed candidate and partial products are preserved.

NEXT: separately clone the exact candidate and explicitly unwrap optional storage
before assigning an Int count or zero, retaining the same pixel-count expression.
No test body, expectation, pixel mutation, allocation/reference operation, Core rule
or source data change is needed. Then run fresh build/package and the exact same34
methods with unchanged limits. This is correction round1 of the declared three.

The failure task archives root1034/prior2257/candidate2261/source55 preservation
and full regular-file/PAX metadata checks separately from the unpassed package and
comparison gates. No tests are queued, no original or affected refused operation
was executed, and no automatic build retry occurred. Independent review, actual
AppKit clear/readback, root promotion/general raster/presentation/conversion,
Windows/callback/fullscreen/remaining providers/input/audio/loading/clean-Mac/full
match/game remain open. NTSDApp still Practice; source59727 remains terminal34
Objects, not137. EXE envelope was not recalculated.

## Verified failure closure

Finalizer25731 terminal0/absent. Full4339-file regular artifact and
27-member PAX metadata archives verified by bodies/modes/nsmtimes/
membership and distinct clone inodes. Root/prior/candidate/source remain exact.
[Publication](../evidence/application-mac-display-validation.json),
[closure](../evidence/application-mac-display-validation-close.json). Task frozen;
all34 methods are unstarted.
