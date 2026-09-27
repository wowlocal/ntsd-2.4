# Loading-audio package source-count correction

2026-09-27. The frozen candidate2290 and release build53067 are unchanged.
Build53067 returned0 in309.8542305s with no guard/signals/live process group.
The first package verifier stopped before publication at its old hard-coded
source counts206Core/289Tests. The declared21-path patch adds4Core/2Tests, so the
candidate and build correctly contain210Core/291Tests. Reference61/Mac11 and
385fixtures/1301runtime resources are unchanged.

Preserve the failed verifier and exact AssertionError/traceback separately.
No package acceptance or Native test execution follows that failed invocation.
Its PID/start time were not recorded by the standalone verifier; do not invent
them. This is a verifier adaptation error, not a Native mismatch or source fault.

Use a separately named package2 verifier whose only body change replaces those
two source counts. Preserve all candidate membership/hash, fresh output, linked
binary and1686 resource-byte checks. Pin both producers and their exact diff,
the candidate/plan/build and this amendment before execution. Keep the original
context/runner pins unchanged. The new read-only verification is bounded at600s,
with the existing121GiB X5/6GiB internal reserve and less than4MiB new metadata.
If it passes, resume the same frozen151-method queue; no build/source restart.
The finalizer must verify the correction receipt in addition to old input pins.
Independent review remains open; author count arithmetic is not that review.
