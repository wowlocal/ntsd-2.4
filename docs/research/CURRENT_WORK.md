# Текущая передача работы

[Profile-aware capture exposes a further window-color mismatch](APPLICATION_MAC_VIEW_CAPTURE.md):
owned snapshot agrees with separate ICC calculation on128 opaque samples, but four
pure-blue monitor-profile samples differ from input by7/255 red; original2/255
limit unchanged. Explicit sRGB/direct controls pass; alpha/bounds/ownership checks
pass. Overall control matrix remains nonpassing. First invalid bitmap-constructor
exception and bounded input correction retained; production unchanged. All jobs
terminal/absent; finalizer93739 verifies47-member archive, task frozen, root/source
preserved. [Publication](../evidence/application-mac-view-capture.json).
NEXT: separate display correction2 with explicit sRGB native window backing and
owned profile-aware capture; require unchanged34 methods plus a nonuniform pattern
regression. Preserve all old failures/expected; native policy is not Windows evidence.
Independent review/root promotion/general graphics/providers/loading/Windows/input/
audio/clean-Mac/full match/game remain open. NTSDApp still Practice; EXE envelope
not recalculated. Supersedes the sampling-only NEXT below.

[Color diagnosis localizes a readback-profile discrepancy](APPLICATION_MAC_DISPLAY_COLOR_DIAGNOSIS.md):
48 native view cases plus8 direct-image controls checked. Bitmap.colorAt returns
Generic RGB while actual bitmap profiles are sRGB or monitor ICC. Explicit sRGB
raw pixels match every input; default profile reproduces the failed RGB triplet
exactly. All24 NSImage/CGContext pairs agree. No production/expected change.
First missing-SDK compile failure preserved; build65983/probe66814/finalizer71256
terminal0/absent,34-member evidence archive verified, task frozen; root/prior/source
preserved. [Publication](../evidence/application-mac-display-color-diagnosis.json).
NEXT: validate profile-aware sampling/conversion of actual bitmap data before a
separate capture/comparator correction. Preserve failed methods/expected RGB and
all34 requirements; a rendering change is not justified by this readback result.
Independent review/all34/root promotion/Windows/input/audio/full match/game stay
open; NTSDApp still Practice, EXE envelope not recalculated. Supersedes correction2
implementation as the immediate next action below.

[Display correction1: build passes, AppKit color fails](APPLICATION_MAC_DISPLAY_CORRECTION1.md):
whole-startup physical allocation passes; second method reports nine sRGB readback
mismatches at three samples. Expected RGB/tolerance and all tests unchanged;32 of34
methods unstarted. Build/package verified199Core/61Reference/5MacPlatform/279tests,
1686 resources. Queue42859 terminal1/absent; finalizer52939 terminal0/absent,
4940-file artifact/75-member metadata verified, task frozen. Root/prior/source preserved.
[Publication](../evidence/application-mac-display-correction1.json).
NEXT: finite Native CGImage/NSImage/AppKit bitmap color-path diagnosis before a
separate correction2, retaining original assertions and all34 methods/limits.
Independent review/root promotion/rendering acceptance/remaining providers/loading/
Windows/input/audio/clean-Mac/full match/game remain open; NTSDApp still Practice.
EXE envelope not recalculated. Supersedes the explicit-count correction NEXT below.

[Display candidate compile failure preserved](APPLICATION_MAC_DISPLAY_VALIDATION.md):
build20523 terminal1/absent; observation known-pixel count remains Int? where Int is
required. No package acceptance or XCTest; all34 methods unstarted. Failed2261
candidate and partial build preserved;4339-file artifact/27-member metadata archives
verified, finalizer25731 terminal0/absent, task frozen. Root/prior/source unchanged.
[Publication](../evidence/application-mac-display-validation.json).
NEXT: separate exact-clone correction explicitly unwrapping storage for the same
Int pixel-count expression, then fresh build/package/all34 with unchanged methods
and limits. No pixel mutation/allocation/reference/Core/expected change. Independent
review/root promotion/actual clear/readback/general raster/presentation/conversion/
callbacks/fullscreen/providers/loading/Windows/visual/input/audio/clean-Mac/full
match/game remain open; EXE envelope not recalculated. Supersedes fresh34 NEXT below.

[Native display-resource candidate](APPLICATION_MAC_DISPLAY.md): owned display,
primary/backbuffer/clipper allocations, shared window/resource tokens and masked
full-color clear/image delivery implemented. Fresh pixels remain unknown; primary
writes clip to the native window. XRGB8888/logical-screen mapping is explicit host
policy, not Windows format evidence. Windowed WinMain still performs no clear;
that helper has a separate physical test and unchanged420-case regression.
Five files parse;34 methods selected, not run. Root1034/base2257/source55 protected;
2261-file archive, five-file patch roundtrip and61-member metadata verified.
Finalizer14412 terminal0/absent; task frozen.
[Publication](../evidence/application-mac-display.json).
NEXT: fresh build/package/all34 on exact candidate, including actual backing,
clipper lifetime, full color fill and AppKit view readback. Preserve failures before
correction. Independent review/root promotion/general blit/presentation/conversion/
callbacks/fullscreen/other providers/loading/Windows/visual/input/audio/clean-Mac/
full match/game remain open. NTSDApp still Practice; EXE envelope not recalculated.
Supersedes resource-implementation NEXT below.

[Physical AppKit window passes all29 methods](APPLICATION_MAC_WINDOW_VALIDATION.md):
fresh build/package verified199Core/61Reference/2MacPlatform/278test sources and1686
resources. Four actual-window whole-startup/geometry/permit/late-retry methods pass;
794×550 client points at2x backing,11 physical window requests, one create across
late rollback. All25 original controlled regressions pass unchanged. Queue75740/
finalizer81466 terminal0/absent;4932-file artifact/147-member metadata archives
verified, task frozen. Root/prior/candidate/source preserved.
[Publication](../evidence/application-mac-window-validation.json).
NEXT: concrete native display/surface acquisition and startup clear through the
same exchange and actual window identity. Use existing descriptor/mask/alias/release
contracts; establish host format/backing provenance before conversion, retain whole
startup/late rollback and unsupported boundaries. Independent review/root promotion,
Windows format/palette/text/clipper/callback/fullscreen, other providers/audio,
loading/visual/input/Windows/clean-Mac/full match/game remain open. NTSDApp still
Practice; EXE envelope not recalculated. Supersedes fresh29 NEXT below.

[Physical macOS window candidate](APPLICATION_MAC_WINDOW.md): AppKit service now
consumes whole-startup permits on the same Host, owns cursor/class/window identities
and retains physical replies through rollback. Common beginService rejects foreign,
duplicate/cancelled physical starts before IO. Six Swift files parse; four new plus
25 unchanged methods selected, not run. Root1034/base2254/source55 preserved;
2257-file/60-directory archive, six-file patch roundtrip and45-member metadata
verified. Finalizer59873 terminal0/absent; task frozen. Native policy uses points,
AppKit decorations/center; Windows callbacks/DPI/menu/focus are not proved.
[Publication](../evidence/application-mac-window.json).
NEXT: fresh build/package/all29 on this exact candidate, including actual AppKit
window checks and the new target's compiled source membership. Preserve any failure
before correction. Independent review/root promotion/graphics/raster/other physical
providers/callbacks/fullscreen/loading/Windows/clean-Mac/full match/game remain open.
NTSDApp still Practice; EXE envelope not recalculated. Supersedes window-service NEXT below.

[Observed whole startup passes all25 methods](APPLICATION_OBSERVED_STARTUP_CORRECTION1.md):
import-only correction builds;199Core/61Reference/277test sources and1686 resources
verified. Full35 cases retain23 matches/5 stops/7 provenance outcomes,6325events/
119WAVs and1841 replies (650window/1191nonwindow). Actual Mac clocks are acquired
at whole-caller permits, FILETIME after21window replies; late retry retains both.
Four new plus21 unchanged tests pass. Queue10821/finalizer16329 terminal0/absent;
4916-file artifact/133-member metadata archives verified, task frozen. Root/base/
failed candidate/source preserved; prior compile failure remains recorded.
[Publication](../evidence/application-observed-startup-correction1.json).
NEXT: concrete macOS window/resource request service consumed by this whole-startup
exchange and same Host. Freeze finite AppKit/windowed mapping and observable failure/
callback boundaries, implement owned identities/lifetimes and actual window checks;
reuse existing evidence, not another inventory/queue-only phase. Synchronous callbacks,
unknown fullscreen provenance, other physical providers/nonthrowing/aggregate audio,
independent review/root promotion/loading/Windows/clean-Mac/full match/game stay open.
EXE envelope not recalculated. Supersedes import-correction NEXT below.


[Observed startup build failure preserved](APPLICATION_OBSERVED_STARTUP_VALIDATION.md):
fresh build84305 terminal1/absent: new test imports nonexistent NTSDReference instead
of NTSDReferenceChecks. No XCTest/package acceptance; all25 methods unstarted.
Failed2254 candidate/Core and partial build preserved;4601-file artifact/28-member
metadata verified, finalizer92639 terminal0/absent, task frozen. Root/prior/source
unchanged. [Publication](../evidence/application-observed-startup-validation.json).
NEXT: separately cloned test-import correction, then fresh build/package and exact
same25 methods/limits. No Core/assertion/expected change; preserve failed candidate.
Independent review/root promotion/actual clocks/window/input/audio/full match/game
remain open; EXE envelope not recalculated. Supersedes fresh25 NEXT below.


[Resumable startup candidate](APPLICATION_OBSERVED_STARTUP.md): one typed exchange
now covers window plus16 throwing nonwindow families; production provider and same
Host retain actual answers/resources across retries. External macOS integer clock
producer implemented. Seven Swift files parse; four new plus21 unchanged methods
selected, not run. Root/base/source and prior tests preserved;2254-file archive,
seven-file patch roundtrip and48-member metadata archive verified. Finalizer77836
terminal0/absent, task frozen. [Publication](../evidence/application-observed-startup.json).
NEXT: fresh build/package/all25 methods on this exact candidate, including actual
Mac clock acquisition at whole-caller permits and late retry. Then concrete physical
backend acquisition; independent review/root promotion/nonthrowing constants/live
window/input/audio/loading/Windows/clean-Mac/full match/game remain open. EXE envelope
not recalculated. Supersedes prepared-only acquisition NEXT below.


[Prepared startup validation complete](APPLICATION_PREPARED_STARTUP_PLATFORM_VALIDATION.md):
fresh build/package and all11 selected methods passed on unchanged2249 files.
The production Core provider preserves23 complete/5 stops/7 provenance outcomes,
6325events/119WAVs/650 window replies, late failures/copies/owner retention and16
prepared-response families; eight unchanged inspection/startup methods also pass.
Queue34416/finalizer36848 terminal0/absent;4906-file artifact/71-member metadata
archives verified, root/prior/candidate/source preserved; task frozen.
[Publication](../evidence/application-prepared-startup-platform-validation.json).
The preparation job's inherited summary label8 is preserved and separately qualified;
actual selection/limits/controls/queue all contain11, no tests were omitted or rerun.
NEXT: connect resumable external nonwindow observations to this platform and whole
startup, preserving actual request payloads and fulfilled values/resources across
retries. Milliseconds precedes the window; FILETIME must be observed after it.
Current immutable preparation is not live acquisition. Reuse the exchange/Host;
require complete caller/late rollback and actual macOS observations where implemented.
Independent review/root promotion, physical backend/callbacks/input/audio/loading
messages/fills/full137 source/Windows/clean-Mac/full match/game remain open; EXE
envelope not recalculated. Supersedes the fresh11-method NEXT below.

[Production prepared startup candidate](APPLICATION_PREPARED_STARTUP_PLATFORM.md):
Core now supplies the real startup-platform conformance from bundled original inputs
and typed explicit observations, with independent positions/output/cursor copies
and retained owners. Two new files parse; all old algorithms/tests/fixtures/resources
remain exact. Three new whole/boundary methods plus unchanged8 are selected (11),
not executed. Root1034/base2247/source55 preserved;2249-file archive, two-new-file
patch roundtrip and31-member metadata archive verified. Finalizer14906 terminal0/
absent; task frozen. [Publication](../evidence/application-prepared-startup-platform.json).
NEXT: fresh build/package/all11 methods on exact candidate295864416a72f76e19471ece43331fc40d4a2a2ec8b6d66dbe69251c7c977eb6.
The runtime provider is implemented but unaccepted; it does not supply actual
physical device observations. Independent review/root promotion/physical backend/
callbacks/loading messages/fills/audio/full137 source/Windows/clean-Mac/full match/
game remain open; EXE envelope not recalculated. Supersedes the provider NEXT below.

[Host inspection validation complete](APPLICATION_HOST_WINDOW_INSPECTION_VALIDATION.md):
fresh build/package and all8 complete methods passed on the unchanged2247-file
candidate. The three new methods cover post-handoff copying,32 whole key transactions
with concurrent readers, and private inspection across failures/cancellation; five
whole startup regressions retain23 complete/5 stops/7 provenance outcomes and650
once-served replies. The reported lock edge is removed in code and the declared
controls pass; independent review and exhaustive scheduler coverage are not claimed.
Queue82338/finalizer84149 terminal0/absent;4902-file artifact/60-member metadata
archives verified, root/prior/candidate/source preserved; task frozen.
[Publication](../evidence/application-host-window-inspection-validation.json).
NEXT: production startup platform consumed by this coordinator and the same Host,
using original bundled inputs, Native-owned staged storage and explicit prepared
nonwindow observations. Freeze its concrete ownership/request/failure contract,
replace the XCTest-only adapter and retain whole startup/late-failure comparison;
reuse the existing inventory, not another inventory/receipt-only study.
Physical backend/callbacks/input/audio/loading dispatch, independent review/root
promotion/full137 source/Windows/clean-Mac/full match/game remain open. EXE envelope
not recalculated. Supersedes the fresh8-method NEXT below.

