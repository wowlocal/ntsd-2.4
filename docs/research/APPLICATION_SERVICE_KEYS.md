# Application dispatcher service-key scan

[OriginalApplicationKeyScan](../../native/Sources/NTSDCore/OriginalApplicationKeyScan.swift)
matches3964 original43e9db..43ea95 prefix exits and9278 ordered global stores.
This is the service-key scan before surface clearing and dispatcher routing.
It is separate from local player-command input inside4246b0.

The pinned NTSD2.4 EXE, SHA256
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`,
executes under Unicorn2.1.4. Declared inputs are acquired300-byte keyboard
state, sequence0..3, diagnostic0/1 and dispatcher mode0..2. No pointers,
security structures or fault stimuli are changed. This prefix has no imports
or helper calls. Low-level reads and stores establish scan order, retained
sequence behavior and function-key precedence. All57 instruction starts in
this slice execute; the43ea95 stop is excluded. The full dispatcher has236
byte-checked static instructions, not236 dynamically covered instructions.

The original scans indices0..<250 in ascending order and recognizes byte100.
It does not consume keys or detect press edges here. A advances sequence0 to1;
B advances1 to2; C advances2 to3 and enables diagnostics. Repeating the last
accepted key retains its stage. Other pressed keys reset the sequence, while
an empty scan retains it. Once diagnostics is set, an interrupted sequence
does not clear that flag. Keyboard indices250..<300 are not read by this slice.

The source first stores diagnostic450bec, then sequence4593a4. If diagnostics
is nonzero, it checks F1/F2/F3 in that order and writes mode4593a0 as0/1/2 for
each held key. Multiple mode stores remain observable; F3 is last when all
three are down. Those keys also participated in the preceding250-key scan.

| Compared observation | Count |
| --- | ---: |
|Prefix cases|3964|
|Actual keyboard reads|997303|
|Diagnostic stores|3964|
|Sequence stores|3964|
|Mode stores|1350|
|Retained multi-call sequences|3, with28 calls|

The finite corpus crosses all64 combinations of A/B/C/F1/F2/F3 with the four
sequence, two diagnostic and three mode inputs. It also presses every single
key0..299 from each sequence/diagnostic input, and retains three multi-call
chains. Source observers reconstruct the entire50088-byte global region from
the original PE template, declared inputs and ordered stores. Every remaining
byte and all300 keyboard bytes are unchanged. Slice ESP and output registers
are checked; CW023f is controlled input, not initialized application evidence.

Native owns the three semantic fields independently. In retained chains it
uses its own preceding result. A late observer throws after diagnostic and
sequence stores and all three mode requests; all native fields retain their
entry values. The source corpus contains no such observer exception. The
caller must buffer external effects until its encompassing transaction commits.

The loaded-match global record ends before4593a0/4593a4. This prefix API does
not enlarge that record or import source storage to supply outer application
ownership. The complete dispatcher, loader/clear callbacks, fixed World458b00
initialization and the actual timed/device join remain separate dependencies
in [the plan](APPLICATION_SERVICE_KEYS_PLAN.md) and
[APPLICATION_TIMER_PLAN](APPLICATION_TIMER_PLAN.md). There is no whole-game,
Windows, app-window, input-latency or clean-Mac claim here.

Source: [oracle_application_service_keys.py](../../tools/oracle_application_service_keys.py).
Static byte inventory: [inspect_application_dispatcher.py](../../tools/inspect_application_dispatcher.py).
Independent validation: [verify_application_service_keys.py](../../tools/verify_application_service_keys.py).
Acceptance: [accept_application_service_keys.py](../../tools/accept_application_service_keys.py).
Report: [application-service-keys.json](../evidence/application-service-keys.json).

Raw source6762062 bytes, SHA256
`d5b8cd63d5c98dc10fd00dd6aa8923162e1b20d1d43be7859a1fd0aa96bc0961`;
lossless packed485739 bytes, SHA256
`99fdf9a2d8079144ed21734631621b9f1820b5e6dc718d8dd5bb6f82023f25ec`.
All194 prior fixture pins are unchanged;195 at this milestone. Full restored
bytes/JSON/lengths/hashes and all10 codec vendor files independently verify.
Transport deflation remains separate from the game's replay codec.

The native-only30ce08e export adds only this implementation/test, excluding
unfinished active and dispatcher work. Two raw release tests pass0.086s/
build174.13s. The public type was subsequently named OriginalApplicationKeyScan
to avoid a name collision with concurrent dispatcher integration; its algorithm
and source corpus are unchanged. Exact package hashes, final packaged check
and job outcomes are in `build/research/application-service-keys-work.json`.
The final packaged two release tests pass0.065s/build180.90s after that rename,
without the raw override. Source and both SwiftPM jobs are terminal0. NTSDNative
linked; no application window or device was exercised.
