# E5a survey: the 0x44d000 record, EXE tables in engine code, content couplings

Read-only survey, 2026-10-19, worktree `/Volumes/NTSD-Builds/tasks/engine-split/worktree`
(branch `exp/engine-split`, HEAD `40611c4d`, clean). No repository file changed, nothing
built, no content bytes read: `initial.bin`/`initial.mask` were not opened; only the
startup `manifest.json` structure, file names/sizes, the packer source
(`tools/package_startup_inputs.py`) and git blob ids were used. Address census by a
script over `engine/Sources` (hex literals in `0x44d000..<0x4593a8`).

Kinds of claim: **S** = read in source/manifest; **I** = inference.

## 1. The record and `initial.bin`

### 1.1 What `initial.bin` is (S)

- `native/Sources/NTSDContent/Resources/OriginalStartup/`: `manifest.json` (15 KB),
  `initial.bin` (50,088 = 0xc3a8 B), `initial.mask` (50,088 B), `bitmaps/` (36 DIBs from
  the EXE's resources), `data/` (7 original files: `adinfo.txt`, `control.txt`, five
  `m_*.wav`). 45 manifest entries; `absentFiles: ["data/ad0.txt"]`.
- Manifest `provenance.globalSpans`: one span, `address 0x44d000, count 0xc3a8`, from
  section `.data` with `fileSize 8192`, `virtualSize 50980`.
- Producer `tools/package_startup_inputs.py:22-36`: for `0x44d000..<0x4593a8`, the
  byte is the EXE file byte if `offset < fileSize`, else `0`. The mask is 1 everywhere.
  So **`initial.bin` = 8,192 file-backed bytes of `.data` (`0x44d000..<0x44f000`) +
  41,896 zero-fill bytes (`0x44f000..<0x4593a8`)**. Every byte is defined
  (PE zero-fill counts as known). The record stops 0x37c bytes before the
  section's virtual end (`0x459724`).
- Blob ids are the same on `exp/ntsd-2.8.3.3`: `initial.bin` 37c7d2de…,
  `initial.mask` 20ec2a87…, `manifest.json` 414ff0d2….

### 1.2 How it reaches the engine (S)

| Step | file:line |
| --- | --- |
| Game: `NTSDContent.identity` (EXE SHA, startup manifest SHA `f67aff08…`, 45 entries, absent `data/ad0.txt`); `NTSDContent.location(in:)` → `OriginalContentLocation(appBundle:identity:fallback:)` | `native/Sources/NTSDContent/NTSDContent.swift:14-33` |
| Host answers `contentLocation(in:)`; session takes it | `engine/Sources/NTSDRuntime/OriginalRuntimeSession.swift:33,160` |
| Session start: `OriginalApplicationStartupInputs.bundled(in:resources)` (read once, kept for loading) | `OriginalRuntimeSession.swift:241-242`, reuse `:388-389` |
| Folder lookup `content.directory("OriginalStartup")` | `engine/Sources/NTSDCore/OriginalApplicationStartupInputs.swift:124-129` |
| Manifest digest vs `identity.startup.manifestSHA256`; contract `version 1`, **`globalAddress == 0x44d000`, `globalCount == 0xc3a8`** (engine literals), `exeSHA256`, absent files, entry count | `OriginalApplicationStartupInputs.swift:139-144` |
| Composition: exactly the manifest's files; `initial.bin`/`initial.mask` present, **`count == 0xc3a8`**, mask all 1 → `OriginalStateRecord(bytes:defined:)` | `:185-187` |
| `OriginalMacRuntimeStartup.run` → `Driver(…, instance:0x400000, show:10, initial: inputs.initial)` | `engine/Sources/NTSDRuntime/OriginalMacRuntimeStartup.swift:93-97` |
| `OriginalApplicationWindowStartup`/`ObservedStartup` → `host.start(…initial:)` | `OriginalApplicationWindowStartup.swift:26-63`, `OriginalApplicationObservedStartup.swift:26-63` |
| `OriginalApplicationHostSession.start(…initial:)` | `OriginalApplicationHostSession.swift:226-235` |
| `OriginalApplicationBootstrap.start`: checks `initial.byteCount == 0xc3a8`; slices `0..<0xb440` (`OriginalMatchPreparation.globalSize`) as `globals` for `OriginalWinMainStartup.run`, writes it back into the full image, builds `Session.State(full:)`; loop counter from `full[0xb580]`, replay pointers `slice(full,0xb8a8,8)` | `OriginalApplicationBootstrap.swift:132-170` |
| Menu state holds `full` in parts `[0,0xb440,0xb580,0xb588,0xb8a8,0xb8b0,0xbb00,0xc2d8]` (CORE_REALTIME B1, copy-on-write per part) | `OriginalApplicationMenuSession.swift:8-15,46-48` |

