# E5c-0 plumbing survey (read only, worktree 144022f1)

## 1. Catalog construction paths
`OriginalLoadedCatalog` (engine/Sources/NTSDCore/OriginalLoadedCatalog.swift) has three public entry points: `init(source:[UInt8]…)` :37, `init(source:()throws…)` :66 (no caller), `static loadWithFiles` :97. All three funnel into `private init(…fileSession:)` :130. `frameAllocationOrder` is set at :250. There are five call sites:
- engine OriginalApplicationCatalogSession.swift:390 (`Attempt.run`, `loadWithFiles`). This is the only runtime path. It has `inputs: Resources`.
- native/Sources/NTSDReferenceChecks/LoadedCatalogReference.swift:203 (`loadWithFiles`) and :250 (`init(source:[UInt8])`). 29 files reach a catalog through `LoadedCatalogReference.compare(…onLoaded:)`: 25 test files plus NTSDCatalogCheck, CatalogSoundsReference and MatchPreparationReference. NTSDReferenceChecks depends only on `core` and CZlib, so it has no NTSDContent.
- native/Tests OriginalCatalogChecksumTests.swift:20 (`loadWithFiles`). It already has `inputs` from NTSDContent.identity.
- native/Tests OriginalWarSetupNativeTests.swift:30 (a synthetic `.init(source:)`).
There are none in engine/Tests.

## 2. Content to catalog path
`OriginalRuntimeSession.contentLocation()` (NTSDRuntime/OriginalRuntimeSession.swift:160) returns `host.contentLocation` → `OriginalGame.content(bundle)` (NTSDContent.location). It continues through `OriginalRuntimeLoadingPackages(in:)` (:267/:391; OriginalMacRuntimeLoading.swift:39) → `OriginalApplicationCatalogInputs.bundled(in:)` → `load(directory:identity:)` (OriginalApplicationCatalogInputs.swift:30; the identity is checked and then dropped). From there it goes to `OriginalMacRuntimeLoading.run` :218 `Catalog.Resources(files:bitmaps:…)` → `catalog.load(resources:)` → `Attempt.run` → :390. The second entry, `load(inputs:)` :112, builds Resources from `Inputs` (:41) and is used only by OriginalApplicationCatalogSessionTests.
**2.8.3.3** (`git show exp/ntsd-2.8.3.3:native/Sources/NTSDRuntime/OriginalRuntimeContentInputs.swift`): this is a session-owned class with `identity: String` ("NTSD-2.4-2.0a" or "NTSD-2.8.3.3-partial") and a `.baseline(bundle)`/`.target` source. The session takes it in `init(…contentInputs:)`, and `acquireLoading` builds `OriginalRuntimeLoadingPackages(in:bundle)`. On this branch's model it becomes a per-session `OriginalContentLocation` whose identity carries that profile's rules. Those rules then flow through the same packages → inputs → Resources path with no extra plumbing. The target still stops at `unsupportedTargetStartup`, and its layout differs, which the rules do not cover.

## 3. How the passes reach headers
- `OriginalHitPass` (OriginalActorHits.swift:59) is a struct. It holds `var world/actors/globals/memory/crt` and `let objectCount`, `let header: (Int) throws -> OriginalStateRecord` and `let frame`. It does **not** hold the catalog. `h(a,o)` = `header(object(a))` (:83), where `object` reads actor `+0x368`. Both `makePass` overloads (:17 and :37) do `let catalog = state.catalog` (a separate local `let` struct copy, taken before any `inPlaceTake`), and the closures capture that copy.
- `OriginalContactPass` (OriginalWorldContacts.swift:85) works the same way. `apply(state:)` :19 does `let catalog = state.catalog`, the closures capture it, and the internal `apply(world:…header:…)` :37 builds the pass.
- The cheapest route that also avoids any overlap is a stored `let rules` in each pass, filled from the local `catalog.rules`. A `mutating` method reading its own `let` is a plain read, with no inout overlap and no closure call.

## 4. Fixtures that construct catalogs or passes
- Catalog: the 2 reference sites, the 2 test sites above, and the session Resources/Inputs helpers OriginalApplicationCatalogFullTests.swift:177-182 (shared by the LoadedMenu, LoadedCycle, Pool and Mac LoadingAudio suites) and OriginalApplicationCatalogSessionTests.swift:15-21.
- Passes: OriginalActorHitsTests:107, OriginalLibActorHitsTests:101 (+ explicit `apply` at :120, :191, :205), OriginalWorldContactsTests:92 (+ `apply` at :105, :159, :167), OriginalLibWorldContactsTests:91 (+ `apply` at :101, :148). That is 4 files and 12 call sites.
- `OriginalMatchPreparation(catalog:…)` appears 15 times in 17 files. None of them need changes if the catalog carries the rules.

