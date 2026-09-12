# Native session bridge

The current library continues the same owned session from `FRONT_SETTINGS_READY`
to `FIRST_MENU_RETURN` through the original prefix, panel, pristine body,
alternate, main-menu and presentation handlers. Call
`ntsd_bridge_continue_front_screen(handle, milliseconds)` with an explicit UInt32
clock. Its background provider looks up all 13 original MENU_BACK resources on
request and retains the consumed DIB. The two validated whole trajectories use
clock 0 and the declared A5/ascending and ramp/reverse headless profiles.

The call commits one revision or restores the complete previous owner. It keeps
25 bitmap owners, globals/World, CRT/replay state, typed retained Sleep and full
phase observations, including source-dependent extra draws. Draw exports bind
resource identity separately from the target surface role. The native private
body/fill storage has independently checked producers and known-byte masks.
No device side effect is performed by this headless interface; no tick is exported.

Current arm64 library, 6,822,664 bytes:

```text
build/l2df-prototype/loaded-session-20260912/front-screen-02/swift-build/arm64-apple-macosx/release/libNTSDNativeBridge.dylib
```

SHA-256 `0c0f5a49b82b922386600602ecca230233c6a0e586e6bc021bf16e754fdb1064`.
It passed local code-signature verification and links Apple system/Swift libraries.
ABI 1 capabilities are 1|2|4 (Actor storage, front/settings, first menu return);
lifecycles are 1 Actor storage, 2 pristine boot, 3 ready settings, 4 first return.
The original EXE/DLL, reference cases and expected snapshots are absent from the
native package. This is a development library, not a release game or portable app.

Completed commands from this worktree:

```sh
python3 prototypes/l2df/native_bridge/build.py --study loaded-session-20260912 --label front-screen-02 --plan L2DF_FRONT_SCREEN_SESSION.md
python3 prototypes/l2df/native_bridge/check_ffi.py --study loaded-session-20260912 --build-label front-screen-02 --label ffi-01 --resources build/l2df-prototype/loaded-session-20260912/resources-01/resources
```

Existing labels refuse overwrite; choose fresh labels only for a new authorized
test. `front-screen-01` preserves the initial compiler failure; the repaired
build took 85.94 s. One LÖVE 11.5/LuaJIT run took 3.018 s and passed 336 assertions.
Its first external comparator rejected two JSON schema differences. The reviewed
V2 decoder maps only optional Blit `effects` omission to nil and the panel's
explicitly empty string array to its narrower source event type. All saved
Native outputs and V1 remain unchanged. The read-only final comparison is
`front-screen-02/comparison-01/verification.json`; it passed 14 decoder controls,
the complete old Actor/front/settings checks and both first-menu returns.
The future driver now selects this V2 decoder; Native was not repeated for that
tool update.

Each new trajectory matched 202 record comparisons (1,740,888 record bytes plus
the same mask count), all 25 owners, inputs, RNG/replay state and six checkpoints.
The main-menu 11-event checkpoint is included again in the final 20/27-event
completion checkpoint; it is not an extra source call. All 187 compiled inputs
matched their frozen pins. See [the full contract and retained failures](../../../docs/research/L2DF_FRONT_SCREEN_SESSION.md).

## Earlier boot/front/settings handoff

The earlier library additionally creates an owned pristine session from the
exported original resources and runs the original front-resource/settings
handoff. `ntsd_bridge_create_pristine` reports `PRISTINE_BOOT`; only a successful
`ntsd_bridge_load_front_settings` changes it to `FRONT_SETTINGS_READY`. The
resource path is UTF-8 bytes plus a count. Profile 0 is the declared A5/ascending
allocator input; profile 1 is ramp/reverse. These are headless device profiles,
not Windows heap behavior or a playable game initializer.

It owns PE-backed globals/BSS, its constructed World, 24 bitmap wrappers,
settings scratch and consumed resource bytes. Complete rollback, read-only
snapshot export and release work through the same opaque session handle.
`ntsd_bridge_developer_front_rollback` is a test-only late failure; it reports
`UNSUPPORTED` after running the real consumers, without committing their state.
No tick or gameplay capability is exported. The original Actor-storage API
below remains available; using its setup/read functions on a pristine owner
returns `UNSUPPORTED`.

Earlier arm64 library, preserved unchanged:

