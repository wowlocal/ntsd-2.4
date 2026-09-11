# War Start preparation — static evidence only

This follows the unfinished [War setup](LIB_WAR_SETUP_STATUS.md). Recover the
Actor/arena/music/replay preparation beginning at the existing BEFORE43a21f
boundary. No preparation instruction has been executed by this new study;
the574-case setup audit/comparison still requires the unavailable X5 corpus.
This analysis neither replaces that corpus nor establishes a new native match.

Reference: NTSD EXE
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`, lib.dll
`28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba`.
`tools/inspect_war_preparation.py` reads the retained llvm-objdump listing and
verifies every selected byte against the immutable PE. It inspects no process
memory, executes no EXE/DLL, and changes no pointers or protection structures.
Instruction operands are needed to recover destination ownership, stack words,
RNG streams and operation order before composing the existing native helpers.

The finite static result is330 instruction starts covering1359 contiguous bytes
43a21f..43a76d, including alignment. Their SHA256 is
`83413b37066674ac123f19a8d1ba5c31aef0236aa6d53c6169e41a4eaa511697`.
There are15 call sites, not15 executed calls or a branch-coverage claim. The
machine-readable report is
`build/research/lib-war-storage-interruption/war-preparation-static1.json`.
Its parent `static-war4.json` SHA256 is
`763a29121956e3eabf5f2109a58145ca456f5021047cdd7c3ccf12750e0a04d2`.

| Region | Static behavior / dependency |
|---|---|
|43a21f..43a2b5|Clear450bb0/450bb4/menu; GetLocalTime; two sprintf calls; recording notice; clear400 World activation bytes|
|43a2b6..43a304|If44d028==1, draw arena with stream123/range BG-count−2; map BG-count−3 to99|
|43a305..43a3b0|Five-cell unrolled pass over400 activation bytes; assign team slot+10 only when active and existing team0|
|43a3b1..43a42c|Clear450c24..450c04 descending, then450c28; release every BG's layers; load selected arena except99|
|43a42d..43a70b|Eight source seats: status>10 creates CPU at slot+10; positive status≤10 reconstructs the same seat; other status skips|
|43a70c..43a76d|44d034=1 before450bbc=0; clear450bdc; resume stored music; reconstruct inactive20..399; reset input; initialize full recording; jump439e76|

The retained bytes give the actual filename format
`%4d%02d%02d_%02d%02d%02d_Battle`, then `%s.lfr`; the suffix is **Battle**.
The temporary date/name begins at rootSP+84c. SYSTEMTIME begins at rootSP+40.
The six arguments select year/month/day/hour/minute/second, accounting for
each pending push. Recording notice450b70 becomes1 only when450be4 is nonzero;
450b6c clears regardless.

The team-assignment pass follows a normal completed memset(World+4,0,400).
With no intervening World activation stores in this block, its conditional team
writes therefore see zero. This is a static data-flow conclusion requiring
dynamic confirmation; it is not permission to import old active flags or drop
the pass from a whole source observer.

Both participant branches preserve the selected Object and team across the
real4061d0 constructor. CPU uses destination World.Actor[seat+10]; human uses
World.Actor[seat]. Both restore Object+90 into Actor+31c, team into+364/+344,
write+8=75 and activate their own destination. Team1 starts at X100; the other
declared team starts at arenaWidth−100. Z uses [arenaLower,arenaUpper) with
stream125 for CPUs and127 for humans. Preserve the distinct streams and live
slot order. Actor+354 becomes seat+10 for CPU, seat for human. Actor+340 reads
44d754+4*team, which selects the two War multipliers for declared teams1/2.
Actor+308 is200, with a mode-pointer==1 branch setting500.

The x87 literals are retained with exact raw bytes: CPU initial X350, human
initial X400/Y−50, and shared initial Z300. Later FILD/FSTP writes replace X/Z
with the signed integer positions; the human branch explicitly clears integer
Y and floating Y. These intermediate stores and FPU order remain part of the
eventual original comparison, even when their final values are overwritten.
No new hardware/Windows FPU result is claimed.

Caller storage must retain its actual producers.438b90 stores the menu pointer
at root1c,438b9b the mode pointer at root38,438ba6 World at root28, and438e77
the World Actor-table cursor at root3c. At43a2aa, `[esp+38]` occurs after three
pushes and therefore writes **root2c=World+4**, preserving root38. At43a68c,
`[esp+40]` occurs with two RNG arguments pending and reads **root38**, the mode
pointer. The CPU controller expression uses `(World+4+seat)+(6−World)=seat+10`.
These are static provenances, not recovered whole private-stack contents.

The final43d2c0 call receives mode, World+4 and the Actor-table cursor. It must
retain the existing complete recording ownership/bytes and cleanup contract;
it is not a menu-success stub. Likewise40c0e0/40c030 must preserve real layer
Release/free/load ordering, and4025b0 must retain the selected music behavior.
There is no ret in this block:43a769 joins439e76, then the existing War/common
menu return and output still run.

Dynamic preparation work must first establish a reproducible original parent
at the actual saved43a21f boundary, after auditing setup. Do not recapture the
completed574-case corpus to replace unavailable storage. The source continuation,
full read/store/REP/FPU/helper evidence, all owned Native records/masks, CPU/human
slot distinctions, arena release/reload, recording, late rollback and actual
outer return remain unverified. A finite dynamic manifest must be frozen after
those parent inputs are available.43a860 War gameplay and the full game remain open.