[Host inspection correction candidate](APPLICATION_HOST_WINDOW_INSPECTION.md):
coordinator value reads now use Host's own lock; after handoff coordinator platform
copying rejects before Host access, with copies available on the returned Host.
The reported opposite lock edge is removed in code. Two Swift files parse; three
new bounded inspection/concurrency methods plus five unchanged whole startup
methods are selected, not executed. All old tests/Core dependencies/root1034/
base2246/source55 preserved;2247-file archive, two-file patch roundtrip and31-member
metadata archive verified. Finalizer58464 terminal0/absent; task frozen.
[Publication](../evidence/application-host-window-inspection.json).
NEXT: fresh build/package and all8 methods on this exact correction. Passing the
prior28 is baseline evidence only. Independent review/root promotion, production
providers/backend/devices/full catalog source/Windows/clean-Mac/full match/game
remain open; EXE envelope not recalculated. Supersedes the correction NEXT below.

[Same-Host startup validation](APPLICATION_HOST_WINDOW_STARTUP_VALIDATION.md):
all28 methods passed on the unchanged2246-file candidate, including five new whole
startup/rollback/protocol/lifetime methods and23 retained window/Host/context/
Bootstrap methods. Exact23 complete/5 original-stop/7 provenance outcomes and650
once-served startup replies retained. Fresh build/1686 package files,4900-file
artifact and140-member metadata archives verified; root/prior/candidate/source
preserved. Queue23770/finalizer38551 terminal0/absent; task frozen.
[Publication](../evidence/application-host-window-startup-validation.json).
NEXT: correct the [post-handoff inspection lock-order gap](../evidence/application-host-window-startup-lock-review.json)
identified by author source inspection; freeze finite checks before edits. This
possible concurrent cycle is not an observed hang and is outside the28-method
selection; its pass does not accept the complete ownership contract. Preserve the
same Host and receipt/rollback rules. Independent review/root promotion, production
providers/backend/devices/full catalog source/Windows/clean-Mac/full match/game
remain open; EXE envelope not recalculated. Supersedes the fresh28-method NEXT below.

[Same-Host window startup candidate](APPLICATION_HOST_WINDOW_STARTUP.md): one
retained Host now receives fresh prepared window cursors between startup attempts.
Receipt completion follows the fallible delivery-context copy and precedes Host
publication. Five Swift files parse; all old test bodies/comparators remain exact.
Five new and23 retained methods (28 total) are selected, not executed. Root1034/
base2244/source55 preserved;2246-file archive, five-file patch roundtrip and49-member
metadata archive verified. Finalizer6126 terminal0/absent; task frozen.
[Publication](../evidence/application-host-window-startup.json).
NEXT: fresh bounded build/package and all28 complete methods on this exact candidate,
including whole WinMain outcomes, late failures and retained Host/context consumers.
Independent review/root promotion, production providers/physical backend/devices,
full catalog source/Windows/clean-Mac/full match/game remain open. EXE envelope not
recalculated. Supersedes the Host startup implementation NEXT below.

[Window exchange validation complete](APPLICATION_WINDOW_EXCHANGE_VALIDATION.md):
all 10 selected methods passed on the unchanged 2244-file candidate. The 280
whole-window cases fulfilled 4574 requests once each; WinMain retained 23 complete
chains, 5 original stops and 7 provenance rejections with 650 window replies.
Fresh build, 1686 package files, 4896-file artifact and 67-member metadata archive
verified; root/prior/candidate/source pins preserved. Queue58993/finalizer62857
terminal0 and absent; task frozen. [Publication](../evidence/application-window-exchange-validation.json).
NEXT: finite Host startup preparation and window-response coordinator on the same
Host, preserving receipts across suspension and late failures; publish only after
the whole caller and response-consumption checks succeed. This closes the concrete
missing startup preparation hook identified in the study. Independent review,
root promotion, production providers/backend/devices, full catalog source/Windows/
clean-Mac/full match/game remain open; EXE envelope not recalculated. Supersedes
all earlier window-exchange build/comparison NEXT statements below.

[Window exchange candidate](APPLICATION_WINDOW_EXCHANGE.md): additive Core
receipt/suspension/claim/answer/failure owner implemented; same window/WinMain
algorithms remain unchanged. Four Swift files parse; five new whole-caller/
protocol/lifetime methods and five retained methods are selected, not executed.
All old82 test bodies,385 fixtures,1301 resources and root1034/base2242/source55
preserved. Four-file patch roundtrip,2244-file candidate archive and46-member PAX
archive verified; finalizer37731 terminal0/absent, task frozen.
[Publication](../evidence/application-window-exchange.json).
NEXT: fresh bounded build, package verification and all10 complete methods on
this exact candidate. This supplies before-consumption window response ownership;
production provider/Host suspension integration, independent review/root promotion,
real devices/full catalog source/Windows/clean-Mac/full match/game remain open.
EXE envelope not recalculated. Supersedes the implementation NEXT below.

[Host delivery-context validation complete](APPLICATION_HOST_DELIVERY_CONTEXT_VALIDATION.md):
all82 methods passed on the unchanged2242-file candidate, including all76 prior
whole catalog/Host/caller methods and the complete17/48/14 gameplay schedules.
Queue5193 terminal0/2984.333s; finalizer98639 terminal0/91.621s, both absent.
Fresh build,1686 package files,4892-file artifact and367-member metadata archives
verified; prior145-member progress archive preserved. Root1034/prior2241/current2242/
source55 unchanged; task frozen. [Publication](../evidence/application-host-delivery-context-validation.json).
NEXT: finite resumable window request/reply owner consumed by whole WinMain,
following the prepared backend preflight; freeze contract/cases before edits.
Keep280 whole-window cases,23 successful startup parents and distinct original
stops/provenance rejections, plus suspension/receipt/late-rollback checks.
Independent review/root promotion/backend/loading message and fill contracts/
catalog transport/full137 source/devices/Windows/clean-Mac/full match/game remain
open; EXE envelope not recalculated. Supersedes all live-queue NEXT prose below.

[Prepared backend preflight](APPLICATION_PREPARED_BACKEND_PREFLIGHT.md) closed its
static scope:23 Native files/15 studies pinned;56-member PAX archive verified.
Current batches retain owners but cannot supply before-consumption device replies.
Catalog already has animated drawing; nonempty loading messages/fill/link paths
remain explicit gaps. Publisher64234 terminal0/absent; no source/Native/device run.
[Receipt](../evidence/application-prepared-backend-preflight.json).
NEXT remains the same82-method validation queue and its terminal/archive gates.
After closure: finite resumable window request/reply owner in actual WinMain,
with unchanged280 whole-window and23 successful whole-parent comparisons plus
preserved stops/provenance rejections. This is a design contract, not an actual
backend or relaxed IO/rollback rule. Independent review/root promotion/devices/
full catalog source/match/game open; EXE envelope not recalculated.

## Продолжение — 2026-09-26

[Delivery-context checkpoint](APPLICATION_HOST_DELIVERY_CONTEXT_VALIDATION.md):
40/82 exact saved method results verified; same queue5193 continues test41.
The145-member progress archive was fully reverified; finalizer result predicates
remain unchanged. [Receipt](../evidence/application-host-delivery-context-validation-checkpoint.json).
NEXT remains same-queue completion/diagnosis and full archive closure; no rerun.
Independent review/backend/app/full-game gates remain open.

[Host delivery context validation](APPLICATION_HOST_DELIVERY_CONTEXT_VALIDATION.md):
fresh build93616 terminal0/291.448s,192 Core/61 Reference/272 test sources and
all1686 package files verified. All six new delayed-delivery/copy-failure/lifetime
methods pass;12/82 total passes in the10:07:34Z saved snapshot. Queue5193 verified
live and continues the unchanged candidate and complete old76 schedules/limits.
Root1034/prior2241/current2242/source55 unchanged;145-member progress archive
verified. [Receipt](../evidence/application-host-delivery-context-validation-start.json).
NEXT: revalidate/observe this same queue and current child; preserve and diagnose
any nonpass. After terminal, pinned task-local finalize1.py verifies all saved
results and full candidate/release/metadata archives; separately reverify progress
archive. Do not duplicate or rerun. Full82/archive closure/independent review/root
promotion/prepared backend/catalog transport/full137 source/app devices/Windows/
clean-Mac/full match/game remain open. Task not frozen; EXE envelope not recalculated.
Supersedes the fresh-build NEXT below.

[Retained Host delivery context candidate](APPLICATION_HOST_DELIVERY_CONTEXT.md):
startup/iteration/loaded batches now retain their own computed Application and
independent Platform. Three Swift files parse; six new methods are written and
all76 prior method bodies preserved (82 selected, not executed). Root1034/base2241/
source55 unchanged;2242-file/59-directory regular archive,38-member metadata archive
and three-file patch roundtrip verified. Finalizer82743 terminal0/absent; task frozen.
[Publication](../evidence/application-host-delivery-context.json).
NEXT: fresh bounded build and all82 comparisons on this exact candidate, retaining
old76 limits/schedules. This validates delayed delivery resources and publication
rollback before the prepared backend can consume batches. Independent review/root
promotion/backend/catalog transport/full137 source/app devices/Windows/clean-Mac/
full match/game remain open. EXE envelope not recalculated. Supersedes the earlier
implementation NEXT below; no original or previously completed job was restarted.

[Catalog package validation complete](APPLICATION_CATALOG_PACKAGE_VALIDATION.md):
all76 methods passed on the unchanged2241-file candidate, including4 reader,
3 direct catalog and69 retained whole-host/caller methods. Queue42094 and
finalizer29333 terminal0/absent. Fresh build,1686 resource files, all five isolated
Core-client checks,6093-file artifact and381-member metadata archives verified;
root1034/prior1040/source55 preserved. Task frozen. [Publication](../evidence/application-catalog-package-validation.json).
NEXT: finite retained per-commit delivery context for startup/iteration/loaded
Host batches, from this candidate and the existing app preflight. A delayed
consumer must retain its own resources/order after later commits; failed attempts
must leave earlier batches and owners intact. Freeze contract/cases before edits.
Independent review/root promotion/prepared backend/catalog transport/full137
source/AppKit devices/Windows/clean-Mac/full match/game remain open. EXE envelope
not recalculated. Supersedes the live-queue/archive NEXT below; do not rerun it.

[Catalog package comparison checkpoint](APPLICATION_CATALOG_PACKAGE_VALIDATION.md):
57/76 complete methods verified at08:52:46Z; same queue42094 and child80613/test58
confirmed live. Finite finalizer prepared for6093 candidate/release/standalone app
files; exact saved-result classification agrees on51 logs and12 controls. No new
build/test/source launch. [Receipt](../evidence/application-catalog-package-validation-preclose.json).
NEXT: observe this same queue, preserve/diagnose a nonpass; after terminal run the
pinned task-local finalize2.py and verify all archive/preservation gates. Do not
run it while the queue is live. Full76/large archive/independent review/root
promotion/backend/app devices/full catalog source/full match/game remain open.
Initial finalizer and the checkpoint observation race are preserved; queue and
candidate unchanged. EXE envelope not recalculated. Supersedes the dated count below.

[Catalog package validation started](APPLICATION_CATALOG_PACKAGE_VALIDATION.md):
fresh build25257 terminal0/311.585s,192 Core/61 Reference/271 test sources and
all1686 packaged files verified. Core-only client links no test/reference objects;
relocated app reads all521 files/669 images/8 music inputs with repository/X5/T7
reads actually denied. All three denial probes, complete read and missing-package
control passed; client queue40449 terminal0. First7 Native methods pass (4 reader,
3 full-catalog/late rollback);16 total passes in the dated progress snapshot.
Queue42094 continues all76 on this unchanged binary under the original limits;
156-member progress metadata archive verified. [Receipt](../evidence/application-catalog-package-validation-start.json).
NEXT: revalidate and observe the same queue/current child. On nonpass diagnose
its exact saved result; otherwise finish all76/preservation/large archive gates.
Do not duplicate, rebuild, rerun prior passes or alter pinned tools/candidate.
Root1034/prior1040/current2241/source55 unchanged. Full76 acceptance/large archive
closure/independent review/root promotion/backend delivery/catalog transport/
full137 source/app devices/Windows/clean-Mac/full match/game remain open; task is
not frozen. EXE envelope not recalculated. Supersedes the fresh-build NEXT below.

[Catalog package candidate](APPLICATION_CATALOG_PACKAGE.md): regular original
input package and Native reader implemented in isolated2241-file candidate.
1,198 payloads/661,635,220 bytes plus manifest verified against original inputs;
full catalog input preparation now uses this producer. Root1034/prior1040/source55,
all old fixtures/resources and69 existing test bodies unchanged. Three Swift files
parse; no compile/XCTest yet. Finalizer98474 terminal0/absent;2244-file/60-directory
candidate and34-file metadata archives verified, task frozen.
[Publication](../evidence/application-catalog-package.json).
NEXT: separately bounded fresh release build, all76 methods (4 reader +3 direct
full-catalog/late rollback +69 retained host/caller), complete built package byte
verification and isolated Core-only reader against an ordinary app layout.
Use selected-methods2 and the saved-log reader correction; keep original limits
for inherited methods, and freeze new method/client limits before launch. No
original restart or edits to this closed candidate. Native comparison/independent
review/root promotion/backend delivery/catalog transport/full137 source return/
actual app/Windows/devices/clean-Mac/full match/game remain open. EXE envelope not
recalculated. This supersedes the catalog-package NEXT below.

[Host app preflight complete](APPLICATION_HOST_APP_PREFLIGHT.md): three ordered
batch streams, all23 startup provider members and nine later input groups mapped.
Full catalog still receives original input bytes from XCTest fixtures; the app
has no shipping catalog reader or host consumer. Preparation40374/finalizer62503
terminal0/absent;12-member metadata archive verified. Root1034/candidate1040/
source55 unchanged. No original/Native/device execution; independent review open.
[Publication](../evidence/application-host-app-preflight.json).
NEXT: original catalog/media package and Native reader in a fresh candidate from
current1040. Pin521 file roles,669 image roles and8 WMA inputs to original bytes;
count unique payloads separately. Compare complete maps with the old input producer,
retain all69 host/caller methods and17/48/14 schedules, then verify self-contained
bundle reads. Freeze copying/build/test bounds before execution. This removes a
standalone-data dependency on the path to the full match. Retained delivery owners,
prepared device replies, root promotion, catalog transport/full137 return, actual
app/Windows/devices/clean-Mac/full match/game remain open. EXE envelope not
recalculated. This supersedes the app-preflight NEXT below.

