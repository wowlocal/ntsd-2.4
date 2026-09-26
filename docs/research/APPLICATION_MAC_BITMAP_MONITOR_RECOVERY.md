# Bitmap build monitor failure and same-process exit observation

2026-09-26. Supplemental to APPLICATION_MAC_BITMAP_PLAN; original plan and all
pinned producers remain unchanged. Native build54930 is not restarted.

The inherited monitor raised AssertionError at `pid=int(a[0]);assert pid!=59727`
while enumerating selected build processes. Source59727 was already terminal
and absent before this build. A numeric PID is reusable. The monitor failed before
recording this new59727 process's identity, so its exact command/start/cwd are
unknown; do not label it as a particular compiler. The parent build54930 remained
live with its exact start/command and owned candidate/native cwd after the monitor
exited. Its first monitor-error job/log stay immutable.

Read-only task observer62380 attached to that same revalidated build through macOS
kqueue PROC NOTE_EXIT|NOTE_EXITSTATUS. Local SDK sys/event.h documents status for
a child or process the observer is allowed to signal; no signal is sent. The
observer takes2-second descendant RSS/space samples, at most600s, retaining the
original12GiB RSS,57GiB external combined reserve,6GiB internal and26GiB observed
decrease limits. It records the actual kernel event and raw wait status. Two
separate controlled child exits0/7 compare that encoding with Popen.wait; these
are observer controls, not source or game execution. There is a monitoring gap
between the failed monitor and this witness: its peak RSS is unavailable.

Once the same build is terminal, retain a separate recovered result with both
provenances. Do not rewrite build1.job.json or infer an exit from a log banner.
If the exit event/status is missing, leave the build gate open. Verify absence of
that process and recorded descendants before package inspection or any new job.

For the still-unstarted48 methods, generate a separately pinned test monitor from
the existing one. Replace only the permanent numeric-PID exclusion with identity
by PID/start time; preserve descendant/cwd/command checks and all test predicates,
selectors, inputs and budgets. Keep the old monitor, queue and planned finalizer
intact. New package/queue/closure adapters explicitly consume the separate exit
receipt and retain the monitor gap. Controlled identity cases must reject the same
protected lifetime, including an exec/changed-command within it, while permitting
a later start with the reused number. No original/capture/build retry is authorized
by this correction, and it does not close independent review or Windows gates.
