# E5d survey: the character AI's hook and routines (2026-10-20)

A read-only survey by a separate agent at `85dc2e40` (nothing built or run;
"inf." marks inference, the rest is read code). Recorded verbatim in
substance; the loop's decisions on it are in the card's E5d notes.

## 1. Where the AI lives

- **Entry.** `OriginalCharacterAI.apply`/`applyInPlace` (public;
  `engine/Sources/NTSDCore/OriginalCharacterAI.swift:12,23`) build
  `OriginalCharacterAIPass` (internal struct, :38). `run` :110 → `setup`
  :159 / `search` :214 / `items` :250 / `idle` :314, or `fight` :333 →
  `special` :511 → `approach`/`weapon`/`tactics`/`attackHelper`.
- **0x403a40.** `special` :511–537, in order: the entry roll
  `draw(0x3c, g(0x44f618)&+1) > 0 → false` (:512) for every ID; `let own =
  try id(s)` (:513); `switch own` (:514–535), `default: false`. A true result
  ends `fight` (:373).
- **The 20 routines** (`OriginalCharacterAISpecial.swift`; random streams):
  naruto2 :23 (3d–40), sakura1 :59 (41–4a), sai4 :84 (4b–4d), shino5 :97
  (4e–51), hsasori6 :112 (52–54), lee7 :120 (55–58), chiyo8 :159 (59–5c),
  sasuke11 :203 (5d–5e), deidara10 :211 (5f–64), itachi9 :243 (65–68),
  hunter32 :265 (69–6b), clone33 :380 (6c), kidomaru34 :278 (6d), pein50
  :284 (6e–6f), sakon35 :298 (70), tayuya36 :308 (71–72), sasukeCS38 :324
  (73–75), sand39 :335 (76–77), kyubi52 :347 (78, 7b–7e), sasori51 :367
  (7f–81). EXE ranges: `es-e5a-id-sites.md` §E. Shared helpers: `command`
  :5, `aimed` :7, `wounded` :10, `dx`/`dz` :14–15, `facingToward` :17,
  `healAlly` :38, `lunge` :181, `dash(reach:mp:)` :188, `frameField` :196.
- **Reads:** Actor `+0x10/14/18/40(ftol)/70/80/98/2fc/300/308/364`, frame `+8`
  (state) and `+0x2c` (`frameField`), globals `0x44f604`/`0x44f608`, World
  activity and the actor table. **Writes:** buttons `0xcd–d3` and their
  previous copies `c6–cc`, commands `0xd4–dc`, the RNG words
  `0x450bcc`/`0x450c34`, and the events. No World or Object writes.
- **Per tick:** `OriginalRuntimeSession.swift:415` →
  `OriginalMacRuntimeLoading.complete` :394 → `runCycle` :358 →
  `cycle.advance(dispatch:)` (Runtime closure :363–376) →
  `OriginalApplicationLoadedCycleSession.advance` :20 →
  `OriginalLoadedMatchCycle.run` → `OriginalLoadedMatchEntry.run` :24 →
  `localInputInPlace` (`OriginalLocalInput.swift:113–127`, slots 10..<400 of
  type 0) → `applyInPlace(state:&match)` :369. Reached from the input step,
  not the gameplay body; all six hosts share this Runtime path.
  `CharacterAIReference.swift:104–151` is the only other caller
  (`OriginalCharacterAITests`, `NTSDCatalogCheck/main.swift:168`).
- **Errors:** `OriginalStateError.invalidStorage("Character-AI …")` from the
  primitives; `outsideVerifiedDomain` from the RNG's `validate` and from
  `idle` :321 (Runtime maps it to `Boundary.unexpected`, :370).
- **Events and in-place:** `draw` (:90) appends `.random` events, observed
  after `run` (:34); `inPlaceTake` moves the records in and `defer` writes them
  back (:29–32); the pass is a local `var` (statically checked accesses).
- **ID rows:** the special holds A92 (the switch) and A99 (`[2,9,10,11,33,34]`,
  Special :26); the generic part holds A80–A91 and A93–A98 at the survey's
  lines (still matching). A96 builds a `Set<Int32>` on every call (:613).

## 2. Primitives the routines need (all internal today)

- **Types:** `OriginalCharacterAIPass` :38, `Key` :48, `Locals` :131 (the
  routines read `nearest38`, `ball30`, `aligned34`, `tState`).
- **Members:** `g` :51, `active` :53, `index` :57, `i` :63, `facing` :64, `id`
  :70, `type` :71, `state` :72, `ftol` :79, `byte` :81, `press` :82,
  `release` :83, `abs` :89, `draw` :90.
- **`abs` is a silent trap.** If it is not visible from the other module,
  `abs(…)` in `dx`/`dz`, `dash`, `itachi9`, `kyubi52`, `clone33`, `healAlly`
  and `lee7` resolves to `Swift.abs`, which traps on `Int32.min` where the
  pass's `0 &- v` wraps. Nothing fails to compile.