[Host gameplay comparison complete](APPLICATION_HOST_GAMEPLAY_COMPLETION.md):
all69 methods verified on unchanged correction1 binary:57 prior, separately
recovered58,11 new. Queue90854 terminal0/absent; finalizer26386 terminal0/absent.
Root1034/candidate1040/package487/source55 and prior2488-file archive unchanged;
new70-member metadata archive verified, task frozen. Old reader nonpass preserved.
[Publication](../evidence/application-host-gameplay-completion.json).
NEXT: bounded read-only app-delivery preflight of the host startup/iteration/loaded
batches, platform input provenance, retained resources, cross-domain delivery and
failure/retry ownership. Current AppKit remains on practice scenes; host has no
shipping consumer. End with a finite implementation/comparison plan for the next
runnable app boundary. No source restart or test rerun. Independent review/root
promotion/catalog transport and whole137 return/app devices/full match/game remain
open. EXE envelope not recalculated. This supersedes the live-queue NEXT below.
T7 is now authorized for artifacts under AGENTS/WORKFLOW; its ExFAT boundaries and
40GiB reserve are recorded. The old WORKFLOW was archived before the policy update.

[Host gameplay saved-result recovery](APPLICATION_HOST_GAMEPLAY_COMPLETION.md):
one-anchor reader correction passes2 positive/12 negative controls; all57 prior
classifications unchanged, method58 separately recovered without rerun. Old nonpass
retained. Preparation90525 terminal0; root1034/candidate1040/package487/source55
unchanged. Queue90854 running only59–69 on the unchanged binary, original limits.
[Receipt](../evidence/application-host-gameplay-completion-start.json).
NEXT: revalidate/observe this same queue/current child, then diagnose any nonpass
or finalize all69/package/old2488-file archive/new metadata. Do not duplicate,
rebuild, rerun1–58 or restart source. Full69 comparison/archive/independent review/
root promotion/app/match/game remain open. This supersedes the reader-recovery
NEXT below.

[Host gameplay correction1 terminal result](APPLICATION_HOST_GAMEPLAY_CORRECTION1.md):
queue20715 terminal1/absent after57 accepted methods. Method58 has a complete named
XCTest pass, three zero-failure summaries and exit0, but the reader's line-start
anchor misses its result embedded in buffered JSON. Exact byte-span diagnosis and
old nonpass are preserved;59–69 remain unstarted. Finalizer70559 terminal0/absent;
2,488-file artifact and275-member metadata archives verified. Root1034/current1040/
both prior1040/source55/package487 unchanged. [Publication](../evidence/application-host-gameplay-correction1.json).
NEXT: separately freeze/read-only validate the one-anchor result-reader correction,
recover method58 from its immutable log, then run only59–69 on this unchanged
binary with unchanged limits. Do not rerun58, rebuild, edit the closed task or
restart source. Independent review/full69 comparison/root promotion/app/match/game
remain open. This supersedes the live-queue NEXT below.

[Host gameplay correction1](APPLICATION_HOST_GAMEPLAY_CORRECTION1.md): the one
missing optional driver declaration now passes fresh build10257 (exit0/282.927s),
exact191/61/270 source inventories and487 packaged resource bytes. Only one test
signature changed in the isolated1040-file candidate; root1034, both prior1040
candidates and source55 remain unchanged. Queue20715 is running all69 unchanged
methods with previous limits; first3 passed at the build/start receipt. Full
comparison/archive/review gates remain open. [Receipt](../evidence/application-host-gameplay-correction1-start.json).
NEXT: revalidate and observe this same queue/current child, never duplicate it;
on terminal outcome diagnose the first nonpass or finalize all69/package/archive.
Generated tools and exact paths are in the study. This supersedes the correction
NEXT below. Source59727 is terminal0/absent since2026-09-23T00:10:17Z, stopped at
the declared publication logical cap (researchBoundary/dependency), not a full
catalog return; do not restart. Root promotion/installed trajectory/devices/catalog/
first complete match/full game and prior safety dependencies remain open.

[Catalog53 terminal preflight](FIRST_DAMAGE_CATALOG53_TERMINAL_PREFLIGHT.md):
saved249,780,969-byte publication SHA verified; source stops at publication
logical cap after34 Object returns, pending35/kisame.dat, not whole137 return.
Nine manifests/80,296 parts have valid metadata and present exact-sized regular
files;326,092,501,942 trace raw bytes and27,852 blobs remain undecoded/unverified.
Eight-member metadata archive verified; source/root1034/host1040 preserved.
[Evidence](../evidence/first-damage-catalog53-terminal-preflight.json).
Independent branch complete at metadata scope. First finish/diagnose same host69
queue above; next source gate is separately bounded whole saved transport audit,
then provenance/read/state audit. No original restart or full catalog acceptance.

## Актуальный срез — 2026-09-22

[Host gameplay validation failed at compile](APPLICATION_HOST_GAMEPLAY_VALIDATION.md):
fresh build83817 exited1/154.046s in the test target. ActiveOutputTests.sequence
forwards driver but lacks the optional parameter; its HostGameplayTests caller
also reports an extra argument. One declaration correction is identified.
All69 methods unstarted; no test binary or complete package accepted. Failed tree,
log and diagnosis preserved;2180-file/145-directory artifact and22-member metadata
archives verified. Root1034/both1040 candidates/source55 unchanged. Finalizer86322
terminal0/absent; task frozen. Source59727 live at19:53:23 UTC:3719 chunks/24 Objects.
[Evidence](../evidence/application-host-gameplay-validation.json).
NEXT: separate one-file correction adding the optional driver to ActiveOutputTests.
sequence; retain every other file/all69 methods/current limits, then fresh build,
comparison/package/archive gates. No retry in the closed failed task or source
restart. Independent review/root promotion/installed trajectory/devices/catalog/
full match/full game remain open. This supersedes the initial-validation NEXT below.

[Host gameplay candidate](APPLICATION_HOST_GAMEPLAY_CANDIDATE.md) implemented in
isolated1040-file tree: common input outcome, private Ready/body/platform retention,
existing normal/paused child, and one final outer publication. Nineteen Swift paths
parse successfully; compilation and all69 selected methods remain unexecuted.
Existing full17/48/14 sequences and keyboard comparisons share actual host transport;
two acquisition-helper paths were explicitly added before edits.446 comparison
lines retained; patch round-trip and58-member candidate/draft/metadata archive pass.
Root1034/prior1039/385fixtures/102resources/source55 unchanged. Task frozen;
finalizer82133 terminal0/absent. Source59727 live at19:39:12 UTC:3634 chunks/24 Objects.
[Evidence](../evidence/application-host-gameplay-candidate.json).
NEXT: freeze fresh build/all69-method/package/archive validation for this exact
candidate, with declared whole-parent memory/time limits and stop on first nonpass.
No old binary pass validates this changed Core. Independent review/root promotion/
installed trajectory/app devices/full catalog/full match/full game remain open.
This supersedes the implementation NEXT below; no original restart.

[Host gameplay preflight](APPLICATION_HOST_GAMEPLAY_PREFLIGHT.md): traced current
input ownership through normal/paused GameplaySession and the outer return on
actual candidate1039. Proposed common preparation retains one acquired Ready,
then its returned body/platform, with exact tickets and retries before one final
publication. Six saved envelopes verified;304,819,130 cumulative decoded bytes
including four repeated reads. No Native/original execution. Exact63 existing +6
proposed methods selected, preserving both17/48/14-call schedules and whole owners.
Original1MiB metadata gate failed; oversized keyboard report preserved under a
separate3MiB delivery amendment. Root1034/candidate1039/source55 preserved.
[Evidence](../evidence/application-host-gameplay-preflight.json).
NEXT: separately plan and implement the isolated host gameplay candidate, retaining
all69 selected methods, then fresh build/comparison/package/archive gates. Source59727
continues without restart. Independent review/root promotion/installed trajectory/
app devices/full catalog/full match/full game remain open. This supersedes the
read-only preflight NEXT below; no new Native acceptance is claimed.

[Typed host comparison complete](APPLICATION_HOST_MATCH_COMPLETION.md): all53
selected methods pass on the unchanged correction1 binary (25 retained +28 new).
Actual host Start/platform retention, whole launch/outer commit, late rollback,
foreign/sibling/stale ticket and reentry checks pass. First gameplay input is
compared inside the host then deliberately rolled back; no completed tick claimed.
Queue66967 terminal0/1233.194s; no new failure/guard. Prior compiler and RSS failures
remain preserved. Finalizer73241 terminal0/absent; prior2486-file archive and
new132-member metadata archive verified. Task frozen; root1034/candidate1039/
package487/source55 unchanged. Source59727 live (18:52:53 UTC:3338 chunks/22 Objects).
[Evidence](../evidence/application-host-match-completion.json).
NEXT bounded read-only preflight: actual host gameplay-entry/input retention and
its next consumer, with saved whole-caller evidence/owners/rollback before API
extension. Full catalog source, independent review, root promotion, actual app/
devices/retained gameplay/full game remain open. No original restart or code edit.
This supersedes the unfinished-method NEXT below.

[Typed host correction1](APPLICATION_HOST_MATCH_CORRECTION1.md): one Core
platform-assignment correction builds successfully; fresh191/61/269 source targets,
62,637,720-byte binary and487 resource payloads verified.25 methods passed.
Method26 hit8GiB RSS at8,894,627,840 bytes/86.344s, exit-15; no completed result,
27 later methods unstarted. Queue62872 terminal1; guard and partial log preserved.
Finalizer65026 terminal0/absent;2486-file/156-directory artifact and164-member
metadata archives verified. Task frozen; root1034/candidate1039/source55 preserved.
[Evidence](../evidence/application-host-match-correction1.json).
NEXT separate continuation on this unchanged binary: retain25 passes, run whole26
at12GiB/600s, then27–53 with unchanged limits/7200s queue. No candidate/root/source
change or repeat of this closed attempt. Independent review/full53 comparison,
root promotion/devices/full game remain open. Original source59727 stays live
(18:23:09 UTC:3155 chunks/21 Objects).
This supersedes the compiler-correction NEXT below.

[Typed host validation failed at compile](APPLICATION_HOST_MATCH_VALIDATION.md):
fresh build57019 exited1/4.192s; Swift6.4 reports signal6 at HostSession.finishLoadedMenu
local platform binding. Static defect: that binding shadows the host property at
the final assignment. All53 tests unstarted; Native/package gates remain open.
Failure/log/candidate preserved;1645-file/74-directory partial artifact and25-member
metadata archives verified, root1034/candidate1039/source55 unchanged. Finalizer57553
terminal0/absent; task frozen. [Evidence](../evidence/application-host-match-validation.json).
NEXT separate correction: rename the returned-case binding preparedPlatform,
copy it, and explicitly assign self.platform at commit; retain the failed tree and
all53 names, then fresh build. Source59727 remains live (17:58:01 UTC:2997 chunks/
20 Objects). No original restart, root promotion or device/full-game acceptance.
This supersedes the initial-validation NEXT below.

[Typed host Start/launch candidate](APPLICATION_HOST_MATCH_CANDIDATE.md) implemented
in isolated1039-file tree: five changed Swift files parse successfully; no compile
or XCTest yet. Host retains Start/platform, resumes existing launch, then commits
returned child/platform once. Existing character/selection comparisons are shared
through the actual host;53 exact methods selected. Patch round-trip and24-member
metadata/changed-file archive verified. Root1034/prior1037/385fixtures/102resources/
source55 unchanged. [Evidence](../evidence/application-host-match-candidate.json).
Task frozen within1GiB; finalizer55198 terminal0. Source59727 revalidated17:43:07 UTC,
2905 chunks/20 Objects, still live. NEXT: freeze fresh build/53-method/package/archive
validation and resource bounds informed by prior whole-parent RSS; stop first
nonpass. Independent review/root promotion/devices/full game stay open. This
supersedes the implementation NEXT below; no original restart.

[Host Start/launch preflight](APPLICATION_HOST_MATCH_PREFLIGHT.md) complete as
read-only analysis: actual candidate1037 traced through typed PendingMatchPrelude,
existing launch child and final Bootstrap tail. Four saved envelopes verified
(34,579,061 decoded bytes); no new source/Native execution. Proposed isolated
extension retains Start/platform, then returned child/platform, with retry at each
stage and one outer publication. Exact50 existing +3 proposed new methods selected;
none of those proposed runs is claimed here. Root1034/candidate1037/source55
preserved; independent review/root promotion/devices/full game remain open.
[Evidence](../evidence/application-host-match-preflight.json). The same source
process59727 remains live, now19 Objects; no restart. NEXT: freeze and implement
the isolated typed host candidate described in the preflight, retaining all old
comparisons and failures. This supersedes the preflight NEXT below.

[Host loading regressions complete](APPLICATION_HOST_LOADING_REGRESSIONS.md): all42
methods verified on the unchanged round3 binary (34 retained +8 new, new queue
exit0/131.274s). Native comparison/package/archive gates pass; independent review,
root promotion and devices remain open. Root1034/candidate1037/package487/source55/
prior2482-file archive unchanged;51-member metadata archive fully verified.
External task frozen within1GiB; finalizer48699 terminal0/absent. Earlier assertion,
RSS and timeout outcomes remain immutable. [Evidence](../evidence/application-host-loading-regressions.json).
Source revalidated17:07:07 UTC:2670 chunks/18 Objects/654717456 stores, still live.
NEXT independent task: bounded read-only preflight of actual host ticket/platform
through LoadedMenu.Outcome.matchPrelude/PendingMatchPrelude and its consumers;
select saved whole-caller/rollback evidence before extending the API. No source
restart or root promotion. This supersedes the remaining-method NEXT below.