Nothing else reads `inputs.initial` (the other startup-package users take bitmaps,
`data\control.txt` and the WAVs). Tests seed parts of the record without
`initial.bin` (see §2, rows 1–2).

### 1.3 Is the layout written down as types? (S)

No. There is no Swift type or offset table for the record. Accesses are raw EXE
addresses minus the base, written at each site: 426 distinct addresses in
`0x44d000..<0x4593a8` on 2,181 source lines in 133 engine files; literal `0x44d000`
on 138 lines/46 files, `globalBase` on 168 lines/72 files. Extents are repeated
constants:

| Constant | Where |
| --- | --- |
| base `0x44d000` | `OriginalMatchPreparation.globalBase` (`OriginalMatchPreparation.swift:14`) + literals in 46 files + manifest check `OriginalApplicationStartupInputs.swift:142` |
| match globals `0xb440` (`0x458440-base`) | `OriginalMatchPreparation.globalSize` (`:15`), `OriginalApplicationMenuSession.globalCount` (`:8`) |
| full record `0xc3a8` | `OriginalApplicationDispatchEntry.globalSize` (`:7`), `OriginalApplicationStartupInputs.swift:142,186` |
| outer block `0x458440` | `OriginalWindowInput.localBase` (`:5`), `OriginalStartupStorage.observedBase` (`:5`, count 0x854) |
| parts | `OriginalApplicationMenuSession.partStarts` (`:15`) |
| World `0x458b00`, `0x7d8` | `OriginalApplicationMatchBindings.swift:134`, `OriginalApplicationPoolSession.swift:259`, `OriginalStateRecord.worldPrefixSize` |

Documentation: partial address tables in `docs/research/ADDRESS_BOOK.md`
(e.g. lines 296–300: World fields, pause queue, RNG `0x44ff90/0x450bcc/0x450c34`)
and in each study card; no single layout document.

### 1.4 Record map and consumers (S unless marked)

Counts from the census: file-backed `.data` part 71 addresses/527 lines/86 files;
zero-fill globals 341/1,739/122; outer block 13/31/12.

**A. `0x44d000..<0x44f000` — file-backed `.data` (the only non-zero bytes of `initial.bin`)**

