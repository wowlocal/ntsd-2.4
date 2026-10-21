# E6a survey: which profile rules are LF2 2.0a's and which NTSD's (read-only)

Worktree `/Volumes/NTSD-Builds/tasks/engine-split/worktree`, branch `exp/engine-split`, HEAD
`689ebcb3` (0cdd9b5f by the end: E7e-2 changed no engine source), 2026-10-21. Nothing edited, built or run in the worktree. Inputs: Swift sources,
`docs/research/*.md`, `docs/evidence/es-e5*.{json,md}`, `lib-runtime-static.json`, `es-e7e2-scan-policy.json`, its report and the loop's uncommitted `es-e6a-lf2-reference.json` (metadata). No content
bytes, EXE bytes or DLL bytes were read. Per-entry data: `es-e6a-classification.json` (`entries`, `hooks`, `libSites`,
`otherItems`, `exeStrings`). The use sites were found by grep (the agent's working files stay in the task scratch folder).

**Premise (the loop's static comparison, 2026-10-21, es-e6a-lf2-reference.json):** the `.text` of NTSD 2.4.exe equals lf2.exe's
except at 0x445561 (2 bytes), 0x4464ab (7) and 0x4464c4 (17). `.rdata` differs only at 0x44c600 (17
bytes), `.data` is identical and `.rsrc` differs. Every NTSD code change therefore comes from lib.dll.
An EXE rule outside the hooks' bypassed ranges is LF2 2.0a's.

## Result

| Class | Entries | What |
| --- | ---: | --- |
| LF2 2.0a code | **128** | All 107 ID roles of the 14 rule families, the AI special-move hook (403a40) and its 20 routines |
| data/identity | **10** | The 9 `interface` lists (names in `.rdata`, presumed; rectangles as `.text` immediates) and the label "NTSD 2.4 2.0a" |
| lib.dll (NTSD) | **0** | No profile entry. lib.dll behaviour lives outside the profile (§2) |
| unclear | **0** | Four caveats below; none changes a class |

No role's EXE address lies in a hook's bypassed range. No role's code is reachable only through a
hook. **E5 moved LF2 2.0a code into the game: all of E5c, E5d and E5e.** NTSD inherits these rules
because it puts its own DATs into LF2's ID slots. For example: 7+8→51 fusion, 122/123 drinks, 300
exemption, hidden 30–39/50–59, the AI's per-ID routines. The NTSD-only part is the lib.dll
behaviour, which the application turns on unconditionally.

## 1a. Hooks and their bypassed EXE ranges

The table comes from `lib-runtime-static.json` (original/installed bytes and the DLL's stored
continuations) and the LIB studies. "Fixed" means the range is never executed with lib.dll loaded.
"Conditional" means a path skips it only in some cases.

| Site → DLL | Original bytes | Continuations | Bypassed (study) |
| --- | --- | --- | --- |
| 430c8c → 100013d0 | cmp edx,8; jne 430ceb | 430ceb, 43187a | fixed 430c8c..430ceb: the kind-8 compare and its original body. The DLL redoes kind 8 with Z-addend bits `004176cb00447a08` instead of +1 (164 pristine outcomes change) and adds kinds 80–89/800–825 (LIB_WORLD_HITS) |
| 4176ac → 10001807 | cmp edx,8; jne 4176cf | 4176cb, 417f59 | fixed 4176ac..4176cb: the kind-8 defender-category test. The DLL filters kinds 8, 36, 80–89 and 800–825; a rejection goes to 417f59 (LIB_WORLD_CONTACTS) |
| 4177b9 → 100011b9 | mov eax,[esp+44]; … | 4177ca, 41780b, 417866 | fixed 4177b9..4177ca. For attacker state 20, also conditional 4177ca..41780b (old team/state-18 test) or a jump to 417866 |
| 42fcb1 → 10001322 | cmp eax,3; je 42fcbb | 42fcbb, 42fd1d | fixed 42fcb1..42fcbb: the effect 3/30 test. The DLL keeps it and adds effect ≥6000 → frame (LIB_WORLD_HITS) |
| 41f5fc → 1000109d | cmp eax,8000 | 41f60a, 41f675 | fixed 41f5fc..41f60a: the 8000..<9000 test. The DLL adds 4000..<4999 first and an Actor+7b4 write (LIB_TRANSFORMS) |
| 41408b → 10001125 | cmp [edx+ecx+7ac],… | 414099, 414243 | fixed 41408b..414099. The DLL adds states 85/86. A DLL slot holding 414159 is never used (LIB_ACTOR_CONTROL) |
| 401290 → 10001298 | push esi; … | return | the whole text routine (its end, before 4013d0, is not recorded): opaque SetBkColor becomes SetBkMode(1) with a retained DC |
| 424352 → 10001236 | push 3c; push …260 | 4243b1 | fixed 424352..4243b1: the old label code 424359..4243b0. The DLL's label is "Loading files" with phase colours (LIB_LOADING) |
| 424357 | `00 00` → `90 90` | – | inside the 424352 range; never executed |
| 4214d7 → 10001a9a | cmp [450bb8],… | 4214e4, 42154e, 421552, 42179b | fixed 4214d7..4214e4. For command word 3, also conditional 4214e4..42154e (the word-1 filter), replaced by the requested-ID scan (LIB_STAGE_COMMANDS) |
| 42d5ce → 10001b1b | mov [450c1c],ebp | 42d5d4 | 42d5ce..42d5d4 is re-executed; the DLL adds byte 450bb8 = 3 |
| 42d30b → 10001b2e | mov eax,[eax+edi+5db0] | 42d312 | re-executed; adds BG+0xc → 459ff8 before RNG 0xdb |
| 42d473 → 10001b48 | mov eax,[edx+edi+5db0] | 42d47a | re-executed; adds BG+0xc → 459ff8 and clobbers ECX (X changes) |

## 1b. Profile entries by family

The file:line of each NTSD value is in `native/Sources/NTSDProfile/NTSDProfile.swift` and is listed
per entry in the JSON. EXE ranges come from `es-e5a-id-sites.md` (rows A/D), `es-e5c-rest-plumbing.md`
(N1–N5) and the code comments.

| Family (roles) | Rows | EXE | Hooked function? | Class |
| --- | --- | --- | --- | --- |
| reflection (4) | A8, A12–A16, A20 | 42e87d..42fdf2 (42f70f..42fcaa), 417400 | yes: before 42fcb1 ("after damage, knockdown and reflection"); A20 is at the ITR loop head, before 4176ac | LF2 |
| armour (6) | A1–A6 | 42e100 guard test; 42fdf2..43056e | no | LF2 |
| interaction (4) | A17–A19, A21–A23 | 43056e..43187a (kinds 7/2/10/11); 417400 | yes: other kinds than 430c8c's kind-8 body. The 212 gate precedes 4177b9; A22/A23 follow the team gate | LF2 |
| impact (4) | A7, A9–A11 | 42e87d..42fdf2, 42ef45 | before 42fcb1 | LF2 |
| items (7) | A39–A44, A48–A50, A64 | 41eefb..41f2ac, 41b5d0, 417f80, 4214d5..421a15, 437400 | A48/A49 lie in 4214d7's conditional range, which runs for word 1; A50 lies after both paths | LF2 |
| roster (3) | A70–A79 | 42b290..42e0d2, 433550, 4356d8, 43986a, 433bc9, 435d59 | no | LF2 |
| modes (16) | D2–D4, D6–D10, D14, N5, A30, A51, A60–A65, A67 | 437400, 437860, 4386xx–43899d, 42cf8a..42d1ff, 42cb86, 41b130, 41b5d0, 43a910, 43abe2..43ac75, 4214d5 | A51 is reached through 42179b ("other words"); D8/D9 come before the preparation hooks | LF2 |
| physics (8) | A33–A38 | 40e490..40ef6a, 41e634..41eed1 | no | LF2 |
| drawing (2) | A45, A46 | 41a5a0..41ae50 | no | LF2 |
| effects (8) | A55–A59, N2–N4 | 41fb0b..4203b4, 420c7b, 420f89, 4211f6, 407232, 407ad5 | no | LF2 |
| lifecycle (8) | A28, A29, A31, A32, A47, N1 | 41f550..41fb0b, 41f734, 40d960, 41ddf2, 412fdd | yes: A31 is before 41f5fc; N1 and A29 come after 41f675 | LF2 |
| fusion (3) | A24–A26 | 4064d0..406a1f | no | LF2 |
| weaponBreak (15) | A52–A54 | 41f550..4214d5 (420537) | not in 41f5fc..41f60a | LF2 |
| characterAI (19) | A80–A91, A93–A98 | 4034f0, 408cb0, 409928..40bba3 | no | LF2 |
| characterAISpecial: hook + 20 routines | A92, A99 | 403a40 (after the 0x3c roll) and 403a7e..40618b, end 4061a0 | no | LF2 |
| interface (9) | E5f | 424755..427089, 41c2f5, 41be98, 4297ae, 438bbb, 43d08e, 43ccf2 | no | data/identity |

The 20-routine if-chain covers IDs 2,1,4,5,6,7,8,11,10,9,32,33,34,50,35,36,38,39,52,51. This is LF2
2.0a's own per-character AI. The names `naruto2` … `kyubi52` are the port's labels; the EXE has no
names.

**Interface (data/identity).** These entries are counted by item, so the front menu's two lists
(`frontBitmaps`, `frontSheets`) are separate entries.

| Kind | Entries | Where the values sit |
| --- | --- | --- |
| Names | `frontBitmaps` (24), `interfaceBitmaps` (10), `menuBitmaps` (11), `warBitmaps` (2) | Resource names pushed by `.text`, presumably `.rdata` strings. Their string addresses are not recorded in the repo. The bitmaps themselves are `.rsrc`, which differs between the EXEs. |
| Names | `commonSounds` (18), `menuSounds` (5) | Data-file names, presumably `.rdata` |
| Rectangles | `frontSheets` (151), `panelFrames` (11), `warModeFrames` (2) | `.text` immediates (es-e5f-plumbing §2) |

All of them have the same values in both EXEs, but they are content vocabulary and EXE-copied tables,
not rules.

**Caveats** (none moves an entry out of LF2 code):

1. The exact instruction addresses of A20–A23 inside 417400 are not recorded. Their order relative to
   the two contact hooks rests on LIB_WORLD_CONTACTS and on the engine's statement order. That order
   matches 10,661 library-enabled and 7,925 pristine calls.
2. A48/A49 are LF2 code that NTSD skips only for command word 3.
3. The original `jne` at 4176ac targets 4176cf, computed from the bytes, while the acceptance
   continuation is 4176cb. E6a should disassemble this; it does not affect any role.
4. The 17 bytes at 0x44c600 are now identified. The loop's uncommitted
   `docs/evidence/es-e6a-lf2-reference.json` (found in the worktree during this survey) shows they are
   the hint/name entry of import slot 0x447068: `IsDebuggerPresent` in LF2 2.0a and `LoadLibraryA` in
   NTSD. So no interface name lies there. Side effect in NTSD only: any CRT call through slot 0x447068
   calls LoadLibraryA instead. That call is not traced and is not modelled by any profile entry.

## 2. The engine's lib.dll-derived code

No single flag exists, and none is part of `OriginalGameRules`, `NTSDProfile` or the content identity.
Six carriers exist:

- `OriginalMatchPreparation.libraryCommands: OriginalLibStageCommands?`
  (`OriginalMatchPreparation.swift:26-28`). Nil means "the pristine EXE contract".
- `bundledLibrary: Bool = false` in `OriginalWorldControl`, `OriginalActorControl` and
  `OriginalWorldContacts`.
- `OriginalGameplayBody.Library?`, holding text, hits and transforms (`:9-17`).
- `OriginalLibSurfaceText`, threaded through the menus.
- `OriginalLibTransformBacking?`.
- `OriginalLibHitState?`, a field of `OriginalActorHits`.

The application turns all of them on unconditionally:

- `OriginalApplicationInputSession.swift:94-96` sets `match.libraryCommands = .init()`.
- `OriginalGameplayBody.swift:84` requires that `library` and `libraryCommands` agree; it derives
  `bundledLibrary` at `:102,112` and chooses `OriginalLibWorldHits` at `:117-122`.
- `OriginalApplicationGameplaySession.swift:98` builds `Library`.
- The menu sessions call only the `…WithLibrary` entry points.
- `OriginalApplicationBootstrap.swift:161` builds `libraryText`.

The shipped game therefore never runs a pristine path.

| Hook | Engine site (NTSDCore unless noted) | Pristine counterpart, and how it is chosen |
| --- | --- | --- |
| 41408b | `OriginalActorControl.swift:241-252` (`OriginalLibActorControl` is a wrapper used only by tests) | else branch; `bundledLibrary` |
| 4176ac, 4177b9 | `OriginalWorldContacts.swift:106-113,190-192,202` (`OriginalLibWorldContacts`, tests only) | kind-8 gate `:192`; `bundledLibrary` |
| 430c8c | `OriginalLibActorHits.swift:101-131`, called from `OriginalHitSpecial.swift:6` | `case 8` (+1); `library != nil` |
| 42fcb1 | `OriginalLibActorHits.swift:77-82`, called from `OriginalHitDamage.swift:93`; `OriginalLibHitState`/`OriginalLibWorldHits` `:3-13,44-72` | `OriginalWorldHits`; `GameplayBody:117-122` |
| 41f5fc | `OriginalPostDrawSlotPrefix.swift:227-236`, `OriginalLibTransformBacking` (`applyUsingBundledLibrary` has no callers) | nil backing; `GameplayBody:229`, Runtime `OriginalMacRuntimeLoading.swift:459,465-480` |
| 4214d7 | `OriginalPostDrawCommands.swift:37,118-131,227`, `OriginalLibStageCommands` | the word-1 path. `:37` falls back implicitly to `state.libraryCommands` |
| 42d30b/42d473/42d5ce | `OriginalMatchPreparation.swift:112-139,203-212,231-234` (`prepareUsingBundledLibrary`) | `prepare(mode:)` `:95-107` |
| 401290 | `OriginalLibSurfaceText`; the `Renderer` seam `OriginalSurfaceText.swift:8-15`; menu branches in FrontScreenBody, MenuPresentation, MenuReturn, ModeScreen, CharacterScreen, MatchSelection, MusicConfiguration, ComputerSelection, (Team)TournamentSetup, WarSetup | `OriginalSurfaceText`; entry-point choice (`advance` against `advanceWithLibrary`) |
| 401290 (no pristine path) | `OriginalNetworkMenu.swift:19,51`, `OriginalFrontScreenBody.swift:25-35`, `OriginalApplicationCatalogSession.swift:308-313`, `OriginalApplicationLoadedMenuSession.swift:316`; Runtime `OriginalMacRuntimeLoading.swift:349-356` (`demoMusicResidue`: the demo track as the ECX residue that 10001298 leaves); `OriginalMacDisplayBackend.swift:1216-1222` | none |
| 424352/424357 | `OriginalLibLoadingProgress` ("Loading files" at `:60`) | only the no-draw path (`OriginalInitialLoading.swift:10-30`); the animated pristine path throws |

**Pristine paths kept mostly as reference-check or test controls:**

- `OriginalLoadedGameplayCall`.
- The pristine `OriginalModeScreen`, `OriginalMenuReturn` and `OriginalMatchSelection` `advance`.
- `OriginalMusicConfiguration.advance`, used only by `NTSDProfileRosterTests`.
- `NTSDReferenceChecks`' `libraryEnabled = false` defaults, whose `NTSDCatalogCheck` uses false.

`OriginalLibSurfaceText.Response` also serves as the generic front-API response type: in the display
backend, Bootstrap, HostSession and MenuGraphicsRequestExchange.

## 3. An "LF2 2.0a default profile"

- **The engine could supply** every ID role of the 14 families (107 values, the same as NTSD's) and
  the 20 routines as the default `OriginalCharacterAISpecial` conformer. These are LF2 2.0a `.text`,
  and NTSD inherits them unchanged.
  - With D1 the armour thresholds, gravities and decade arithmetic that E5 kept in the engine are
    also confirmed LF2's.
  - The "engine default = no special IDs" of the E5 design becomes "engine default = LF2 2.0a". The
    synthetic `engineTests` rules stay a separate test profile.
- **NTSD-only (lib.dll):** nothing in the profile today, but the following are not yet behind a
  game-level switch:
  - the six carriers above and the application's unconditional enablement;
  - the DLL data held in engine code: "Loading files" with its colours, and the Z-addend bits;
  - the Runtime's `demoMusicResidue`.

  An LF2 default needs a profile or game value, such as `library`/`extensions`, that the NTSD game
  sets. It also needs pristine application paths where none exist: animated loading, the network
  menu, the own-startup front body, and the text-event filters.
- **Data the game must supply anyway:**
  - the 9 `interface` lists (the same in both EXEs, but they name and position the content);
  - `initial.bin` (`.data`, identical);
  - the content identity and the game identity.

  An LF2 2.0a content pack would carry the same interface lists and `initial.bin`.
- **What the scan policy now allows** (`es-e7e2-scan-policy.json`, user, 2026-10-21): "EXE strings:
  open; E6 sorts them by D1: LF2's stay engine text, NTSD's move to the game profile". Data-file
  names stay ("keep").
  - E7e-2's engine-literal report (`scratch/e7e2/scan-policy-2.json`) puts all 159 EXE-string hits
    in NTSD 2.4.exe `.rdata`. They come from 51 engine files, at file offsets 291568..310958, where
    raw = RVA. That is before the only differing run at 0x4c600 (312832), so every one is LF2 2.0a's
    and stays.
  - The only NTSD string in engine code is lib.dll's `Loading files` (DLL data 0x10003040..). At 13
    bytes it is below the scanner's 16-byte minimum, which is why the scan missed it. It moves to the
    game with its colours.
  - The 3 msvcr80.dll hits are CRT text.
  - By the same rule, the 6 interface **name** lists (resource and data-file names) and E5f's "stays
    (D1/E7)" constants could be the engine's LF2 default, with the game overriding them. Those
    constants are the music tracks and labels, `MENU_BACK%d`, the built-in background names and the
    EXE strings.
  - The 164 **rectangles** (`.text` immediates) are an EXE table that no policy class covers. The loop
    decides; the recommendation is to treat them like the names.
  - A cheap static E6a check: compare the `.rsrc` bitmap **names** of lf2.exe and NTSD (names only)
    to confirm that LF2's `.rsrc` also holds MENU_CLIP2–7 and CS2–6.
- **Moves back from the game:**
  - `NTSDCharacterAISpecial.swift` (E5d-3);
  - every ID-role value in `NTSDProfile.swift`.

  Optionally, per the policy above, the E5f interface lists move back too. `NTSDProfile` then
  shrinks to: the LF2 2.0a default, its label and the library extension switched on. NTSD's DATs and
  `.rsrc` remain its content.

## 4. Proposed E6 sub-steps

Each step is one commit, gated like E5's steps. Each is behaviour-neutral for NTSD: no NTSD value
changes.

| Step | Change | Files | Evidence needed |
| --- | --- | --- | --- |
| E6a | The reference part is already in progress, uncommitted in the worktree: `es-e6a-lf2-reference.json`, `es-e6a-lf2-files.json`, `tools/compare_pe_sections.py` and AGENTS.md's D1 line. Add this classification (a role→address→class table and the hook bypass table) after an independent review. Also: disassemble 4176ac's target, compare the `.rsrc` names, and record the EXE-string sort. | `docs/evidence/es-e6a-*.json`, ENGINE_SPLIT.md | static only |
| E6a-2 | Settle the policy's open "EXE strings": all 159 hits are `.rdata` before 0x4c600, so they are "keep". Move `Loading files` and its phase colours into the game's library data. | `tools/scan_original_bytes.py` POLICY, `OriginalLibLoadingProgress.swift`, `NTSDProfile.swift` | static; the scan rerun plus the loading suites |
| E6b | Move the ID families into the engine as its LF2 2.0a default values (for example `OriginalGameRules` LF2 families in a new `OriginalLF2Rules.swift`). `NTSDProfile.rules` composes them. A test checks that the new `NTSDProfile.rules ==` the old literal value, family by family, with a mechanical literal comparison as in E5. | `engine/Sources/NTSDCore/OriginalGameRules.swift` (+ the new file), `NTSDProfile.swift`, engine and native profile tests, doc comments | settled statically; gates as E5c (clean builds, mlgate, WASI vs, `*Check`, gate3 profile suites, a phone A/B for the hot passes because constants now live in the engine module) |
| E6c | Move the 20 routines back: `git mv NTSDCharacterAISpecial.swift` into the engine as the default conformer, then give the routines neutral names by ID in the same commit or a follow-up. The public surface that E5d-3 opened can narrow. | `NTSDCharacterAISpecial.swift` → `engine/Sources/NTSDCore/…`, `NTSDProfile.swift`, the `NTSDProfile` target's settings | settled statically (403a40..4061a0 has no hook); gates as E5d-3 (`OriginalCharacterAITests` corpora, symbol check, phone and Mac A/B) |
| E6d-1 | Make the library extension a game value. A profile or content-identity flag replaces `OriginalApplicationInputSession:94-96`, `GameplaySession:98` and `Bootstrap:161`. NTSD sets it. | `OriginalGameRules` (or the identity), the application sessions, `NTSDProfile` | none new (NTSD unchanged); mlgate set, library suites |
| E6d-2 | The menus and the Runtime follow the flag: `WithLibrary` against pristine, `demoMusicResidue`, the text-event filters. The DLL data constants are grouped as NTSD library data. | the menu sessions, MenuSession, LoadedMenuSession, CatalogSession, `NTSDRuntime/OriginalMacRuntimeLoading.swift`, the display backend | none new; mlgate set, per-host rows (Runtime) |
| E6e (optional, new behaviour) | Pristine models for the paths only lib.dll covers today: the animated loading label (424359..4243b0), the network menu's and front body's pristine text, and the filters. | `OriginalLibLoadingProgress`/`OriginalInitialLoading`, `OriginalNetworkMenu`, `OriginalFrontScreenBody` | **new pristine comparisons**. Either EXE below the library entry works (the code is identical) |
| outside E6 | Claim that the engine default reproduces LF2 2.0a gameplay. Needs an LF2 2.0a content identity and loaders, then the engine on LF2's data against lf2.exe (the Unicorn harness or CrossOver). | content identity, new fixtures | **new comparison against lf2.exe** (LF2 data never ran) |

**The pristine-EXE controls as LF2 2.0a evidence.** LIB_RUNTIME's earlier fixtures executed NTSD
2.4.exe *below* the library-loading entry: no lib.dll, and neither the entry call nor the detour was
executed. With identical `.text` outside those three ranges and identical `.data`/`initial.bin`,
those runs executed exactly lf2.exe's instructions. Examples:

- LIB_WORLD_HITS: 7,845 ×2 precision corpora (the 164 old kind-8 outcomes are LF2's);
- LIB_WORLD_CONTACTS: 7,925;
- LIB_ACTOR_CONTROL: 25,795;
- LIB_TRANSFORMS: 897;
- LIB_MODE_SCREEN: 1,264 screens;
- LIB_STAGE_COMMANDS: 3,898 probes and 50 preparations;
- the initial and menu loading fixtures.

They are valid evidence that the engine's pristine paths model **LF2 2.0a's code**. They are not
evidence of LF2 2.0a's game, for four reasons:

- Their inputs are NTSD's DATs, catalog, `.rsrc` bitmaps and declared API responses, so code paths
  that only LF2's data reaches are not exercised.
- They are controlled callers, not an application. (The same limit holds for NTSD.)
- Any read of `.rdata` 0x44c600 or of `.rsrc` would differ. E6a should confirm that no compared
  path reads 0x44c600.
- The engine's runtime never takes those pristine paths today (§2).

Steps E6a–E6d need no execution of lf2.exe.
