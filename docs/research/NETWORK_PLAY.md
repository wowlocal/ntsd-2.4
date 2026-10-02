# Network play in the app — results

[Plan](NETWORK_PLAY_PLAN.md). The original is not executed.

## Resumed priority and independent N1 correction (2026-10-02)

The user lifted the networking deferral in the active goal. The Claude incident
below remains open: the exact withheld operation is unknown. This continuation
does not implement or execute the unfinished N2 window-message route. The
independent operation is a correction to the previously implemented N1 transport:
observe a task-owned TCP peer's abortive close and preserve the error for the
game's subsequent receive. No original EXE, reference harness, native game
session, or application `0x401` handler is executed by this check.

Static review found that `OriginalMacWinsock.readable` handles positive reads
and EOF but drops negative `MSG_PEEK` results. A readiness probe can consume
ECONNRESET, incorrectly turning the next game receive and notification into a
graceful close. Conversely, a game receive can consume the error before the
notification probe. Both orders need to retain the same transport failure.

The platform contract is documented by Microsoft's
[WSAAsyncSelect](https://learn.microsoft.com/en-us/windows/win32/api/winsock/nf-winsock-wsaasyncselect):
FD_CLOSE carries WSAECONNRESET in the high word for a reset. The recovered
[game callback](NETWORK_NOTIFICATION.md#dispatch-and-original-request-order)
ignores that high word but still needs the close event; its implementation and
immutable comparison corpora are unchanged. This is a declared Windows API
contract with a real macOS loopback check, not an actual Windows observation.

Finite correction scope: the existing three N1 tests plus a new loopback case
for reset-before-receive and receive-before-notification, including single
delivery and failed receive. Preserve the failing run, then rerun the affected
service tests after correction. Files owned by this increment: the Winsock
service, its test, this addendum, a short CURRENT_WORK update and evidence.
Pre-existing interface-address changes in those files remain separate WIP.
Application integration and independent review remain open.

Run storage: `/Volumes/X5/ntsd-2.4-research/network-service-reset-20261002`,
APFS UUID `3A4F5FA6-DC86-4C6E-87E2-EAC2C2D72548` verified, approximately
108 GiB free before preparation; 12 GiB new-output bound, preserving the original
40 GiB external and 6 GiB internal reserves. Use the existing SwiftPM/XCTest
test target; build limit 15 minutes, test limit 60 seconds per run, maximum
three correction rounds before diagnosis. The checked consumer is N1's public
receive/notification API; N2 integration remains blocked by the unresolved
incident scope and is not claimed as validated here.

**Result:** [evidence](../evidence/network-service-reset-20261002.json).
Run1 built in 339.62 seconds: the three retained tests passed, the new test
failed twice because both reset orders eventually delivered graceful FD_CLOSE
instead of its error form. Run2 retains the original expectations and adds an
explicit assertion that the notification-first case delivers before game recv;
it passed all four tests in 0.264 seconds after a 171.60-second build. The socket
now owns a reset flag shared by the receive and readiness paths. The notification
reports error 10054 and recv retains the reset failure, following the documented
[recv contract](https://learn.microsoft.com/en-us/windows/win32/api/winsock/nf-winsock-recv).
errno is captured before rearming the observer. No Core rule or comparator changed.
The failing code, both test versions, logs, process identities and actual code
pins are retained on X5. The build included the pinned pre-existing dirty inputs;
the executed scope is N1 only, not acceptance of the dirty application or an
exact committed app package. Independent review remains open.

**Next independent N1 issue:** `release` closes the descriptor immediately after
`source.cancel()`. Apple's
[cancellation-handler contract](https://developer.apple.com/documentation/dispatch/dispatch_source_set_cancel_handler)
requires waiting for the source to release the descriptor before closing it.
Review and correct this lifetime without changing the game's close ordering or
resuming the held N2 routing operation. A repeated successful reset test alone
does not establish safety of that separate lifetime.

## N1 descriptor lifetime correction (2026-10-02)

Independent continuation of the transport correction above; the held N2 route
and the unknown refusal trigger remain unchanged. Target: the Mac service's
own descriptors during cancellation, replacement of a selection, close and
cleanup. No original EXE, reference harness, application callback router or
game session is run. Consumer: the existing public N1 API. Its blocking close
must release the socket before the caller proceeds, without deferring an OS
close until the game next pumps its main queue.

The current immediate `cancel(); close(fd)` violates Apple's cancellation
contract cited above. The correction will use a private readiness queue and
a cancellation completion barrier. Readiness is coalesced while a main-queue
callback is pending; only the current observation may inspect the descriptor.
All game state, recv probes and notifications remain on the main queue. The
readiness queue never waits for the main queue, so closing from a notification
can wait for cancellation without deadlocking. Independent review is open;
static ownership/ordering evidence is separate from finite race-window tests.

Cases: retain the four N1 tests, add close-and-rebind inside an accept callback,
replacement of a read selection and rearming after partial/stale reads, and
32 select/cancel/close or cleanup cycles with immediate port reuse before the
main queue is pumped. Inspect and fix failures within this mechanism; original
expectations and corpora remain immutable. This follows the two reset runs
(one failing, one passing), not a reset of the correction history.

Paths owned: Winsock service/test, this addendum, CURRENT_WORK and evidence;
pre-existing interface-address and application WIP remain separate. New logs
and code pins use `/Volumes/X5/ntsd-2.4-research/network-service-lifetime-20261002`.
Reuse the previous terminal SwiftPM build cache (not a pinned reference artifact)
at `network-service-reset-20261002/build`, preserving all prior logs and inputs.
X5 writable APFS UUID revalidated with 97.1 GiB free; at most 4 GiB additional
outputs, retaining the 40 GiB X5/6 GiB internal reserves. Build limit 15 minutes,
tests 60 seconds; existing SwiftPM/XCTest target and N1 test selection.

**Result:** [evidence](../evidence/network-service-lifetime-20261002.json).
Syntax and diff checks passed. Run3 built in 168.74 seconds; all seven tests
passed in 0.483 seconds. The private `ReadObservation` serializes suspend/rearm/
cancel with a lock, signals a completion group from its cancellation handler,
and never waits for the main queue. Close waits for that group before releasing
the descriptor; notification code can therefore close/rebind immediately.
Main-queue deliveries retain a weak observation and check its identity before
probing a socket. A stale ready indication after a game recv rearms observation;
accept also captures errno before rearming. Existing packet/partial-read/reset
checks remain green. Prior logs and code pins remain intact; the actual dirty
inputs are pinned, and unrelated WIP is not staged. Independent concurrency
review remains open; finite tests do not prove every scheduler interleaving.

Next independent client prerequisite found by reading the existing code:
`OriginalNetworkClient.attempt` requests `hostByAddress(raw4,4,2)` after a failed
name lookup, but the Mac service currently exposes only name lookup. Establish
and implement that platform response from the existing client contract before
any integration; this does not resume the held application notification route.

## Deferred by the user (2026-10-01)

Networking remains in the full scope, but the user has deferred it in favour
of independent work outside networking. N1 is preserved in commit `7727346`.
Partial N2 integration remains uncommitted, including the new
`OriginalMacRuntimeNetwork.swift`; preserve these changes without treating
them as an accepted increment or including them in unrelated commits.
The session reports an app build and limited probes, but these do not establish
N2 acceptance or validate all current working files. N3–N5 remain open.

Claude Code recorded a safety refusal during N2 work at
2026-10-01T18:06:07.306Z. The withheld output and exact trigger are unknown;
nearby file reads do not establish the cause. The
[incident record](../evidence/claude-code-network-safety-2026-10-01.json)
preserves public messages and identifiers. Do not retry or reroute the affected
operation. Deferring networking does not resolve that refusal, and it must not
resume automatically after another task. Continue independent permitted work
under [CURRENT_WORK](CURRENT_WORK.md).

## N1: Mac Winsock service (2026-10-01)

`OriginalMacWinsock` (NTSDMacPlatform) gives the original's WSOCK32 calls BSD
sockets, under the plan's declared Windows behaviour:

- WSAStartup answers wVersion 0x101 and wHighVersion 0x202 in a 400-byte
  WSADATA ("WinSock 2.0", "Running").
- gethostname, gethostbyname (IPv4 address words; 127.0.0.1 is 0x0100007f),
  inet_addr, inet_ntoa, htons.
- socket(AF_INET, SOCK_STREAM, TCP) handles from 0x100, step 4.
- bind with Windows-like reuse of TIME_WAIT ports, listen, accept (which
  inherits the listener's mode and selection), connect, send, recv (what has
  arrived; 0 at close), sendto as send on a stream socket, closesocket,
  FIONBIO and WSACleanup.
- WSAAsyncSelect: non-blocking. FD_ACCEPT is re-armed by accept, FD_READ by
  recv, and FD_CLOSE is posted once. Notifications go to the main queue as
  (window, message, socket, event | error << 16). Message 0 with events 0
  cancels; FIONBIO 0 is refused while a selection is active.

**Checks:** `OriginalMacWinsockTests` (3 tests, loopback) pass:

- startup, names and addresses;
- the host notification's order:
  - FD_ACCEPT, then accept;
  - the 14-byte greeting;
  - on the non-blocking accepted socket, recv returns WSAEWOULDBLOCK before
    the reply arrives, then the 77-byte reply;
  - the 3001-byte table;
  - a 10-byte partial receive;
  - FD_CLOSE delivered to the accepted socket, then recv 0;
- cancelling, FIONBIO, a refused connect and an unknown handle.

Not connected to the app yet (N2–N5). EXE envelope not recalculated.
