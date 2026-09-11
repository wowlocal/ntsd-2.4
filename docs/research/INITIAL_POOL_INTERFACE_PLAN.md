# Initial Actor pool and UI composition

Controlled native acceptance is complete; see [INITIAL_POOL_INTERFACE](INITIAL_POOL_INTERFACE.md). The original finite scope and remaining own boundary below remain in force.

Recover the original ordering of the400 Actor allocations,408 constructor
returns, caller field stores, and subsequent10 UI bitmap loads in41c052..41c581.
The original loader constructs each Actor before requesting the next allocation.
Native callers need the same boundary so owned allocator/device state can be
staged across the complete pool and UI operation.

Reference: the ten immutable cases in
[INITIAL_INTERFACE_SURFACE](INITIAL_INTERFACE_SURFACE.md), pinned NTSD EXE
3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c and VC80
c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d on the declared
controlled Unicorn CPU. All original resource bytes, writes, helper boundaries
and masks remain unchanged. This extension performs no new source execution.

Use the retained memory-write order to reconstruct each actual4061d0 return's
complete Actor bytes and masks. Compare them to native constructor outputs,
including the second construction of slots0..7. Compare allocation size/ordinal
and original constructor order, then all final World/Actor/UI records, complete
globals, platform requests and resource lifetime from the same accepted corpus.
Instruction addresses and writes establish operation order and ownership, not
private C++ ABI, host allocator, hardware FPU or Windows device equivalence.

Implement lazy Actor backing delivery through the existing bootstrap, followed
by the existing complete bitmap surface loader. Stage one value-semantic context
until both pool and UI succeed. The caller's first Object+90 remains a declared
boundary input in these controls; a future own caller must obtain it from its
own loaded catalog. Do not supply expected Actor bytes or unknown source stack.

Finite acceptance: all ten controlled chains and the retained eight bootstrap
layouts must match, including every constructor return. Native-only late Actor
allocation/constructor and final UI failures must retain the caller's previous
context and publish no new pool/UI result. Numeric bitmap failures retain the
original continuation and cleanup behavior. NULL Actor source continuation is
outside this corpus; native thrown allocation failure is not a source match.

The active three own catalog captures and their frozen observer inputs remain
unchanged. Full own catalog/pool/UI composition, whole41bc90 return, application
window, Windows/device runs, full match and all-content checks stay open.