[Host loading round3](APPLICATION_HOST_LOADING_CORRECTION3.md): Bool presence
assertion preserves semantics; fresh build/package and34 methods passed. All four
new host-loading methods pass, including ticket identity97.395s/9.587GB RSS.
Whole LoadedCycle method35 hit8GiB RSS guard at8,712,486,912 bytes/18.722s, reaped-15;
seven later methods unstarted. Exact candidate/results archived; comparison incomplete.
Three correction rounds complete; static diagnosis finds no NotNil in cycle test
and does not attribute its peak. Revised NEXT contract: same binary,34 retained
passes, whole35–42;12GiB for three LoadedCycle methods and8GiB for five initialized,
600s unchanged, stop first nonpass. No automatic fourth candidate edit/source retry.
Root1034/candidate1037/package487/source55 preserved; independent review/devices open.
[Evidence](../evidence/application-host-loading-correction3.json). Supersedes round3
NEXT below while retaining all earlier failures.

[Host loading completion attempt](APPLICATION_HOST_LOADING_COMPLETION.md): same
binary/candidate retained27 passes; whole method28 timed out at600.748s, reaped-15,
no XCTest result;14 later methods unstarted. Native comparison remains incomplete.
One declared1s/5ms stack sample places144 main-thread samples in line275
XCTAssertNotNil recursively printing the large retained child. This observation
does not establish the whole runtime or assertion outcome; sample/guards preserved.
NEXT round3: separate test-only presence check `XCTAssertTrue(alternate != nil)`,
retain all semantic checks and run full42 on newly compiled candidate. No source
rerun, expectation edit or broader limit. Root1034/candidate1037/package487/source55
and prior2482-file archive reverified. Independent review/root/devices remain open.
[Evidence](../evidence/application-host-loading-completion.json). Supersedes same-
binary continuation NEXT below; earlier failures remain immutable.

[Host loading correction1](APPLICATION_HOST_LOADING_CORRECTION1.md): one new test
assertion corrected in a separate1037-file tree; all Core/fixtures/resources unchanged.
Fresh build/package passed.27 methods passed, including corrected loading/cycles
and late retry; method28 exceeded8GiB sampled RSS (8786558976 bytes), received
revalidated SIGTERM and reaped-15 without a complete XCTest result.14 unstarted.
Candidate/products/guard archived; Native comparison stays false, review open.
NEXT: separate bounded continuation, same verified binary and27 retained passes;
whole method28 with12GiB RSS ceiling and fourteen unstarted methods. Host has24GiB
physical memory; keep original space reserves and old guard. No method splitting,
source restart or expected edit. [Evidence](../evidence/application-host-loading-correction1.json).
This supersedes the correction NEXT below while preserving the failed original.

[Host loading validation](APPLICATION_HOST_LOADING_VALIDATION.md): fresh Core/
dependent build and487 package files verified;25 methods passed, method26 failed
with two operation-wrapper assertions;16 methods unstarted. Exact failed candidate,
logs and products preserved; Native comparison remains false. Author diagnosis:
fresh loading retains Loading→Catalog→Pool→Input wrappers, whereas cached cycles
use direct Input.menu. No source expected/mask or candidate change in this task.
NEXT: separate correction round with both complete prefix types and the same42
methods. Independent comparator/contract review remains open. Root1034/candidate1037/
55 source pins preserved; original source remains live. This supersedes the build
NEXT below, without changing frozen evidence. [Receipt](../evidence/application-host-loading-validation.json).

[Host loading candidate](APPLICATION_HOST_LOADING_CANDIDATE.md) implemented in a
new isolated1037-file tree: exact suspension identity, prefix reply exhaustion,
retained actual child/platform and retryable final outer commit with one loaded
batch. Six changed Swift files parse (PID18895 exit0/0.055s); compilation/tests
remain open. Four new methods plus38 regressions frozen for42-method validation.
Root1034/baseline1036/385fixtures/102resources/55 live pins preserved; patch
round-trip and22-member archive fully verified. External task frozen within1GiB;
finalizer19435 terminal0. [Evidence](../evidence/application-host-loading-candidate.json).
NEXT: separately bounded fresh Core/dependent build and all42 methods, package
and archive gates; no old binary or edits in the frozen candidate. Independent
review/root promotion/devices/later typed child retention remain open. Source
revalidated15:29:37 UTC:2039 chunks/14 Objects/500022617 stores, still live.
This supersedes the implementation NEXT below; source capture is not restarted.

[Host loading preflight](APPLICATION_HOST_LOADING_PREFLIGHT.md) completed from
current code and three hash-verified saved envelopes (134093766 decoded bytes).
Mapped actual pending/platform through first loading and cached cycles to the
single Bootstrap loaded commit. Two static host gaps identified: per-suspension
identity (same-owner/revision sibling tickets) and prefix packet exhaustion on
loading. Preserve the loop continuation's prepared baseline123456923; the source
loading record's baseline field is current ESI0x458b00, not timer state.
NEXT: new isolated host continuation candidate with retained prepared child,
staged platform and retryable final time/Sleep/commit, one loaded batch, whole
loaded-menu/cycle checks plus five initialized regressions. No code/test/device
execution or new whole-source equivalence here; independent review stays open.
[Verification](../evidence/application-host-loading-preflight.json). Root1034 and
55 source pins preserved; same source process continues. Supersedes preflight NEXT below.

[Host transaction validation](APPLICATION_HOST_TRANSACTION_VALIDATION.md): unchanged
candidate freshly compiled and all25 declared methods passed, with complete named
XCTest results/exit0. Build1 testability failure and first package-check timestamp
failure retained; separately identified corrections, no candidate/expected edit.
Core191/ReferenceChecks61/Tests266 sources,487 packaged resources,2480-file regular
archive and137-member metadata archive verified. Root1034/candidate1036/55 live pins
unchanged; task frozen within24GiB, finalizer12164 terminal0/absent. Independent
review, root promotion and actual devices remain open. [Evidence](../evidence/application-host-transaction-validation.json).
Source revalidated14:48:59 UTC:1768 chunks/12 Objects/433556355 stores, still live.
NEXT independent task: bounded read-only preflight of the retained host loading
ticket/platform through existing loading/cycle owners to Bootstrap.finishLoadedMenu;
identify saved whole-caller cases and failure/commit boundaries before extending.
This result supersedes the candidate's syntax-only status and compile/test NEXT
below; do not rebuild the successful frozen candidate or restart the source.

[Host transaction candidate](APPLICATION_HOST_TRANSACTION_CANDIDATE.md) implemented
in an isolated1036-file tree: persistent Bootstrap/platform owner, staged input
preparation, committed-batch handoff and retained loading ticket. Bootstrap forwards
nil initialization/body diagnostics; five new tests retain whole-parent comparators.
Seven changed files pass syntax parse (PID99133 exit0/0.262s), not typecheck/tests.
25 methods/eight families frozen for fresh validation. Root/baseline1034,385fixtures,
102resources and55 live code pins unchanged; patch round-trip and22-member archive
fully verified. Finalizer99726 exit0; external candidate frozen within256MiB.
One inspected packet-filter correction/draft preserved. Independent review and
root promotion remain open. [Evidence](../evidence/application-host-transaction-candidate.json).
Same source revalidated14:03 UTC:1462 chunks/ten Objects/358498342 stores, still live.
NEXT independent task: separate bounded fresh Core/dependent-target compilation
and the25-method validation; never use the old binary to validate changed Core.

[Production host transaction preflight](APPLICATION_HOST_TRANSACTION_PREFLIGHT.md)
completed as read-only analysis: selected saved case0 reaches the whole ordinary
first-menu return through `Bootstrap.step`; `finishLoadedMenu` belongs to later
pending children. Package inputs, host response gaps, staged owners and ordered
commit delivery are inventoried. Next independent task: freeze an isolated
candidate and implement the bounded transaction driver with explicit providers,
six finite acceptance groups and retained pending tickets. No runtime edit,
build/test, device acceptance or independent review is claimed.1034 Native files/
55 live code pins unchanged; saved67,627,502-byte payload transport verified.
[Receipt](../evidence/application-host-transaction-preflight.json).
Same source PID59727 identity/job revalidated13:34:56 UTC:1274 chunks/eight Objects/
312464419 stores; remains running, no whole return. [Observation](../evidence/application-host-transaction-preflight-context.json).

Завершена [диагностика первого урона](FIRST_DAMAGE_DIAGNOSTIC.md) из собственного
Bootstrap: два сценария обычной атаки, 184 новых полных вызовов/3496
body checkpoints после отдельных17-call neutral parents. Точные HP, контакты,
откаты и границы — в [evidence](../evidence/first-damage-diagnostic.json).
Это проверенная Native-диагностика; новые damaging calls ещё не сравнены с оригиналом.

Реализация: два новых XCTest/support файла; Core/1028 прежних Native-файлов
неизменны. Candidate1 отклонён до запуска и сохранён; candidate2 получил review,
ровно2 release-теста прошли. `damage2.job.json` терминален exit0, не перезапускать.
383 fixtures/102 resources,485 package files и архивы проверены отдельно.
Незавершённого кандидата этой карточки нет; конечный результат подготовлен к коммиту.

Принятые neutral/active19-stage и [pause/step/resume](APPLICATION_PAUSED_GAMEPLAY.md)
сравнения сохранены. [Карта препятствий](FIRST_MATCH_READINESS.md) объясняет прежний
active48 без урона: защита58→10. Новая диагностика прошла далее окончания защиты,
но не закрыла whole damaging source equivalence, первый матч или полную игру.
NTSDApp всё ещё вызывает OriginalMelee practice.

NEXT — независимое сравнение целого damaging caller для фактически достигнутых
контактов/Frames по FIRST_DAMAGE_DIAGNOSTIC: сохранить lifecycle и весь outer
commit, начать с уже сохранённых library доказательств и указать недостающие
same-input installed-source наблюдения до нового исполнения. Критерий — сравнение
целого вызова с неизменяемым оригинальным эталоном, не Native-only прогноз.
Production app session/input/commit adapter остаётся независимой ветвью.
Полная игра, raster/audio/window, Windows/device/clean-Mac и safety incidents
открыты. EXE envelope не пересчитывался.

## Подробная история и сохранённые ограничения

Срез 2026-09-13. Это навигация для следующего goal, не новая приёмка игрового
поведения. Обязательный порядок работы — [WORKFLOW](WORKFLOW.md); подробная очередь
и доказательства — [RESEARCH_MAP](../RESEARCH_MAP.md). Старые «NEXT» читать в контексте
соответствующего исследования, а не как конкурирующие команды запуска.

## Принятая опора

[Матрица подготовки War](LIB_WAR_PREPARATION_MATRIX.md) принята в своём конечном
объёме: 256 внешних вызовов, 236 возвратов War, 56 подготовок. Она сохраняет
порядок music RNG перед arena RNG, sparse seats, retained owners и промежуточные
числовые stores. Приёмка: [evidence](../evidence/lib-war-preparation-matrix.json).
Предшествующий [preflight](LIB_WAR_PREPARATION_NATIVE_PREFLIGHT.md) остаётся отдельным
принятым корпусом. Ни один из этих результатов не является сыгранным полным матчем.

Не перезапускать завершённые матрицу, preflight, War setup и каталожные захваты.
Их ошибки, исходные ожидаемые данные, masks, frozen plans и producers сохраняются.
Полный каталог candidate5 закончил на объявленном лимите хранилища после 28 Objects;
это не полный возврат каталога. Проверять его сохранённые job-данные, не следовать
старым историческим записям, называющим тот процесс живым.

Завершены также два накопленных Native-блока:
[собственные файлы/каталог](APPLICATION_CATALOG_NATIVE_FILES.md) и
[library transforms](LIB_TRANSFORMS.md). Приняты три прежних полных каталога
через собственный файловый слой, ограниченные DAT/Object lifecycle и четыре
отрицательных close responses; 1 760 returned transform cases сравнились по
полным нормализованным записям/маскам и 3 480 событиям. Четыре source faults
отдельно отвергаются Native с откатом и не считаются совпадениями.
Release: 40 тестов плюс четыре после добавления negative-close, 41 уникальный
тест, без ошибок. Нового исполнения оригинала нет. Состав, transport, review,
архивы и границы: [evidence](../evidence/pending-native-completion-2026-09-12.json).
Полные собственные каталог, library loop и приложение остаются открытыми.

Принят [NULL bitmap при подготовке War](LIB_WAR_NULLABLE_BITMAP.md): три сохранённых
returned вызова s02/00, s02/01 и s03/00 совпадают с Native по целому вызывающему
пути, 3 838 событиям и 48 числовым checkpoints. При первом NULL четыре поздних
owner сохраняются и переживают следующий Start99 без Release/free. Проверены
11 связанных откатов; Native самостоятельно выполняет по десять принятых
prefix calls для двух цепочек, без нового исполнения оригинала.
Raw-тест прошёл за 19.231с; 17 bundled release-тестов за 510.590с, включая
матрицу 256 вызовов, preflight 22 и общие Tournament/Team/resource регрессии.
333 прежних fixtures неизменны, 336 текущих/777 Native-файлов, Git и оба архива
проверены. [Приёмка](../evidence/lib-war-nullable-bitmap.json).
Отдельный s03/01 source fault и остальной error corpus этим не приняты.

