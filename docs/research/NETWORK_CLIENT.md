# Deferred client connection and paired handshake

The finite [NETWORK_CLIENT_PLAN](NETWORK_CLIENT_PLAN.md) is accepted at the
declared platform boundary. OriginalNetworkClient matches392 complete deferred
actions428420..42873e/4287de, including357 completed handshakes. One additional
client and one whole server callback exchange their own generated packets in
both source and native implementations. This is not a whole menu return or an
actual Windows/TCP session. The application still uses Practice.

## Reference, environment and address correction

The [source harness](../../tools/oracle_network_client.py) executes the pinned
NTSD EXE, its actual lib.dll installer and VC80 .6195 memset on Unicorn2.1.4.
The EXE SHA256 is
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`;
the CRT SHA256 is
`c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d`.
The complete installer parent reproduces [LIB_RUNTIME](LIB_RUNTIME.md).
Socket, lookup, Sleep and MessageBox results are declared adapters. No external
endpoint, actual socket, Windows loader, clock wait or device is exercised.

Earlier documentation called402d70 the client handshake. Static disassembly
shows402d70..402eb6 instead sends the optional `Client want to EXIT.` notice
through sendto, then closes/clears sockets and invokes WSACleanup. Its only
direct caller is427f6b. Actual deferred client connection is428420..42873e with
error continuation4287de. This corrects a static address label; no accepted
server reference bytes or results changed. Whole402d70 is now compared in [NETWORK_EXIT](NETWORK_EXIT.md).

The real4246b0 prologue executes34 instruction starts through the unexecuted
42709b boundary. It produces EBX0, ESIffffffff, EBP19 at424771, phase4511f8=1
and caller World/target words from declared arguments. Its cookie/SEH setup is
preserved. **The intervening UI42709b→428420 is not executed.** EBP19 is therefore
a declared connection-action ABI, not an established lifetime through that UI.
Neither42873e presentation nor4287de epilogue is executed here; no ret4 claim.

Instruction and memory observations recover behavior that a conventional
retrying socket abstraction would change: uncleared short receives, ignored
numeric failures, the listener closed on connect failure, live names and exact
ordering. Source control fields are never supplied as native data. No source
memory fault or protection overwrite was manufactured or observed.

## Connection and storage order

Pending4511b0 must equal1. The original reads old44f46c, clears pending, closes
that socket, requests socket(2,1,6), then stores the result even when-1. Exact-1
shows `socket()` / `Client Error` and reaches4287de. Otherwise World+7d8 supplies
the hostname to gethostbyname. A null result uses inet_addr, stores its raw word
at rootSP+14, and calls gethostbyaddr(raw4,4,2). Each host result updates44f2d4.
Null fallback shows `Can't get the Server` / `Error`, stores menu44d064=1 and
reaches42873e. Menu already1 after successful lookup skips address dereference.

For other menus, sockaddr44f58c gets family2, the first address obtained through
actual hostent+c/list/word loads, and low16(htons12345). Connect receives all16
sockaddr bytes and live44f46c. Exact-1 shows `Can't connect to server` / `Error`,
closes **listener44f1b4**, sets menu1 and reaches4287de. The new44f46c remains
stored. Other numeric connect results proceed.

RootSP is2000e000. The native1024-byte local record begins at root+14 and ends
before cookie+414; root0..13 and414..42b remain unchanged in source. This is an
observed data region, not recovered C-array sizes. World is declared2112 bytes
at32000000 with a bounded input hostname; its complete bytes remain unchanged.
The hostent mapping33000000 and target34000000 are controlled research inputs.

| Root offset / global | Recovered behavior |
| --- | --- |
| +18 / +20 | Actual prologue World/target arguments; native uses typed World and returns the continuation, without importing pointer words |
| +284..2e7 | recv100 greeting, no clear; actual REPE CMPSB compares14 literal bytes including NUL, stopping at first mismatch |
| +a4..f0 |77-byte outgoing template: `00001111`,68 ASCII0 and NUL;19 dwords from449788 followed by one byte |
| +c4..f0 |45 underscores, overwritten by four live strings, then NUL→underscore over44 bytes and final NUL |
| +108..154 | recv77 reply, no clear; unwritten suffix retains earlier caller backing |
| 44ff90..450b48 | recv3001 directly into RNG; partial output retains prior suffix |
| 450b5c..450b68 |1/2/3/4 written between the template's dword copy and final byte; received ASCII1 later overrides any of8 seats to-1 |
| 44f1af | Byte1 before send77, retained through ignored send/receive numeric errors |

After a matching greeting, each of four live44fcc0+11*i strings is first copied
through NUL to44fcec+11*i, then reread into its outgoing packet stride. There is
no11-byte length cap. Later writes and overlapping strings remain live. Source
controls preflight every string to terminate inside the first44 input bytes;
broader settings-name/alias lifetime remains open. No truncation or injected
source result resolves that boundary.

The source sends77 bytes, requests Sleep500, receives77, requests Sleep500,
then receives3001. All send/receive numeric results are ignored. API output
prefixes are independent declared inputs, including combinations not claimed
to occur on Winsock. No retries or invented complete packet are added.

