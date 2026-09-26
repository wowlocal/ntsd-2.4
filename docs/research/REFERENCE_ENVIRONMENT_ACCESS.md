# Reference environment: application access boundary

2026-09-26. Continues [environment preparation](REFERENCE_ENVIRONMENT_CONTINUATION.md).
[Verified checkpoint](../evidence/reference-environment-access.json).

The user explicitly authorized AppleScript/System Events to control the existing
Wine/NTSD window. PID33492, start21:40:15, executable, cwd and launch2 job were
revalidated. The first bounded query timed out with AppleEvent -1712. A separate
service-version query then returned System Events1.3.6; the process-only query
identified NTSD2.4.exe/PID33492 and reported UI elements enabled=false.
The window-only query returned `osascript is not allowed assistive access. (-1728)`.
These outcomes are retained separately; no OK press or game restart occurred.

CUA inspection of System Settings confirms Ghostty's switch is off under
Privacy & Security > Device Control and Data Access. This macOS27 permission is
broad, including control of apps and access to their data. The settings page was
prepared, but no permission was enabled. An action-time confirmation asks whether
to enable that access or let the user dismiss the game's dialog manually.
The previous AppleScript-method question is answered and must not be asked again.

While checking whether an OS permission prompt had appeared, a CUA request for
Ghostty itself returned exactly:

> Computer Use is not allowed to use the app 'com.mitchellh.ghostty' for safety reasons.

The [new refusal record](../evidence/codex-cua-ghostty-refusal-2026-09-26.json)
retains the operation, response, available context and timestamp uncertainty.
Ghostty UI access is stopped; do not retry it through AppleScript or another tool.
This tool refusal is distinct from the macOS assistive-access error encountered
by the already authorized, separately scoped Wine query. Neither user permission
nor independent progress clears the Ghostty refusal. The historical
[refusal register](../evidence/codex-safety-incidents-2026-09-12.json) remains intact.

Windows download3 PID60299 is verified live by process identity/cwd and its
existing tool handle. At the checkpoint it retains3,048,210,432 verified range
bytes; full ISO/vendor SHA acceptance is pending. No producer or successful range
was restarted. UTM's CLI and UI both report the reference VM stopped, with no NIC,
host shares, clipboard or USB sharing. CD2 is labelled utm-guest-tools-latest.iso;
its hash/content are still unverified. A private-container filesystem read was
denied, and no alternate filesystem access was attempted. The CD browsing dialog
was cancelled without changing either attached image.

NEXT: continue observing the existing ISO download and resolve the actual OS
permission or manually dismissed dialog after the user's reply. Preserve current
game and source bytes. Independent review, Windows/API/font/cursor/device,
Native integration and the complete match/game remain open. EXE envelope was not
recalculated; no Native code or expected fixture changed.
