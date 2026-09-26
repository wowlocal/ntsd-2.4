# Reference prerequisites and observed dialog dismissal

2026-09-26. Continues [the access checkpoint](REFERENCE_ENVIRONMENT_ACCESS.md)
and [UTM preparation](WINDOWS_UTM_REFERENCE_SETUP.md).
[Verified publication](../evidence/reference-prerequisite-preparation.json).
This is environment preparation, not a new engine rule or Windows comparison.

The user authorized Ghostty's Device Control and Data Access permission. On
reinspection its switch was already on; the agent did not toggle it. Scoped
AppleScript then reported UI access enabled and identified the existing NTSD
PID33492, its ERROR dialog and Little Fighter 2 window. After checking process
identity/start/cwd and the frontmost ERROR title, one Return was sent at
19:17:54 UTC. The 19:20:18 query subsequently reported only Little Fighter 2,
with bounds 3,31,794,578. No game restart or further game input occurred.

A window-only screenshot failed with `could not create image from rect (1)`.
The exact rectangle was not retained before failure; its cause is unknown.
Later AX queries reported zero windows for the still-live game and explorer.
This does not establish failed execution or successful menu/gameplay. The user
mentions the CrossOver launch; the agent has not independently observed a menu.
All query, wrapper and capture failures remain in the published manifest/archive.
The separate [Ghostty CUA refusal](../evidence/codex-cua-ghostty-refusal-2026-09-26.json)
remains open; no Ghostty UI retry or alternate access was attempted.

The retained Visual C++ 2005 SP1 x86 redistributable was prepared for the future
Windows guest, using the exact input from [CRT_SCANNER](CRT_SCANNER.md). Its
2,710,520 bytes have SHA256
8648c5fc29c44b9112fe52f9a33f80e7fc42d10f3b5b42b2121542a13e44adfd,
matching the repository LFS pointer and prior study. The existing .6195 publisher
policy covers the EXE's requested .762; actual Windows assembly binding is still
unobserved. Microsoft's [product page](https://www.microsoft.com/en-gb/download/details.aspx?id=26347)
identifies the package. No fresh vendor-byte comparison is claimed.

Preparation95947 completed0 in0.435s within32MiB, with four retained inputs
unchanged. The embedded PKCS7 certificate metadata contains Microsoft Corporation;
this is not Authenticode content or chain verification. Before execution, the
guest must verify its file hash and a Valid Microsoft Authenticode signature.
No installer or original DLL executed in this preparation, and no EULA was accepted.

NTSD-VC80-Prerequisite.iso is2,766,848 bytes, SHA256
4cc9d606264cf4e9987bea2b12b0795036f0b7b5ce92278be0027d966fc179ca.
Its three files (installer, README and provenance manifest) were mounted read-only
and verified for exact membership and bytes; the owned mount was ejected.
The publication archive separately verifies45 retained metadata members. These
gates do not establish Windows execution, signature trust or compatibility.

The attempted addition of two optional simultaneous USB CD drives did not
complete: after selecting Removable, UTM exposed merged AX controls and subsequent
button/keyboard actions added no drive. The interrupted initial interval and
bounded continuation are recorded. The final sheet was cancelled; config bytes
are identical to the original3396-byte file, SHA256
640f64c8dac3c7d79b4a7c78b6287e378dc9db33c797c7cbdaef9c96be7538e6.
The two verified transfer/prerequisite images remain ready for ordinary media
selection through an existing CD drive. The VM is stopped; no guest boot,
network/share change or new disk allocation occurred.

Windows download3 PID60299 remains live, revalidated by OS identity and cwd;
its checkpoint contains6,986,661,888 accepted bytes of7,994,415,104. The previous
tool polling handle returned `Unknown process id 51478`; this is a handle error,
not process termination. No producer or completed range was restarted. Full ISO
vendor SHA verification remains required before replacing the partial CD/booting.

The user questioned Windows11 compatibility, then left the choice to the agent
and retained CrossOver as an option. Windows11 ARM compatibility is unverified;
its x86 translation and virtual devices must remain explicit in future evidence.
CrossOver remains useful for original-game observations, with Wine provenance.

NEXT: observe the existing download, verify the complete ISO, replace the partial
CD and perform ordinary guest setup. Use a bounded separate plan for actual
Windows NLS/font/cursor observations and original-game compatibility. Independent
review, Native raster/root promotion, input/audio, clean-Mac, full match and game
remain open. No Native code, source fixture or historical expected bytes changed;
no Native build/test or EXE-envelope recalculation was warranted by this increment.
