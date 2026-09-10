# Own early screen and background drawing

The own startup/message-loop/dispatcher/resources/settings chain now continues
actual42709b through the initial selector, fill, background load and bitmap draw.
Forty original prefixes reach the next screen body:39 stop at427127 and one at
4275cb, all SP1000ea74. A separate NULL background allocation stops before the
bitmap read at43f04b. It is not a successful original draw or screen-body return.
The World and application dispatcher remain unreturned.

The [finite plan](APPLICATION_FRONT_SCREEN_PLAN.md) follows
[APPLICATION_SETTINGS](APPLICATION_SETTINGS.md) and retains the earlier
[FRONT_SCREEN_PRELUDE](FRONT_SCREEN_PRELUDE.md) corpus unchanged. That earlier
corpus supplied43ed10 loading results and private fill backing. This own chain
executes the complete background loader/copy and preserves the actual inherited
stack, while Native leaves private fill fields unknown.

## Reference and controlled environment

Pinned NTSD EXE SHA256:
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.
VC80 SHA256:
`c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d`.
Original control.txt and36 embedded DIBs, including all13 MENU_BACK resources,
remain immutable. Unicorn2.1.4 executes the original EXE and CRT on the same
CPU, stack, PTD, device and resource state as each freshly executed parent.
No registers, selector, target, stack or old allocations are injected or reset.
Normal SEH/cookies execute; no control/protective storage corruption, bypass or
arbitrary fault continuation occurs.

Seventeen settings parents reproduce their accepted full corpus records exactly.
Two additional fresh parents select setting1 and setting-1 through the actual
settings parser, using declared control-file bytes. Their complete settings
state/stack/mask checkpoints reconstruct and compare natively. Seven full bitmap
parents remain exact. Earlier CRT initialization/NLS is still open; retaining
the existing research PTD does not imply Windows DLL startup was completed.

Timer, thread, allocator, image/GDI and DirectDraw responses remain declared
platform inputs. Default timeGetTime123456900 follows the earlier own loop clock;
13 further controls explicitly supply residues0..12. New background allocation
continues the own wrapper registry, using its declared A5 backing. This does not
recover actual Windows heap content or measure device pixels and timing.
CreateThread observations do not execute its worker or deliver concurrent writes.

## Recovered sequence and own native composition

The selector follows the existing original rules:initial-2 becomes0 for ordinary
settings, setting-1 selects-3, and setting1 invokes the actual4237e0/43c450 worker
request. The own `now` string opens that request. Enter/LeaveCriticalSection
surround the current458424 read; zero requests43c240 with the original arguments.
Successful handle50010000 and zero-handle/GetLastError5 are controlled responses.
The thread-ID outputABCD is explicitly supplied even in the failed-handle control;
that is not a claim about Windows failure output. No worker body runs here.

The original415160 fill uses own global455608, rectangle0,0,794,550, color10206c
and flags01000400. It writes only the size and color in100-byte DDBLTFX. All41
source frames retain their actual earlier bytes and known masks. Native compares
328 owned bytes;3772 private bytes remain zero/false, without importing any
source stack. Fill HRESULT is ignored by the following caller.

Because own4511ac is zero,423840 reads timeGetTime, formats MENU_BACK%d with
actual VC80 sprintf and allocates a1f50 wrapper. Native retains all14 bytes of
the literal-then-formatted name. Every non-NULL allocation executes whole43ee50,
43ed10,4013d0 and actual CRT memset as required by the image path. The new optional
constructor provider in OriginalMenuBackground/OriginalFrontScreenPrelude uses
`OriginalBitmapConstructor.constructWithSurfaceLoading`; the old supplied-result
provider remains unchanged. Surface identity comes from the actual declared
CreateSurface response and native constructor result, not an expected wrapper.

Missing images, negative and positive nonzero CreateSurface, failed GetDC and
negative color key preserve the previously recovered loader/cleanup rules.
Dimensions written before failed surface creation survive. Positive creation
result1 still returns no surface to the caller despite a supplied allocated
pointer. Color-key failure releases and clears the wrapper surface; ignored
numeric errors do not invent an early successful exit.

The actual42710f caller draws frame-1 through whole43f010/43ef70. Its target is
Native's own settings/GameEntry output. Untouched bitmap count/metadata retain
declared A5 allocator backing and false masks. Across200 bitmap reads,82 read
undefined words; they remain undefined, with exact original values and order.
The40 clip returns and40 Blt requests compare, including missing-image rectangles
and null source surfaces at the declared graphics boundary. This is not proof
that Windows renders those requests successfully.

