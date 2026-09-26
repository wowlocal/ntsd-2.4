# Windows setup: approval received, host screen locked

2026-09-26. Continues [installer start](WINDOWS_UTM_INSTALLER_START.md).
[Exact checkpoint](../evidence/windows-utm-host-lock.json).

The user explicitly approved the Windows11 Home April2024 EULA, then requested
continued installation without repeated confirmation of required agreements.
Accept has not yet been pressed: CUA returned `cgWindowNotFound` for the existing
UTM window, a fresh app binding and a later AX observation. App inventory still
reports UTM running but no app windows. A read-only IORegistry observation reports
`CGSSessionScreenIsLocked=true`. The initial metadata parser's dictionary/list
error and its read-only correction are retained. This is an unavailable host UI,
not a safety refusal, an installer failure or a request to restart the guest.

QEMU43650 retains its September26 22:40:45 start, expected UUID, command and cwd.
The original game33492 remains live in CrossOver. Neither was restarted, and no
host unlock/authentication attempt occurred. VM configuration, verified ISO,
resources/isolation and prior evidence remain unchanged. The last actual guest
screen is the pending EULA; no installation or Windows/game compatibility claim
follows from the live process. The preparation is within existing storage bounds.

NEXT when the host UI becomes available: reobserve this same installer and accept
the already-approved EULA, then continue ordinary installation. No repeated EULA
question is needed. While locked, continue independent permitted work on the
first-menu renderer's missing reference contracts; the prepared cursor kit is
committed at4ad8cbb. Actual Windows capture, independent review, Native raster,
full menu/match/game and existing safety incidents remain open. No Native code,
source expected bytes or envelope estimate changed in this checkpoint.
