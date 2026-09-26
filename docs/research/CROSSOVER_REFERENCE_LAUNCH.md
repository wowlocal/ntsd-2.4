# Original NTSD process launched through CrossOver

2026-09-26. Continues [setup](CROSSOVER_REFERENCE_SETUP.md) under its existing
[plan](CROSSOVER_REFERENCE_SETUP_PLAN.md).
[Launch checkpoint](../evidence/crossover-reference-launch.json).

The user explicitly confirmed Rosetta installation and Apple SLA acceptance.
At the next UI read the installation dialog had already disappeared and the
CrossOver main window was open. pkgutil confirms Rosetta1.0.0.0.1788432274,
install-time1790447759. The agent did not click Install; do not attribute that
installation action to it. Earlier pending-consent checkpoint remains history.

CrossOver's bottle directory now points to task-owned X5/Bottles. The documented
XP32-bit creation option was enabled and NTSD24XP created. UI reports Windows XP
32-bit(deprecated), Ready; configuration records Template=winxp, WineArch=win32,
CrossOver26.3.0.39832. This is Wine/Rosetta compatibility, not Windows XP execution.

First launcher32672/child32676 exited1 in0.600s: CLI bottle lookup did not use
the GUI's selected directory. No original game ran in that attempt. The exact
error/log/producer remain. Vendor CXBottle.pm:120–141 supports CX_BOTTLE_PATH;
launch2 supplies that task-owned path to the same unchanged run-ntsd24.sh, keeping
GAME_DIR, EXE_PATH, BOTTLE and original bytes unchanged. This is the third diagnosed
setup correction (after transport and version-field wrapper corrections).

Launch2 wrapper33454 remains identity-verified live; original NTSD process33492
started2026-09-26 21:40:15 Europe/Moscow. Its command and actual cwd both identify
the verified task-owned game copy. All1,595 copied game files still match the
original manifest. The pinned2,599-byte log snapshot includes GStreamer element/
reference-count warnings; no source memory fault or successful menu is inferred.
A live process alone is not playable-game acceptance.

CUA shows the CrossOver bottle but does not expose the separate Wine window in
its app inventory; lookup by NTSD process name failed and Dock inspection timed
out. No other UI-control technology was used. A concise user question asks whether
a menu/loading/error/no window is visible; the answer is pending at publication.
The process was not restarted or killed for silence. Trial was explicitly selected
by the user, but an expiry/activation screen has not been independently observed.

Run NTSD24XP.command in the task directory is a syntax-checked convenience wrapper
for the existing repo launcher with the four exact environment overrides. It has
not been run again; using it while33492 is live would create another game instance.

The independent Windows download2 PID94629 is now terminal1 after1274.885s:
one8MiB request timed out at180s with7,709,645 bytes received. All175 successful
ranges/1,484,783,616 total bytes including prefix are retained; no automatic retry.
NEXT: preserve original launch, resolve visible UI status when available, and
continue Windows transport with smaller missing ranges in a separately pinned
correction. Verify Microsoft's full hash before guest boot; the UTM CD still
references the initial partial. Windows/API/font/cursor/full-frame, Native
integration, input/audio/clean-Mac/match/game and independent review remain open.
No Native code or expected fixture changed. Do not label this process checkpoint
an actual Windows comparison or completed game launch acceptance.
