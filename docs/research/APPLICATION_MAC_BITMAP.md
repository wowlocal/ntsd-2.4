# Native bitmap resources on the startup display

2026-09-26. The new provider passes all48 selected methods on the actual2265-file
candidate. It connects the recovered whole bitmap constructor/loader/copy to the
same Native display registry as whole WinMain. Whole front-screen Host integration
and independent review remain open. NTSDApp still runs Practice, not this path.

[Plan](APPLICATION_MAC_BITMAP_PLAN.md),
[monitor recovery](APPLICATION_MAC_BITMAP_MONITOR_RECOVERY.md),
[publication](../evidence/application-mac-bitmap.json),
[closure](../evidence/application-mac-bitmap-close.json) and
[three-file patch](../evidence/application-mac-bitmap.patch) retain exact inputs,
outcomes and open gates. The new card follows display correction2; its passing
results and all earlier display/capture failures remain unchanged.

## Implementation and evidence boundary

OriginalMacDisplayBackend now owns offscreen storage, image/module identities,
stock bitmap identities, memory DC selection and surface DC acquisition. Every
token comes from the existing window identity pool and is never recycled. Images
use immutable declared file/resource inputs. Source colors copy one-to-one into
the same XRGB8888 display storage; masks copy with them. Unknown DIB positions
remain unknown, including when they overwrite a previously known destination.
Color-key metadata is retained for the next raster consumer. Actual color-key Blt
and presentation are not implemented by this increment.

Native-produced GetObject output defines dimensions, stride, planes and depth;
ignored type/private-pointer bytes are not fabricated. The shared display budget
bounds offscreen allocation. DC associations retain actual owners. Cleanup
retires resources once; active surface DCs prevent destruction, selected images
remain owned, and retained receipt/pixel snapshots survive cleanup.

OriginalMacBitmapService adapts the existing OriginalRequestExchange. Its caller
stages a value cursor through the whole Core call, serves each newly claimed
request outside Core, then retries with the saved prefix. Physical allocation or
copy is not repeated after a late caller failure, and Core rollback is not
described as undoing host IO. Unknown/scaled inputs and diagnostics needing a
separate UI/debug consumer reject explicitly before service. Allocation failure
after service begins records an indeterminate outcome with retained owners.

The behavioral reference remains the original EXE SHA256
3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c and the previously
accepted BITMAP_SURFACE_LOADING, APPLICATION_SURFACE_COLORS and
APPLICATION_GRAPHICS_OWNERS evidence. No original/emulator/historical producer
executed. Core, all old test bodies, fixture bytes and original expectations are
unchanged. Native XRGB, module/DC ownership and numeric responses are explicit
host mappings, not observed Windows GDI/DirectDraw behavior.

## Validation

Four new physical-provider methods passed. All36 original named DIB resources
traverse whole43ee50/43ed10/4013d0 after actual Native window/display startup.
Full XRGB words are independently assembled from accepted source RGB inputs and
compared along with every mask, including146289 unknown pixels. Checks also cover
exact constructor requests, wrapper masks/dimensions, color-key metadata,
retained snapshots, release and restoration of the storage budget.

Other controls cover whole-constructor late failure/retry, declared absent files,
one file-image path, the original skipped pixel-format size word, DC selection
and cleanup, duplicate acquisition, RLE unknown-over-known copying, rejected
rectangles/scaling without mutation, foreign/duplicate/cancelled permits and a
zero-byte allocation budget. The file control wraps unchanged original DIB colors
in a declared BMP header; it is not an observation of a new original BMP file.

All35 preceding display/window/startup/clear methods and all9 selected original
bitmap-loader, DIB and source-color methods also passed unchanged. The48 exact
one-method process outcomes took109.354s in total; queue69433 completed in235.178s.
No test guard or signal fired; every selected method ran. The sampled test RSS
maximum was2066972672 bytes, not an assertion of continuous memory measurement.

Fresh package verification checks199 Core,61 Reference,7 MacPlatform and281 test
sources,385 fixtures and1301 runtime files. The65809944-byte test binary SHA256 is
04822039dd6603860c3770a106494abc3456af658e4d1faf81ea4dffb057dad9.

The first build monitor failed on a permanent numeric exclusion of PID59727;
that source process was already terminal, and the number appeared again in the
build's selected process tree. The new process identity was not captured before
the assertion. Build54930 itself continued and was never restarted. A separately
validated macOS exit observer recorded its actual raw status0/exit0 after297.083s.
There is a95.735s gap between resource samples; continuous build resource bounds
remain unverified. The original monitor-error record is preserved separately.
The unstarted test monitor was versioned to check PID plus start time, retaining
all guard/signal checks, inputs, selectors and test result predicates.

## Publication and next consumer

Finalizer77265 completed in85.036s. The4948 regular artifact files and238 PAX
metadata members are verified, including names/bytes/SHA/modes/mtime, plus the
three-file patch roundtrip. Candidate manifest SHA256:
944cd8c8a83ace502c7c950d22aec925ffcc827e883b2df438b0c319b38ce843.
The task is frozen at `build/research/application-mac-bitmap-20260926` on X5.
Root1034, prior2257, baseline2263 and source55 pins are unchanged. All owned
processes are absent; the original monitor-error record remains intact. Source59727 stays at its recorded34-Object boundary, not137.

Next: compose this provider with the existing whole front/bootstrap caller and
retained Host state, including suspension, late rollback and required-resource
diagnostics. Preserve actual resource identities between calls and do not deliver
both recorded effects and their graphics-command projection as duplicate draws.
General Blt, callbacks/rectangle provenance and exact zero presentation rectangles
remain required before accepting rendered front-screen output. Independent review,
root promotion, palette/text, remaining providers/loading, Windows/input/audio,
clean-Mac/full match/full game remain open. EXE envelope was not recalculated.
