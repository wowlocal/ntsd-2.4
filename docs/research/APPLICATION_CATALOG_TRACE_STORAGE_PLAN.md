# Preserve the live catalog capture while moving trace storage

The full own library catalog remains required for the native application join.
Candidate5 is the existing controlled NTSD EXE/lib.dll/VC80 Unicorn2.1.4 process
started2026-09-11T08:56:40UTC, Python78863/UV78860/wrapper78850. It is still
executing the unchanged original catalog load, with a declared synthetic clock,
fixed source/API inputs,20000-chunk bound and6GiB research storage reserve.
Previous storage-limited captures are not whole native/source matches.

The internal volume has about8GB free. The mounted local APFS volume X5 has
about245GB free, UUID3A4F5FA6-DC86-4C6E-87E2-EAC2C2D72548. Create only a new
task-owned research directory there. Do not inspect or edit unrelated contents.
Move the growing candidate5 trace transport into that directory while keeping
its original repository pathname as a symbolic link. New isolated study outputs
and builds may also use this task area. This is development storage, not a
dependency of the native shipping app or its original game resources.

Why process inspection is needed: TraceLog writes a temporary file, renames it,
then updates its index. Copying during that sequence could retain an incomplete
part or leave an open writer on the old inode. After revalidating the exact
process identity, suspend only Python78863 with SIGSTOP. Confirm state T and
inspect its open descriptors. If any trace file or directory is open, resume
immediately and leave the original directory untouched. No emulator memory,
register, instruction, virtual protection, original API result or input changes.
Host elapsed-time logs will include this pause; this is not a CPU/device measure.

Finite migration:

1. Save source job, producer/input pins, volume identity and exact source/target
   paths before operating. Revalidate all890 frozen catalog inputs and ownership.
2. Suspend the same live worker, prove no open trace descriptor and no unfinished
   temporary trace file. Record every file's bytes/SHA, mode and mtime and every
   index's complete contents. No source restart or recapture.
3. Copy every trace file to the new task directory, verifying full byte equality,
   SHA, mode/mtime and exact filenames. Abort before publication if the pause
   exceeds45seconds or any check fails. The original remains available.
4. Rename the local directory to a uniquely named backup, publish the prepared
   symbolic link, and verify the entire inventory through the canonical path.
   Resume the same worker in a finally block on success or error; roll back the
   canonical path before resuming if publication fails. Keep the local backup
   until new trace writes and increasing chunk counts are observed from this PID.
5. Independently check every copied immutable part and each saved index prefix
   against the continued external directory. Only after these pass may the
   redundant migration backup be removed, retaining all original readable paths,
   file bytes/masks, immutable parts and index history. Record actual free space.

Acceptance is transport continuity and preservation, not a new game-compatibility
match: identical existing parts, valid increasing index prefixes, same PID/start
identity, new source chunks/parts after resume, unchanged producer/all890 inputs
and unchanged reserve/chunk/checkpoint settings. Preserve exact errors/refusals;
do not retry a refused operation. An absent worker or changed input aborts this
plan. No arbitrary corruption, fault continuation, protection bypass, Windows,
device or full-catalog-return claim is authorized or implied by this operation.
