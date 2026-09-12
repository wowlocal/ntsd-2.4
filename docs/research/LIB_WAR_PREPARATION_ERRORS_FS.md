# War error study: separate FS storage from linear NULL

The first three scenarios of the [error plan](LIB_WAR_PREPARATION_ERRORS_PLAN.md)
are terminal. Normal-primary reproduced the whole accepted Start after removing
only new labels/observer metadata. First-wrapper allocation failure returned,
and the declared next Start99 skipped release of the other four live wrappers.
The replay NULL case exposed an inherited harness limitation, not the intended
unmapped-NULL environment.

`oracle_lib_menu_continuation.py` maps address0..fff for emulated FS:0 and records
four bytes at0. Thus43d2fd actually wrote through NULL into that synthetic head;
later recording writes reached an unmapped address630bc0 at43d382. The complete
fault, writes, masks, registers, files and the three terminal jobs remain in
`war-preparation-errors-preflight1-review.json`. This result cannot establish
the Windows NULL boundary. Do not continue its VM or rerun the same operation
in the old environment. No safety refusal occurred.

Correct the reference environment before any further NULL-result experiment.
The purpose is to represent x86 FS addressing separately from ordinary linear
data addressing. Configure a synthetic GDT descriptor and FS selector whose
base is7d010000, with GDT storage at7d000000. Preserve the same declared four-byte
exception-head initial value12345678 and all original instruction bytes. Keep
linear page0 unmapped. These are controlled emulation inputs, not actual Windows
TEB/CPU behavior, host memory mappings or an attempt to bypass a protection.

First run four isolated original-instruction probes in fresh Unicorn2.1.4 VMs:
the41bc90 prologue's FS head load and store must access the new head, while
40c116 with ECX0 and43d2fd with EAX0 must fail at linear address0. The invalid-
memory observer records and returns false; each fault ends its VM. Decode exact
probe bytes from the pinned EXE and retain bytes/hash, segment setup, memory
accesses, terminal registers and head before/after. No source fault is resumed.

If those pass, integrate the separate FS model in a new study class without
editing the historical source producers or their expected corpora. The existing
host-only return assertion must read the declared FS head address, without
redirecting ordinary source NULL reads. Preserve the original write/read hooks
at the new region, snapshot its bytes/mask and assert page0 stays unmapped.

Reproduce both normal controls and ten-call parents. Compare all original bytes,
masks, events, helper returns and state after an explicit address relocation
normalization limited to the FS head record and source accesses bearing the FS
segment override. The head's content and original code must remain identical.
Do not relabel arbitrary zero-address reads/writes or import expected bytes.
Report the changed environment rather than claiming byte-identical virtual
addresses. Then execute fresh replay-NULL and first/last wrapper failure cases
in this environment before the remaining finite29-case study. Existing captures
remain unchanged and separate. Native and full preparation acceptance stay open.