| Range | Contents (role) | Main consumers | Class |
| --- | --- | --- | --- |
| `44d000` | music volume (`"Volume: %d"`) | MenuPresentation:275, MusicPlayback:219-220 | defaulted state |
| `44d010` | music on/off | MusicConfiguration:55-61, MusicPlayback:86,178, MatchPreparation:98,116, MatchContinuation:89 | defaulted state |
| `44d014/018` | window width/height (computed from viewport) | WindowInitialization:90-106 | state |
| `44d020` | current menu/screen id (125 lines; 200..299 War, 20..29/120..129 tournaments) | CharacterScreen, InputControl, MatchRound, WarSetup, Tournament*, MusicPlayback:137 … (24 files) | defaulted state |
| `44d024`, `44d028` | selected arena/background; random flag | BackgroundDrawing:12, **CharacterAI:160 (per tick)**, MatchContinuation, MatchSelection, MissionStage, PostDrawCommands:141 … | state |
| `44d02c` | game speed | InputControl:217,238, MatchRound, ModeScreen, PausedGameplay, ApplicationMenuSession:187,448 (as `full[0x2c]`) | defaulted state |
| `44d030`, `44d034` | toggles (`44d034` read by ActorControl:108, ActorInput:82, ActorScheduler:164 — **per actor per tick**) | + InitialLoading, ReplayFileInput, preparations | defaulted state |
| `44d03c` | **game version word** (`0x1e` → "v2.0") written into network packets and compared with replays | InputControl:150,170, ReplayPlayback:166-172, ReplayRecording:91, MenuPanelDrawing:128 | game/EXE identity data |
| `44d040..+22` | local network packet bytes | InputControl:136-154, LocalInput:30,105, PostHUDNotices:102 | state |
| `44d058..44d07c` | front/menu state and one-shot load flags (`44d05c`, `44d068`, `44d07c` start at 1 and are cleared after first load; `44d070` sentinel −100; `44d078` 150-tick timer) | InitialInterfaceLoading:68,93, InitialLoading:127 (guard ==1), FrontMenuResources:53, MenuResourceLoading:39,87, CharacterScreen, MatchSelection, MenuReturn | defaulted state |
| `44d080..44d11f` | tournament per-seat arrays (HP 500, −1, roster ordinals `44d0c0`, participants `44d0e0`, teams `44d100`) | Tournament*/TeamTournament* (5 files) | state |
| `44d120..44d317` | **tournament bracket layout: 126 Int32 (sizes, line coordinates)** | TournamentBracket:53-56, TeamTournamentBracket:53-56, TournamentLayout:19 | static UI data (copied in Swift, §2 row 2) |
| `44d318..44d323` | tournament level; one-char label buffers `44d31c/44d320` | TournamentBracket, TournamentSetup:83, TeamTournamentSetup:83 | state |
| `44d324..44d34b`, `44d34c` | **10 character IDs: pool for stage spawn id 1000 ("random hero"), shuffled in place by 50 RNG swaps**, cursor | MissionStage:141,425-434, ReplayPlayback:114, ReplayRecording:101 | content ID table, read live |
| `44d350..44d777` | **War tables**: unit object IDs ×11 (`44d350`), unit count 11 (`44d37c`, guarded ==11), side presets (`44d380/384`), 5 presets × 11 totals (`44d388`) and actives (`44d468`), backups (`44d548`,`44d5a0`), per-side active/reserve (`44d5f8`,`44d650`), finalized (`44d6a8`,`44d700`), team words (`44d754`), defense multipliers (`44d758/75c`), war-setup cursor/selection (`44d760..44d774`) | WarTroops, WarSetup, WarBattle:98-160, WarPreparation:107-110, ReplayPlayback:109-180, ResultRecording:160-164 | content data + state (copied in Swift, §2 row 1) |
| `44d778..44d79f` | ad/info panel words (`44d778` −99 sentinel, `44d77c`, `44d780`, ad index `44d784`, period `44d788`); **viewport width/height `44d78c/44d790`** (read by every bitmap draw: BackgroundDrawing:21, WorldDrawing:61, WorldHUD:81, BitmapFont:65, ResultLayout:66, LoadedMenuSession:349-402, LoadingSession:90); window flag `44d794` | MenuContent, MenuInfoReading/Writing, MenuPanel*, WindowInitialization, WindowLifecycle:77 | defaulted state / LF2 constants |
| `44d7a0..` | **replay key C string** (applied to the first bytes of a compressed replay; its length matters, a long key can alias later globals) | ReplayWriter:119, ReplayFileInput:67 | game data (format key) |
| `44dce4` | dispatcher state word | ApplicationDispatchEntry:42,53 | state |
| `44dce8` | zlib version pointer, **must equal EXE address `0x44a2b4`** | ReplayWriter:85 | EXE pointer |
| `44dd50` | zlib CPU-detect selector (2 → detect once) | ReplayWriter:105-111 | CRT/zlib state |
| `44dd54..44eecb` | not referenced by any engine source (I: CRT/zlib/other initialized data) | — | copied, unused |
| `44eecc` | DirectSound device pointer | QueuedSound:23,34, MenuSoundStartup, MenuPresentation, catalog/loading sessions, Runtime OriginalMacAudioBackend:117, OriginalMacRuntimeLoading:205 | state |
| `44eed0` | selected music path buffer | MusicConfiguration:51-52, MusicPlayback:70-90, MatchPreparation:272, Replay* | state |
| `44ef04`, `44ef38` | current music path; working-directory string (`%s\graph.log`) | MusicPlayback:166-226 | state |

**B. `0x44f000..<0x458440` — zero-fill globals (runtime state, zero at start)**

