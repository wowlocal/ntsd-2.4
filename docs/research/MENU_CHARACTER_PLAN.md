# Whole menu character decoder

Status: accepted as [MENU_CHARACTER](MENU_CHARACTER.md), first dependency of
[NETWORK_MENU_PLAN](NETWORK_MENU_PLAN.md). The finite criteria below are retained.
Recover whole422f60..423222 and its exact GetKeyState/Shift read order. The
hostname caller42836b scans0..299 and consumes signed AL at428371. The helper
also maps navigation keys to keypad digits; modern text-input substitution would
change original behavior. Pinned EXE/lib installer on Unicorn2.1.4; GetKeyState
responses are declared, with no Windows keyboard/device or real input polling.

Finite acceptance: all300 caller key values at five Shift bytes and six signed
Caps Lock low16 values; all36 successive Caps Lock pairs for26 letters with
Shift0x64; all256 Shift bytes for representative letter/digit; unsigned key-range
controls and API high-word controls. Trace actual PCs, all Shift reads and
request order, full global before/after bytes and zero write mask, saved-register
restoration and real return. Preserve full source EAX, but compare AL natively:
the caller sign-extends AL and does not consume the API-dependent high bytes.

Unknown required Shift and unavailable first/second key-state responses must
reject; space/keypad paths must not demand unread Shift/keyboard state. The
decoder has no native mutation to roll back. The later menu operation must
stage its own text/state changes and buffer external output until commit.

Preserve all217 old fixtures and immutable source results. Atomic cases/blobs,
independent PE/installer/input/read/request/PC/return reconstruction, raw native
acceptance, transport JSON/SHA verification and packaged retained network tests
are required. Do not call static unreachable repeated letter checks dynamic
coverage. Do not manufacture code/cookie corruption or memory faults. Actual
keyboard/NLS/layout, complete hostname scan/menu/output/return and full-game
macOS/Windows/device/clean-Mac acceptance stay open.
