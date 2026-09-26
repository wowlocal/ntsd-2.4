# Verified Windows ISO reaches the installer

2026-09-26. Continues [reference prerequisites](REFERENCE_PREREQUISITE_PREPARATION.md)
under [the setup plan](WINDOWS_UTM_REFERENCE_SETUP_PLAN.md) and the retained
guest-setup1 plan. [Publication](../evidence/windows-utm-installer-start.json).
This supplies the prospective environment for bounded NLS and first-menu GDI/
cursor observations; it does not execute the original game or accept its behavior.

Download3 PID60299 completed0 at19:39:44 UTC after2622.423s, with no failures.
The176 retained ranges and6209 new ranges cover exactly7,994,415,104 bytes without
gaps or overlap. Producer assembly verified each part; a separate full-file read
then reproduced Microsoft's SHA256
638aa2c88e94385b00f4f178d071e3df0b7d9e335577a83bd533b7f2eb65adf0.
The completed file is Win11_25H2_English_Arm64_verified3.iso on authorized T7.
The original16MiB partial, failed download2 range and all producer/input records
remain unchanged. No completed source or successful range was restarted.

The independent verification took8.343s. The34,549,760-byte PAX publication
archive separately round-trips12,432 members: terminal metadata, setup records,
producer/plan/input manifests and retained download3 response headers/logs.
SHA2567d74312806706ba1485fcf058a5d237db38f211ca02a80241e721b8ddaf16ec6.
The ISO and range bodies remain external regular files, not runtime fixtures.
The archive remains task-owned on X5; signed download access information is not
published into Git. Setup metadata stays within64MiB; prior reserves/VM bounds
remain unchanged.

UTM's first CD now visibly names the verified3 image. Its QEMU command independently
confirms that exact path with media=cdrom/readonly=on. The VM config remained
byte-identical before boot;4CPU/8GiB/64GiB thin disk, no NIC or host shares remain.
QEMU43650 started22:40:45 local time (Europe/Moscow), with identity/cwd recorded.
There was one VM boot, followed by ordinary firmware media selection, not resets.

The initial automatic boot reached UEFI shell. Exiting to Boot Manager and
selecting the first USB CD displayed the normal press-any-key invitation, but a
separate tool-call acknowledgement returned to firmware. A separately recorded
second selection acknowledged the invitation within the same tool call and
reached Windows11 Setup. This establishes a successful installer boot; the exact
cause of the earlier missed transition is not proven. No firmware/security/setup
checks were bypassed. The [UTM guide](https://docs.getutm.app/guides/windows/)
describes the ordinary CD invitation; its optional bypass recipes were not used.

The installer uses English (United States), US keyboard and the default Windows11
Home edition. Its official "I don't have a product key" path was selected; no key,
purchase or activation was fabricated. This is not evidence of an evaluation
license or Windows activation. The next screen is Microsoft's license agreement,
labelled Last updated April2024. Accept has not been pressed. Action-time user
confirmation is pending; prior Rosetta agreement acceptance does not cover it.
No guest OS installation, VC80 installer or original game execution is claimed.

CUA text entry/paste in the host file chooser failed; exact paste timeout and
partial-path observations are preserved. Navigating observed T7/task folders with
their exposed Open Finder item actions completed the selection. This was ordinary
UI error handling, with no other UI technology or Ghostty access. The separate
Ghostty CUA safety refusal and earlier IoT endpoint refusal remain open.

NEXT after actual Windows-EULA approval: continue ordinary installation inside
this isolated VM; preserve any actual setup/account/network boundary. If approval
is declined, retain verified media and use the available CrossOver environment
within its own provenance. Windows11 ARM game compatibility, real OS NLS/font/
cursor/device observations, guest-tools verification, independent review, Native
raster/root promotion and full match/game remain open. No Native code/tests or
historical source fixtures changed; the EXE envelope was not recalculated.
