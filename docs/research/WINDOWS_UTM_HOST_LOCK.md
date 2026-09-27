# Windows setup: approval received, host screen locked

**2026-09-27: UTM work discontinued at the user's explicit request, “give up on
UTM”. Do not resume this installer or further UTM setup.** Earlier instructions
below to resume after unlock are superseded. CrossOver remains the authorized
alternative for running the original; it does not establish actual Windows
device equivalence. Preserve the VM, ISO and previous evidence.

Immediately before cancellation, the existing UTM guest window became observable
at the April2024 license screen. A coordinate click failed with
`Computer Use server error -10005: windowNotFoundAtPosition((857.0, 1396.0))`.
After a fresh unchanged-screen observation, Return advanced to “Please wait”.
The next screenshot showed only the UTM library. At06:42:46 UTC, `ps` no longer
listed the previously pinned QEMU43650. Its terminal cause/exit is unknown;
neither successful Windows installation nor an installer error is established.
No restart or further UTM input followed the user's cancellation. The independent
Native loading test57258 remained live.

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

2026-09-27 display-capability follow-up: the same QEMU identity, command, cwd and
configuration remain unchanged. Its QMP monitor is carried by a named SPICE port;
the observed command exposes no separate `-qmp` socket/stdio endpoint. The VM
package top level contains only config.plist, without a saved screenshot. The
installed CLI/SDEF inventory and [UTM scripting guide](https://docs.getutm.app/scripting/cheat-sheet/)
have no display-read command in the inspected interfaces. The
[QMP reference](https://www.qemu.org/docs/master/interop/qemu-qmp-ref.html) documents
`screendump`, but an available connection to it in this installed UTM process has
not been established. This does not prove absence of every possible capture path.

The [capability receipt](../evidence/windows-utm-display-capability.json) preserves
the fresh locked-console flags, process/config pins and an initial absent-alias
read error corrected using the physical path already present in the QEMU command.
No SPICE/QMP connection, guest command, UI input, VM restart or configuration
change occurred. The last actual guest screen remains the approved EULA;
installation is still incomplete. The separate Native loading queue continues.

The [screenshot capability follow-up](../evidence/windows-utm-screenshot-capability.json)
checks installed4.7.5/build118 against versioned public source. The
[CocoaSpice SDK](https://github.com/utmapp/CocoaSpice) supports guest display
screenshots and Unix sockets, but that does not supply an installed capture CLI.
No second client was connected; its effect on the current session is unverified.

The [4.7.5 timer](https://raw.githubusercontent.com/utmapp/UTM/v4.7.5/Services/UTMVirtualMachine.swift)
runs every60 seconds, while the general documentation says30. It calls
[the SPICE capture method](https://raw.githubusercontent.com/utmapp/UTM/v4.7.5/Services/UTMSpiceVirtualMachine.swift),
which updates in-memory image state without saving a PNG. Disk saving is separate;
there is still no screenshot file in this task's VM package. Two named defaults
queries returned an absent domain, so the actual preference values are unknown.

[QEMU VM source](https://raw.githubusercontent.com/utmapp/UTM/v4.7.5/Services/UTMQemuVirtualMachine.swift)
saves the image during default saved-state creation or terminal stop. It rejects
saved states for GL displays and NVMe drives; the pinned VM has both. This is a
source/config inference, not an attempted suspend or a new runtime error.
No suspension, restart, configuration/preference change, guest input, host unlock
or denied-path retry occurred. Process43650 and config remain unchanged. The
receipt preserves the public-tree transport/reader errors separately. Windows
installation and actual font/cursor observations remain open; approval persists.
