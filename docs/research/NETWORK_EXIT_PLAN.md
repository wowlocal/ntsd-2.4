# Network exit and retained cleanup

Status: accepted in [NETWORK_EXIT](NETWORK_EXIT.md):56 whole returns and one
own client producer, final14 packaged tests5.678s/build0.32s. Previous goal
turn made progress in77cbfb6, [NETWORK_CLIENT](NETWORK_CLIENT.md). Read also
[NETWORK_NOTIFICATION](NETWORK_NOTIFICATION.md) and [MAIN_MENU](MAIN_MENU.md).

Recover whole402d70..402eb6 through both actual returns, not merely a successful
close request. It is called at427f6b after the menu's sound/state/background
cleanup; that enclosing UI remains a separate required join. Static inspection
suggests sendto-1 returns before clearing globals/WSACleanup and strlen may stop
before appended address bytes. Execution is needed to recover actual payload,
read/write order, ignored returns and retained retry behavior.

Use the pinned NTSD EXE and lib.dll installer with actual VC80 .6195 memset on
Unicorn2.1.4. Socket/sendto/MessageBox/WSACleanup responses are declared adapters;
no actual socket or external endpoint is used. Compare complete globals and
the256-byte observed local data region below the original cookie. Retain actual
setup/checks and saved registers; never import control/cookie bytes into native.

Finite acceptance:
1. Listener and44f1b0 gates0/1/ffffffff, sendto-1/0/positive and ignored close/
   cleanup/message results. Compare which operations occur, exact result,
   request/store interleaving and full storage/masks through both returns.
2. Address words with every byte boundary and NUL position, declared sockaddr16
   bytes and complete local clear/literal/address stores. Verify actual strlen
   reads and transmitted bytes, including untouched local suffix on bypass.
3. Retained send failure→retry success→repeat exit use each preceding native
   result. Additionally run the accepted client's own complete action before
   exit on the same original CPU and compose the corresponding native routines;
   do not inject captured client after-state into native exit.
4. Required unknown address/sockaddr/gate backing and late providers/observers
   reject with whole-operation rollback; bypass paths do not demand unread
   local/address bytes. Ordinary numeric failures retain original behavior.
5. Preserve source bytes/masks and all216 prior fixture pins. Atomic source cases,
   raw native acceptance before packing, independent PE/installer/input/store/
   read/PC/cookie verification, full raw/packed JSON/SHA/blobs, vendor hashes and
   isolated owned native export; then packaged retained client/server tests.

No deliberate control corruption, manufactured memory fault, actual Windows
heap/socket execution or platform reentrancy is part of this study. External
effects must be buffered by the encompassing operation. Full menu1/2/3 output,
host/client input and key translation422f60, presentation/epilogue, initialized
listener/peer routing, Windows/TCP, CRT/lib/macOS runtime and full-game/clean-Mac
acceptance remain required; this dependency does not redefine the full goal.