Приняты [частичные surfaces War](LIB_WAR_PARTIAL_SURFACES.md): шесть сохранённых
returned s04..s09/call-00, 7 884 события, 96 numeric checkpoints, пять wrapper
owners на вызов и 18 связанных откатов. Сохраняются неизвестные размеры при
missing image, неудалённый image при CreateSurface failure и запись о Release
при colorKey failure. Последняя не доказывает фактического уничтожения surface.
Raw прошёл за 38.681с; девять bundled release-тестов за 268.324с, включая War
matrix/preflight/nullable и общие BitmapSurfaceLoading/CharacterMenuSurface.
Нового исполнения оригинала и изменения Core/expected не было. 336 прежних
fixtures неизменны, 342 текущих/784 Native-файла, Git и три отдельных архива
проверены. [Приёмка](../evidence/lib-war-partial-surfaces.json).
Шесть следующих call-01 source faults сохранены отдельно и не приняты как matches.

Приняты [ошибки графических API War](LIB_WAR_GRAPHICS_ERRORS.md): восемь
сохранённых returned s12..s19/call-00, 10 550 событий, 598 API-запросов,
128 numeric checkpoints, 40 новых wrapper owners и 24 связанных отката.
Проверены точные остановки после выбранного API, recording и перед outer return.
При GetDC failure два запроса пропускаются только в первом constructor;
CreateDC0 передаётся следующим операциям. DeleteDC фиксирует запрос даже при
результате 0, а DeleteObject0 сохраняет image с deleted=false. Эти записи
не доказывают реальное существование или уничтожение Windows/device объектов.
Raw прошёл за 50.264с; десять bundled release-тестов за 317.460с, включая War
matrix/preflight/nullable/partial и общие BitmapSurfaceLoading/CharacterMenuSurface.
Нового исполнения оригинала и изменения Core/expected нет. 342 прежних fixtures
неизменны, 350 текущих/793 Native-файла, staged Git и оба архива проверены.
[Приёмка](../evidence/lib-war-graphics-errors.json). Девять source faults остаются
отдельно; всего приняты 17 из 28 returned error-corpus вызовов.

Приняты [музыкальные ошибки War и два штатных контроля](LIB_WAR_MUSIC_ERRORS.md):
девять saved returned s00/s01/s20/s21/s23/s24/s25/s26/s27, только call-00.
Сравнились 12 028 событий, 144 numeric checkpoints, 221 bodyMusic events,
два сообщения, 827 graphics API requests, 55 wrapper owners и семь wide buffers /
210 bytes; прошли 27 связанных откатов. Responses строятся из declared inputs.
Сообщения сверяются с собственными globals после music stores; NULL Render и
opaque backing после conversion0 сохраняют владельцев и исходные маски.
Raw 56.435с; шесть bundled War-тестов 370.173с и пятнадцать общих тестов
224.595с прошли на одном frozen candidate — 21 уникальный bundled метод.
Core только передаёт optional store observer; правила игры и expected не менялись.
350 прежних fixtures неизменны, 359 текущих/804 Native-файла, Git и оба архива
сверены. Новый source не исполнялся. [Приёмка](../evidence/lib-war-music-errors.json).
Всего принято 26 из 28 returned вызовов; девять source faults остаются отдельно.

Приняты [сохранённые bitmap fields War](LIB_WAR_RETAINED_SCRATCH.md): два
returned s10/s11/call-00, 2 638 событий, 150 graphics API requests, 32 numeric
checkpoints и десять новых wrappers. Native получает поля от собственного menu
descriptor/GetDC и сохраняет их через десять prefix calls и пять arena constructors
в каждом случае. Actual music format завершает loader lifetime: поздние source
ABI bytes остаются известными, но не импортируются как Native dimensions. Copy
field сохраняется; следующий metadata consumer после music имеет отдельную границу.
Проверены десять связанных откатов и семь Native guard controls. Raw
17.523с/build281.21с; bundled War7 за 389.629с и shared10 за
477.643с прошли, 17 уникальных bundled методов. Первый кандидат выявил
60 поздних ABI comparison ошибок; он, поправки плана и второй кандидат сохранены.
Expected не менялись, нового исполнения оригинала нет. Все 359 прежних fixtures,
361 текущий/808 Native-файлов, Git и оба архива проверены.
[Приёмка](../evidence/lib-war-retained-scratch.json). Теперь приняты все 28 returned
вызовов в их объявленных границах; девять source faults остаются отдельно.

Приняты [девять Native отказов с полным rollback](LIB_WAR_FAULT_REJECTIONS.md)
по saved s03..s09/call-01,s22/00,s28/00. Каждый тест выполняет97 returned parent
invocations и9 отдельных отказов, сравнивает7844 front events плюс отдельный
allocator0,214 checkpoints (включая32numeric),38music и202graphics events.
Шестнадцать staged Release/free pairs в четырёх last-layer случаях полностью
откатываются вместе с globals/World/Actors/BG/bitmap/music/replay/War/library/events.
Это Native rejections, а не matches исходных memory faults. Для s28 guard стоит
до front calloc; middle-state clear/live установлен code review, не snapshot.
Raw56.029с/build278.35с; bundled War8 за443.553с
и shared10 за474.245с прошли:18 уникальных bundled методов.
Первый кандидат остановился на отсутствующем nested startup report; ошибка,
первый review и поправка callback mapping сохранены. Core/expected не менялись.
Все361 прежних fixtures,370 текущих/818 Native-файлов, Git и оба архива проверены.
Нового исполнения оригинала нет. [Приёмка](../evidence/lib-war-fault-rejections.json).
Все28 returned error-corpus вызовов приняты в своих границах; для девяти source
faults проверены отдельные Native rejection/rollback contracts. Полная игра и
три safety incidents остаются открытыми.

Принята [собственная menu-session в production Core](APPLICATION_MENU_SESSION.md).
OriginalApplicationMenuSession выполняет50 сохранённых цепочек:62 завершённые
итерации и3 явные loading boundaries,18835 событий/869 checkpoints/9000 RNG.
Сравниваются1171 committed platform operation и отдельно3 pending clear, а не
повторное исполнение helper summaries. Canonical full record сохраняет реальные
aliases/masks; registry удерживает live/dead owners, библиотеку/DC и RNG.
Восемь поздних откатов и новые alias/unknown/owner/effect guards прошли вместе
с MenuReturn/MenuInput/MessageLoop/LoadingPrefix:11 release-методов за68.560с,
сборка283.55с. Первый compile setter failure и замечания review сохранены.
370 прежних fixtures неизменны,819 Native-файлов и оба архива сверены. Четыре
старых envelopes опускают финальный LF: payload+LF точно воспроизводит все
276384592 raw bytes/SHA,JSON и16424 blob entries. Эталоны не менялись.
Нового исполнения оригинала нет. [Приёмка](../evidence/application-menu-session.json).
На том этапе bootstrap ещё создавался в Native test composer; следующая
принятая карточка ниже переносит его в Core. Приложение и игра остаются открытыми.

Принят [production bootstrap от WinMain entry до первого меню](APPLICATION_BOOTSTRAP.md).
OriginalApplicationBootstrap сохраняет весь startup owner (panel/calendar/music/
пять WAV) и живую MenuSession. Core выполняет startup, resize,24 front resources,
settings, background/body/menu и timer return. Прежние50 session chains и12
LoadingPrefix cases получают этого собственного родителя.
48 primary attempts содержат один distinct WinMain original-entry и перекрывающиеся
43body/40front/19settings/7bitmap parents:47 menu commits и отдельный NULL-cursor
rejection/rollback. Startup144 операции (7input/20own-memory/117platform) повторён
48раз; early callbacks49 операций считаются отдельно. First-menu22623 committed
операции и464 uncommitted NULL-операции сверены по сохранённому порядку и маскам.
24 bundled release-метода прошли за149.107с, сборка293.60с, включая6 новых startup
и17 first-menu late controls. Candidate1 timer-routing failure и две ошибки
нового read-only projection verifier сохранены. Все370 fixtures неизменны,
822 Native-файла и оба архива сверены; пять дополнительных raw/fixture пар
воспроизводят205795824rawbytes и5443blobentries. Первые четыре пары используют
прежнюю полную проверку после новой сверки pins. Нового исполнения оригинала нет.
[Приёмка](../evidence/application-bootstrap.json). Это проверка declared inputs;
file/package/AppKit/audio, полная загрузка/каталог/игра и три incidents открыты.


Принят [регулярный пакет startup inputs](APPLICATION_STARTUP_INPUTS.md):
46 файлов/29700372 bytes содержат PE initial record50088 с доказанными masks,
adinfo/control, пять WAV и36 исходных DIB. Native владеет неизменяемым снимком,
строит19 settings inputs из явных преобразований control и получает bitmap
metadata из DIB, surface descriptions — из своего CreateSurface request.
Все48 primary attempts,50 MenuInput chains и12 LoadingPrefix cases используют
этого родителя; полные image/surface bindings сравниваются, сохраняются в Session
и откатываются вместе с ним. 28 bundled release-методов прошли за173.944с,
сборка295.28с. Проверены перенос в .app, отсутствие/порча пакета и независимость
снимка от последующего удаления файлов. Native1 path-alias failure, неисполненный
frozen candidate2 и исправленный candidate3 сохранены; expected не менялись.
Все370 fixtures,871 Native-файл и оба архива проверены. [Приёмка](../evidence/application-startup-inputs.json).
Новое исполнение оригинала не требовалось. Это inputs/metadata, ещё не pixels,
host graphics/audio, запуск приложения или полная игра; три incidents открыты.

Приняты [Native colors/masks для36 startup DIB](APPLICATION_DIB_PIXELS.md).
Два независимо закреплённых data decoder совпали по всем40736644 bytes:
30552483 RGB +10184161 masks. Проверены14632 rows и все44980 RLE commands.
10037872 пикселя записаны;146289 остаются неизвестными в cursor/SLOGAN/WORDS.
OriginalDIBPixels хранит top-left RGB8/defined; Bitmap владеет ими до Core attempt,
live image lookup отвергает удалённые handles, чтение unknown color — явная ошибка.
Прежние48/50/12 parent chains сравнивают новые colors/masks actual image owners
с сохранением всех records/events/rollback. 20 bundled release-методов прошли
за135.303с, сборка297.09с;18 controls =3 returns/15 rejections.
ImageIO отдельно совпал для29 ресурсов, разошёлся на567 written pixels в7;
его данные/диагностика сохранены, expected под host не менялись. Два synthetic
host controls не добавляют исходных ресурсов. Все370 прежних fixtures и46
package files неизменны;372 текущих fixtures/875 Native-файлов и оба архива
проверены. [Приёмка](../evidence/application-dib-pixels.json). Нового исполнения
оригинала нет. Unknown colors, surface/raster/device и полная игра остаются открытыми.

Принята [полная инвентаризация bitmap/surface startup](APPLICATION_BITMAP_SURFACE_INVENTORY.md).
Все48 primary/50MenuInput/12LoadingPrefix цепочек связаны с224 stage identities
и354 retained parent entries;41658 исходных событий сохранены целиком.
200 StretchBlt в7 bitmap/40front stages — full-image1:1 SRCCOPY;36 имён ресурсов
содержат28 разных DIB payloads. Отдельно491 downstream Blt также без scaling,
но их flags/clipping/NULL sources и raster contract остаются отдельными.
Все errors, повторное использование DC по поколениям и3 поздних Release
(3input/12loading occurrences) сохранены. Source image deletion не решает
срок хранения скопированных цветов; Release не доказывает уничтожение устройства.
Declared primary8-bit indexed reply не задаёт palettes/конверсию offscreen.
Inventory1 raw-deflate failure, inventory2 DC-reuse assertion и отдельно
закрытый catalog4 publication gap сохранены. Никакого исполнения оригинала
или нового Native теста нет;875Native/372fixtures/46package/90pins неизменны.
[Результат и проверки](../evidence/application-bitmap-surface-inventory.json).

Приняты [собственные source colors для startup surfaces](APPLICATION_SURFACE_COLORS.md).
40 saved bitmap/front lifetimes (индексы0..34,36..40),16929 полных API operations,
995 surfaces/992 copies/3 uncopied owners и993/992 поколения DC совпали с Native.
Surface сохраняет исходные RGB/masks после DeleteObject; unknown не становится
black. MenuSession учитывает3 поздних method8 Release до observer, включая12
loading parents; prefix-aware comparison и whole rollback сохраняются.
23 bundled release-метода за142.844с/build308.06с прошли без корректировок
кандидата/expected; все48 primary routes (47commits/1NULL rejection),50 input
и12 loading chains сохранены.17 supplemental controls дополняют source cases.
372 старых fixtures/46package неизменны;373current/878Native и оба архива
проверены. Две data-only reference ошибки сохранены; оригинал не исполнялся.
[Приёмка](../evidence/application-surface-colors.json). Device conversion,
palette/raster, полная игра и три safety incidents остаются открытыми.

## Непринятая работа и отказ Codex

Сохранённый этап — [обычные ошибки ресурсов War](LIB_WAR_PREPARATION_ERRORS_PLAN.md).
Среда и сохранённые исправления стенда описаны в [FS](LIB_WAR_PREPARATION_ERRORS_FS.md)
и [FS/stack](LIB_WAR_PREPARATION_ERRORS_FS_STACK.md). Они не меняют реальную Windows
среду и не разрешают повторять исходные ошибки или продолжать faulted VM.

После обновления методологии завершена отдельная карточка проверки сохранённых
данных: [результаты и Native gaps](LIB_WAR_PREPARATION_ERRORS.md),
[машинная сводка](../evidence/lib-war-preparation-errors.json).

- Все 29 `war-preparation-fs-errors-s*-capture2.job.json` имеют `terminal`, exit 0.
- Старый audit2 проверял 7 сценариев /11 вызовов; он сохранён неизменным.
  Новый read-only audit3 проверил **29 сценариев /37 вызовов:28 нормальных
  возвратов и9 source faults**, все записи/маски, stores, перечисленные reads,
  checkpoints, события выделения/освобождения и терминальные исходы.
- Дополнительная инвентаризация проверяет состав корпуса, input pins,
  290 сохранённых producer proofs,37 переходов live-owner flags и9 failure
  sidecars. Это чтение готовых данных; новых исполнений оригинала нет.