```text
build/l2df-prototype/loaded-session-20260912/session-01/swift-build/arm64-apple-macosx/release/libNTSDNativeBridge.dylib
```

SHA-256 `9d52465bce04da2606358dd2a253d5c54ed9da3278b0b74e76b2d00d2f6bb2a7`;
6,584,216 bytes. Its data input root is
`build/l2df-prototype/loaded-session-20260912/resources-01/resources`.
The completed commands were:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 prototypes/l2df/native_bridge/build.py --study loaded-session-20260912 --label session-01
PYTHONDONTWRITEBYTECODE=1 python3 prototypes/l2df/native_bridge/check_ffi.py --study loaded-session-20260912 --build-label session-01 --label ffi-01 --resources build/l2df-prototype/loaded-session-20260912/resources-01/resources
```

Those labels already exist and refuse overwrite. Build took 83.90 s; native
LÖVE/FFI took 2.009 s and passed 269 assertions, including the retained Actor suite.
The external comparator initially hit a Python 3.9 `zip(strict=True)` error.
After the independently reviewed, equivalent length-guard correction,
`session-01/comparison-01/verification.json` passed on the same saved outputs.
No Native/FFI repetition or expected changes were needed. Each of two natural
settings trajectories matched 144 records, all 6,892 front events, 63 settings
events, 24 retained bitmap records and 53 globals/scratch checkpoint pairs.
All 186 compiled package files matched their frozen pins. Original failure and
both comparator versions are preserved. The full test adds no window or device
claim. See [the session contract](../../../docs/research/L2DF_LOADED_SESSION.md).

## Earlier Actor-storage foundation

ABI 1 also exposes **owned, unbound Actor storage** through
[ntsd_bridge.h](include/ntsd_bridge.h). It does not initialize a match and has no
tick entry point. The developer/setup API is infrastructure for connecting the
accepted Swift engine; it is not the game interface.

The bridge copies declared allocator backing, runs the accepted public
`OriginalStateRecord.actor(over:)`, and retains its bytes and initialization
masks. Opaque integer handles avoid dereferencing stale object pointers. Typed
reads reject unknown bytes. Setup batches commit all writes and one revision,
or preserve the complete previous record. The C caller must provide valid,
properly sized/aligned buffers; snapshot output buffers must not overlap.

Build from this worktree, using new labels for new authorized runs:

```sh
cd /Users/michael/Developer/ntsd-2.4-l2df-prototype
PYTHONDONTWRITEBYTECODE=1 python3 prototypes/l2df/native_bridge/build.py --label foundation-01
PYTHONDONTWRITEBYTECODE=1 python3 prototypes/l2df/native_bridge/check_ffi.py --build-label foundation-01 --label ffi-01
```

These labels already contain the completed proof; commands deliberately refuse
to overwrite them. `build.py` verifies X5 UUID/reserve and actual main sources
against pinned revision `ab0db06c6f0a6162f1935a1badbfc2a750822096`, copies all 167
Core and 16 codec files, and builds a new isolated package. It does not edit main
or the existing game. Build limit: 300 seconds/2 GiB. FFI limit: 90 seconds.

The completed library is:

```text
build/l2df-prototype/native-bridge-20260912/foundation-01/swift-build/arm64-apple-macosx/release/libNTSDNativeBridge.dylib
```

It is arm64, 6,330,776 bytes, SHA-256
`9a3cdc161f9ce4fe83c5d597cc40a228bf54d413054d55ee23d60d6390e6310b`.
It links only Apple system/Swift libraries and contains linker-generated ad-hoc
signing. This is a local development artifact, not a signed release bundle.

Native LÖVE 11.5/LuaJIT arm64 passed 201 FFI assertions and two independently
compared complete constructor records/masks. All 185 compiled package files
including the manifest matched their pins. Evidence and terminal jobs are under
`foundation-01/`, with final check in `ffi/ffi-01/verification.json`.

The next required step is an owned initialized catalog/session continued into
`OriginalLoadedGameplayCall`, adding ABI capabilities without recreating Actor,
World, globals or RNG from Lua each tick. Full gameplay, x86_64/universal builds,
window/input/audio devices and clean-Mac acceptance are outside this foundation
check. See [the finite plan and review](../../../docs/research/L2DF_NATIVE_BRIDGE.md).
