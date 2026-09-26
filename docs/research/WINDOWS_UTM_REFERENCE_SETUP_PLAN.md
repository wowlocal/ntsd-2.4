# UTM Windows reference setup

2026-09-26; base HEAD2255ba5. User authorized Windows setup in UTM and reports UTM
installed; also points to the existing CrossOver launcher. This is reference
infrastructure for original first-menu cursor/GDI/device observations and the
prepared NLS collector, not shipping runtime or a Native compatibility result.
Read WINDOWS_REFERENCE_PLAN/PREPARATION, first-menu raster contract, archive
2128–2143, README CrossOver section and NTSD24_CROSSOVER_ERRORS_AND_SOLUTIONS.

## Bounded work

Inventory existing environments; prepare one named NTSD reference VM in UTM4.7.5
on Apple Silicon/macOS27.0 (26A428), maximum4vCPU/8GiB RAM, thin64GiB guest disk.
Use an official Microsoft Windows11 ARM64 ISO; record version/language/SHA and
verify against the vendor hash before boot. The independently accessible retail
ISO page is https://www.microsoft.com/en-us/software-download/windows11arm64.
The old rejected IoT redirect2276103 is not retried through any tool; that incident
and its affected download stay open. No installation/security-check bypass,
fabricated registration/credentials, unapproved license purchase or activation.
Stop at any genuinely required user credential/terms action while continuing
independent preparation. No source/harness refusal is cleared by this task.

Use task-owned X5 directory windows-utm-reference-20260926 under existing thread
01a0dc49-738f-7972-8fb0-e98fb2f34408 for VM/configuration/evidence (72GiB physical
ceiling). ISO/download artifacts go to /Volumes/T7/ntsd-2.4-artifacts/
windows-utm-reference-20260926 (16GiB ceiling). Both writable mounts and their
AGENTS UUIDs verified in context1.json; retain40GiB each, internal6GiB, and17GiB
source commitment. Never format/repartition either physical disk, touch unrelated
videos, remove evidence or alter pinned producers. Limit each download to2h;
inspect progress/process identity and preserve failed/partial output. Setup may
span turns; no automatic restart for silence. Three diagnosed setup corrections
before revising the plan. No current guest existed at inventory.

Guest gets no host home/workspace mounts or credentials. Use explicit read-only
transfer media for collector/game copies and isolated task-owned output. No NIC
by default; if the supported installation needs connectivity, document its scope
and disconnect before original game execution. Windows ARM x86 translation,
virtual display/audio, host display scaling and exact versions are explicit
provenance, not physical x86 hardware/Windows XP evidence. Normal OS installation
and starting the game do not authorize unrelated system operations.

The original baseline EXE SHA256 remains
3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c; lib.dll remains
28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba. Do not run from or
modify baseline assets: copy and verify into task-owned environment. The CrossOver
README's NTSD24XP/clean-path recipe may be used if its installation is available;
historical troubleshooting changes to DAT/EXE are not current instructions and
are prohibited for the baseline. CrossOver observations stay separately labelled.

## Verification and handoff

Confirm VM registered under intended name/path, resources/firmware/TPM configuration,
actual installer/guest state and terminal/live process records. Hash downloaded
ISO, explicit transfer inputs, scripts and result artifacts; preserve failed
attempts. Record a partial setup honestly if installer needs user action or an
image cannot be obtained. VM boot alone is not Windows/API/game acceptance.

Actual NLS capture follows existing collector plan; original cursor/text capture
requires a separate finite plan once OS environment exists. No Native files or
expected fixtures change in this setup. Independent review is unavailable and
stays open. Commit checked setup/docs increment with exact unresolved gates;
full original comparison, Native raster, integration and complete game stay open.