- В исторической сводке `nativeCompared=false`, `fullPreparationComplete=false`,
  `fullGameComplete=false`. Приёмки трёх NULL-вызовов, шести partial-surface,
  восьми graphics-error, девяти control/music и двух retained-scratch возвратов
  не переписывают источник;
  девять отдельных rejection/rollback contracts приняты новой карточкой выше;
  source faults не считаются успешными matches.
- Проверка процессов по командам War error capture/audit, transform boundaries
  и result recording не нашла соответствующих работающих процессов на момент
  чтения. Перед любым дальнейшим действием нужна новая проверка; это не инвентарь
  всех процессов проекта.

Данные лежат в `build/research/lib-war-preparation/`, symlink в task-owned X5.
Сводка `build/research/application-catalog-work.json → libWarPreparation.errors`
может отставать от terminal job-файлов: в ней ещё говорится о настроенных
оставшихся сценариях. При расхождении сначала сверять происхождение файлов,
времена, команды и результаты, затем выпускать новую наблюдательную сводку.

Ход Codex завершился 2026-09-12 в 00:30:32.397 UTC с `cyber_policy`; ранее были
ещё два отказа. Все три сохранены в [реестре](../evidence/codex-safety-incidents-2026-09-12.json)
с session/turn, точными ошибками, предшествующими публичными действиями и SHA логов.
Точная причина фильтра и невыданный вывод неизвестны. Последняя завершённая
команда сама по себе не считается доказанным триггером.

Новый goal **не возобновляет автоматически затронутое исследование**. Остановка
ответа Codex также не отменяет уже завершённые захваты. Ограниченный Native
[transform-контракт](LIB_TRANSFORMS.md) теперь проверен по сохранённым данным;
это не снимает прежний incident. Полный transform/application и result-recording
пути остаются с собственными границами и отказами; смена модели не закрывает их.

Приняты [графические владельцы startup](APPLICATION_GRAPHICS_OWNERS.md):
Bootstrap/Session связывают команды с собственными display/bitmap/DC generations
и снимками source colors. Все48 primary attempts (47commits/1NULL rejection),
50 input и12 loading chains сравнили53 265 команд из224 stages;5 612 команд
уникальны. Сохранены501 nonnegative text acquisitions,6 negative GetDC и6 failed
ReleaseDC, точные rectangles, ответы API и whole rollback. Loading пока остаётся
композицией принятого production helper в тесте.32 bundled release-метода прошли
за166.551с/build309.09с. Ошибки двух первых кандидатов, три замечания review
и исправление hardcoded loading reply сохранены; expected неизменны.
373 старых fixtures/46package неизменны;374current/881Native и оба архива
проверены. [Приёмка](../evidence/application-graphics-owners.json). Финальные pixels,
реальное устройство, полная игра и три safety incidents остаются открытыми.

Принят [переход от меню к общей загрузке](APPLICATION_LOADING_SESSION.md). Собственный обработчик
принимает PendingLoading, выполняет MENU_WAIT, загрузку общих WAV и presentation.
Он сохраняет полный record 0xc3a8, PCM и маски, порядок операций и графические
команды. Проверены все 12 случаев: девять доходят до PendingCatalog, три явно
отвергают продолжение после ошибки CreateSoundBuffer. Результаты всех 190 WAV
попыток наблюдаются однократно: 187 возвратов и три отказа. Пять поздних ошибок
сохраняют прежнее состояние меню; незавершённая итерация таймера не фиксируется.

Пакет из 19 файлов (353 249 байт) содержит 18 исходных WAV (351 078 байт).
Все 19 release-тестов прошли за 155.354 с, сборка — 316.59 с. Прежние 374 fixtures
и 46 файлов Startup неизменны; проверены 903 Native-файла, новый пакет и оба
архива. Ошибка первой проверки размера sparse relations сохранена; после
фиксации candidate1 код Core и ожидаемые результаты не менялись.
[Приёмка](../evidence/application-loading-session.json). Полный каталог, возврат из загрузки и внешнего цикла,
вывод изображения/звук, матч/игра и прежние incidents остаются открытыми.

## Текущая граница и следующая карточка

[Поддержка всех 669 исходных изображений](APPLICATION_CATALOG_DIB_INPUTS.md)
сохранена как отдельная принятая зависимость. Реализован
[собственный catalog session из PendingCatalog](APPLICATION_CATALOG_SESSION.md).
Три Native-цепочки из собственного bootstrap/menu/common состояния совпадают до
20-го child return: по 194 bitmap, 4 995 malloc, 94 WAV и 51 510 событий.
На всех 60 границах сверены полные records/masks, files, WAV, globals, allocations,
операции и новые graphics/color owners. Parent остаётся с count19/188 known bytes:
двадцатый slot ещё не записан. Native knowledge отделена от source-observed mask.

21 bundled release-метод прошёл за 136.426с/build307.11с, включая прежние полные
каталоги и loading-регрессии. Проверены поздние откаты и запрет allocation overlap
с живыми common PCM. Source/expected неизменны; нового исполнения оригинала нет.
425 pins, 913 Native-файлов, 379 fixtures и оба пакета проверены; ошибки preflight,
transport и первой компиляции сохранены. [Evidence](../evidence/application-catalog-session.json).
Независимые plan/reference/draft review сохранены. Доступный отдельный reviewer
завершил [review4](../evidence/application-catalog-session-final-review.json) точного
f601614 без существенных замечаний: gap финального comparator закрыт.
12 449 appended graphics commands на цепочку сверены независимо. Все3 177 Blt
читают прежние три surfaces;194 новых catalog surfaces проверены по owners/RGB/
masks, а их последующий draw consumer ещё открыт.

[Полный input preflight](APPLICATION_CATALOG_FULL_INPUTS.md) подтвердил156 DAT/
registry-файлов,365 WAV и669 изображений —647 179 902 исходных байта. Все400 WAV
вызовов возвращаются1 без live temporary. Но старый audio adapter в одном CPU
сбрасывает w.regions и переиспользует два PCM mapping:666 сохранённых областей
не означают666 одновременно живых allocations. Полные записи и порядки каталогов
есть; полного clock/message/COM/DC потока собственного приложения в них нет.
[Evidence](../evidence/application-catalog-full-inputs.json):1219 pins/1227 archive
members проверены; все913 Native/379 fixtures и пакеты неизменны, новых запусков нет.

Принят [полный собственный Native catalog → PendingPool](APPLICATION_CATALOG_FULL_NATIVE.md)
в явно объявленном platform environment:137 Objects/17 BG/Stage,155 child returns,
829 bitmap owners,400 WAV и15 683 allocation tuples. Сверены полные Object/101 BG/
60 Stage records/masks, файлы, retained cache backing, новые bindings и цепочка
callbacks → operations → graphics. Исходный stride20/full-path cache воспроизведён
независимо:7412 записанных offsets/4364 retained, включая588 внутри первых8000.
Expected и Core game rules не менялись; все379 fixtures сохранены.

24 bundled release-теста прошли за191.186с/build312.21с; поздний Stage rollback,
before-publication rollback и новая попытка с fresh provider проверены. Independent
review закрыл существенные замечания. Все916 Native-файлов, пакеты и оба архива
проверены. Native1 compile failure, Native2 cache mismatch/явная остановка после
профиля XCTest и неисполненный frozen3 сохранены. [Evidence](../evidence/application-catalog-full-native.json).
Полного original application return или новых Windows/device/raster наблюдений нет.

Принято [соединение собственного каталога с pool/UI](APPLICATION_POOL_INTERFACE.md):
400 Actors/408 constructor returns, две полные фазы пула,10 UI bitmaps/170 API
и11 исходных global stores. PendingInput сохраняет actual World/globals/aliases,
каталог,423 WAV owners и20 command bytes.10 DIB/40102 bytes дают102933 pixels:
96058 known/6875 unknown; все RGB/masks/313 rows проверены независимо.
26 bundled release-тестов прошли за190.426с/build313.61с, включая8 поздних
откатов и19 guards.379 прежних fixtures неизменны,381 текущий/934 Native-файла,
пакеты и архивы сверены по manifests; [evidence](../evidence/application-pool-interface.json).
Native1 pass, неисполненный frozen2 и Native2 compile error сохранены;
финальный candidate3 меняет лишь конфликтовавшее локальное имя теста.

Открыта [карточка собственного loaded return](APPLICATION_LOADED_RETURN_PLAN.md).
Её [промежуточная зависимость](APPLICATION_LOADED_RETURN.md) теперь сохраняет
PendingLoading.loopContinuation: текущие MSG/masks, prepared timer и counter.
Resume выполняет только оставшийся tail после результата dispatcher, без
повторных queue/time-prefix/dispatch.16 release-тестов прошли64.236с/build313.44с:
2025 сохранённых timer cases/8163 events,1215 suspended continuations и три
собственных loading parent. Native-only tail не считается original loaded return.
Неисполненный candidate1 и неуспешный Native1/candidate2 сохранены; candidate3
исправляет только новый тест. Native2 terminal0; [evidence](../evidence/application-loaded-return.json).

Принято [соединение текущих владельцев с input/round](APPLICATION_LOADED_INPUT.md).
OriginalApplicationInputSession продолжает собственный полный catalog/pool/UI
через шесть input checkpoints до menu continuation. World/400 Actor/globals
и masks переводятся из текущих logical tokens в ordinals и обратно; повторные
ссылки, Object0 как живой владелец,800 saved-playback bytes и replay aliases
сохраняются. Actual WinMain.output.music теперь проходит через catalog/pool;
его wide allocation участвует в проверке пересечений. Arithmetic precision
передаётся явно; Native53 не доказывает прежнюю CRT initialization.
26 bundled release-методов прошли288.845с/build318.42с на первом кандидате:
четыре новых метода,13binding guards,7late rollback/retry и22 прежние регрессии.
Оба MENU_STARTUP сохраняют все прежние source comparisons; дополнительная
binding-проверка не является новым whole-original application capture.
938 Native-файлов/457 packaged files/381 прежний fixture и Native archive
сверены. Наблюдатель optional Native profile не прошёл precheck перед terminal
success; точный подпункт неизвестен, sample/сигнал/перезапуск не выполнялись.
[evidence](../evidence/application-loaded-input.json) сохраняет результаты отдельно.

Принято [продолжение загруженного меню и его внешней итерации](APPLICATION_LOADED_MENU.md).
Actual input/menu parent сохраняет WinMain music и создаёт11 bitmap owners,
проходит shared library screen/panel/loading/early return. Исходная Session
завершает именно свой suspended loop, проверяет UUID/revision и counter alias;
чужой, устаревший или повторный результат отклоняется до outer IO.
Два собственных backing варианта сравнивают по15 saved resource checkpoints:
99 bitmap records и11 final records на вариант; полные masks и selected load flag.
Whole operation/graphics journal, все graphics owners и полный final State
сверены;9menu/3outer rollback points, retry, overlaps и lazy clocks проверены.
43 bundled release-метода прошли281.445с/build318.05с на candidate3:
956 Native-файлов,383fixtures/381прежний неизменен,471package files и архив
сверены. [Evidence](../evidence/application-loaded-menu.json). Full original
application match/device/backend publication этим не заявлены.

Принято [повторение загруженного цикла через Bootstrap](APPLICATION_LOADED_CYCLE.md).
Текущие match/music/menu/background owners фиксируются вместе с Session.
Следующий actual World2 step даёт новый ticket и повторяет prologue/input;
ранний screen prefix в этой ветви не исполняется. Два own backing варианта
дают phase0/1/0/1: neutral, keydown, held-confirmation и keyup. Первые три
новых цикла на вариант возвращаются целиком; четвёртый сохраняет текущий
Actor attack и доходит до явной границы selected character body. Cached меню
не создаёт resources/bitmap API/music заново. Все appended graphics, Release/
free/clear, full final State/operations и late rollback проверены.
51 bundled release-метод прошёл310.184с/build324.17с на candidate3;
958 Native-файлов, все383прежних fixtures и471package files сверены.
Candidate1 остановился на Int/Int32 compile error нового теста; candidate2
обнаружил ошибку нового parent adapter при разборе windowDefault replies.
Оба failures и review gaps сохранены; Core/expected не менялись после candidate1.
Candidate3 исправляет только тестовый адаптер и добавляет3старые WindowInput
регрессии к прежним48. [Evidence](../evidence/application-loaded-cycle.json).

Проверен [собственный character-menu join](APPLICATION_LOADED_CHARACTER.md):
четвёртый input child с retained attack проходит общий human handler, затем
собственные WndProc/input/Bootstrap cycles доводят Naruto17/Sasuke21 до
status3/3, team0/0, selection0, countdown147. Две цепочки по34 экрана дают
68 возвратов/66 дальнейших loading entries и816 body checkpoints. Полные
write footprints/records/masks, live portraits, library text/current sound,
current graphics owners, enclosing return и late rollback проверены.
Native2 прошёл57 release-методов за365.385с/build319.31с. Все960 Native-файлов,
383прежних fixtures,471package files и архивы сверены.
Native1/56passed сохраняет34ошибки нового общего ожидания Flip вместо
control/displayMode3/Blt. Исправлен только новый тест; обе source return
проекции независимо проверены по display mode и полному rectangle.
Core/expected не менялись; ошибки review/data-reader и первый кандидат сохранены.
[Evidence](../evidence/application-loaded-character.json). Оба Native jobs
терминальны; job/manifest находятся в
`build/research/application-loaded-character-native-20260913/`. Не перезапускать.

Проверено [продолжение selection/Start](APPLICATION_LOADED_SELECTION.md) после
`1747cdd`: две собственные50-кадровые цепочки дают98 новых Bootstrap returns,
два retained pending Start и1536 body checkpoints. Сохраняются текущие
владельцы, настройки, библиотечный DC, музыка и незавершённый ticket.
Таблица RNG actual Bootstrap отличается от pristine reference: независимая
проверка формулы/candidates/order проецирует собственные selected/music fields,
не подменяя исходный эталон или собственное состояние.

