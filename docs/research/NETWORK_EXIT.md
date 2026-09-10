# Whole network exit and retained cleanup

[OriginalNetworkExit](../../native/Sources/NTSDCore/OriginalNetworkExit.swift)
matches56 whole402d70 returns under the finite
[NETWORK_EXIT_PLAN](NETWORK_EXIT_PLAN.md). One additional accepted client action
produces its own state before two exit calls. All57 calls compare2647680 storage
bytes, recorded masks,171 requests and733 semantic stores. This recovers a
dependency of the network menu; the enclosing cancel UI and real network session
are not yet joined. NTSDApp remains Practice.

## Reference and boundary

The [source harness](../../tools/oracle_network_exit.py) uses the pinned NTSD EXE,
the actual [lib.dll installer](LIB_RUNTIME.md) and VC80 .6195 memset on
Unicorn2.1.4. Each original call runs through its actual cookie check and return.
Socket, sendto, MessageBox and WSACleanup responses are declared platform inputs.
There is no real network connection, Windows socket, external endpoint or device.

EXE SHA256:
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.
CRT SHA256:
`c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d`.
The complete installer parent reproduces unchanged. EXE/lib/CRT code images
remain unchanged throughout the controlled exit and client calls.

The earlier [NETWORK_CLIENT](NETWORK_CLIENT.md) corrected a static address label:
402d70 is exit, while connection starts428420. Its sole direct caller427f6b
follows cancel sound, menu44d064=0,44d780=-1 and background release423910.
Those surrounding operations are static context here, not newly executed UI.

Low-level observations are needed because a normal socket-cleanup abstraction
would change the source's binary address truncation, early error return and
retained globals. The function reserves0x104 bytes; the compared256-byte local
data region begins at2000eefc and ends before its cookie. Saved ESI and control
storage are excluded from native inputs. This is an observed region, not a
recovered source array declaration. No control corruption or source memory fault
was manufactured or observed; all56 cookie checks and saved registers survive.

## Payload and cleanup rules

The original reads listener44f1b4 into ESI. Only when it is nonzero does it read
44f1b0; both must be nonzero to prepare/send a notice. Exact values other than
zero do not distinguish the gate. A bypass still closes the listener, including
zero, writes44f1b4=0 then44f1b0=0, and calls WSACleanup.

With both gates enabled, actual CRT memset clears all256 local bytes. The source
copies the20-byte literal `Client want to EXIT.` using DWORD stores in order
offset0,8,12, then a zero byte at20, then DWORDs4,16. Address bytes44f208..44f20b
overwrite offsets20..23 in order0,2,1,3. The source's load order and every raw
store remain recorded separately.

Actual strlen scans from local0. Thus sendto transmits20 literal bytes plus
only the nonzero address prefix: lengths20,21,22,23 or24, excluding the NUL.
For raw little-endian word0100007f, it sends the literal plus7f, length21. It
does not convert the address to dotted decimal or transmit a fixed24-byte packet.
All four address bytes are read/written even when the first is zero. The16-byte
sockaddr at44f58c is supplied separately and passed unchanged with flags0.

| sendto result / gate | Actual continuation |
| --- | --- |
| Gates bypass send |Close captured listener, clear44f1b4 then44f1b0, WSACleanup, return402eb6 |
| Exact-1 |MessageBox `sendto()` / `Error`, reread and close44f1b4, cookie check, return402e7b; globals retained and no WSACleanup |
| Any other observed numeric status |Reread listener, close, clear44f1b4 then44f1b0, WSACleanup, return402eb6 |

Numeric MessageBox/close/cleanup failures do not add branches or repair state.
EAX at return retains the last close result on the early path or cleanup result
on the normal path; the original menu caller ignores this word. Some supplied
positive send statuses exceed the requested payload length. These distinguish
the numeric predicate and are not asserted to occur on Winsock. The adapters
do not deliver reentrant callbacks or mutate unrelated globals; actual platform
reentrancy remains open.

Only44f1b4 and44f1b0 are cleared here. Connected socket44f46c, network bytes,
menu/names/seats/RNG and other globals retain their preceding values. No extra
close or reset is invented. Raw/semantic after-state comparison covers the
complete46144-byte global record.

## Retained state and native failure behavior

