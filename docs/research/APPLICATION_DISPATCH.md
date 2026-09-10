# Application dispatcher prerequisites and embedded World

The whole application dispatcher43e9a0..43ed01 is still open. This study
compares its service-key prefix, the complete401250 surface-clear helper,
and the explicit446300 World initializer at their declared boundaries.
It also recovers the storage binding that a fresh whole-dispatcher join must
use. The accepted loaded-gameplay chain cannot simply be renamed as that join.

[OriginalApplicationKeyScan](../../native/Sources/NTSDCore/OriginalApplicationKeyScan.swift)
is shared with [APPLICATION_SERVICE_KEYS](APPLICATION_SERVICE_KEYS.md).
This additional corpus has4348 prefix exits, including arbitrary signed
sequence/diagnostic/mode values and seeded keyboard bytes. Native compares
all50088 global bytes after each call and all9847 ordered source stores.
The retained chains and late observer rollback from the earlier3964-case
study remain a separate check of the same implementation.

[OriginalSurfaceClearing](../../native/Sources/NTSDCore/OriginalSurfaceClearing.swift)
implements whole401250..401281. Across420 original returns, native compares
the complete100-byte effect record, its write mask, target, flags and HRESULT.
The existing World constructor independently matches the explicit static
initializer over the original image's zero-filled backing.

## Source and declared boundaries