| Range (selection) | Role | Consumers (families) |
| --- | --- | --- |
| `44f040..44f060` | DirectShow graph interfaces, music label | MusicPlayback, MusicConfiguration, GraphEvents, Runtime OriginalMacRuntimeMusic |
| `44f128..44f1b4` | music text, music choice, remote packet/checksum bytes, network role `44f1af` | InputControl, NetworkClient/Menu/Exit/Notification, ModeScreen, MainMenu |
| `44f208..44f59c` | network sockets/names/addresses | Network*, RuntimeSession |
| `44f604..44f620` | AI words (`44f61c`, 25 lines, **per AI tick**), catalog checksum `44f620` | CharacterAI(+Special), CatalogRegistry, InitialLoading, Replay* |
| `44f87c..44fd98` | HUD/menu bitmap slots, fonts (`44faf4/44f888/44fcbc`), control settings | InitialInterfaceLoading, FrontMenuResources, BitmapFont, Settings*, ResultLayout |
| `44ff8c`, `44ff90..+3000` | PAUSE bitmap; **RNG table, filled at start-up by CRT `rand`** (OriginalCRTRandom:32-38) | every RNG user (21 files) |
| `450b4c..450c38` | loop/match state: input-slot modes, phase, counters, RNG index/counter `450bcc/450c34`, difficulty `450c30`, mode label | Actor*, World*, Match*, Replay*, CharacterAI |
| `450e30..450f64` | playback-information text | PlaybackInformation |
| `451154..4514e0` | game mode `451160` (60 lines), menu bitmap slots `451164..4511a8`, selection/tournament/war/mission per-seat words | menus, Tournament*, War*, MissionStage |
| `451b20..451db0` | results/teams/war per side, sound buffers | Result*, War*, ActorHits, CPointPlacement |
| `452170..454a18` | sound queues, info strings, panel rows, window input, window handles `4546d0..4546f8` | QueuedSound, MenuInfo*, MenuPanel*, WindowInput, Display* |
| `455378..4553f3` | keyboard state (300 B), cheat flags `455470/71` | WindowInput, InputControl, DispatchEntry:37-38 |
| `455608..455638` | DirectDraw surfaces, menu sound buffers | drawing, Runtime display backend |
| `455638..458438` | sound-cache bytes (compared whole, CatalogSession:350-391) | catalog session |
| `457578..457bc8`, `458348..45843c` | device/mouse words, pending sounds, CRT/startup flags | many |

**C. `0x458440..<0x4593a8` — outer block (zero-fill)**: WinMain locals/C++ static objects
(`0x854` observed, OriginalStartupStorage), cheat-sequence progress `458578/7c`, loop
counter `458580`, saved playback `458588` (0x320), replay pointers `4588a8`, World
`458b00` (0x7d8), host name `4592d8`, key-scan words `4593a0/4593a4`. Beyond the
record, lib.dll's word `0x459ff8` is deliberately **not** known zero
(`OriginalLibStageCommands.swift:1-8`).

**Game data vs engine state (S/I).** Everything game-specific in the record sits in
the 8 KB `.data` part. Content-like tables: tournament layout `44d120..44d317`, random-hero
pool `44d324..44d34b`, War tables `44d350..44d777` (unit IDs and presets), the version
word `44d03c`, the replay key at `44d7a0`. The rest of the 8 KB is engine state with
non-zero defaults (volume, music on, flags, sentinels, viewport 794×550, zlib state),
plus EXE pointers (`44dce8`). Which defaults are NTSD edits and which are LF2 2.0a is
undecidable without D1. B and C are pure runtime state: an engine could build them
as zeros without input.

## 2. Original data embedded in engine Swift code