Native1 terminal1:63 из65 методов прошли, два новых остановились на frame21
из-за ожидания human45560c вместо confirmation455610. Сохранённые call sites
и review4 доказали ошибку компаратора и прежней рецензии. Core/expected
не менялись; review5 проверил два исправленных компаратора. Native2 остановлен по профилю затратной диагностики; сохранён один
сбой старого ожидания loopcounter61 вместо0. Bool-проверки присутствия и
правильное ожидание сброса исправлены только в тестах; review7 проверен.
Native3 прошёл
все65 release-методов за564.928с/build325.72с. Все962 Native-файла,383
неизменных fixtures,471package files и архивы сверены. Ошибки, все три кандидата
и прежний draft сохранены. [Evidence](../evidence/application-loaded-selection.json).
Все три Native jobs терминальны; manifests/reviews находятся в
`build/research/application-loaded-selection-native-20260913/`. Не перезапускать.

Проверено [продолжение собственного Start](APPLICATION_LOADED_LAUNCH.md): две
retained цепочки проходят prelude, installed-library подготовку District,
stage5 music, запись повтора, настоящий Bootstrap return и следующий gameplay
input до41e339. На цепочку:15 surfaces/225 bitmap API,382 Actor constructors,
четыре собственных RNG draws и234 слова всех18 replay participants. Полные
records/masks, journal/graphics/current owners, replay aliases и late rollback
проверены; controlled live replacement/DC остаётся отдельной проверкой.
Все93 release-метода прошли за732.971с/build0.37с;
980 Native-файлов,383 прежних fixtures и485 package files сверены.
[Evidence](../evidence/application-loaded-launch.json). Ошибки и кандидаты
сохранены в `build/research/application-loaded-launch-native-20260913/`;
терминальные исходные захваты не перезапускать.

Сохранена [промежуточная интеграция gameplay](APPLICATION_LOADED_GAMEPLAY.md)
после41e339: библиотечные control/contact/hit/transform/text handlers, текущие
bitmap/surface owners и возврат по тому же Bootstrap ticket. Две собственные
цепочки по17 neutral calls прошли34 возврата и646 контрольных точек. Два новых
release-теста прошли за39.496с/build334.31с;132 регрессионных метода —
за1066.816с/build0.36с, включая все93 проверки предыдущего Start.
Ошибки первых трёх кандидатов сохранены; независимая проверка подтверждает
поправку ожидания девяти animation counters District по всем202 исходным
BG records/masks. Core и прежние expected при этой поправке не менялись.
[Evidence](../evidence/application-loaded-gameplay.json),
[план](APPLICATION_LOADED_GAMEPLAY_PLAN.md).

**Эта интеграция ещё не принята по полному differential-сравнению.** Принятый
frontier остаётся на собственном Start/следующем input. Следующая задача —
закончить независимую проекцию всех19 стадий, records/masks/stores и graphics/audio
на собственные позиции/RNG/installed hooks. Новый Z-порядок Actor
нельзя заменить переносом координат старого event stream. Native-only preflight
и старые helper-регрессии не закрывают эти проверки. Все пять Native jobs этой
карточки терминальны; кандидаты/логи находятся в
`build/research/application-loaded-gameplay-native-20260913/`. Не перезапускать.
Полный матч, другие modes/CPU/playback, backend, окно/ввод/звук, Windows/cleanMac,
полная игра и прежние safety/source-fault зависимости остаются открытыми.

Отдельно проверены [gameplay providers](APPLICATION_LOADED_GAMEPLAY_PROVIDERS.md):
все829 catalog/15 arena bindings, семь class-wide owner rejections, music resume,
file/codec callbacks, шесть returned-IO вариантов и поздний rollback с повторным
успехом того же session/ticket. Три release-метода прошли за46.702с/build337.52с;
четыре writer/recording регрессии — за53.406с/build0.36с. Прежние134 успешных
метода сохранены через полное равенство982 исходных файлов; заново не запускались.
Core/старые tests/383 fixtures/102 resources неизменны. Ошибки двух кандидатов
и пропуски review сохранены; все четыре новых Native jobs терминальны.
[Evidence](../evidence/application-loaded-gameplay-providers.json).
Независимый saved-data review описывает idempotent stores и точное округление
проекции, но не заменяет готовый comparator. NEXT — закончить все19 стадий и
16 последующих вызовов по [плану](APPLICATION_LOADED_GAMEPLAY_COMPARISON_PLAN.md).
Новые artifacts: `build/research/application-loaded-gameplay-comparison-native-20260913/`;
старую папку gameplay и завершённые захваты не изменять/не перезапускать.

Проверен [reader сохранённых gameplay-данных](APPLICATION_GAMEPLAY_SOURCE_READER.md):
32 основных корпуса и два initialized bridges, по17 вызовов/323 стадии на вариант.
Два release-теста прошли за10.956с/build339.52с. Проверены полные
pool bytes/masks, связи снимков ввода, все distinct blob SHA и576 ordered global
stores на вариант. Все983 прежних Native-файла неизменны; ошибки import/parent
и различие FPCW0/023f сохранены. Это проверка reader, не совпадение собственного
gameplay. Полный19-stage comparator остаётся следующим шагом по прежнему плану.
[Evidence](../evidence/application-gameplay-source-reader.json); все три Native jobs
в `build/research/application-loaded-gameplay-projection-native-20260913/` терминальны.

Проверен [ограниченный scalar comparator gameplay](APPLICATION_GAMEPLAY_SCALAR_PROJECTION.md):
обе собственные цепочки по17 Bootstrap returns и323 source-first стадиям.
Сравниваются полные World/400 Actors/globals/101 BG bytes/masks, собственные
Frame-буферы, bitmap owners, CRT/replay и aliases. Четыре release-метода прошли
за61.951с/build343.98с; восемь отрицательных comparator guards.
983 прежних Native-файла неизменны;141 прежний метод не перезапускался.
Первый ошибочный recording guard и замечания review сохранены. Input/output
используют saved ordered store footprint с независимым расчётом значений.
Полная graphics/audio/caller-journal проверка и acceptance gameplay остаются
открытыми по прежнему плану. [Evidence](../evidence/application-gameplay-scalar-projection.json). Нового исполнения оригинала нет.
Все jobs этой проверки терминальны в
`build/research/application-owned-gameplay-comparison-native-20260913/`.

Принято [полное сравнение нейтрального gameplay](APPLICATION_GAMEPLAY_EFFECTS.md):
два собственных прохода по17 Bootstrap returns,646 стадий в сумме. Независимый
расчёт сначала воспроизводит сохранённые source-события, затем проверяет собственные
координаты/bitmap reads/masks/clipping/HUD/text/audio, весь журнал и владельцев
графики/цветов/памяти.14 поздних body-отказов и12 внешних откатов сохраняют
предыдущие commits. Четыре release-метода прошли за71.192с/build381.09с;
141 прежний метод сохранён по неизменным pins.985 прежних Native-файлов,
383 fixtures/102 resources и485 package-файлов неизменны; все989 Native-файлов
и оба архива проверены. Первая прерванная сборка, ошибочный запрет bitmap alias
и исправления review сохранены. Нового исполнения оригинала и изменения Core нет.
[Evidence](../evidence/application-gameplay-effects.json). Задача19×17×2 закрыта только
для нейтральной последовательности; это не полный матч или готовая игра.
Следующий шаг — собственный ввод и уже сохранённые active/paused gameplay ветви,
с независимым сравнением состояния/эффектов и откатами. Device raster/audio,
Windows/clean-Mac, другие режимы, сеть и полная цель остаются открытыми.
Все jobs этой проверки завершены или явно отмечены interrupted/no-exit в
`build/research/application-owned-gameplay-effects-native-20260913/`.

Проверено [собственное active48 input-продолжение](APPLICATION_ACTIVE_GAMEPLAY_INPUT.md)
после17 принятых neutral returns: оба48-call schedules проходят настоящий
Bootstrap/WndProc, включая retained text editor и joystick profiles неактивных
мест.576 полных source input endpoints и96 prologues воспроизведены независимо;
проверены собственные input state/masks, replay allocation, события и журнал.
96 собственных body returns/1824 стадии,18 input/6 late-body/18 outer rollback
и6 same-ticket retries прошли как Native preflight. **Полное active body
differential-сравнение ещё не принято; per-instruction input stores также открыты.**
Четыре release-метода прошли за114.261с/build380.85с;143 прежних
метода сохранены по pins,988 прежних Native-файлов и485 package files неизменны.
Все991 Native-файл и оба архива проверены. Четыре ошибки компаратора/сборки и
пропуски review сохранены; Core/source expected не менялись. Нового исполнения
оригинала нет. [Evidence](../evidence/application-active-gameplay-input.json),
[план](APPLICATION_ACTIVE_GAMEPLAY_PLAN.md). Все пять Native jobs терминальны в
`build/research/application-owned-active-gameplay-native-20260913/`; не перезапускать.
На этом входе все19 active body стадий оставались открытыми;
следующее принятое конечное сравнение управления описано ниже.

Принято [сравнение конечной active control стадии](APPLICATION_ACTIVE_BODY_CONTROL.md):
960 source Actor checkpoints/96 полных control endpoints воспроизведены до
сравнения96 собственных checkpoints, шести RNG-событий и всех retained owners/
caller journal.12 отрицательных проб проверяют границы компаратора. Четыре
release-метода прошли за138.078с/build382.17с;145 прежних методов
сохранены по pins,990 старых Native-файлов и485 package files неизменны.
Все994 Native-файла и оба архива проверены. Core/source expected не менялись;
оригинал не исполнялся. [Evidence](../evidence/application-active-body-control.json),
[план](APPLICATION_ACTIVE_BODY_PLAN.md). Оба Native jobs терминальны в
`build/research/application-owned-active-body-native-20260914/`; не перезапускать.
На этом входе остальные18 стадий оставались открытыми. Следующее
принятое конечное сравнение физики описано ниже; полный body не принят.

Принято [сравнение active physics](APPLICATION_ACTIVE_PHYSICS.md) из текущего
собственного control snapshot:192 source Actor checkpoints/96 полных endpoints
воспроизведены до96 собственных physics snapshots с полными владельцами и
журналом. Восемь отрицательных проб сохраняют границы компаратора. Четыре
release-метода прошли за148.355с/build356.77с;147 прежних методов
сохранены по pins,993 старых Native-файла и485 package files неизменны.
Все997 Native-файлов и оба архива проверены. Core/source expected не менялись,
оригинал не исполнялся. [Evidence](../evidence/application-active-physics.json),
[план](APPLICATION_ACTIVE_PHYSICS_PLAN.md). Native job1 терминален в
`build/research/application-owned-active-physics-native-20260914/`; не перезапускать.
На этом входе остальные17 стадий оставались открытыми. Принятое конечное
сравнение следующих семи стадий описано ниже; полный body ещё не принят.

Принято [сравнение active contacts](APPLICATION_ACTIVE_CONTACTS.md):672 source и672
собственных endpoints семи последовательных depth/contact/hit/cpoint стадий
после текущей физики,96 собственных item RNG, полные records/masks/владельцы и
журнал.12 отрицательных и2 положительных comparator controls. Четыре release-метода
прошли за171.106с/build352.34с;149 прежних методов сохранены по pins.
1000 Native-файлов и оба архива проверены;996 прежних файлов и485 package files
неизменны. Independent review обнаружил неверное смещение ITR.effect в первом
компараторе; ошибка/кандидат/лог сохранены, чтение+2c проверено различающими
контролями. Core/source expected не менялись, оригинал не исполнялся.
[Evidence](../evidence/application-active-contacts.json),
[план](APPLICATION_ACTIVE_CONTACTS_PLAN.md). Оба Native jobs терминальны в
`build/research/application-owned-active-contacts-native-20260914/`; не перезапускать.
После контактов оставались открытыми десять body стадий. Принятое сравнение
следующих трёх описано ниже; полный active tick ещё не принят.