Each received ASCII1 flag sets its corresponding450b4c+4*i to-1; other flags
retain prior values. Unlike the server, the client does not default the first
four seats here. It copies44 remote name bytes from reply+32 to44fcc0, with a
raw store then a second zero store for underscore. Finally menu44d064=4.
Greeting mismatch only restores the retained target and reaches42873e.

## Independent peers and comparison

392 controls cover pending/socket/lookup/connect outcomes,14 separate greeting
mismatches,17 greeting prefixes,256 seat combinations, all78 reply prefixes,
four RNG prefixes, numeric statuses and four name backings. All actions compare
4116 requests and37667 semantic stores. Original globals/local bytes and masks,
World bytes, request/store interleaving and returned continuation agree.

The additional pair runs two independent original CPUs with their own installer
parents. Thread-safe FIFO adapters deliver, in causal order, server14, client77,
server77 and server3001: four transmissions/3169 bytes. The native test runs
OriginalNetworkClient and accepted [OriginalNetworkNotification](NETWORK_NOTIFICATION.md)
with two independent states and a separate FIFO. Receives consume the other
native implementation's actual outgoing bytes. Captured packets are comparison
targets only. The FIFO's packet delivery and timeout are declared test behavior;
TCP stream segmentation, OS scheduling, reentrancy and latency remain open.

Own underscore-containing names stay unchanged; only received names are decoded.
Thus both peers agree on the RNG, while their complete88-byte name banks differ
exactly as the original does. The independent verifier initially asserted whole
bank equality and failed. The first verifier/log hashes and error are preserved
in `build/research/network-client-work.json` and its attempt1 files. Only that
assertion was corrected to derive each bank from own names and received packets;
source/native/expected bytes were unchanged. Both raw and packaged native tests
passed on their first executions.

Combined392 standalone + paired client + paired server counts are4137 requests,
30658 sent bytes,38012 semantic stores/1185930 written bytes and47750 recorded
local/name/host data reads.41980 raw stores (40880 CPU/1100 API) reconstruct the
same bytes/masks; semantic stores coalesce only360 actual CRT memset calls.
359 complete packet REPs and386 greeting comparisons retain their observations.
Full compared storage is19413344 bytes plus the recorded write masks. These
totals include the pair; do not confuse them with the392-action counts above.

The action/callback union executes386 EXE and37 CRT starts, separate from the34
client prologue starts.193/195 client starts execute; only skipped alignment at
428703/42870a is absent. This is instruction-start coverage, not all branch
outcomes or whole-menu execution. CW023f survives every client action.

[verify_network_client.py](../../tools/verify_network_client.py) independently
rebuilds declared before storage from PE/installer/prologue/input provenance,
models reads and semantic action order, reconstructs after bytes/masks from raw
writes, verifies original instruction/literal bytes and packet/REPE/REP results,
and checks full peer delivery provenance. Source asserts World/control/code
storage unchanged. No expected after bytes initialize a native continuation.

Native unknown hostname/name/greeting/reply backing, a host result lacking first
address provenance and a3002-byte output for recv3001 reject with complete
global/local rollback. Throwing on final receive or the final menu store also
rolls back after preceding effects. A first-byte greeting mismatch succeeds
without requiring unknown suffix bytes. Buffer external effects until the
encompassing operation commits; rollback cannot retract an already delivered
real packet. These are native provider/storage trials, not original crashes.

## Acceptance and remaining dependencies

Source6-case and paired probes are terminal0 and remain exactly reproduced in
the complete corpus. The392 source records and824 blobs are atomically retained;
the complete pair additionally has7 client and6 server blobs. Never restart the
completed source capture. Raw10 release tests passed15.351s/build181.47s, including
five new tests3.950s, four retained server tests and the retained main-menu test
(1020 probes/450 mouse callbacks/4150 events/14 network error exits).

Final packaged10 tests passed14.426s/build0.28s without raw override; five client
tests took3.311s. All owned jobs are terminal0. Full raw/packed bytes/JSON/SHA,
all837 blob records,392 atomic cases, both probes,215 unchanged prior fixtures,
216 current pins,10 vendor hashes and555 isolated native files verify. Foreign
unfinished transforms were excluded and unchanged. NTSDNative linked; no app
window, device or Windows run occurred. Transport deflation only packs research
fixtures; the shipping implementation uses no EXE/DLL/emulation.

Raw54323566 bytes SHA256:
`dfca9fd92d406d689f18fec7bd378565ef20a3b9b4fc097fd5061043a11219fe`.
Packed4724320 bytes SHA256:
`9af4be05dbe727fa426aceeceb479ffdc87a2ae0e0af3a6ee4565b178e16558e`.
Evidence: [network-client.json](../evidence/network-client.json). Jobs and the
preserved verifier correction: `build/research/network-client-work.json`.

The exit helper is now compared in [NETWORK_EXIT](NETWORK_EXIT.md).
The host/client input screens, initialized menu/listen/accept
and presentation/epilogue joins, actual controlled network sessions and Windows
delivery remain required. CRT/NLS/WinMain, lib transforms/routing, the macOS
renderer/audio/input/timing loop, full matches/content/replays/network and
clean-Mac acceptance are open. This milestone does not complete the full goal.