| # | file:line | Size | EXE source | What | Duplicates `initial.bin`? | Class |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `NTSDCore/OriginalWarTroops.swift:128-154` (`fileWords`), writer `:122-127` | 266 Int32 = 1,064 B | `.data` `0x44d350..0x44d777` (doc comment `:121`) | War unit IDs (30,31,33,34,39,32,35,36,37,122,123), count 11, presets, initial per-side state, multipliers | **Yes**, offsets 0x350..0x777 (claimed by the comment; not byte-compared here). Used **only by tests**: `OriginalWarSetupNativeTests:38`, `OriginalLibWarPreparationTests:287`, `OriginalWarDependenciesTests:31`, `OriginalLibWarSetupTests:262` | NTSD/LF2 game data (D1) |
| 2 | `NTSDCore/OriginalTournamentLayout.swift:5-15`; `sourceSHA256 "ae205dff…"` | 126 Int32 = 504 B + a digest | `.data` `0x44d120..0x44d317` | tournament bracket dimensions/coordinates | **Yes**, offsets 0x120..0x317. Tests only: LibWarPreparation:286, LibTeamTournamentPreparation:169, LibWarSetup:261, LibTeamTournamentBracket:154,158 (`:158` checks the range's digest against `sourceSHA256`) | UI data (D1); the digest is a content pin left in the engine |
| 3 | `NTSDCore/OriginalFrontMenuRectangles.swift:1-177` (generated by `tools/extract_front_menu_rectangles.py`; EXE SHA in comment `:2`) | 10 sheets, 151 rectangles (×4 Int32) + counts, ~2.4 KB | `.text` immediates `0x424a72..0x426b95` | sprite-sheet rectangles of front-menu bitmaps (`MENU_CLIP*`, …) | No (code). Runtime use: FrontMenuResources:90 (menu start-up), StageEnding:23 | NTSD art layout (D1); not hot |
| 4 | `NTSDCore/OriginalMusicPlayback.swift:74-76` `demoTracks`; same paths `OriginalMusicConfiguration.swift:50`, labels `:47`; `"bgm\\main.wma"` MusicPlayback:137, StartupOutput:67 | 8 paths (+9 labels) | `.rdata` `0x4476d4..0x447744` | BGM paths | No | LF2 standard names (engine, pending D1) |
| 5 | `NTSDCore/OriginalInitialSoundLoading.swift:13-15` | 18 paths | EXE load list | shared `data\0NN.wav`; loading manifest must equal it (`OriginalApplicationLoadingInputs.swift:40`) | No | LF2 standard (engine, D1) |
| 6 | `NTSDCore/OriginalMenuSoundStartup.swift:26` | 5 paths | EXE | `data\m_*.wav` | No | LF2 standard |
| 7 | `OriginalFrontMenuResources.swift:21-24` (24 names+slots), `OriginalInitialInterfaceLoading.swift:53-54` (10), `OriginalMenuResourceLoading.swift:21-22` (11), `OriginalApplicationMenuInputs.swift:11` (`BATTLEMODE`,`BATTLETROOPS`), `OriginalMenuBackground.swift:18-20` (`MENU_BACK%d`, count 13 by `%13+1`) | 47 names | EXE resource names/strings | bitmap names; package manifests must match them (InterfaceInputs:36, MenuInputs:43) | No | names likely LF2; counts (`MENU_BACK1..13`, `MENU_CLIP2..7`, `CS2..6`, `WORDS0..5`, battle) possibly NTSD (D1) |
| 8 | `OriginalFrontScreenBody.swift:38-47` | 3 obfuscated strings + 4 links | `.rdata` `0x449204..0x4498d8` | credits/URL strings | No | LF2 (E3: EXE strings stay) |
| 9 | `OriginalSettingsWriting.swift:12-14` | 3 strings | `.rdata` `0x449120/0x449134/0x449660` | `<No name>` defaults | No | LF2 |
| 10 | `NTSDRuntime/OriginalMacRuntimeNetwork.swift:86-92` | 5 strings keyed by EXE address | `.rdata` `0x449324..0x4493b4` | network error texts (Core passes string addresses: InputControl:169-191) | No | LF2; EXE-address coupling |
| 11 | ~60 UI/error `Array("…".utf8)` literals in Core (e.g. WindowInitialization:110 "Little Fighter 2"/"Marti", WindowInput:151, ReplayPlayback:137-172, MenuPresentation:275-296, Tournament*Preparation:37-65 `.lfr` names) | short strings | `.rdata` | messages, formats, URLs | No | LF2 (E3 decision) |
| 12 | `OriginalCatalogRegistry.swift:91-101` | 5 ints + 6 strings | code + `.rdata` | built-in background ("Lee On Road", `shadow1`, `back99_1..3`, "Random") | No | D1 |
| 13 | `OriginalWindowInput.swift:146-147` | 7 + 15 VK bytes | code | cheat sequences "LF2.NET", "HEROFIGHTER.COM" | No | LF2 |
| 14 | `OriginalKeyName.swift:24-33` | 33 labels | code/.rdata | key labels | No | LF2 |
| 15 | `OriginalDATDecoder.swift:34` | 37 B | `.rdata` | DAT key `SiuHungIsAGoodBear…` (also in 2.8.3.3's `NTSD2833FileBytes.swift:18`) | No | **LF2 engine constant** |
| 16 | `OriginalMusicPlayback.swift:116,160`, `NTSDRuntime/OriginalMacRuntimeMusic.swift:20` | 16 B GUIDs | Windows SDK | DirectShow IIDs | No | platform constant |
| 17 | `OriginalDiagnosticNumber.swift:163-211` (`tableHex`) | 42 × 12 B | pinned **VC80 CRT DLL** `.6195`, `781c1ff0/781c2150` | power-of-ten scaling table | No | CRT constant (Microsoft DLL bytes; derivable) |
| 18 | `OriginalCalendarTime.swift:24,34,140-141` | small | CRT | PST/PDT, days per month, DST rule | No | CRT |
| 19 | `OriginalStateRecord.swift:1017-1022`, `OriginalWorldBootstrap.swift:44,46` | 3 binary64 | `.rdata` `0x447920/0x447928/0x449470` | float constants | No | engine |
| 20 | Code-immediate tables: `OriginalTournamentSetup.swift:181,209`, `OriginalTeamTournamentSetup.swift:193,225`, `OriginalTournamentBracket.swift:145`, `OriginalMatchSelection.swift:172`, `OriginalModeScreen.swift:180`, `OriginalResultLayout.swift:128-149`, `OriginalWarSetup.swift:142,334`, `OriginalWorldBootstrap.swift:68-69`, `OriginalStageLoader.swift:125-128`, `OriginalBackgroundLoader.swift:160-162`, `OriginalFrameLoader.swift:134-161`, `OriginalObjectLoader.swift:375-381` | small | `.text` | UI coordinates, DAT field offsets/defaults | No | rules (LF2/NTSD per D1); field tables are the LF2 DAT format |
| 21 | ID sets (for the ID-site survey): `OriginalCharacterAI.swift:613`, `OriginalPostDrawLifecycle.swift:207-208`, `OriginalHitDamage.swift:135`, `OriginalWorldContacts.swift:105-108` (lib.dll itr kinds), `OriginalObjectInput.swift:13`, `OriginalMissionStage.swift:422-438` (ids 0x12c/0x3e8/0xbb8/0xbb9) | — | `.text` | object/kind IDs | No | profile (E5 ID sites) |
| — | Not EXE data: `PortableSHA256.k`, PNG signature, `NTSDRuntime/OriginalHIDKeys.swift`, `OriginalMacRuntimeMessages.swift` (host key maps), `OriginalRuntimeMenuGamepad.swift` targets (port's own), `NTSDReplayCodec/upstream.json` (zlib digests) | | | | | |

Digests left in engine code: `OriginalTournamentLayout.sourceSHA256` (row 2) and the
EXE SHA in the generated comment `OriginalFrontMenuRectangles.swift:2`. No manifest
digest, count (1198/521/669) or functional EXE-SHA pin remains (E2 holds).
`OriginalRandom.sourceSHA256` is a field (empty in production). `engine/Tests`
(106 tests) has no original tables or pins.

## 3. Other original-content couplings in the engine

| Coupling | Where |
| --- | --- |
| Package folder names: `OriginalStartup`, `OriginalCatalog`, `OriginalCommonSounds`, `OriginalLoadingInterface`, `OriginalCharacterMenu`, `OriginalWarMenu`, `OriginalMatchArenas`; `OriginalMusic` in hosts | StartupInputs:125, CatalogInputs:25,32, LoadingInputs:19,25, InterfaceInputs:16-17, MenuInputs:17,27, ArenaInputs:16; `NTSDSDLHost/SDLLaunch.swift:35`, `NTSDUIKitHost/NTSDiOSHost.swift:102`, `NTSDAndroidHost/NTSDAndroidApp.swift:208` |
| Startup package format: `manifest.json`, `initial.bin`, `initial.mask`, `bitmaps/*.dib`, `data/` → `data\` names; manifest `globalAddress/globalCount` | StartupInputs:139-202 |
| Manifests must equal the engine's load lists (rows 5, 7) | LoadingInputs:40, InterfaceInputs:36, MenuInputs:43 |
| Game file names: `data\data.txt` (CatalogSession:384), `data\stage.dat` (LoadedCatalog:223, LoadingFiles:212), `data\control.txt` (StartupInputs:218, Settings*:68/74, Runtime MacRuntimeMenu:99,262), `data\adinfo.txt`/`data\ad%d.txt`/`sprite\sys\ad%d.bmp` (MenuContent:89-90, MenuInfo*), `data\temporary.txt` (LoadingFiles:61), `recording\` (ReplayWriter:64, Runtime MacRuntimeLoading:484), overlay names `data\adinfo.txt`, `data\ad0.txt` (Runtime MacRuntimeStartup:88, StartupService:85) | as listed |
| Version identity: record word `44d03c` (0x1e ⇒ "v2.0") in replay/network checks | ReplayPlayback:166-172, InputControl:150,170 |
| EXE addresses used as values: `44dce8 == 0x44a2b4`; `.rdata` string addresses passed to the runtime and mapped to text; window class/title pointers `0x447634/0x447620`; COM CLSID/IID addresses `0x44a2a4/0x44a254`; instance `0x400000`; `0x447850` message caption | ReplayWriter:85; InputControl:169-191, ReplayTick:128,153, MacRuntimeNetwork:86-92, MacRuntimeLoading:286; WindowInitialization:99-108, RuntimeWindowBackend:244-258; MusicPlayback:154, MacRuntimeMusic:94; MacRuntimeStartup:97 |
| Engine-model sizes: 400 actors × 0x420, World 0x7d8, Frame stride 0x178, Object header 0x7a4 (2.8.3.3 differs, §4) | MatchPreparation:62-64, StateRecord:21-23 |
| EXE SHA: comment only (`OriginalFrontMenuRectangles.swift:2`); catalog count 1198: none | — |
| Identity strings left (D2): thread names `NTSD.readahead`, `NTSD.load` | `OriginalConcurrentInputs.swift:49,113` |

## 4. `exp/ntsd-2.8.3.3` (read only)

- Branch tip `19116511`; merge base with this branch `ab4e65b4` (main). `git diff --stat
  40611c4d exp/ntsd-2.8.3.3 -- native/Sources/NTSDCore` reports 1,753 files added only
  because Core moved to `engine/` here. Against the merge base, 2.8.3.3 adds three Core
  files: `NTSD2833FileBytes.swift` (45 lines, duplicates the DAT key), `NTSD2833ObjectStorage.swift`
  (147; `allocationSize 0x69e00`, `frameBase 0x830`, `frameStride 0x1b0`), and
  `NTSD2833TokenStream.swift` (64). Runtime adds `OriginalRuntimeContentInputs.swift` (160),
  and `OriginalRuntimeSession.swift` changes (39 lines).
- OriginalWarTroops, OriginalTournamentLayout, OriginalMatchPreparation,
  OriginalFrontMenuRectangles, OriginalApplicationDispatchEntry,
  OriginalApplicationMenuSession, OriginalRandom, OriginalDATDecoder, OriginalMusicPlayback
  and OriginalDiagnosticNumber are byte-identical to `40611c4d`'s. The startup and
  catalog loaders equal the merge base (pre-E1/E2). The same `initial.bin`/mask/manifest blobs.
- **Supply:** `OriginalRuntimeContentInputs` fixes one origin per session.
  `baseline(in:)` (identity "NTSD-2.4-2.0a") wraps the 2.4 bundled readers.
  `targetPartial(directory:writableParent:)` reads nine ordinary files
  (`data/data.txt`, `data/control.txt`, seven `custom/1genma/…dat`; 161,202 B;
  manifest pinned `c0ef67b9…`, EXE `5eda5144…`). The target's `acquireStartup()` throws
  `.unsupportedTargetStartup`, so **no 2.8.3.3 record or `initial.bin` exists**. The plan
  says "Target startup inputs need not share the 2.4 package's type or raw ABI"
  (`NTSD_2_8_3_3_IMPLEMENTATION_PLAN.md`, M0).
- **Evidence on its layout** (`NTSD_2_8_3_3_ENGINE_DIFF.md`): RNG routine
  `0x417170` is identical except for addresses. Table/index/counter are at
  `0x49ff90/0x4a0bcc/0x4a0c34`, all `+0x50000`. (I: the globals block moved, perhaps to base
  `0x49d000`; its size and internal layout are unknown.) The camera loop bound goes from 400 to 1000
  actors, the World table field from `+0x194` to `+0x3ec`, the Frame stride from `0x178` to
  `0x1b0`, and Object fields from `0x7ac/0x7d0` to `0x838/0x85c`; the Actor object reference stays at `+0x368`.
  The EXE has an 86 MB raw / 2.9 MB virtual section with an `ENIGMA` marker
  (`NTSD_2_8_3_3_PREPARATION.md`), so its `.data` cannot be copied the way
  `package_startup_inputs.py` copies 2.4's. Initial state would need their D2 Windows observation.

## 5. Recommendation

1. **The game supplies the bytes, the engine owns the layout.** Keep the startup
   package (`initial.bin` + mask + manifest) game-side as it is (NTSDContent, E2
   identity). Add one engine type (e.g. `OriginalGlobalLayout`) that names the base
   `0x44d000`, the extents `0xb440`/`0xc3a8`, the outer/World/part starts. It replaces the
   duplicated constants in StartupInputs:142,186, DispatchEntry:7,
   MatchPreparation:14-15, MenuSession:8-15. The manifest check then reads "the
   engine's layout", so another EXE's package is refused with a typed error, as in 2.8.3.3's M0.
   Leave the ~2,200 address sites as compile-time constants; do not
   introduce a runtime offset table.
2. **Delete the two duplicate copies (rows 1–2) from the engine.** They are
   test-only. Their tests (game-side after E4c-2) take `0x44d350..0x44d777` and
   `0x44d120..0x44d317` from NTSDContent's `initial.bin`. Before deleting, compare the
   Swift literals with those ranges once, and record any difference as a mismatch.
   `OriginalLibTeamTournamentBracketTests:158` already pins the layout range's digest.
   The `sourceSHA256` pin moves with the test.
3. **Profile data, not record:** `OriginalFrontMenuRectangles` (row 3) and the
   NTSD-likely bitmap-name counts (row 7) become game-profile data. They are read only at
   front-menu start-up and stage ending, so the cost is negligible. The LF2-format
   names, the DAT key, the GUIDs, the CRT tables and the EXE strings stay engine constants until
   D1. The E7 scan needs a stated policy for EXE `.rdata` strings and the VC80 table
   (row 17, derivable). That policy is the user's call.
4. **Bit-exactness risks.** Supply the whole `0xc3a8` image with an all-defined mask. If
   the package is ever reduced to the 8 KB part, the zero-fill must reproduce exactly
   the same bytes and mask. Never extend the record over `0x459ff8`, which is lib.dll's word with unknown
   backing. Keep the engine-side split at `0xb440`, the merge in Bootstrap:150-156 and
   `partStarts`. Defaults in the 8 KB, such as volume, flags, the version word and the replay key, are
   behaviour: two games with different `.data` are different profiles even with
   identical code.
5. **Performance.** Start-up reads 100 KB plus two SHA-256 digests, which is negligible. Hot paths
   (`44d034` per actor, `44f61c` per AI tick, RNG `450bcc/450c34`, viewport per draw)
   use constant-folded `address-0x44d000`. Keep the offsets in the engine module: values
   from the game package would not inline across the package boundary (E4's cross-module
   optimization stays inside `engine/`). Keep the part-wise copy-on-write state.
6. **2.8.3.3 fit:** a byte-only profile cannot express it, because its base, extents, actor count and
   World/Frame/Object layouts change with the code. A second EXE means a second engine
   layout, which needs code and evidence. The API shape still fits: the
   M0 `Startup` ticket carries the game's startup inputs, and a typed layout lets
   it refuse cleanly until a 2.8.3.3 record is observed.