After drawing,42711b loads the established Sleep import into ESI. Source ESI
therefore becomes30009040, while its own target remains in EDI. Native retains
`.sleep` as a typed operation for the next branch, without importing a research
executable address. No new Sleep call occurs in this prefix. NULL bitmap stops
before that instruction and does not produce a completed retained operation.

## Cases and comparison

The41 fresh cases contain all17 successful settings predecessors,13 background
residues, eight resource/graphics failure controls and three setting/thread
controls. There are40 new constructors and1023 full retained/new wrapper records,
8200368 bytes plus masks. All prior wrapper bytes remain unchanged.

The source executes540 new EXE and413 CRT instruction starts and363 complete
helper returns:41 each fill/sprintf/background,40 constructor/loader/draw/clip,
39 memset,37 copy, and two each worker gate/request. These counts do not establish
every branch combination; static per-helper gaps are retained in the report.
All13 library patch spans are disjoint from the observed instructions.

20791 CPU stores and189 API stores reconstruct83545 written bytes, all source
globals, stack and wrappers.1266 ordered events compare full globals at their
boundaries. CPU write hooks observe old memory; their event snapshots are checked
before applying the pending recorded store. Source API structures compare their
actual stack bytes and write masks. Native compares4508 owned image-API field
bytes and leaves5524 private bytes unknown, separately from the fill fields.
Original CRT/PTD/calendar state and CW037f survive each prefix.

The parent verifier also reconstructs1087 complete settings checkpoints and
1322 settings events across19 unique parents. All1316 storage blobs,41 atomic
cases and36 whole DIB assets are checked in full, with original instruction bytes
and parent/fixture hashes. Source expected bytes are never edited to fit Native.

Native rebuilds the complete own parent before continuing. Its event shadow uses
its own game globals and retained World/outer bytes. Old front resources and the
new background's bytes/masks, live surface identities and cleanup requests all
compare. Each staged prefix then rolls back the enclosing unfinished message-loop
iteration at the required body/alternate/NULL boundary, preserving committed
startup/callback, MSG, counter, baseline, globals and all resource ownership.

Nine additional late failures cover fill, format, CreateSurface, DeleteObject,
background global store, Blt, next-body observer, CreateThread and GetLastError.
They preserve the same full outer state, including the new background registry,
settings outputs and cached Sleep operation. External effects must remain
buffered until the enclosing iteration can commit.

## Acceptance and remaining work

The first raw9 release tests passed25.373s/build205.06s. Review then strengthened
the comparison-only global shadow:the earlier version used the already checked,
unchanged source-before suffix; it never fed that suffix to a game routine. The
final comparator instead retains and uses the independently rebuilt own suffix.
Review also recovered the actual42711b cached Sleep consumer. Neither change
altered the original raw corpus or expected bytes. Exact final acceptance and
processes are recorded in `build/research/application-front-screen-work.json`.

The final raw9 tests passed25.582s/build195.33s. Packaged9 tests passed24.655s/
build0.28s without raw overrides, retaining settings, bitmap loading and the
earlier screen-prefix corpus. NTSDNative linked. All source/native jobs are
terminal; final isolated614 files comprise612 committed base files plus owned
additions and exclude six unchanged foreign worktree files.

Raw48603072bytes SHA256:
`7cde4e83c49a78e82cd02bf63c15d7e2e87aa8a04937ae196d1e9864f3d17632`.
Lossless fixture12155724bytes SHA256:
`86e8deb50553406af7a12695487939a102a8ed4aa99917597780d7955ba2995f`.
Full raw/packed bytes, JSON/SHA,1316 blobs,41 atomic cases,36 whole assets and
10 vendor files verify. All241 prior fixture pins remain unchanged;242 current.

Tools: [source](../../tools/oracle_application_front_screen.py),
[independent verifier](../../tools/verify_application_front_screen.py),
[acceptance](../../tools/accept_application_front_screen.py),
[report](../evidence/application-front-screen.json).
The completed candidate1 capture must not be restarted. All241 previous fixtures
and10 codec vendor hashes remain unchanged. Original EXE/DLL execution remains
research tooling and is not added to the native shipping runtime.

This own composition is still separate from the Practice app. CUA again reports
`Native apps: Error: Sky Computer Use native pipe startup failed`; no window or
input action occurred. Actual Windows files/devices, pixels/audio/input latency
and worker execution remain open.

Next continue actual4236d0 and the427127 screen body, or4275cb alternate branch,
with the own resources, target, cached Sleep and retained stack/CRT. Full World/
dispatcher/WinMain returns, earlier CRT/NLS/library/private-backing dependencies,
worker/application integration, complete Naruto/Sasuke District match, every
original mode/content/network/replay path and clean-Mac acceptance remain part
of the active full-game goal.
