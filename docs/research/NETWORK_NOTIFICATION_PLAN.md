# Original network acceptance notification

Status: finite scope accepted in [NETWORK_NOTIFICATION](NETWORK_NOTIFICATION.md):
415 whole callbacks, full packets/storage/masks/order and native rollback;
final10 packaged tests passed11.552s/build0.28s. Actual network/Windows/app
acceptance remains separate and open. Previous goal turn made progress with accepted
GRAPH_EVENTS commit97b91a6. Parents: [MAIN_MENU](MAIN_MENU.md),
[INPUT_CONTROL](INPUT_CONTROL.md), [GRAPH_EVENTS](GRAPH_EVENTS.md),
[SETTINGS_LOADING](SETTINGS_LOADING.md).

Recover whole WndProc43b3d0 message401 through actual402ec0..40316e and ret16.
This is the server acceptance handshake and READ/CONNECT/CLOSE notification
behavior required by the original game's network session setup. Use the pinned
original EXE and bundled lib.dll, reproduce the accepted installer, and execute
the actual VC80 .6195 memset children on the same Unicorn2.1.4 CPU/stack.
Winsock accept/close/send/recv, Sleep, MessageBox and DefWindowProc are declared
adapters; this stage makes no real network connection, accesses no external
endpoint and does not claim Windows socket/thread/timing behavior.

Instruction/stack/memory traces recover the two77-byte local buffers, actual
packet bytes, live name overlap, output masks and partial-read effects. Actual
security-cookie setup/check executes unchanged. The study does not corrupt
control pointers, saved registers or cookie storage and does not manufacture
source memory faults. Finite names are preflighted to stay below the recovered
cookie boundary, without calling that boundary a recovered C-array size.
Settings accepts unbounded names: broader ordinary-input reachability remains
open, not dismissed as irrelevant or silently truncated by the native engine.

Finite acceptance:
1. Whole callbacks for all low16 notification dispatch values0..33 and selected
   high-bit/error-word values. Cover READ1, ACCEPT8, CONNECT16, CLOSE32; preserve
   ignored high16, caller HWND/wParam and actual DefWindowProc return.
2. Accept -1/0/nonzero, all256 received seat-flag combinations, binary names,
   partial recv0..77, ordinary -1/zero/short send/receive statuses. API outputs
   and numeric results are separate inputs, with supplied bytes bounded by the
   original77-byte recv request. Preserve all three sends and sleeps3000/500/500.
3. Compare full globals and160-byte local region below cookie, both masks,
   every ordered global/local semantic store, actual CPU/API writes, source
   helper returns and exact transmitted14/77/3001 bytes. Verify REP copy counts
   and complete bytes independently; do not replace missing raw observations.
4. Use four live global strings at44fcc0+11*i, retaining overlapping backing
   and NUL-to-underscore packet conversion. Preserve the first four seat defaults
   and other retained slots, remote underscore-to-NUL conversion and live state.
   Repeated callbacks retain native outputs including accepted socket/global
   state. Listening socket, names/RNG, message delivery and stack backing remain
   explicit inputs, not a complete initialized menu/client/server join.
5. Native-only missing required names/RNG/backing, unavailable response and late
   observer failures must reject and roll back the whole callback. Buffer
   external effects; source ignored numeric errors remain ignored. Do not replace
   source outcomes with rejection successes, early return or corrected packets.
6. Preserve atomic source cases/blobs and prior fixtures. Raw native acceptance
   precedes packing; verify full raw/packed bytes/JSON/SHA, original PE bytes,
   parent, CRT hash, all prior fixture/vendor pins and isolated native export.

Actual controlled network sessions, exit402d70, menu/listening initialization
join, Windows nested callbacks, CRT/NLS/WinMain, lib transforms/routing and native
macOS renderer/audio/input/timing remain required. The app still uses Practice;
this dependency does not complete a full match, application or the full goal.

Follow-up [NETWORK_CLIENT](NETWORK_CLIENT.md) accepts392 deferred428420 actions
and a paired FIFO exchange.402d70 was previously mislabeled client connection;
static inspection identifies exit/sendto/cleanup. Accepted source data is unchanged.
