# HUD callee used by paused gameplay

`OriginalWorldHUD.drawPreservingCommands` implements the whole41ae60..41b12d
callee without the unpaused caller's command resets. All1,789 controlled
original calls match full World/400-Actor bytes and masks, whole globals and
283,090 ordered drawing events. The existing `apply` API still executes the
421a15..421a2d caller, which clears450bc0 and450bb8 before drawing.

This is a dependency for paused gameplay. It does not execute the whole paused
caller, an initialized own pause or its return. The unpaused body and subsequent
loaded calls have separate evidence in [GAMEPLAY_BODY](GAMEPLAY_BODY.md) and
[CONTINUOUS_GAMEPLAY_PLAN](CONTINUOUS_GAMEPLAY_PLAN.md).

## Compatibility boundary

The reference is the pinned NTSD2.4 EXE, SHA256
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`,
executed by Unicorn2.1.4 with CW027f, FPSW0 and tagffff. Original constructors
produce alternating a5/ramp-backed World and Actor records. The four declared
Object headers, thirteen bitmap records, full globals and COM HRESULTs use the
same controlled input contract as [WORLD_HUD](WORLD_HUD.md). No source DLL
executes in this study. Constructor memset and device responses remain declared
boundaries; neither source execution nor native tests establish Windows pixels.

The direct call sets ECX to World, EDI to1 and ESI to the argument, as at
paused41d765. EBP remains a declared sentinel; this does not reproduce an own paused
caller's complete register frame. The original callee executes its actual
ret4. Its saved registers, final stack pointer,
control/status/tag words and unchanged argument bytes are checked after return.
Neither the argument at callee-entry SP+4 nor the caller's retained rootSP+68
is read or written by the callee. The terminal sentinel is not an executed
instruction or an observed code-hook PC. Native therefore needs no fabricated
target from these argument bytes: the HUD uses global455608.

The first1,753 cases reproduce every previous HUD input, full pool/mask hash,
helper count and ordered drawing event. Only the declared callee return and
argument-access metadata, and the globals affected by the omitted caller
resets, differ. All46,144 global bytes now equal independently reconstructed
entry bytes in every case. Another36 cases cross both command flags over
INT_MIN, -1,0,1,2 and INT_MAX while drawing two active cells.

## Observed execution and native behavior

The477 executed original instruction starts comprise all223 HUD starts,
45/57 clip starts,171/214 bitmap starts and38/38 rectangle starts. These are
actual per-instruction code hooks; the six unpaused caller starts are absent.
This does not establish every branch outcome. The61,173 complete helper
returns include the HUD itself. Events are18,344 draw,183,164 read,34,648 clip,
40,542 Blt and6,392 rectangle requests. All70 deliberately undefined bitmap
read events retain their source values and masks.

The native change shares the established HUD algorithm and resource resolvers;
only the caller's two pre-draw stores are conditional. Default `apply` retains
them, while `drawPreservingCommands` omits them. No character IDs, host rendering
rules, expected output bytes or source instruction addresses drive the HUD.
The existing rollback contract remains: globals commit after all callbacks,
and callers buffer external device requests until the enclosing call commits.

The initial source attempt terminated at a harness assertion because it
expected a code hook at a terminal address already used by constructor captures.
A terminal diagnostic also exposed that direct entry had not set ECX to World.
The fresh capture supplies that actual caller register and validates ret4 after
emulation returns. The failed log is preserved; no live process was restarted,
and no accepted fixture or native drawing rule was changed to force agreement.
Before native acceptance, the declared ESI sentinel was tightened to the
argument retained by the pause caller. All1,789 complete source case results
and the instruction inventory reproduced unchanged; the earlier complete raw
capture, report and log remain preserved separately.

## Remaining paused caller

[Static pinned-byte inspection](../evidence/paused-gameplay-static.json)
of41d734..41d799 identifies the required order.
After the cached pause decision,41d742 stores44d02c=1,41d748 calls background
41a250 directly, and41d75d calls world drawing41a5a0 using live450bd8/451160.
It does not call the camera's bounds/update pass. The background's original
animation behavior must still execute. HUD41d765 then precedes the PAUSE bitmap
44ff8c at x360/y288, picture-1, key1 and destination455608.

If450b84 is zero, the caller jumps to common output422994. Otherwise it pushes
the retained target and joins the recording indicator at422952, after the
unpaused indicator caller's push. The optional recording-information consumer
still follows. Whole paused composition must retain that exact stack/target
provenance, background/object/HUD/bitmap order, output and actual return. A
fresh original whole caller and initialized input-driven pause/resume are still
required; the static inspection is not dynamic paused-caller evidence.

Implementation: [OriginalWorldHUD.swift](../../native/Sources/NTSDCore/OriginalWorldHUD.swift).
Source producer: [oracle_paused_hud.py](../../tools/oracle_paused_hud.py).
Acceptance: [accept_paused_hud.py](../../tools/accept_paused_hud.py).
Comparison: [OriginalWorldHUDTests.swift](../../native/Tests/NTSDCoreTests/OriginalWorldHUDTests.swift).
Report: [paused-hud.json](../evidence/paused-hud.json).
Full raw/packed verification: [verify_paused_hud_artifacts.py](../../tools/verify_paused_hud_artifacts.py).

## Validation

The first native build rejected a concurrent edit to
`OriginalContinuousGameplayTests.swift` during compilation. A subsequent
premature isolated attempt failed before compilation because the checkout was
still in progress. Neither attempt ran tests or published a fixture. The final
native package is an independent copy of commit`f98c5ab` with the two owned HUD
source/test changes. All486 package files were checked against committed bytes
or LFS size/SHA before those changes were copied. An unused full checkout was
cancelled while fetching unrelated historical downloads; source and Swift test
processes were not restarted for silence. The concurrent loaded-call work is
excluded from this isolated test package.

Raw release acceptance passed6 tests in58.484s after a172.20s build:1,789
paused callee cases,1,753 retained unpaused caller cases, two existing late
failure checks and both initialized gameplay bodies. The latter retain all19
checkpoints and1012/1068 events, including their late whole-body rollback.
Final packaged verification, without the raw-corpus environment override,
passed the same6 tests in58.119s after a169.18s build. NTSDNative linked; no
application window or device was tested.

The new fixture preserves all35,383,336 raw bytes through737,624 packed bytes.
Independent verification checks the full restored bytes, complete JSON,
lengths, SHA values, all190 preceding fixture pins and ten vendor files.
There are191 current fixture pins. Fixture transport deflation does not
replace the game's private original1.1.4 replay codec. All owned source,
build and test processes are terminal. Python compilation, local documentation
links and owned-file whitespace checks pass.

The complete paused caller, initialized pause, outer clock,
native application integration, full match, device/Windows/clean-Mac checks and
the full native-game goal remain open.