## 5. Choice of carrier and hot-path cost
`OriginalMatchPreparation` stores `let catalog` (internal, :49). Carrying the rules there instead would touch 15+ constructions and would not reach the pre-match menu sites (E5c-2). Threading the rules through the tick APIs touches more code still. The catalog is the right carrier, with `OriginalContentIdentity` as the source (it already reaches every loader through `load(directory:identity:)`, including the test helpers in NTSDContentLocations.swift).
On cost: `state.catalog` is a struct copy (array references retained once per pass). In the contact loop each `h()` is an indirect call through a closure (a function plus its context, not an existential or a class) that returns a copy of `OriginalStateRecord`. Today the list is a hashed `static let Set<Int32>` in hits and a literal `[…].contains` in contacts. A bit set is one compare plus one load, so it should be no slower. Rule 5's phone A/B still applies.

**ID set compared with per-ordinal masks.** The ID set keeps each site's own `h(d,0x6f4)` read, throw and order, and replaces only `.contains`. A mask needs the ordinal, which means a second `object()` read or a changed helper. The ID set is also exact even if headers were ever mutable, and it is the same mechanism as the value predicates the design wants for A60–A67. It does depart from the reviewed design's wording ("compiled … into per-ordinal masks"), so the card's design note must state the change and why.

## Recommended plumbing
```swift
// engine/Sources/NTSDCore/OriginalGameRules.swift (new)
public struct OriginalIDSet: Equatable, Sendable {
    public let ids: [Int32]           // the literal list, for review and tests
    let words: [UInt64]
    public init(_ ids: [Int32])       // precondition 0 <= id < 65536; duplicates harmless
    func contains(_ id: Int32) -> Bool {
        let w = Int(UInt32(bitPattern: id) >> 6)   // negatives become huge: one compare; Int-safe on wasm32
        return w < words.count && words[w] >> UInt64(UInt32(bitPattern: id) & 63) & 1 != 0
    }
}
public struct OriginalGameRules: Equatable, Sendable {
    public let profile: String                 // the profile identity
    public let reflectable: OriginalIDSet      // A8, A12–A16, A20
    public init(profile: String, reflectable: OriginalIDSet)
}
```
Changes, none with a default:
- `OriginalContentIdentity.rules` (init parameter). `OriginalApplicationCatalogInputs.rules = identity.rules` (also kept by `replacingFile`).
- `Catalog.Resources.rules` and `Catalog.Inputs.rules`, plus `load(inputs:)` passing it on.
- `OriginalLoadedCatalog.rules` (`public let`) on all 3 public constructors and the private init. At :390 pass `rules: inputs.rules`. In OriginalMacRuntimeLoading:218 pass `rules: catalogInputs.rules`.
- `OriginalHitPass.rules` / `OriginalContactPass.rules` (`let`, declared after `frame`/`heapWord`). In both `makePass` overloads and in `apply(state:)` pass `rules: catalog.rules`. The internal `apply(world:)` and the public `OriginalLibActorHits.apply(…header:…)` and `OriginalLibWorldContacts.apply(…header:…)` take a required `rules:`.
- Game side: `NTSDContent.rules = OriginalGameRules(profile:"NTSD 2.4 2.0a", reflectable:[200,203,205,206,207,215,216])` and `identity(…rules: rules)`. For LoadedCatalogReference, either add an NTSDContent dependency (Package.swift:116) and use NTSDContent.rules internally, so the 29 callers stay unchanged, or add a resource-free game target for the rules.

Call-site edits for the two reflection sites:
- OriginalHitDamage.swift: delete `static let reflectable` (:135). At :44, :149, :154 and :158 replace `Self.reflectable.contains(` with `rules.reflectable.contains(`.
- OriginalWorldContacts.swift:177: replace `[200,203,205,206,207,215,216].contains(attackID)` with `rules.reflectable.contains(attackID)`. The per-box `attackID` re-read stays.

## Files
Engine: OriginalGameRules.swift (new), OriginalContentIdentity, OriginalApplicationCatalogInputs, OriginalApplicationCatalogControls, OriginalApplicationCatalogSession, OriginalLoadedCatalog, OriginalActorHits, OriginalHitDamage, OriginalLibActorHits, OriginalWorldContacts, OriginalLibWorldContacts, NTSDRuntime/OriginalMacRuntimeLoading.
Game: NTSDContent.swift, NTSDReferenceChecks/LoadedCatalogReference.swift, Package.swift.
Tests: OriginalCatalogChecksumTests, OriginalWarSetupNativeTests, OriginalApplicationCatalogFullTests, OriginalApplicationCatalogSessionTests, OriginalActorHitsTests, OriginalLibActorHitsTests, OriginalWorldContactsTests, OriginalLibWorldContactsTests, a new rules test (`contains` checked against the literal over Int32.min, -1, 0…4096 and Int32.max) plus its CorelibsXCTestSupport line.
Docs: the ENGINE_SPLIT design note and the evidence JSON.
