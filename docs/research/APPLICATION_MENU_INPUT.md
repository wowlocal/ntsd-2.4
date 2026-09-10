# Own input, repeated menu and actual loading entry

Fifty fresh source chains continue the accepted
[APPLICATION_MENU_RETURN](APPLICATION_MENU_RETURN.md) state. All47 completed
parents execute one further idle iteration. Three independent default/minimized/
negative-presentation chains instead receive actual queued mouse move/down/up,
select the single-player row, execute World1->2, and reach the first real41bc90
loading call atSP1000ea6c. There are62 completed iterations and three pending
loading calls. The earlier NULL-cursor parent is immutable and cannot continue;
it is not silently converted into a successful parent.

The [finite plan](APPLICATION_MENU_INPUT_PLAN.md) fixes these50 cases. Reference
artifacts are the pinned original NTSD EXE, bundled lib.dll, VC80, control.txt,
36 complete PE DIBs and the previously loaded five WAVs. Unicorn2.1.4 runs the
actual relocated DLL attach before independently entered WinMain. This remains
separate from full PE/CRT/NLS startup and actual Windows execution. No parent
CPU/registers, stack, globals, held/mouse/World or CRT state are reset. Original
SEH/cookie code executes normally; no control/protective corruption, bypass,
external network/URL operations or continuation after memory faults occurs.

## Delivered input and continuous returns

The default idle repeat re-enters43e9a0 and4246b0 with its own current target.
The dispatcher scans250 acquired keyboard bytes and clears the surface. World
flips4511f8 and sees44d068=0, so it skips early bitmap/settings allocation. The
existing background is filled/drawn, panel updater and installed library text
run again, then main/tail/World/dispatcher return. The settings-1 parent takes
its own selector-3 alternative. Each idle loop advances counter2 to3 and keeps
its own timer baseline123456855. Resource and previous-click state are retained.

The activation inputs are normal messages, delivered by the declared queue:
WM_MOUSEMOVE(350,230), WM_LBUTTONDOWN, a due iteration, WM_LBUTTONUP, then two due
iterations. Peek/Get output writes the complete MSG, and the Dispatch adapter
places a documented callback frame on the existing stack. Actual43b3d0 executes
and returns through DefWindowProc(-123). No direct global writes simulate mouse
motion, held buttons, previous clicks or World transitions. The native public
`OriginalWindowInput.receive` consumes its own delivered MSG and writes the same
fields/order. Callback-frame delivery is an API boundary, not a Windows queue
or private host ABI measurement.

The clicked main row requests confirmation sound through whole401a30, clears
held state, sets4553bf to0x75, chooses selector0 and changes its own World0 to1.
Whole422ac0 executes3000 actual VC80 rand calls, retaining PTD+14 between them,
writes3000 nonzero table bytes plus NUL, then writes team defaults. The sound
uses the five buffer tokens produced by own earlier WAV startup. The newly
needed Stop/SetCurrentPosition/Play vtable methods are declared API bindings on
those same resources, not replacement sound buffers. All three method requests
and ignored negative numeric replies in the failure control remain observable.
No audio device or playback latency is measured here.

The next due World1 call executes whole423910/43ef50:Release the background
surface, clear wrapper+0, free the known wrapper, then clear4511ac. Original
negative release HRESULT still reaches free/clear. Dead bytes and masks remain
recorded. MENU_WAIT is drawn, World becomes2, then overlay/present and both
ordinary epilogues return. A following due call reaches41bc90 with target31003000
and returnPC424746 on the same stack. That child is not executed here, and the
subsequent457580 clear is not claimed. Native retains the last completed loop
(counter7/baseline123456888); its pending loading iteration is rolled back at
this explicit dependency rather than supplied a successful dispatcher result.

## Full state and native ownership

All47 whole menu parents and their42 body/39 front/18 settings/six bitmap records
reproduce exactly. The source audit reconstructs869 full checkpoints from62842
CPU stores and174 API stores,212735 bytes. It includes globals/stack/known masks,
MSG/library/PTD and21725 bitmap-record comparisons/174147600 bytes plus masks.
The only new PTD change is9000 writes to its random word; other CRT/calendar
storage is unchanged. There are218 ordinary SEH stores and106 actual World/
dispatcher ABI returns, plus nine whole WndProc callbacks. All source private
bytes remain evidence; they are not native input.

