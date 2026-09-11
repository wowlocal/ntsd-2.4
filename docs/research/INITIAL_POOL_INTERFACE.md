# Initial Actor pool and UI composition

The native41c052..41c581 continuation now requests Actor backing one slot at a
time, constructs each Actor before requesting the next, reconstructs slots0..7,
and loads all10 interface bitmaps through the complete surface loader. One
value-semantic allocator/device context commits after the whole operation.

This extends the comparison of the ten unchanged
[controlled UI chains](INITIAL_INTERFACE_SURFACE.md). It performs no new EXE
execution and does not complete the pending own application-catalog chain.
The bounded plan is [INITIAL_POOL_INTERFACE_PLAN](INITIAL_POOL_INTERFACE_PLAN.md).

## Original evidence and native behavior

The original NTSD EXE is pinned to
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`; its VC80 CRT
is `c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d`.
The retained corpus executes World/Actor constructors, actual CRT memset and
whole bitmap loading/copying on one controlled Unicorn CPU. It supplies
catalog[0], Object+90, outer frame, allocator backing and platform responses.
All original bytes, writes, expected results and masks remain immutable.

At41c075 the caller requests0x420 bytes for one Actor, executes4061d0, sets
its coordinates/catalog reference, and stores the World slot before advancing
to the next allocation. The native bootstrap previously received all400
backing arrays up front. Its new allocation callback preserves this operation
order; the older array initializer delegates to the same body.

The constructor observer receives the native record immediately after4061d0,
before caller field writes. The staging loop provides the same boundary after
each reconstruction of slots0..7. Its observer can throw; staged copies retain
the previous pool until all eight slots succeed. Canonical non-null World/Actor/
Object ordinal bindings remain the existing bootstrap representation.

[OriginalInitialPoolAndInterface](../../native/Sources/NTSDCore/OriginalInitialPoolAndInterface.swift)
composes that bootstrap with `loadWithSurfaceLoading`. It receives an existing
World, globals, and first Object+90. A future own caller must read the latter
from its own loaded catalog. This API does not load a catalog or select players.
It stages the supplied value-semantic context and returns bootstrap, interface
and globals together. Callers must buffer external effects in their context.

Numeric bitmap failures continue with the original stores and cleanup. A thrown
allocator, constructor observer or UI dependency leaves the caller's context
unchanged and publishes no new result. This is native rollback; the controlled
Actor allocations are all non-null and establish no source NULL-Actor behavior.

## Comparison

The committed test independently replays the original writes up to each Actor
helper's recorded return. It reconstructs complete bytes and defined masks from
declared allocation patterns, preserving earlier caller stores before the second
constructor pass. Only the established Object pointer at+368 is bound to its
native ordinal when the source mask proves that field defined. These expected
records never supply input to native constructors.

All ten chains match4000 allocation requests and4080 full constructor records:
4,308,480 bytes plus masks. Final World/Actor/bitmap comparisons add4095 records/
4,925,440 bytes plus masks:8175 record comparisons/9,233,920 bytes plus masks in
total. The constructor-return checks are new; final UI records reuse the same
accepted expected data. Constructor order is0..399 then0..7. Both A5 and ramp/
reverse-placement cases remain, along with the accepted bitmap failure cases.

The same composed passes compare UI request/global order and resource bookkeeping:
100 bitmap allocation requests,85 constructors and1406 platform requests. Ten
declared selector assignments remain controlled inputs. The original initial
interface tests also continue to compare all13 older cases through both providers.
Eight retained bootstrap layouts compare all6416 records/6,790,528 bytes and
masks through the delegated initializer. None of these counts proves all branch
outcomes, private C++ ABI, actual Windows allocation, hardware FPU or device output.
Recorded CW0 remains the UI corpus's controlled environment.

Seven native-only controls verify rollback: last Actor allocation; final staging
constructor observer; completed-pool observer; tenth CreateSurface; tenth
DeleteObject; last global-store observer; and a direct late staging observer
over a previously constructed pool. Existing numeric resource failures remain
successful original/native continuations under their declared API responses.

The later [postcatalog continuation](INITIAL_LOADING_CONTINUATION.md) now defers
Object+90 reads until each staging consumer, compares all80 retained read
boundaries and adds an eighth-read rollback control. It also retains actual
native catalog/common resources through this pool/UI result. The source corpus
and this milestone's original comparison below remain unchanged.

## Verification and remaining work

An independent package exported accepted72cd808 plus only the three native code/
test files passed12 release tests in7.119s, build225.60s. New tests took5.079s,
including2.973s for all ten constructor/final-state comparisons. No raw override
was used. NTSDNative linked; no application window or device was exercised.

All628 archived native files were independently verified against their hashes;
625 base files remain byte-identical. All247 existing fixture pins are unchanged;
no new fixture was created. The original corpus SHA remains
`703086bd4b03017ca5aebfed49af80472cc0e1ee960f60c259adb031b81356dd`, and its
packed fixture SHA remains
`7f739a9a72c7fc66c740a5dae8afaa4364219b5c11ce24d2962593b3c2fa7df3`.
Build inputs and results are recorded in
[initial-pool-interface.json](../evidence/initial-pool-interface.json).

```sh
swift test --package-path native -c release --filter 'OriginalInitialPoolAndInterfaceTests|OriginalBootstrapTests|OriginalInitialInterfaceTests|OriginalInitialInterfaceSurfaceTests'
```

The three own catalog captures continue separately. Their new child-state
observer was copied from its tested overlay only after its one-shot source/native
verifier and children were terminal; original archived inputs remain preserved.
Full own catalog ret8, own pool/UI, whole41bc90 return, application input/render/
sound, Windows/device, full-match/all-content and clean-Mac checks remain open.
