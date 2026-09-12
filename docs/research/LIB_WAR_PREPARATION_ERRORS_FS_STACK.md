# War FS environment: explicit flat code/data/stack segments

The four [FS-only probes](LIB_WAR_PREPARATION_ERRORS_FS.md) passed, but the first
normal parent using that GDT failed on its first instruction,41bc90 `push ebp`.
Its terminal job, unchanged690 input pins and complete prefix.failure.json remain
under `war-preparation-fs-errors-s00-capture1`. No menu prefix or resource-error
case completed in that run. The failure does not establish an original game
allocation fault. The previous probe set did not exercise stack instructions.

Before another caller run, extend the controlled environment check to seven
original instructions: retain two FS accesses and two NULL faults, and add the
actual41bc90 push,40c116 flat-data read and43d2fd flat-data write to valid declared
storage. Install explicit32-bit flat CS/DS/ES/SS descriptors along with the
separate FS descriptor. This checks address formation after GDT installation;
it is not Windows CPU evidence or a protection bypass. No original bytes,
failure expectations or historical captures are changed.

Use the same GDT/head bases7d000000/7d010000, CS8, DS/ES/SS10 and FS18. Give each
probe fresh mapped storage and a declared32-bit stack. Successful stack/data
accesses must use their full linear addresses, FS accesses must use the head,
and NULL accesses must terminate at0 without changing any mapped byte. Record
all segment selectors/base, registers, accesses, errors and bytes. Do not resume
faulted VMs. Only after these seven probes pass may fresh normal caller controls
resume the error study. Preserve the first FS driver/probe sources separately.
