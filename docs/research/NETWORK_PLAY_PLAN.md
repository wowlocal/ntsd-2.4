# Plan: network play in the app

2026-10-01. CONTINUE_GOAL assigns network compatibility to the project scope;
no new decision is needed. Task → missing contract → milestone: ONLINE GAME
host/client and a VS match between two players → the app's Winsock answers are
a declared "WSAStartup never succeeded" stand-in → a real Mac Winsock service
with the game's own network code (already ported in Core) driving it → the
original's online play, between two Mac apps and, by the same bytes, with the
Windows original. The original is not executed.

## What is already recovered and ported

- [NETWORK_MENU](NETWORK_MENU.md): `OriginalNetworkMenu`, selectors 1–3, wired
  in `OriginalApplicationMenuSession` with Winsock answered as failed.
- [NETWORK_CLIENT](NETWORK_CLIENT.md): `OriginalNetworkClient.attempt`
  (428420..42873e). It connects to port 12345, then receives a 100-byte
  greeting compared with `u can connect`, flag and name bytes, and the
  3001-byte RNG table.
- [NETWORK_NOTIFICATION](NETWORK_NOTIFICATION.md):
  `OriginalNetworkNotification` (the WndProc's 0x401 message). On ACCEPT8 it
  accepts, closes the listener and sends the greeting. It then waits 3000 ms,
  receives 77, waits 500, sends 77, waits 500, and sends the 3001-byte RNG
  table. Not wired into the app's window input.
- [NETWORK_EXIT](NETWORK_EXIT.md): 402d70 sends `Client want to EXIT.`,
  closes the sockets and calls WSACleanup.
- `OriginalInputControl`: the in-match exchange. 41c603/41c61a cancel async
  select on both sockets and 41c62c/41c64a set FIONBIO, then each tick sends a
  22-byte packet and receives 22 bytes in a loop into 44f198 (41cbdd..41cc25;
  41d14d..41d197 for the other side).

## Winsock surface (EXE call sites through the stubs 43f38a..43f3fc)

| Call | Sites |
| --- | --- |
| WSAStartup(0x101) | 402b86; only wVersion is checked (0x101) |
| gethostname, gethostbyname | 402bcd, 402c0b (own address list) |
| socket(AF_INET, SOCK_STREAM, IPPROTO_TCP) | 402c99 (listener 44f1b4), 428445 (client) |
| WSAAsyncSelect(s, hwnd, 0x401, 0x38) | 402cde; 41c603/41c61a cancel with (0, 0) |
| bind/listen, port 12345 | 427b2a, 427b4d |
| accept | 402f08 (notification) |
| connect | 428506 |
| send / recv | 402f76/403031/403050, 42863e, 41cbdd/41d197 / 402fa9, 42854e/428662/42867f, 41cbf1/41cc1b/41d14d/41d17c |
| ioctlsocket(FIONBIO) | 41c62c, 41c64a |
| sendto | 402e3d (exit notice) |
| closesocket, WSACleanup | 402e61.., 42843a/428529, 427b3b/427b74, 402f32..402f61 |

## Declared Windows behaviour (not the EXE)

Recorded per stage, in short:

- Sockets are blocking unless WSAAsyncSelect made them non-blocking.
- Sockets that accept() returns inherit the listener's async selection, so
  0x38 also delivers FD_CLOSE (32) to the accepted socket. The original then
  shows its `FD_CLOSE` message box.
- WSAAsyncSelect(s, hwnd, 0, 0) cancels and leaves the socket non-blocking
  until FIONBIO 0.
- recv returns what has arrived (up to the length): 0 on an orderly close and
  −1 on error.
- WSADATA as Winsock 2.2 answers a 1.1 request: wVersion 0x101.
- SOCKET values are small handles (a declared token scheme).
- Blocking calls block the game's thread, as on Windows.
- macOS may show its firewall prompt for the listener.

## Stages

- **N1, Mac Winsock service** (`OriginalMacWinsock`, NTSDMacPlatform). BSD
  sockets behind the declared semantics:
  - handles and the operations above;
  - async notifications posted through a callback as (message, wParam =
    socket, lParam = event | error << 16).
  - Checks: loopback unit tests for listen/accept/connect, the greeting →
    77 → 3001 sequence, partial recv, close → recv 0, the FD_ACCEPT and
    inherited FD_CLOSE notifications, cancel and FIONBIO, gethostname and
    inet_addr/ntoa. No app change.
- **N2, startup and host.** The main menu's network input comes from the
  service, replacing the wVersion-0 stand-in. The 0x401 message reaches
  `OriginalNetworkNotification` through the window input. Checks: the
  network-menu suites; an app probe where host mode listens on 12345 and a
  test client gets the greeting.
- **N3, client.** `OriginalNetworkClient.attempt`'s requests go to the
  service in order inside the body. The sends cannot be rolled back, so a
  later failure in the same body is a terminal stop. Checks: two app
  instances on localhost reach connected (World 1 → 2) on both sides.
- **N4, the match.** The input control's FIONBIO, send and recv go to the
  service, and the network character selection and match run lockstep. Check:
  an e2e scenario with two instances on 127.0.0.1 playing a VS match to the
  Summary, with equal results and replays on both sides.
- **N5, exit and errors.** The exit notice, the peer closing (FD_CLOSE box),
  and connection refused (the original's `Client Error` box). The existing
  online e2e scenario keeps the stand-in through an explicit `--no-network`
  option, so the original's WSAStartup error path stays covered.

Windows interoperability (a Mac app against the Windows original) needs a
Windows machine and stays a separate check for the user.

EXE envelope not recalculated.