The controls cover all nine0/1/ffffffff gate combinations, selected send/close/
cleanup/message results, each of four address-byte positions at0/1/7f/80/ff,
two full sockaddr patterns and retained sequences.48 calls send1058 bytes,
56 close sockets,50 request cleanup and6 show an error;6 early returns and50
normal returns are compared. All five transmitted lengths occur.

An original send failure is followed by a retry and another exit on the same
CPU. Native uses its preceding result: failure retains both gates, retry sends
again and clears them, and the next call closes0 then requests cleanup. A
separate whole [client action](NETWORK_CLIENT.md) runs on the same source CPU
before exit/repeat. Its own globals survive into both calls. The native test
executes OriginalNetworkClient and passes that actual result to OriginalNetworkExit;
captured client after-state is only compared. The client action's declared
prologue/UI gap and platform inputs remain unchanged. The inter-call ABI is
declared; the intervening complete menu/cancel path is not executed.

Native rejects required unknown listener/active/address/sockaddr bytes with
whole global/local rollback. A zero listener does not require active/address/
sockaddr backing. Send-enabled calls define all256 local bytes through their
own clear; bypass calls preserve unknown locals. Throwing on final cleanup,
the error-path close or the last global clear also rolls back both records.
These are native provider/storage failures, not successful source-fault matches.
Buffer external effects until the encompassing operation commits; rollback
cannot undo already delivered packets or platform calls.

## Evidence and acceptance

Exit-only execution covers all79/79 function instruction starts,86 EXE starts
with thunks/checks and35 CRT starts.48 actual memset calls,56 cookie checks and
112 helper returns are retained. The exit-only model compares160 requests,
628 semantic stores/13888 written bytes and1453 recorded local/gate/address
reads. Instruction-start coverage does not establish every branch outcome or
actual Windows execution.

Including the one client producer gives281 EXE starts (including its34 prologue
starts),39 CRT starts,171 requests/1135 sent bytes,733 semantic stores/17224
written bytes and1584 recorded reads.3768 raw stores (3765 CPU/3 API) reconstruct
the same bytes/masks; semantic coalescing applies only to complete CRT memset
calls. The producer's own memset/REP/REPE observations remain in its parent
record, distinct from the exit-only48 memset/56 cookie/112 return counts.

[verify_network_exit.py](../../tools/verify_network_exit.py) independently
rebuilds before-globals from PE/installer/declared inputs and retained producers,
reconstructs raw after bytes/masks, models all recorded reads and semantic
request/store order, checks the transmitted lengths/bytes, original instruction
bytes, cookies/returns and the complete client producer via its accepted
independent verifier. It verifies56 atomic cases and all88 blob records. The
first3 probe cases remain unchanged in the completed source corpus.

Raw14 release tests passed5.613s/build182.98s, including five new exit tests
0.099s, the five accepted client tests and four server tests. Source capture,
native implementation and independent verifier all passed their first runs;
no source/native rules or expected bytes were corrected. Final packaged14 tests
passed5.678s/build0.32s without raw override; five exit tests took0.091s. All owned
jobs are terminal0. Python/local Markdown/owned diff checks pass; six foreign
unfinished transform files are unchanged and excluded. Artifact hashes are recorded in
[network-exit.json](../evidence/network-exit.json) and
`build/research/network-exit-work.json`.

Full raw4584610 bytes SHA256:
`38c795a09913c1a952e8cb1c1dff9781c9e591c1a66f06799b5ea20490c3c121`.
Packed295535 bytes SHA256:
`889b9c97786e2bf91231fc20b15d994460bb79077b7c949baf97a180745c07f3`.
216 prior fixture pins remain unchanged,217 are current; all raw/packed bytes,
JSON/SHA,88 blobs,56 atomic cases,10 vendor hashes and558 isolated native files
verify. Transport deflation only packs fixtures. No EXE/DLL/emulation enters the
native shipping implementation. The completed source capture must not restart.

The next network join is the complete menu1/2/3 body, including background,
address formatting, links, waiting animation, hostname editing/key translation
422f60 and actual caller/presentation/epilogue state. Complete initialized
listener/peer routing, Windows/TCP delivery, CRT/NLS/WinMain/lib/macOS runtime,
full matches/content/replays/network and clean-Mac acceptance remain open.
NTSDNative linked; no app window/device/Windows run occurred in this study.
