# Physical macOS window service — implementation candidate

The isolated candidate implements AppKit window requests through the observed
whole-startup coordinator and the same Host. It owns native cursor/class/window
tokens and retains physical resource leases with their replies. Six Swift files
passed syntax checks; fresh compilation and the selected29 methods remain open.
This advances the real window dependency for the first Naruto/Sasuke District
match; it does not provide graphics surfaces, pixels or a playable application.

[Finite plan](APPLICATION_MAC_WINDOW_PLAN.md). Base fc584bb and the actual frozen
2254-file observed-startup correction1; the root1034 files and pending catalog work
remain protected. No original EXE, emulator, capture or refused operation was run.

## Contract and implementation

NTSDMacPlatform is a separate AppKit-linked target, outside Core. It serves metric,
icon, cursor, class registration, window creation, update, show and destroy requests.
The source's separate metric7/8/8/4 calls and both ShowWindow calls remain separate.
CreateWindow produces a native identity, consumed by later whole-startup requests;
UpdateWindow still precedes the recovered HWND store. The service is bound to one
coordinator and records physical replies outside attempted Native calculation.

OriginalRequestExchange.beginService atomically validates the owner, active permit,
open status and absence of a previous start before physical work. Prepared callers
retain their old answer-without-IO path. Cancellation prevents a new physical start;
already begun work can still retain its actual late answer or indeterminate failure.
AppKit errors after start never become invented Win32 numeric outcomes. The service
does not supply DirectDraw, surface, clipper or pixel-format success responses.

The window registry is weak; receipts, snapshots and copied Host delivery contexts
own leases. A window lease retains its class and cursor; final release queues an
owned window close on main. Explicit destroy closes the physical window while
retaining its identity in existing receipts. Native rollback does not undo a visible
window or repeat fulfilled IO. Whole lifecycle callback dispatch is not implemented
by this service and cannot be inferred from successful physical close.

Host policy is explicit: one game unit maps to one AppKit point, with backing scale
observed separately. Native frame/content conversion supplies decoration metrics;
the native window is titled, closable and miniaturizable. Source CW_USEDEFAULT
delegates placement to center. Source style10cb0000 remains request metadata.
Windows DPI, placement, decorations, zoom/menu/focus, synchronous callbacks and
pixel equivalence remain unknown. Fullscreen remains a required open dependency.

Read-only inspection of the pinned EXE finds icon group121 and no group32512 or
menu resource. This supports the missing-icon result for the requested module
ordinal; it is static evidence, not an actual Windows observation. The native
adapter does not substitute icon121 or invent a menu. Microsoft documents the
module lookup and null failure in [LoadIconA](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-loadicona).
The show reply records prior visibility, as documented for
[ShowWindow](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-showwindow).
Installed AppKit SDK declarations and the resource index are pinned in author review.

## Selected verification and limits

Four new methods cover whole startup with a real window, geometry and ownership,
foreign/duplicate/cancelled permits before IO, and late publication failure followed
by retry/handoff/context lifetime and explicit destruction. Remaining APIs in those
methods are declared controls; HWND bindings use the produced native identity.
These are new macOS observations, not comparison of real device values against
old synthetic expected values. All25 previous source-comparison methods and their
fixtures remain unchanged. The new methods are selected but have not been run.

Author review examined the added exchange claim, retained response semantics,
AppKit ownership and explicit host policies. It is not independent review. Visible
window teardown on final lease release is also not covered by the current lifetime
test, which explicitly destroys the window before dropping the last context.
One unused test helper was removed before parsing; the unparsed draft is preserved.
No failed test, expected value or comparator was changed.

## Delivery and next gate

Artifacts are in build/research/application-mac-window-20260926 on task-owned X5.
Closure verifies all2257 candidate files, root1034/base2254/source55 preservation,
old test bytes, six-file patch roundtrip and regular-file/PAX archives. The final
publication records their exact identities. Preparation35106 and parse48432 are
terminal0 and absent; syntax covers six files only, not type checking.

NEXT: fresh build, package verification including the new NTSDMacPlatform target,
and all29 methods on the frozen candidate. Observe actual AppKit state and keep
visual/Windows/device checks distinct. Independent review, root promotion,
graphics/raster, synchronous callbacks, remaining providers and aggregate audio,
initialized loading, Windows/clean-Mac/full match and full game remain open.
NTSDApp still launches Practice. Source59727 remains terminal at34 Objects, not
full137; existing safety incidents remain open. EXE envelope was not recalculated.

## Verified implementation closure

Finalizer59873 terminal0/absent. Full2257-file/60-directory regular archive and
45-member PAX metadata verified, including bodies/modes/nsmtimes/membership and
distinct clone inodes. Six-file patch roundtrip and root/base/source preservation
passed. Candidate manifest SHA256 `f1bdd040998f5d4254277c31d92474206c9d43dccb05ae536643d090279bf92f`.
[Publication](../evidence/application-mac-window.json),
[closure](../evidence/application-mac-window-close.json),
[patch](../evidence/application-mac-window.patch). Fresh build/all29 and independent
review remain open.
