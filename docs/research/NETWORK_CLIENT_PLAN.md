# Deferred client connection and paired handshake

Status: finite scope accepted in [NETWORK_CLIENT](NETWORK_CLIENT.md):392 client
actions plus one paired client/server exchange. Final10 packaged tests passed
14.426s/build0.28s. Previous goal turn made progress in commit e850cad.
Parents: [NETWORK_NOTIFICATION](NETWORK_NOTIFICATION.md), [MAIN_MENU](MAIN_MENU.md),
[FRONT_MENU_LOOP](FRONT_MENU_LOOP.md), [SETTINGS_LOADING](SETTINGS_LOADING.md).

Address correction:402d70 is network exit/sendto/cleanup, not the client connect
handshake. Its only direct caller is427f6b. Actual client socket/lookup/connect
and handshake are428420..42873e with error continuation4287de inside menu3.
Earlier references calling402d70 the client handshake were static naming errors;
their accepted source bytes/results remain unchanged.

Recover the complete deferred connection action, including its pending gate,
socket replacement, name/address fallback, connect failure, greeting comparison,
live overlapping names, packet sends/receives and final state. The mechanism is
required for original client/server network compatibility. Use pinned NTSD EXE,
installed lib.dll and actual VC80 .6195 memset on Unicorn2.1.4. Socket/lookup/
Sleep/MessageBox adapters are declared. No external address or real network IO.

Execute the real4246b0 prologue through42709b to produce EBX0, EBP19 and caller
World/target locals from declared arguments, preserving its actual cookie/SEH
setup. The intervening UI prefix is a declared gap, not claimed executed.
Observe the full connection action to its actual presentation/epilogue entry;
neither endpoint is a completed whole menu return. Compare globals, World and
caller data below cookie, excluding saved control fields from native imports.
Do not replace a missing backing word, failed API result or later output stage.

Finite acceptance:
1. Pending0/1/other; socket-1/0/nonzero; successful hostname lookup, numeric-address
   fallback, lookup failure and connect-1/0/other. Preserve which socket is closed,
   exactly when44d064 changes and which continuation is reached.
2. All14 greeting-byte mismatches, NUL, full/partial/absent writes and ignored
   numeric receive errors. The original compares14 bytes without clearing100-byte
   greeting backing. Native unknown bytes reject only when actually compared.
3. All256 seat flags; recv77 prefixes0..77; partial RNG output0/1/3000/3001;
   binary/overlapping names and ignored send/receive statuses. Compare all local/
   global bytes/masks, actual reads, full packet bytes and semantic request/store
   order. Preserve raw CRT stores and REP/REPE observations separately.
4. Run declared paired client/server instances with deterministic adapter queues:
   each peer consumes the actual bytes sent by the other. Compare native peers'
   independently generated packets and retained final state. Queue delivery and
   schedules are test inputs, not Windows/TCP/device/timing equivalence. No
   fixture packet may stand in for the native peer's own output.
5. Native unknown required name/host/local backing, oversized output, unavailable
   responses and late
   observers reject with whole-action rollback. Buffer external effects. Names
   are preflighted in the source to stay within declared data, avoiding any
   manufactured cookie/control overwrite. Broader reachable settings-name and
   alias lifetime boundaries stay open, not counted as successful matches.
6. Preserve original reference bytes, atomic captures and all existing fixtures.
   Raw native acceptance before packaging; independently verify before provenance,
   after bytes/masks, read/write order, original PCs/parent/CRT hash, all blobs,
   raw/packed JSON/SHA, old fixture/vendor pins and isolated owned native export.

402d70 exit, the enclosing host/client UI, full menu/listen/connection routing,
actual controlled network sessions/Windows delivery, CRT/NLS/WinMain, lib
transforms and native window/renderer/audio/input loop remain required. Full
match/content/replay/network and clean-Mac acceptance are not complete.

Follow-up [NETWORK_EXIT](NETWORK_EXIT.md) accepts whole402d70 and a retained
client→exit sequence. The enclosing menu/input/presentation join remains open.
