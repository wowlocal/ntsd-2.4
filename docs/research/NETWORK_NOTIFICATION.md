# Original network acceptance notification

[OriginalNetworkNotification](../../native/Sources/NTSDCore/OriginalNetworkNotification.swift)
matches415 whole WndProc43b3d0 message401 callbacks through actual402ec0..40316e
and ret16. Full19216160 global/local storage bytes and defined masks,3692
requests and1119304 transmitted bytes agree. Four subsequent notifications retain
the native output of their own accepted connection. The finite scope is
[NETWORK_NOTIFICATION_PLAN](NETWORK_NOTIFICATION_PLAN.md).

This recovers server acceptance and notification behavior needed for original
network setup. It does not establish a real peer session. NTSDApp still uses
Practice; full application, match and Windows/device acceptance remain open.

## Reference and environment

The [source harness](../../tools/oracle_network_notification.py) runs the pinned
original NTSD EXE SHA256
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`,
bundled lib.dll SHA256
`28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba`,
and VC80 .6195 SHA256
`c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d`.
The complete accepted installer case0 reproduces before controlled calls.
Actual EXE and CRT memset78144a20 execute on one Unicorn2.1.4 CPU/stack. Their
image bytes remain immutable; only the declared import binding changes before
capture. No CRT initialization or Windows assembly binding is inferred.

Winsock accept/close/send/recv, Sleep, MessageBoxA and DefWindowProcA responses
are declared adapters. No external endpoint, host socket, process, thread,
clock delay or Windows window is operated. Listening socket, name/RNG backing
and incoming messages are explicit inputs. Low-level observations recover packet
construction, local overlap, masks, status handling and actual cookie checks.
This is needed because a conventional retrying network abstraction would change
the original's single-read and ignored-error behavior.

The source executes225 EXE starts, including36 WndProc and181/182 notification
starts; only the skipped alignment instruction4030e9 is absent in that helper.
There are37 original CRT starts,1245 EXE helper returns (415 each callback,
notification and cookie check), plus724 completed real memset calls. All415
cookie comparisons succeed with the original saved/global value; no cookie,
saved return address or control pointer is corrupted. Saved EBX/EBP/ESI/EDI
survive, returnSP is2000f014 and supplied CW023f remains. This is not Windows,
process-wide FPU, every branch outcome or all CRT memset paths.

## Dispatch and original request order

Only low16(lParam) selects the notification. Its high16 error word is ignored.
READ1, CONNECT16 and CLOSE32 show the exact corresponding `FD_READ`,
`FD_CONNECT` or `FD_CLOSE` text with caption `Handle Message`, HWND0 and flags0.
They do not receive, close or clear network state here. Other values except8
fall through. Every path eventually calls DefWindowProc with the original four
callback arguments and preserves its return. wParam is not the socket used by
the acceptance branch.

ACCEPT8 reads listener44f1b4, writes byte44f1af=2, then requests
accept(listener,NULL,NULL). It stores that numeric result in44f46c even when-1.
Exact-1 shows the original misspelling `Accpet() Error`/`Error`, closes live
accepted44f46c (therefore-1 in this adapter contract), then listener44f1b4.
It neither clears those words nor restores44f1af. Numeric close/message errors
are ignored, and the callback still reaches DefWindowProc.

Every other accept result, including0, executes this order:

1. Close listener44f1b4 without clearing its global.
2. Send14 bytes, `u can connect` followed by NUL, on live44f46c.
3. Clear77 local receive bytes through actual CRT memset, then Sleep3000.
4. Issue exactly one recv(socket,buffer,77,0), then Sleep500.
5. Build and send the77-byte name packet, then Sleep500.
6. Send all3001 bytes at44ff90, then update seats/remote names and byte44f1ae=1.

No send or recv result controls this continuation. A short read leaves the
unwritten receive suffix zero from the earlier memset; there is no retry,
invented complete packet or early return on-1/0. Supplied output bytes remain
independent of the numeric status. Some controlled stress responses intentionally
report a positive send count greater than the14-byte first request or bytes with
a negative recv result; those are adapter controls, not claims that Winsock
produces those combinations in ordinary use. Original numeric ignoring is the
observed fact. Actual OS short/error/output contracts require separate evidence.

## Packet/local storage and live names

The function reserves0xa4 bytes and writes its cookie at+0xa0. The compared
160-byte region below it has frame base2000ef3c in these whole callbacks.
This is a recovered observed region, not a source C-array declaration.

| Frame offset | Behavior |
| --- | --- |
| +00..4c |77-byte receive buffer; clear before recv, supplied prefix writes after request |
| +50..9c |77-byte outgoing packet, copied from literal4478b0 using19 dwords and one byte |
| +70..9c |45 underscores overwrite the copied packet's name area before live string copies |
| +4d..4f, +9d..9f |Untouched in this finite corpus; declared backing and unknown native masks survive |
| +a0 |Original cookie, outside the native local record; actual source setup/check is retained |

The template is four ASCII1 bytes,72 ASCII0 bytes and NUL. At each of four
11-byte strides the source copies the entire live NUL-terminated string from
44fcc0+11*i into packet+32+11*i. It does not limit a string to the stride.
Overlapping global strings are read as they exist after explicit input setup;
later packet copies can overwrite earlier output. Then all NULs in the first44
name bytes become underscores, and the final packet byte is set to NUL again.
The source's362 complete REP copies verify ECX19→0, DF0, source/destination
advancement and all76 copied bytes. Raw write hooks reconstruct their full masks;
no missing-hook mask correction was needed here.

After the sends, the source reads receive byte0, writes the first four seat
globals450b4c..450b58 to1/2/3/4, then writes-1 where each corresponding received
byte is exactly ASCII1. For seats4..7 only that ASCII1 condition writes-1;
otherwise the preceding globals survive. It copies44 remote name bytes from
receive+32 into44fcec, writing each raw byte first and then a second zero store
when that byte was underscore. Finally byte44f1ae becomes1.

The earlier [SETTINGS_LOADING](SETTINGS_LOADING.md) permits unbounded names.
The source corpus preflights these four actual copies to end below the cookie;
it does not truncate or manufacture a source overwrite. Longer reachable
settings names and their complete application lifetime remain an explicit open
boundary. Native rejects a required copy beyond its recovered local record and
rolls back; that rejection is not counted as a source match or a repaired source
packet. No expected source after-state is imported into a native continuation.

## Comparison and native failure boundary

The415 cases cover low16 values0..33, selected high16/error values, accept
-1/0/1/7fffffff, all256 seat-flag combinations, receive lengths0..77, selected
numeric error/output combinations and four binary/overlapping name backings.
One accepted callback is followed by READ/CONNECT/CLOSE/default calls carrying
its own native globals. That retained sequence is not the original menu's full
listen/accept chain, the client402d70 handshake or two real communicating peers.

There are363 accept requests (362 nonnegative results and one-1),364 closes,
1086 sends,1086 sleeps,362 receives,415 defaults and16 messages. The source
records44237 raw stores (43892 CPU/345 API),130913 written bytes and37790
actual local/name reads. Native compares33377 ordered semantic stores over the
same130913 bytes, coalescing only each completed CRT memset into one store.
The raw CRT store sequence is retained separately; no claim of native CRT
instruction/store-width equivalence follows from semantic coalescing.

[verify_network_notification.py](../../tools/verify_network_notification.py)
rebuilds full declared before-globals from PE sections, the installer changes and
explicit case inputs. It reconstructs both after-states and masks from raw
writes, independently models all read addresses/bytes and semantic actions,
checks literal/send bytes, parent hashes, instruction bytes, cookie values,
memset/REP observations and all atomic records/blobs.

Native-only trials reject unknown required name or RNG bytes, a name extending
beyond local storage,78 output bytes for a77-byte receive, unavailable recv and
late DefWindowProc after all three sends. Whole globals/locals roll back.
Untouched unknown locals remain unknown after a successful accept; nonaccept
notifications do not demand unrelated global/local backing. Buffer external
effects until the encompassing operation commits. These are provider/storage
failures, not original crashes or successful source-fault matches.

## Acceptance and remaining work

The8-call probe and complete415-call source capture are terminal0. The first8
cases/blobs remain identical. No original memory fault, safety refusal, source
restart or native game-rule correction occurred. All10 raw release tests passed
12.074s/build179.41s:4 new tests,5 retained graph tests and the main-menu test
covering1020 probes/450 mouse callbacks/4150 events/14 network failures. The
four network tests took2.327s. NTSDNative linked; no app window was exercised.

Final packaged10 tests passed11.552s/build0.28s without a raw override; the four
network tests took2.047s. All owned source/SwiftPM jobs are terminal0. Full
raw/packed bytes/JSON/SHA,415 atomic records,684 blobs,10 codec vendor files
and552 isolated native files verify. Foreign unfinished transforms are excluded
and unchanged. Python compilation, local Markdown links and owned diff checks
pass. One new fixture preserves214 prior pins, making215. Raw41676959 bytes have SHA256
`cd14c267c9b27b8a63095bdf0afbd4d2ee8f737d068c2bbabbfc5756d9a31c24`;
packed3897568 bytes have SHA256
`c3e967399f3a7cf7f96b149bc8ed4eb1cbeba9fa118f0fb2d7019560996fbca7`.
Evidence is [network-notification.json](../evidence/network-notification.json);
commands and job status are in `build/research/network-notification-work.json`.
Transport deflation only packs research fixtures; EXE/DLL/emulation is absent
from the native shipping implementation.

The immutable input/lifecycle/graph/network instruction union now covers574/576
WndProc starts. Only the two negative43bdd0 debug starts43b88a/43b88f remain;
the accepted display helper returns0/1. This is still not all branch outcomes,
a unified native callback router or actual OS delivery. Client402d70, initialized
menu/listening/peer joins, synchronous callback delivery, CRT/NLS/WinMain,
lib transforms/routing, native renderer/audio/input/timing, complete matches,
all content/replays/network and Windows/device/clean-Mac acceptance remain open.