- **`frameField`** stays in the engine as a public primitive (otherwise the
  game calls the generic `integer<T>` directly and `object`/`objects`/`error`
  go public too). Inf.: 2.8.3.3's stride differences inside hsasori6/sasuke11
  then stay in engine primitives.
- **`package` cannot work:** `native` depends on `engine` as a separate package
  (`native/Package.swift:96`): `public` or `@_spi(GameProfile) public`.
- **Already public:** `OriginalStateRecord.integer`/`write`,
  `OriginalLoadedObject.frameStorage`, `OriginalStateError`.

## 3. The hook's shape

- **(a) Recommended:** a protocol `OriginalCharacterAISpecial: Sendable` inside
  `OriginalGameRules`' `Roles`. Signature `func special(own: Int32, _ ai: inout
  OriginalCharacterAIPass, s: Int, t: Int, slot: Int, _ l: Locals) throws ->
  Bool`. Path: `applyInPlace` already copies `state.catalog` (:25), whose
  rules come from the content identity; no public `apply` signature changes;
  `CharacterAIReference` already loads with `NTSDProfile.rules`. Equality adds
  a same-type check (`ObjectIdentifier` of the metatype; stateless structs).
  Cost: one witness call per `fight` past the roll (≤10 per tick); no retain
  for the existential copy. Passed as a parameter (`run`→`fight`→`special`),
  not a pass field (a retain per call, and `self.hook.special(&self)` would
  overlap). This revises E5c-0's "hooks travel separately (e.g.
  `OriginalGame`)": 2.8.3.3 picks content per session, so a hook in
  `OriginalGame` could pair with the wrong content.
- **(a′)** The same protocol in `OriginalGame` or a parallel path: about 30
  plumbing edits or a host/session chain; changes the public `apply`
  signatures (6 reference calls).
- **(b)** Generic over the game type: spreads through the catalog, match state,
  sessions and hosts for one devirtualized call. Rejected.
- **(c)** An engine table (`[Int32: routine enum]`): free at run time, no public
  surface, but NTSD's code stays in the engine against E5/E7. An interim step
  or a fallback only.

## 4. Increments

1. **E5d-1: the generic AI's roles** (A80–A91, A93–A98), a `CharacterAI`
   family; rules as parameters from `applyInPlace` (`catalog.rules`, :25)
   through `run`, `setup`, `items`, `idle`, `fight`, `approach`, `tactics`,
   `item`, `weapon`, `attackHelper`, `dash` (all internal). Public: the family,
   `characterAI:` on `OriginalGameRules.init`, accessors; three constructions
   and new `NTSDProfileCharacterAITests`. Keep A80's short-circuit `slot<20 ||
   id<30`, A83 `id/100==1` (equal to `100..<200` for every `Int32`), A98's
   stream 0x3a drawn only on an ID match, A96's two `id(s)` reads. Decide at
   review whether 200 (A81/A84/A88) is one role and A86's (id, frame window)
   table; optionally two increments.
2. **E5d-2: the hook, routines still in the engine.** The protocol and a
   temporary public engine conformer wrapping today's switch; `special` keeps
   the roll and the `own` read, then calls the hook. The pass, `Key` and
   `Locals` become public types (members internal). `engineTests` gets an
   always-false conformer (tests only; no runtime default). Tests: the order
   (roll, ID read, hook) and true/false ending or continuing `fight`.
3. **E5d-3: the routines to the game.** `git mv`
   `OriginalCharacterAISpecial.swift` to `native/Sources/NTSDProfile/` with the
   import; `frameField` stays; the 14 members public or SPI; the temporary
   conformer removed; `NTSDProfile` gets the cross-module and exclusivity
   settings; an `Int32.min` `dx` test for the `abs` trap; an `nm`/demangle
   check that the release `NTSDProfile` object calls no unspecialised
   `integer<T>`, listing the primitives not inlined.

Gates for each (as E5c-1i): the mlgate set from clean builds; WASI vs; all
`*Check` products with `NTSDCatalogCheck`'s AI reference; gate3 with
`OriginalCharacterAITests` (two corpora, 7,770 calls, every owner —
RESEARCH_MAP:224), `OriginalLocalInputTests`, `OriginalMacRuntimeLoadingTests`
and the `NTSDProfile*` suites; `swift_beginAccess` 3,278; phone and Mac A/Bs
(E5d-2/3 especially) with `characterAI` > 0 in the run's JSON; rule 5. No
frozen candidate under `tools/` copies the AI.

Risks: stale cross-module builds (`Roles` and the pass layout change; clean
builds mandatory); lost inlining across modules in E5d-3 (inf.: small, each
`draw` already copies the 3,000-byte RNG table); wasm32: no new `Int(UInt32)`
conversions.

## 5. Open questions

- **For the user:** none blocks E5d. Inf.: an engine default profile with
  LF2's own routines belongs to D1/E6; the SPI-or-public surface can be
  revisited at E8.
- **For the loop:** the carrier (revising E5c-0), parameter or field, role
  granularity (200, the drinks, the A86 table), `@_spi` or `public`, whether
  cross-module optimization on `NTSDProfile` helps (inf.: Core's own flag is
  what makes the primitives inlinable).
