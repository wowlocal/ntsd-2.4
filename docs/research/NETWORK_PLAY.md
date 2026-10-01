# Network play in the app — results

[Plan](NETWORK_PLAY_PLAN.md). The original is not executed.

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