The reference is the pinned NTSD2.4 EXE, SHA256
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`,
under Unicorn2.1.4. The source executes these three operations separately.
It does not execute the whole dispatcher, CRT initialization table or an
initialized application. CW023f is supplied, not established by that startup.
The COM callback returns declared HRESULTs. The constructor's4450a0 memset
uses the inherited declared adapter; no CRT memset instructions are counted.

| Compared source operation | Calls | Actual original instruction starts |
| --- | ---: | ---: |
|Service-key prefix43e9db..43ea95|4348|57|
|Clear401250..401281/ret|420|17|
|Initializer446300 and World constructor419e40|1|14|

Stops and adapters are excluded from these executed-PC counts. A fresh
llvm-objdump inventory verifies the actual PE bytes of236 whole-dispatcher
instructions,26 instructions in43e8e0,17 clear instructions and14 initializer/
constructor instructions. Static inventory is not execution coverage.

The key corpus crosses eight sequence values (INT32_MIN,-1,0,1,2,3,4,INT32_MAX),
four diagnostic values (-1,0,1,2), five modes (-1,0,1,2,3) and17 key patterns:
2720 calls. Another1500 calls press every index0..<300 from each sequence0..4.
The remaining128 seeded cases include byte values0,1,99,100,101,117,127,255 and
arbitrary signed state. The native API retains their UInt32 bit patterns.
Only byte100 is pressed. The scan reads0..<250 in order; indices250..<300
are unchanged. An invalid sequence resets only when a pressed key is visited;
without one it remains unchanged. Any nonzero diagnostic flag permits the
ordered F1/F2/F3 mode writes. The complete217782624 compared global bytes
include preserved storage outside those three words.

The clear corpus crosses three valid targets, seven colors, four complete
local backings and five HRESULT values: INT32_MIN,-1,0,1,INT32_MAX. Targets
are controlled surface objects. Globals, saved registers, caller arguments,
return PC/SP and unchanged CW are checked by the source producer. This is a
COM request comparison, not Windows raster or native device execution.

## Full-surface clear

401250 allocates100 bytes, writes size100 at offset0 and color at offset0x50,
and calls target vtable+0x14 with null destination rectangle, null source
surface, null source rectangle, flags0x1000400 and that effect pointer.
There is no viewport rectangle. The other92 effect bytes retain the supplied
caller backing. Native preserves every byte and marks only the two DWORDs
written. All42000 effect bytes and masks are compared.

The signed HRESULT is returned unchanged, including failures. The source
uses cdecl return: it removes its local record and return address, leaving
the caller's two arguments. The native request represents the fixed null
rectangle/source semantics without inventing a source surface. A null native
target is explicitly unavailable; this guard is not a compared source fault.
The supplied92 retained bytes are a controlled boundary, not recovered own
outer-caller stack storage. That lifetime must be recovered for a full join.

## Actual embedded World provenance

At43ecb5 the original loads ECX=458b00 before calling4246b0. This World is
embedded in the PE .data section, not allocated at the accepted harness's
22000020 address. Its2008-byte extent starts47872 bytes into .data, beyond
that section's8192 file-backed bytes and within its50980-byte virtual extent.
Every byte therefore comes from the image's zero-filled virtual tail.
The SHA256 of these2008 bytes is
`e991c0a37471f8f9fe6763f2427c9b16725ba1401c9b8be930840c14a5feb9a9`.

The image contains pointer446300 at4472d0. Calling that actual initializer
loads ECX=458b00 and jumps to419e40. The constructor writes World DWORD0 and
clears400 bytes at World+4 through the declared memset adapter. Its resulting
bytes remain zero; its constructor-write mask covers404 bytes, leaving1604
unwritten. That mask tracks constructor writes, not whether the loader's
remaining zero-fill was readable. Native uses
[OriginalStateRecord.worldPrefix](../../native/Sources/NTSDCore/OriginalStateRecord.swift)
over independently recovered zero-fill and compares the entire bytes/mask.

This proves the explicit initializer and image storage. It does not prove
when the CRT walks4472d0 relative to other initializers, the lifetime of other
outer globals, or all later accesses to this World. The accepted initialized
harness intentionally used separately constructed backing and an address at
22000020. A new original startup path must establish the actual static object
and its subsequent own state. Neither copying expected World bytes nor
injecting an alias into the old parent would establish that provenance.

## Remaining whole dispatcher

The byte-checked236-instruction inventory preserves the following order:

1. Service-key scan, followed by44dce4==1 calling43e8e0. That helper queries
   global455634 through vtable+0x54, clears455608 and emits an original debug
   string selected by the clear result. Its whole execution is now compared in
   [APPLICATION_ART_SETUP](APPLICATION_ART_SETUP.md); initialized stack provenance
   and this enclosing dispatcher remain open.
   The enclosing branch then writes458440=1,44dce4=2 and4593a0=0.
2. Clear the live global455608. Ordinary color is0; mode1 outside that special
   branch uses0x2945. Reread mode after the clear callback.
3. Mode1 can read data/data.txt, scan its marker and path into4589c8, allocate
   four0x25360 objects and call4143d0. It calls4151d0 with ECX458af9 and six
   arguments. These loader/editor operations are open dependencies.
4. Reread mode. Mode0 calls4246b0 with ECX458b00 and the live455608 target.
   Reread mode again; mode2 calls414b70 with ECX458af8 and that live target.
5. Restore SEH/cookie state and return at43ed01. On normal ABI-preserving
   paths EAX is the retained EBP value1; nested HRESULTs are not propagated.

Those mode tests are separate live reads, not one captured switch: a callback
can affect subsequent routing. The body contains no direct read of its incoming
stack argument; target loads shown above use455608. Whole-stack and callback
lifetime recovery remain necessary before a native whole-dispatcher claim.
The controlled negative dispatcher responses in [APPLICATION_TIMER](APPLICATION_TIMER.md)
remain declared responses, not evidence that43e9a0 normally returns a negative
nested HRESULT. The whole join plan remains [APPLICATION_TIMER_PLAN](APPLICATION_TIMER_PLAN.md).

## Reproduction and validation

Run [inspect_application_dispatch.py](../../tools/inspect_application_dispatch.py),
then [oracle_application_dispatch_prefix.py](../../tools/oracle_application_dispatch_prefix.py).
[verify_application_dispatch_prefix.py](../../tools/verify_application_dispatch_prefix.py)
checks the pinned PE template and static bytes, every compressed blob, complete
source stores and preserved globals, all clear bytes/masks and actual initializer
pointer. [accept_application_dispatch_prefix.py](../../tools/accept_application_dispatch_prefix.py)
runs native comparison before publishing the lossless fixture. The source
report is [application-dispatch-prefix.json](../evidence/application-dispatch-prefix.json).
The complete byte-verified static inventory and World section provenance are
retained in [application-dispatch-static.json](../evidence/application-dispatch-static.json).

The initial isolated build encountered a concurrent API replacement: its
harness still expected OriginalApplicationServiceState while the shared scanner
had changed. That terminal compilation failure is retained. The corrected
harness uses the committed OriginalApplicationKeyScan from a11f571, comparing
its ordered observer stores as well as state and complete globals. The source
corpus, expected results and scanner algorithm were unchanged. No duplicate
scanner was added.

Raw source is16337221 bytes, SHA256
`30e76519aa2ccd44c1895fd1c8983eb48079ba888aec5abf57fc4ea6be2d5d58`.
Lossless packed10247264 bytes, SHA256
`6641395c9aea0ce49b06577a988e2034339a4582a089a438a3d3b3eab8738ecd`.
All195 prior fixture pins remain unchanged;196 at publication. Independent
verification checks complete restored raw bytes/JSON/lengths/SHA, all4853
internal blobs and10 codec vendor hashes. Fixture transport remains separate
from the game's replay codec. The three raw release tests pass4.258s after
a176.63s build. The stable native-only30ce08e export verifies500 committed
files and adds the three committed scanner implementation/test/fixture files
from a11f571 plus this study's code/test/fixture, excluding active gameplay work.
The final packaged five release tests pass4.452s/build173.02s without either
raw override: this study's three tests plus the retained scanner corpus/chains
and late observer rollback. NTSDNative linked. Source capture and both final
SwiftPM comparisons are terminal0; the initial compile failure is also terminal.
Exact package hashes and job records are in
`build/research/application-dispatch-work.json`.

The full dispatcher, fresh own static-World startup, editor branches, timer/
message-loop join, complete match/content, native application window, input/
audio timing, Windows/device and clean-Mac checks remain open. Linking
NTSDNative is not evidence of any of those application behaviors.