Native transfers its own constructed bitmap records and raw CreateSurface
bindings into its menu allocator registry. This registry supplies current live/
dead bytes for drawing and release; the earlier constructor records retain their
historical output. No expected surface/wrapper word or after-state is imported.
Repeated body calls produce96 owned local bytes and keep96 private bytes zero/
unknown, using the target from their own GameEntry. Source traces retain131347
local reads/132751 bytes with their actual preceding stores. Normal source
prologue/epilogue words remain outside native private-ABI equivalence.

The corpus contains18835 events,10140 helper returns and968 EXE/51 DLL/nine CRT
instruction starts. The declared PTD lookup hook78132e29 is excluded from original
instruction coverage. There are256 bitmap/clip/Blt calls,210 undefined bitmap
reads,56 whole-surface clears,50 fills,147 library text calls,9000 actual rand
calls and three background frees. The92 undefined effect bytes per clear/fill
stay unknown/zero natively;9752 such fields are compared under masks. No all-
branch, raster, hardware FPU, Windows allocator or whole-game claim follows.

Scalar/World store observers now retain the exact RNG table, click and release
order. `OriginalCRTRandom.rebuildGameTable` stages its own state and globals when
an observer can throw; its arithmetic/output rules are unchanged. Native late
checks cover the first callback, a later Blt, the third sound method, a partial
RNG-table write, the completed table observer, background free, final World1
presentation and pre-commit. A failure retains earlier completed input/menu
iterations and rolls back the entire pending iteration, including MSG/timer/
counter/resources/library/RNG/local output. External effects must be buffered
until that iteration commits.

## Acceptance and remaining work

Exact source/native jobs and review live in
`build/research/application-menu-input-work.json`. Initial source probes exposed
an inactive-parent observer-routing error and the distinction between CALL40127c
and return40127e for clear. Their logs/snapshots are retained; observer corrections
never changed expected game data. Native compilation initially tried to call an
internal mouse primitive; the composer now uses the public whole callback API.
The final raw/packaged results and immutable identities are recorded below and
in the [evidence](../evidence/application-menu-input.json).

Raw132657719bytes SHA256:
`33292e107dface97563ea36a3d55e4108ce051d85352345c22e46a8ab898fc18`.
Lossless fixture37774137bytes SHA256:
`e1eb47c2d27dc5da54877dafa3471d03abc34cd608016252b5845634b4f8b6f0`.
All244 prior fixtures remain unchanged;245 current. Independent full raw/packed
bytes/JSON/SHA,7567 blobs,50 atomic parts,36 assets and10 vendor hashes verify.
The620-file isolated package exports618 committed base files plus the new test
and fixture, with only owned overlays; all six foreign files remain untouched.
Raw8 release tests passed71.656s/build66.13s, including the retained own parent
and controlled loop/main/presentation. Never restart completed candidate1.

Final packaged8 release tests passed72.072s/build0.28s without raw
overrides. All source and SwiftPM jobs are terminal. NTSDNative linked; no
application window/device was exercised.

Tools: [source](../../tools/oracle_application_menu_input.py),
[verifier](../../tools/verify_application_menu_input.py),
[acceptance](../../tools/accept_application_menu_input.py).

The [own loading prefix](APPLICATION_LOADING_PREFIX.md) now continues all three
activation chains through prologue/common WAVs/presentation to the actual catalog
allocation request. Its separate failure controls preserve this immutable parent.

Next compose the remaining41bc90 using the retained own World2, resources, RNG, target,
input, library and allocation lifetimes. Recover missing children at their real
entry rather than importing controlled loading after-state. Worker execution/
delivery/reentrancy, earlier full CRT/NLS, other dispatcher modes and repeated
settings/network branches remain open. The window inventory again returned no
apps/browsers and `Native apps: Error: Sky Computer Use native pipe startup failed`.
No window/device was exercised. Actual Windows runs, complete loading/Naruto-
Sasuke District match/all content/modes/network/replays, app integration and
clean-Mac acceptance remain part of the active full-game goal.
