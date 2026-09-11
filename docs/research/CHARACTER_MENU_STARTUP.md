# Native music and character-menu resource startup

`OriginalCharacterMenuStartup` joins the existing menu-music entry and eleven
bitmap resources in their original order. Globals, music allocations, bitmap
owners and the caller's buffered environment commit together after the final
observer. A later resource failure no longer requires a caller to undo already
published music state manually. The [finite plan](CHARACTER_MENU_STARTUP_PLAN.md)
keeps the pending own application catalog and subsequent menu dispatch separate.

## Reference and ordering

The reference is the unchanged pinned NTSD EXE/VC80 and original assets from
[MENU_STARTUP](MENU_STARTUP.md), [MENU_CYCLE](MENU_CYCLE.md),
[MUSIC_PLAYBACK](MUSIC_PLAYBACK.md) and [MENU_RESOURCES](MENU_RESOURCES.md).
Their controlled Unicorn instructions and complete recorded states establish
the4229cc->429730..429e5a continuation. No new source execution or expected-state
editing is needed for this composition.

Music checks previous menu4512cc and current menu44d020 before the resource
prefix copies the current word into4512cc. Reversing these operations could
skip the initial music request. The shared operation preserves that read/write
order and returns the actual conditional-entry result as `musicEntered`.
That Boolean describes the music entry path; it does not claim audio playback
on a real device. The resource result retains selectionAtEntry from before
constructor and seat initialization.

The first historical native loading/input/round entries supply their own
globals. Music owns its actual native wide-path allocations, and resource
loading owns all eleven native wrappers, including the SPARK rectangle writes
and load-flag order. Repeated menu entries reuse those owners and original
gates. The existing globals, records/masks, events and helper ABI witnesses in
both reference checks remain comparisons, not inputs to native game storage.

The historical bitmap constructor's43ed10/COM results remain declared device
boundaries. This study does not turn them into complete surface-helper or
Windows/device executions. The caller's private stack/prologue, the installed-lib
application catalog path and full enclosing return retain their existing limits.

## Transaction and failures

[OriginalCharacterMenuStartup](../../native/Sources/NTSDCore/OriginalCharacterMenuStartup.swift)
stages all four caller-owned values. It first invokes the existing music code,
observes completed music, runs the existing resource loader, verifies a ready
continuation, and finally offers the complete candidate to the observer.
Every platform callback receives the candidate environment; callers must buffer
external effects there until the outer operation commits.

The standalone resource API continues to expose its original partial NULL-SPARK
boundary. The new whole startup throws `OriginalCharacterMenuStartupError.nullSpark`
before publishing that candidate: original429b21 would write through NULL.
This is an explicit native rejection with rollback, not a successful source
fault match or an invented successful menu return.

Five native-only trials use the completed native first-entry globals and only
declared platform replies/allocation backing from the retained source corpus.
They throw after completed music, the sixth bitmap, the SPARK flag checkpoint,
the final observer, and the declared NULL-SPARK allocation. They check that the
requested point was actually reached, no result is returned, and globals,
music/bitmap ownership and the buffered environment remain at their entry
values. Source after-state is not decoded by this rollback test.

## Verification and remaining work

The isolated export of accepted ebe460a plus four owned code/test files passed
all six release tests in81.648s, build230.55s. MENU_STARTUP took15.820s,
MENU_CYCLE25.393s and MENU_RESOURCES40.435s. Both original startup comparisons
retain3412 records/5948634 bytes plus masks,22 checkpoints and68 events each.
Both repeated chains retain their four calls/three returns and all existing
state/resource comparisons. Both187-case resource corpora and their374-case
music,2074-round and1134-replay parents retain the separate original branch
and failure-boundary contracts. These counts are retained source coverage;
the five new rollback trials are native-only checks.

All631 archived files are hash verified:627 accepted base files and all247
fixtures are unchanged, with no new fixture. The existing game routines and
expected corpora were not edited. Evidence is in
[character-menu-startup.json](../evidence/character-menu-startup.json) and
`build/research/character-menu-startup-work.json`. All jobs for this native
study are terminal0. NTSDNative linked; no app window or audio device was
exercised. Pre-existing inferred-Void and trailing-closure warnings remain
outside these changes; the new implementation and tests needed no correction.

```sh
swift test --package-path native -c release --filter 'OriginalMenuStartupTests|OriginalMenuResourcesTests|OriginalMenuCycleTests'
```

Full own catalog/pool/UI/loading continuation, complete surface-helper
composition for these menu resources, menu dispatch/render/return, application
window/latency/sound, Windows/devices, full match, all original content and
clean-Mac acceptance remain open. The original EXE/DLL and Unicorn remain
research dependencies, outside the native shipping runtime.