Принято [сравнение active camera/drawing/impulses](APPLICATION_ACTIVE_GRAPHICS.md):288 source и288
собственных endpoints на текущих позициях, кадрах и ресурсах после контактов.
Сравнены10560 событий и1728 чтений bitmap с undefined masks на каждой стороне,
220 source camera stores,3600 helper returns, полные владельцы и журнал.
20 отрицательных и4 положительных comparator controls прошли. Четыре release-
метода прошли за198.941с/build359.54с;145 прежних методов сохранены по pins,
изменённые input/control/physics helpers проверены внутри выбранных цепочек.
1003 Native-файла и оба архива сверены;996 прежних файлов и485 package files
неизменны. Prefix фактических graphics commands сравнивается на каждой стадии;
для поздних стадий проверена только связь их событий с командами и владельцами.
Core/expected не менялись, оригинал не исполнялся. Сохранены отклонённый до
запуска candidate1, ошибка читателя candidate2 и поправка разбора журнала.
[Evidence](../evidence/application-active-graphics.json), [план](APPLICATION_ACTIVE_GRAPHICS_PLAN.md). Оба Native jobs терминальны в
`build/research/application-owned-active-graphics-native-20260914/`; не перезапускать.
На этом входе семь следующих стадий оставались открытыми. Принятое
[сравнение active lifecycle](APPLICATION_ACTIVE_LIFECYCLE.md) продолжает
текущий собственный impulse output:96 source и96 own endpoints,216 helper
returns,14 sounds и2 transient lifetime на каждой стороне. Сравнены полные
records/masks, текущие владельцы, ordered effects и journal;8 поздних откатов
и2 повтора в той же сессии прошли. [Provenance Actor50](APPLICATION_ACTIVE_LIFECYCLE_PROVENANCE.md)
остаётся отдельным prerequisite сохранения inactive storage доcall48.
Четыре release-метода прошли за220.779с/build356.75с;147 прежних методов
сохранены по pins и не перезапускались. Все1006 Native-файлов и архивы сверены;
1002 старых файла и485 package files неизменны. Core/expected не менялись,
оригинал не исполнялся. Candidate1 отклонён до запуска: пропуски helper results
и дополнительных gameplay families исправлены в candidate2. Ошибки инструментов
публикации также сохранены; успешный Native job2 терминален, не перезапускать.
[Evidence](../evidence/application-active-lifecycle.json), [план](APPLICATION_ACTIVE_LIFECYCLE_PLAN.md).
После lifecycle шесть стадий оставались открытыми. Принято
[сравнение active commands/recovery](APPLICATION_ACTIVE_COMMANDS.md):96 source
и96 собственных endpoints из текущего lifecycle output, полные records/masks,
владельцы, отсутствие primitive effects и journal. Сохранённый source имеет
равные снимки до/после, но компаратор явно вычисляет пять cleanup stores на
каждый active Actor и проверяет write-only masks, соседние байты и inactive
storage. Собственная неизменность не предполагается. Source SP34 не используется;
новое Native ABI/FPU/per-instruction-store совпадение не заявлено.
Восемь release-методов прошли за240.707с/build361.23с, включая3898 сохранённых
контролируемых command cases и прежние rollback tests.145 остальных методов
сохранены по pins. Все1009 Native-файлов и архивы сверены;1005 старых файлов
и485 package files неизменны. Core/expected не менялись, оригинал не исполнялся.
Reader FPSW/export ошибки и уточнение scope отчёта сохранены. Native job1
терминален в `build/research/application-owned-active-commands-native-20260914/`;
не перезапускать. [Evidence](../evidence/application-active-commands.json),
[план](APPLICATION_ACTIVE_COMMANDS_PLAN.md).
После commands пять стадий оставались открытыми. Принято
[сравнение active HUD](APPLICATION_ACTIVE_HUD.md):96 source и96 собственных
endpoints из текущего commands output, полные records/masks, ordered bitmap/
read/clip/rectangle/Blt events, владельцы и journal. Source primary5952events/
960unknown reads, control8640/2496; обе собственные последовательности5952/960
вычислены отдельно из собственных текущих записей. Сравнены192 source command
stores; stack argument не импортируется какtarget. Шесть новых поздних откатов
и два повтора в той же сессии прошли.
Восемь release-методов прошли за270.723с/build354.74с, включая1753 controlled
active HUD и1789 paused cases;151 остальных методов сохранены по pins.
Все1012 Native-файлов и485 package files сверены,1008 старых файлов неизменны.
Core/expected не менялись, оригинал не исполнялся. Candidate1 отклонён до запуска
из-за пропущенного HUD event-scope guard; candidate2 завершился с двумя XCTest
ошибками отрицательного Object-token control. Исправлен только порядок throwing
read передXCTUnwrap; оба прежних кандидата и ошибки сохранены. Native job3
терминален в `build/research/application-owned-active-hud-native-20260914/`;
не перезапускать. [Evidence](../evidence/application-active-hud.json),
[план](APPLICATION_ACTIVE_HUD_PLAN.md).
После HUD четыре стадии оставались открытыми. Принято
[сравнение active notices](APPLICATION_ACTIVE_NOTICES.md):96 source и96 собственных
endpoints из текущего HUD output. Текущие ветвления независимо подтверждают
отсутствие вывода; полные records/masks, владельцы, graphics и journal сохранены.
Source не обращается к наблюдаемой caller-stack области. Menu-local snapshot
не является gameplay formatter: его checkpoint/lifetime остаётся отдельным
ограничением, nil/opaque340 проверены дополнительными public-handler controls.
Четыре поздних отката и два same-session retries прошли.
Семь release-методов прошли за269.509с/build363.95с, включая819
прямых notices comparisons,8 явных sNaN расхождений с QNaN companions,4 отдельных
cookie-overwrite rejections и74424 numeric controls.157 других методов сохранены
по pins;164 unique total. Все1015 Native-файлов и485 package files сверены;
все1012 старых файла неизменны. Core/expected не менялись, оригинал не исполнялся.
Ошибка HUD-prefix в draft verifier и замечания к publication gates выявлены
review до исполнения; прежние варианты и причины исправлений сохранены.
После успешного Native job первый log reader не распознал служебное `1 test`
внутри buffered JSON; точное исправление проверено отдельно, raw/error сохранены.
Native job1 терминален в `build/research/application-owned-active-notices-native-20260914/`;
не перезапускать. [Evidence](../evidence/application-active-notices.json),
[план](APPLICATION_ACTIVE_NOTICES_PLAN.md).
После notices три стадии оставались открытыми. Принято
[сравнение active recording](APPLICATION_ACTIVE_RECORDING.md):96 source и96
собственных endpoints из текущего notices output. Счётчик450bbc вычислен по
текущему signed450bdc и wrap32; все остальные records/masks, replay/memory/
graphics owners и journal сохранены. Сравнены96 исходных stores421ce6; ранний
снимок globals является alias того же record. IO и watched stack accesses нет.
Публичный control проверяет continuation422944 с nil stageDefeated и неизвестными
неиспользуемыми flags. Сам checkpoint continuation не содержит; Body передаёт
фактический result.continuation в layout. Четыре новых late rollback и два
same-session retries прошли; полный layout/output ещё не принят.
Пять release-методов прошли за283.095с/build361.77с, включая95
контролируемых result callers/82writers/12restores,13no-writer gates,76codec successes,
5allocation(-4)/1no-temporary(-2),18322writes/33219692bytes и прежние rollback.
161 другой метод сохранён по pins;166 unique total. Все1018 Native-файлов и485
package files сверены; все1015 старых файлов неизменны. Core/expected не менялись,
оригинал не исполнялся. Native job1 терминален в
`build/research/application-owned-active-recording-native-20260914/`; не перезапускать.
[Evidence](../evidence/application-active-recording.json), [план](APPLICATION_ACTIVE_RECORDING_PLAN.md).
После recording две стадии оставались открытыми. Принято
[сравнение active layout](APPLICATION_ACTIVE_LAYOUT.md):96 source и96 собственных
endpoints от recording до422994. Indicator450b84=0 пропускает вложенный playback,
хотя исходный44d030=1. Полные records/masks, владельцы, journal и отсутствие
events/stores/watched stack accesses сравнены. Прямой public recorder→layout
control передаёт фактический continuation; checkpoint его не раскрывает.
Nil и opaque372 formatter сохранены отдельно от menu-local; неизвестные
неиспользуемые flags/backing не заполняются. Четыре поздних rollback и два
same-session retries прошли; полный output ещё не принят.
Пять release-методов прошли за280.916с/build362.24с, включая599
controlled layout matches и1 отдельный source-fault rejection,386781events/
25661Blts и4 прежних rollback.163 других метода сохранены по pins;168 unique total.
Все1021 Native-файл и485 package files сверены;1018 старых файлов неизменны.
Core/expected не менялись, оригинал не исполнялся. Native job1 терминален в
`build/research/application-owned-active-layout-native-20260914/`; не перезапускать.
[Evidence](../evidence/application-active-layout.json), [план](APPLICATION_ACTIVE_LAYOUT_PLAN.md).
Принято [сравнение active output/return](APPLICATION_ACTIVE_OUTPUT.md):96 source
и96 own endpoints из текущего layout, по75650 событий,1166 source stores,
14plays и15950 source helper returns. Сравнены полные records/masks, владельцы,
ordered graphics/audio journal и конечный PendingReturn. Восемь новых поздних
rollback и четыре same-session retries прошли. Все19 конечных stage contracts
составлены в фактическом порядке с полным графическим журналом до возврата.
Это конечная композиция для текущих входов; full original application equivalence
не заявлена: pristine-source и own installed-library среды различаются, middle
Object/Frame snapshots и другие явно перечисленные зависимости остаются открытыми.
Семь release-методов прошли за285.671с/build365.32с;
165 других сохранены по pins,172 unique. Проверены1024 Native и485 package files,
1021 прежний Native-файл неизменен. Core/expected не менялись, оригинал не исполнялся.
Native job1 терминален в `build/research/application-owned-active-output-native-20260914/`;
не перезапускать. [Evidence](../evidence/application-active-output.json),
[план](APPLICATION_ACTIVE_OUTPUT_PLAN.md).
[Карта оставшихся условий application equivalence](APPLICATION_EQUIVALENCE_FRONTIER.md)
проверена по текущему коду и saved evidence. Новый reader сверил28 pause calls,
их cached phase/latches, удержание counters/notice timer, пять rendering checkpoints
и оба возврата;1024 Native-файла неизменны. Это анализ, не новая Native-приёмка.
Полный installed source application run и middle Object/Frame evidence отсутствуют.
Принято [сравнение application pause/step/resume](APPLICATION_PAUSED_GAMEPLAY.md)
по двум сохранённым14-call schedules после собственного нейтрального родителя.
Текущий PendingContinuation проходит paused body и output с сохранением installed
text/DC, владельцев, HUD flags, таймера notice1 и исходного Bootstrap ticket;
input/round повторно не выполняется. Сравнены324 source и324 own endpoints,
28576 own events и28 возвратов;16 paused calls,12 явно заданных WndProc messages,
36 late rollback и8 same-session retries. Все19 active stages сохранены на
неприостановленных вызовах. Это конечная композиция при объявленных входах;
полная original application equivalence не установлена.
Девять release-методов прошли за299.767с/build382.75с;
167 других сохранены по pins,176 unique. Проверены1028 Native и485 package files;
1020 старых файлов,383 fixtures и102 resources неизменны. Четыре Native-файла
изменены и четыре добавлены. Candidate1 не исполнялся; замечания и исправления
сохранены. Candidate2 прошёл сравнение, упаковку и независимые review.
Native job2 терминален в `build/research/application-owned-paused-gameplay-native-20260914/`;
не перезапускать. [Evidence](../evidence/application-paused-gameplay.json),
[план](APPLICATION_PAUSED_GAMEPLAY_PLAN.md). Оригинал не исполнялся.
NEXT — read-only карточка готовности command/damage continuation к первому
Naruto/Sasuke District match: сопоставить существующие actor-input/combat/active
доказательства с текущими владельцами application, выбрать целый caller с готовыми
зависимостями и закрепить конечный план. Недостающие зависимости перечислить;
не подменять целый бой isolated helpers и не повторять terminal/refused операции.
Полный original active tick/матч/игра ещё не приняты.
Полные helper ABI/FPU/stores, active command/refill/healing/state1700 и другие
ветви вне конечного пути, матч/игра, app/device/Windows/clean-Mac и прежние safety
incidents остаются открытыми. EXE envelope не пересчитан.



Историческое ограничение предыдущего входа (countdown теперь пройден):
Countdown147 и selection0 должны пройти собственный input/handler; не ставить
selection1/countdown0 из expected. Далее preparation/gameplay. Current memory остаётся
источником live bitmap fields; constructor history и startup/earlyScreen нельзя
публиковать заново. Other modes/playback/uncached music/panel IO/recovery/device
остаются отдельными зависимостями. Whole-original application match, backend,
полный матч и полная игра остаются открытыми. Не подставлять expected after-state
и не перезапускать completed captures, включая terminal candidate5 после28 Objects.

Actual raster всё ещё не имеет достаточных format/palette/device inputs в
проверенных зависимостях. Эта граница открыта; исходные RGB не становятся
измеренными Windows pixels. Catalog/loading выбраны как независимая ветвь.

Source-color owners и привязка команд приняты в
[APPLICATION_SURFACE_COLORS](APPLICATION_SURFACE_COLORS.md) и
[APPLICATION_GRAPHICS_OWNERS](APPLICATION_GRAPHICS_OWNERS.md).
Повторять полный inventory,40 lifetime assignments или завершённые тесты для
нового оформления не нужно. Повторять command binding тоже не нужно.
Сохранённые 491 downstream Blt, графические события,
полные request flags и источники находятся в принятом inventory/event-catalog.
Перед будущей реализацией raster consumer определить доказанные входы его формата,
палитры, color key, clipping, текста и назначения; неизвестные зависимости
перечислить до реализации. Primary reply объявляет8-bit indexed, но actual
offscreen conversion/палитра/инициализация устройства пока не установлены.

Нельзя объявить source RGB финальными Windows pixels или незаметно заменить
неизвестный цвет чёрным/alpha0. Все146289 DIB holes и18 downstream NULL-source
occurrences сохраняют границы. Новую карточку ограничить готовыми доказательствами,
целым вызывающим путём и late rollback; expected закрепить независимо от Core.
Исторические producers/captures/auditors не перезапускать. AppKit input/clock/audio,
full loading/catalog, War/матч/полная игра/Windows/cleanMac и три safety incidents
остаются открытыми.

## Дальнейшая сквозная очередь

Незакрытые error contracts сохраняются как зависимость; далее по готовности —
43a860 War gameplay, собственные каталог/инициализация/внешний цикл и подключение
общего движка к приложению. Независимые ветви допустимы по карте. Первый полный
матч, остальное содержимое, сеть, Windows, окно/ввод/звук и чистая macOS открыты.

## Сохранность и навигация

Исходные 4 954 строки AGENTS сохранены побайтно в
[AGENTS_HISTORY_2026-09-12.md](../../AGENTS_HISTORY_2026-09-12.md), SHA-256
`1f124556e757a1f1efe7dabbc19df76bc482ca9a316df2295eb86beeae1f5dff`.
Файл находится в корне, поэтому его старые относительные ссылки работают.
Ограничения соответствующего исследования обязательны; история не является
новой командой выполнения. Архив не редактировать.

Перед обновлением методологии dirty-файлы закреплены в
`build/research/methodology-update-20260912-before.json`. В продолжении War все31
сохранены побайтно; девять относящихся к исследованию планов/инструментов включены
в исследовательский коммит. Остальные 22 pending-файла завершены отдельной
Native-карточкой выше: их исходные версии сохранены в
`build/research/pending-completion-20260912/initial-pending/`, старые 325 fixtures
неизменны. Из исходных pending изменён только расширенный transform test;
добавлены постоянные проверки, восемь fixtures, упаковщики и итоговые документы.
Исторический work JSON не переписывался. Новые принятые NULL/partial-surface/
graphics/music-error/retained-scratch/fault-rejection и menu-session/bootstrap контракты описаны выше.
