# Native bridge foundation

ABI 1 exposes **owned, unbound Actor storage** through
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
