# Own application settings and scratch lifetime

The own WinMain/message-loop/dispatcher/front-resource chain now continues
whole423480 settings through42709b/SP1000ea74. Seventeen fresh calls return;
one missing-FILE path stops before the first4234db/fscanf. That stopped path is
not a successful original settings return. The enclosing World and dispatcher
remain pending at the screen consumer.

The [finite plan](APPLICATION_SETTINGS_PLAN.md) follows the seven usable own
[bitmap resource parents](BITMAP_SURFACE_LOADING.md). Every source parent is
executed freshly and reproduces the full accepted startup, callback, message
loop, dispatcher entry, resource events and wrapper bytes. The existing
[settings corpus](SETTINGS_LOADING.md) remains unchanged, including its distinct
supplied500-byte scratch and explicit later caller entries.

## Reference and execution boundary

The pinned NTSD EXE SHA256 is
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`;
VC80 SHA256 is
`c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d`.
Original `data/control.txt` SHA256 is
`cc7f84872d9b95fe64c1c95cc7895b3e2c0a52a3ae0f7f7970f0b3c56b7037c0`.
Unicorn2.1.4 executes the original helper, actual fscanf/fgets/feof and normal
cookie check on the same CPU, stack and existing initialized thread binding as
the parent. No CRT image, PTD, globals, scratch or registers are replaced when
continuing the actual427089 call. This retains the parent's declared CRT setup;
it does not close the earlier real DLL initialization/NLS dependency.

Fopen/fclose, translated `_read` bytes and existing single-thread services
remain declared platform inputs. The declared32-byte FILE record uses flags9,
buffer capacity10000hex and synthetic descriptorFFFFFFFF; logical CRLF-to-LF bytes
are not a recovered Windows text-translation implementation. Original files
are read only. No actual Windows file opening, host heap exhaustion, source
control/protective storage corruption, protection bypass or external target
is involved. Missing FILE stops before CRT invalid-parameter handling.

## Actual own scratch and caller registers

The original settings helper enters at SP1000ea70. Its500-byte observed scratch
is1000e878..1000ea6b, ending before the cookie; this is not a recovered C-array
size. At the primary entry311 bytes have earlier known writes, with private
values left by the full parent. All source bytes and masks are retained.

Across18 calls,825 scratch reads consume1284 bytes. Every read is covered by
writes of the current settings call. The source's first info fgets therefore
establishes all bytes subsequently needed by the append loop. Empty input and
an absent profile tail do not read the scratch. Trailing LF and exact99/198-byte
info still duplicate the retained last line when a later fgets discovers EOF;
they do not require any old stack value.

`OriginalSettingsLoading.loadOwnStartup` creates500 zero bytes with false masks,
uses the existing settings rules, and requires defined bytes for semantic string
reads. Zero is an unknown-storage representation, never imported source backing
or an assumed original value. Every owned byte and mask compares; the original
private remainder stays immutable evidence. The previous supplied-backing API
keeps its old contract through the default option.

Whole423480 preserves EBX/EBP/ESI/EDI and returns fclose's bits. Its caller then
changes two registers:42708e restores EDI from rootSP+20;427098 sets ESI toFFFFFFFF.
The saved target has exactly one write in the entire retained own history,
4246fd, and no intervening overwrite. Native supplies that target from its own
`OriginalApplicationDispatchEntry.GameEntry`, then returns it and the retained
minus-one value for the next screen consumer. It does not load an expected
stack word. The missing-FILE result supplies neither returned-register value.
The caller427092 still stores its own EBX0 into44d068 after the helper return.

## Cases, comparison and rollback

Seven fresh cases continue all accepted resource parents that reached settings:
restore, minimize, missing cursor image, first negative CreateSurface, last
positive CreateSurface, last negative color key, and NULL cursor allocation.
Eleven more use a fresh normal parent for raw control bytes, chunk1/chunk7,
trailing LF, empty input, absent profile tail,99/198-byte info, backtick names,
missing FILE and negative fclose. None is a forced retry after an interrupted
helper. Resource records and the whole World/outer suffix remain unchanged.

There are1197 ordered settings events:18 opens,799 scans,53 fgets,36 feof,
257 caller writes,17 closes and17 helper returns. The888 actual CRT returns
preserve their entry/return stack and nonvolatile registers. All195 executable
settings starts plus four caller starts run; two other decoded settings starts
are alignment only. Total new instruction coverage is202 EXE and733 CRT starts.
This is not every scanner input, branch combination, CPU or Windows outcome.
Thirteen installed-library patch spans are disjoint from these instructions.

Source reconstruction checks152573 CPU stores/566870 bytes and976 complete
state checkpoints, including full globals, all9216 observed stack bytes,500
scratch bytes and masks. Its1598 CRT data stores also reconstruct; the complete
CRT/PTD/calendar state is unchanged after each call.274 declared read requests
supply2984 bytes. Complete parent payloads and all1207 storage blobs verify.

Native compares958 settings checkpoints: full known game globals, with the
unchanged World/outer suffix established by its independently rebuilt parent,
and2277 owned scratch bytes. Another476723 scratch bytes at those checkpoints
remain unknown and zero/false natively. This is not native equality for the
original private stack. Original resource ownership remains intact.

Each matching staged continuation still rolls back the entire enclosing pending
message-loop iteration at the required screen or missing-FILE boundary. Committed
startup/callback, MSG, counter, baseline, globals, input/replay ownership, front
bitmaps, graphics and typed caller/settings state remain unchanged. Seven further
late failures occur at the47th scan, third fgets, second feof, fclose, settings
return, final flag store and screen-boundary observer. Settings-local failures
roll back that helper; the screen failure follows its successful staged return
and rolls back at the enclosing loop. External effects must be buffered until
that whole iteration can commit.

## Verification and remaining work

Raw9 release tests passed11.049s/build195.18s. Final packaged9 tests passed10.388s/build0.26s without a raw override. Both include retained settings, bitmap loading and application entry. NTSDNative linked.

Raw38354477 bytes SHA256:
`f5f3c58d2ac8aa3c2a37d2d220b2994eee02a312cdba80235b736bc8d13f1532`.
Lossless fixture7826352 bytes SHA256:
`73bbc8475c73f1d1c6752b9127f3019cd9222f757903bc7c9de52ab39658a06f`.
All240 previous fixture hashes remain unchanged;241 current fixtures. Full raw/packed bytes, JSON/SHA,1207 blobs,18 atomic cases and10 vendor files verify.
The final isolated612 files comprise610 committed base files plus owned
additions; six foreign worktree files are excluded and unchanged. Both source
captures and all three native jobs are terminal.

Exact acceptance details are recorded in
`build/research/application-settings-work.json` and the
[report](../evidence/application-settings.json). The first build-only invocation
found that a new optional test-context property needed an explicit default; no
test ran. The initial verifier incorrectly required preserved registers across
the caller tail; source evidence separated the real helper preservation from
EDI/ESI updates. No source expected bytes or settings parsing rules changed.

Tools: [source](../../tools/oracle_application_settings.py),
[independent verifier](../../tools/verify_application_settings.py),
[acceptance](../../tools/accept_application_settings.py).
The completed candidate1 corpus must not be restarted. Earlier240 fixtures and
ten codec vendor files stay unchanged. Reference execution remains research
only; no Windows executable or DLL is added to the native runtime.

This own composition is still separate from the Practice app. CUA reports
`Native apps: Error: Sky Computer Use native pipe startup failed`; no window or
input action occurred. Actual Windows, device pixels/audio/latency, read-error
continuations and complete application execution remain open.

Next continue the actual42709b screen selection/fill/background/draw, preserving
own target and stack/CRT/resources, then the whole World/dispatcher return.
Library routes, worker/runtime integration, complete Naruto/Sasuke District
match, all original content/network/replays and clean-Mac acceptance remain
requirements of the active full-game goal.
