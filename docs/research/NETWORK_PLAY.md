# Network play in the app — results

[Plan](NETWORK_PLAY_PLAN.md). The original is not executed.

## Current next step (2026-10-02)

N2 is implemented and checked below; continue N3 client integration using the
existing service and recovered client contract.
The earlier blanket hold on N2–N5 was an unsupported interpretation of the saved
Claude incident and has been removed at the user's request. The exact withheld
operation remains unknown; the incident record is preserved without treating it
as evidence that all network integration is prohibited. No new safety refusal
occurred during the N1 checks. General WORKFLOW refusal handling still applies.

Next result: the app client performs its own lookup/connect/handshake through
iteration permits and two native apps retain their connected roles and RNG.
Then continue N4–N5 to a complete two-app match. N1/N2 checks do not establish
whole-match acceptance.

## N2 host integration (2026-10-02)

Connect the already compared `OriginalNetworkNotification` (415 saved whole
callbacks in NETWORK_NOTIFICATION) to the application's message loop and the
existing Mac service. Reference artifacts and contracts are unchanged; no new
original execution. Fresh callback locals remain undefined until written.
Socket operations and their in-handshake sleeps use iteration permits, so
replaying a suspended Core attempt cannot duplicate a send or accept. Messages
and DefWindowProc use the existing window channel. A provider failure after
external IO remains terminal; it is not a successful rollback of that IO.

Checks: syntax first, then retained notification/menu/iteration tests and a new
whole-iteration route/order/replay test, plus a native host probe on port 12345
with a task-owned localhost peer. The app must send the original greeting,
names and RNG bytes and retain its own accepted state. No Windows or full-match
acceptance is claimed by this stage. Independent review remains open.

Owned paths: the application Bootstrap/Host/Menu/ObservedIteration provider
chain, Mac runtime Network/Menu/Messages, their tests, and this result/handoff.
Preserve existing unfinished N2 input changes and unrelated work. Storage:
`/Volumes/X5/ntsd-2.4-research/network-app-host-20261002`; mounted writable APFS
UUID verified, 89.4 GiB free, at most 12 GiB new output, retaining 40 GiB external
and 6 GiB internal. Reuse the terminal network-service-reset SwiftPM cache.
Build bound 15 minutes, selected tests 5 minutes, host probe 60 seconds; at most
three correction rounds before diagnosis. A separate goal-100 worktree app was
observed running and is not owned or changed by this task.

**Result:** [evidence](../evidence/network-app-host-20261002.json). The existing
N2 main-menu WIP is integrated with the new 0x401 route, socket permit/reply and
Mac request provider. Undefined 160-byte locals are owned by the callback;
global writes return through the enclosing session. MessageBox and default
window handling stay on the window channel. The Mac provider executes the
original 3000/500/500 ms waits before the next IO.

Run1 built in 319.83 s; all 17 selected tests passed in 39.413 s. The new runtime
test creates the host from menu input and exchanges actual bytes with its own
local peer. It verifies the nine IO/sleep requests, exact greeting/names/RNG,
stored socket/roles/names and unchanged remaining bytes/masks. A deliberately
late publication failure then resumes the same journal without repeating IO.
READ/CONNECT/CLOSE keep their message-box-only semantics. Retained main-menu,
network-menu, whole-notification and iteration/menu tests also passed; all 669
candidate code pins remained unchanged.

A separate `NTSDNative --original` process created its listener from ONLINE
GAME, sent 14+77+3001 bytes to a peer on the same Mac, and exited 0 via its script
with no boundary or message box. The original selected local interface
100.123.168.127, so this was not a 127.0.0.1 bind. The whole-menu test additionally
selected the Host screen; the separate process probe stayed in the ONLINE
choice screen and did not launch a match. The retained `--no-network` error
scenario passed unchanged. This checks the pinned SwiftPM binary, not a clean
shipping package. All owned runs are terminal; N3–N5, the complete match,
Windows interoperability and independent review remain open.

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
receive/notification API; N2 integration is not validated by this check.

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
Review and correct this lifetime without changing the game's close ordering.
A repeated successful reset test alone
does not establish safety of that separate lifetime.

## N1 descriptor lifetime correction (2026-10-02)

Independent continuation of the transport correction above. Target: the Mac service's
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
application integration; the application notification route remains unfinished.

## N1 reverse lookup for the client fallback (2026-10-02)

