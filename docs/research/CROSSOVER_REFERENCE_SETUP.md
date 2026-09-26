# CrossOver installed; Rosetta consent pending

2026-09-26. [Plan](CROSSOVER_REFERENCE_SETUP_PLAN.md),
[publication](../evidence/crossover-reference-setup.json).
User suggested the existing CrossOver launcher, confirmed no installation on this
Mac, then explicitly selected the trial because the license key is unavailable.
No purchase, activation workaround or account creation was performed.

Official CrossOver26.3.0 trial build is now installed in /Applications/CrossOver.app.
Bundle short version26.3, full version26.3.0.39832. The official ZIP387,192,026 bytes,
SHA2568688e0848c4e5f79f1cc351cb52d32447da00c6c00cfd3b4bb2d164d44589a26,
contains8,332 members whose ZIP CRC/path checks passed. Extracted and installed
CodeWeavers signatures verify with codesign --deep --strict; Gatekeeper accepted
the extracted application. No trust, quarantine or security settings were changed.

[CodeWeavers trial](https://www.codeweavers.com/crossover/download) is14 days with
no card required. The [official guide](https://support.codeweavers.com/en_US/crossover-mac-user-guide)
describes standalone EXE launch and bottle configuration. The repo's existing
run-ntsd24.sh targets NTSD24XP/clean distribution. Modern CrossOver26 hides
32-bit bottle creation behind its deprecated-bottle preference; the documented
XP configuration still needs to be created after the application can start.

The first app UI is an Install Rosetta dialog. It explicitly states that
installing Rosetta accepts Apple's macOS software license agreement. Separate
confirmation was requested through the UI confirmation rule and is pending.
Install was not clicked. The trial has not yet been activated through its UI;
no bottle, Windows game, NLS collector or Native application has run in this task.
A user reply authorizing Rosetta is the next dependent step. Do not treat waiting
for that reply as license acceptance or an automatic-approval rejection.

A task-owned game copy already contains all1,595 hash-verified original files.
It is at crossover-reference-20260926/game/NTSD 2.4_2.0a on the existing X5 thread
root. EXE SHA2563f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c;
lib.dll28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba.
Use this copy through GAME_DIR/EXE_PATH rather than executing/writing baseline
assets. Exact names/hashes are pinned in game-copy1.json. The launcher itself
was not changed; installed cxstart remains the vendor's symlink to wine.

## Preserved transport and wrapper failures

First download3760/curl3768 was slow; an exact1MiB HTTP206/Content-Range/ETag probe
completed in6.831s. After process/start/cwd revalidation, original curl was stopped
at18,243,584 bytes, terminal-15 in132.998s. All partial bytes/headers/logs remain.
The corrected transport reuses those bytes and352 fixed1MiB ranges from the same
authorized endpoint; no automatic retries. Download8439 terminal0 in352.627s,
387,192,026 bytes assembled, no failed range. This is transport correction, not a
safety-refusal retry. No historical game capture or affected rejected URL ran.

Install wrapper14060 failed before signature/install because it incorrectly
required the short version field to equal26.3.0. Extraction had completed and the
observed fields are26.3/26.3.0.39832. Original wrapper/error/extraction are retained;
install2 accepts those exact short/full fields and preserves all signature gates.
Install20066 terminal0 in3.994s. No application runtime failure is claimed from
the wrapper assertion. All producer/job/diagnosis records remain on X5.

The independent [UTM task](WINDOWS_UTM_REFERENCE_SETUP.md) remains active:
Windows ISO download94629 was revalidated live when publishing, and UTM's guest
support ISO is now shown attached. The guest remains stopped/uninstalled. Do not
restart this download for silence; replace its partial CD bookmark only after
the complete image matches Microsoft's SHA. Preserve all prior checkpoints.

NEXT after explicit Rosetta confirmation: install it via the pending dialog,
start trial, create the documented bottle, launch the verified task-owned game
through the existing launcher, and record actual menu/failure/process state.
CrossOver output is compatibility-layer evidence, never actual Windows/device
acceptance. Independent review, Windows cursor/GDI/NLS, Native raster/integration,
input/audio, complete match and game remain open. Unrelated Native/catalog53 work
and immutable AGENTS archive are preserved. No Native tests were required.
