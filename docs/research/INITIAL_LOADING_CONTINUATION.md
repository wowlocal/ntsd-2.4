# Native continuation from completed catalog to pool and interface

The continuation now consumes the native common-loading prefix, completed
catalog and registered-sound owners, the existing World, and current globals.
It constructs the Actor pool and interface, retaining the prefix's pause value
and both10-byte command buffers in `OriginalInitialLoading`. It never restores
the old prefix globals or catalog sound-cache bytes over the supplied current
state. The purpose and finite acceptance are in
[the plan](INITIAL_LOADING_CONTINUATION_PLAN.md).

## Reference and scope

No new original execution or expected data was created. The reference is the
pinned NTSD2.4 EXE/VC80 and original resources, through the two unchanged
[full initial-loading corpora](INITIAL_LOADING.md) and ten unchanged
[whole pool/UI corpora](INITIAL_INTERFACE_SURFACE.md). Those original
instructions ran in their declared controlled Unicorn environments.

The older full loading chains retain their frozen progress clock and supplied
43ed10 device-result boundary. The ten pool/UI chains separately execute whole
43ee50/43ed10/4013d0 at declared Win32/COM responses. Composing the native APIs
does not turn either corpus into the pending installed-library application
chain, actual Windows execution, or a real device measurement.

## Native ownership and operation order

[OriginalInitialLoadingContinuation](../../native/Sources/NTSDCore/OriginalInitialLoadingContinuation.swift)
accepts existing native outputs. Its public completion delegates to
`OriginalInitialPoolAndInterface` and the recovered full surface helpers.
Allocator, constructor and device bookkeeping are staged in the caller's
value-semantic context. A final observer can fail after every pool/UI operation
without publishing the candidate result or changing that context.

The historical `OriginalInitialLoading.load` now constructs this same
continuation after its existing catalog/cache comparison boundary. Its supplied
interface-device route uses the same pool implementation and preserves that
older corpus's explicit helper boundary. The historical cache stores before
this boundary remain part of that loader's existing contract; the new public
continuation itself performs no cache synchronization.

The first Object+90 is read from the owned native catalog at each of its eight
consumers. Reading it before pool construction would change dependency order.
The retained source records show each read after the matching staging Actor
constructor returns and after exactly one subsequent store, Actor+368. The
test checks all80 reads against their read/write/helper indices, addresses,
four original bytes and known masks. It also checks that the native observer
has reached constructor401 through408 when the respective provider executes.
Expected Actor records remain comparison operands, never inputs to constructors.

## Comparison and rollback

Both historical full loading cases compare their original phase/pause behavior,
all native catalog/audio outputs,400+8 Actor constructors, ten interface
constructors and complete globals/events through41c581. Each retains137 Objects,
15388 Frames,400 registered WAVs and18 common WAVs. The two cases preserve the
established362,760,002 compared bytes plus their masks across loading, catalog
and audio. Their source execution boundary remains unchanged.

The ten retained pool/UI cases still compare4080 raw constructor records plus
4095 final records:9,233,920 bytes and masks. The additional80 late-read checks
do not increase source instruction or branch coverage. They recover the exact
dependency order needed by this continuation.

The native-only ownership control receives the catalog and common prefix just
constructed by the first full comparison. It changes one declared test word in
current globals within the old cache span, then completes the public full-helper
route. Its platform returns missing UI images, allowing all ten constructor
failure paths to finish; this is a native control, not another source full-loading
match or a renderer for the application. It verifies retained resources, pause,
commands and that the current global word survives. A second completion throws
at the final observer and preserves the earlier completed context and result.

The pool/UI rollback controls also now throw on the eighth Object+90 provider
read. Together with the seven retained controls, these eight checks preserve
the context or previously constructed pool. Native exceptions are not claimed
as successful matches to original faults. No NULL-Actor source path, private
stack contents, Windows heap behavior or unknown storage is introduced.

## Verification and remaining work

Release comparison and input-preservation results are recorded in
[initial-loading-continuation.json](../evidence/initial-loading-continuation.json).
The independent package exports acceptedb16b981 plus seven owned code/test
files. It excludes the pending catalog implementation and six unrelated working
files. All629 archived native input files have been independently hash-checked;
622 base files remain unchanged. No fixture was added or edited.

All14 release tests passed in20.873s, build224.56s: both full loading cases
took13.474s and the three pool/UI tests5.421s. The retained eight bootstrap
layouts and thirteen historical UI cases also passed. All247 fixture pins are
unchanged. The native test process is terminal0. NTSDNative linked; no application
window, device or Windows run was performed for this code composition.

```sh
swift test --package-path native -c release --filter 'OriginalInitialLoadingTests|OriginalInitialPoolAndInterfaceTests|OriginalBootstrapTests|OriginalInitialInterfaceTests|OriginalInitialInterfaceSurfaceTests'
```

The three own catalog captures and the frozen40-checkpoint package continue
independently. This continuation is ready to consume their actual native
completed resources; it does not supply a missing catalog return. Full own
catalog/pool/UI,41bc90 return, window/input/render/sound, Windows/devices,
full match, all original content and clean-Mac acceptance remain open.