Independent missing platform response, following the checked lifetime increment.
The recovered [client contract](NETWORK_CLIENT.md#connection-and-storage-order)
requests gethostbyaddr(raw4,4,AF_INET) after a null gethostbyname result and uses
the returned first IPv4 address. N1 currently has no reverse-lookup method.
Implement it with the Mac resolver, copying its borrowed address list into
owned Swift words before any later lookup. The platform result can be nil;
an unresolved address must not be turned into a successful host entry.
Reference game rules and immutable corpora are unchanged.

API evidence: Microsoft's
[gethostbyaddr contract](https://learn.microsoft.com/en-us/windows/win32/api/winsock2/nf-winsock2-gethostbyaddr)
and Apple's [resolver manual](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man3/endhostent.3.html),
plus the installed macOS SDK netdb.h for hostent layout and HOST_NOT_FOUND /
TRY_AGAIN / NO_RECOVERY / NO_DATA constants. Resolver policy and available names
are supplied by macOS; Windows/NetBIOS equivalence is not claimed.

Finite check: a new N1 test resolves the local hosts entry 127.0.0.1, retains its
value across another resolver call, and checks the uninitialized/cleaned-up
service errors; retain all seven existing N1 tests. No external host is queried,
no original or native game/client action is executed. Integration into the
application client provider remains open alongside the unfinished N2 route; a service
test cannot establish the app's fallback behavior. Independent review is open.

Own service/test/addendum/evidence paths only; keep previous interface-address
and N2 WIP separate. Logs and code pins:
`/Volumes/X5/ntsd-2.4-research/network-client-lookup-20261002`; reuse the terminal
SwiftPM cache at `network-service-reset-20261002/build`. X5 APFS UUID revalidated,
97.1 GiB free; at most 2 GiB additional output, keeping 40 GiB external/6 GiB
internal reserves. Build at most 15 minutes, selected tests at most 60 seconds.

**Result:** [evidence](../evidence/network-client-lookup-20261002.json).
Syntax, standalone Swift type checking and diff checks passed; run4 passed
all eight N1 tests. The new overload copies the complete IPv4 address list,
returns nil when the resolver fails, and maps the documented resolver errors.
The actual loopback result and service initialization boundaries were checked;
environmental lookup failures and Windows/NetBIOS equivalence were not observed.
The pre-existing interface-address WIP remains separate. Code inspection confirms
that `OriginalApplicationMenuSession` still answers client/exit socket operations
through its `refused()` stand-in, and `OriginalMacRuntimeNetwork` only serves
main-menu requests. Connecting the recovered client, match and exit providers,
and the unfinished N2 notification route, remains the required next integration
work. No standalone N1 check substitutes for that work.

## Preserved N1 interface lookup promoted (2026-10-02)

The pre-existing own-host interface lookup and its five-line test addition are
now included in the N1 increment, without changing their bytes. The saved
pre-refusal progress message explicitly reported this part implemented before
starting N2b. For the exact hostname returned by macOS, the service supplies
up, non-loopback IPv4 interface addresses in system order, with a DNS fallback
if the list is unavailable/empty. This is a declared Mac platform policy; it
does not establish what a particular Windows machine would return.

[Promotion evidence](../evidence/network-service-interface-promotion-20261002.json)
reuses run4's eight passing service tests: all 668 actual source pins still
match, including the complete service and test files. No successful check was
rerun. The retained own-interface assertions are conditional on an available
non-loopback interface; no new branch-coverage or independent-review claim.
N2 application changes and unrelated files remain separate WIP.

## Remaining integration (2026-10-02)

The network deferral is lifted. The following gaps are present in the current
working code, so the goal's whole-match criterion is not satisfied:

| Required result | Current code/evidence | Remaining dependency |
| --- | --- | --- |
| N2 host greeting from the app | Menu listener and 0x401 consumer implemented; 17 tests and separate native-process greeting probe pass | Independent review remains open; use this retained session for N3/N4 |
| N3 client connects through the UI | Menu client calls still use `refused()`; `OriginalMacRuntimeNetwork.answer` handles only main-menu requests | Connect the real client requests to the shared socket service and preserve delivery/terminal-failure semantics |
| N4 synchronized match to Summary | The loading control provider still returns -1 for asyncSelect/ioctl and has no send/receive implementation | Live session state from N2/N3, game input exchange, then two-app synchronization evidence |
| N5 exit/disconnect/errors | Menu exit uses `refused()`; FD_CLOSE delivery needs the unfinished notification route | The same app socket/session routing plus actual failure/exit scenarios |
| Offline behavior and Windows comparison | Prior offline acceptance has its own pinned inputs; new service tests execute no app. Windows was not observed | Recheck affected app paths after integration; Windows interoperability stays separately open |

The next implementation increment is N3, as described above. Repeating successful
N1 tests or offline soaks would not supply the missing app integration. The
earlier requirement for external clarification before any N2–N5 work was based
on an unsupported expansion of the unknown refusal scope and is withdrawn.

## Deferred by the user (2026-10-01)

Historical status, superseded by the user's 2026-10-02 networking priority and
the current next step above.

Networking remains in the full scope, but the user had deferred it in favour
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
