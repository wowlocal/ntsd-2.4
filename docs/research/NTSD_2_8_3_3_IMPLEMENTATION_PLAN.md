# NTSD 2.8.3.3 on the native engine: implementation plan

2026-10-17. Initial plan at `723b424fe7de9680d4da91ba228ee15940c3d141`,
revised against completed engine evidence at `45d0fedc`,
local branch `exp/ntsd-2.8.3.3`, worktree `/Users/michael/Developer/ntsd-2.4-v2833`.
Status: **proposed implementation sequence, not behavioral acceptance**. The parent
owns review, Git and CURRENT_WORK. This pass edits only this document; no build,
original execution, extraction, new capture, installation or publication.

## Recommendation and immediate result

Evolve the existing Swift engine on the separate target branch. Keep its native
hosts, owned state, transaction/receipt mechanisms, numerical primitives and
comparison infrastructure. Reuse a game handler only to the extent that its
target inputs, dependencies and observable contract have been established.
The current application is substantial enough to justify this choice; rebuilding
the platform or returning to the rejected JavaScript implementation would not
resolve the actual target uncertainties.

This is not an asset replacement. The live resource acquisition path admits only
the pinned 2.4 packages; frame capacity, storage, input/AI, images and application
orchestration contain concrete 2.4 assumptions. The first implementation below
changes that acquisition seam in the actual runtime, preserving the baseline
adapter. It admits known target raw inputs with an honest startup boundary.
It does not wait for a complete executable or content diff.

No universal version framework, dual-version shipping application or wholesale
engine rewrite is prescribed. Use the branch as the isolation boundary. Separate
target handlers where evidence demonstrates a different contract; factor common
code when both callers justify it. Native macOS shipping remains mandatory:
no Windows EXE/DLL execution, Wine, CrossOver, browser engine or emulation in the
Mac runtime. Other commissioned hosts and their accepted conveniences are separate
delivery/acceptance surfaces, not a replacement for the Mac application.

## Revision: completed evidence → implementation decisions

This revision incorporates [the engine study](NTSD_2_8_3_3_ENGINE_DIFF.md),
[static run1](../evidence/ntsd-2.8.3.3-engine-diff-20261017-run1.json),
[RNG pilot1](../evidence/ntsd-2.8.3.3-engine-diff-20261017-rng1.json) and its
[interpretation correction1](../evidence/ntsd-2.8.3.3-engine-diff-20261017-rng1-correction1.json).
The correction supersedes the overbroad Actor/Object-offset conclusion in pilot1;
the original receipt, failed audit, bytes and comparison output remain immutable.

| Completed evidence, 2026-10-17 | Decision and remaining gate |
| --- | --- |
| First recorded x86 code section `0x401000..<0x497000` is readable: 614,400 bytes, SHA-256 `9364fc67c15991140a8d379987c23e70bb33660f104a1d6e9203a056a1079eb0`. | Initial code availability is established. Use these saved bytes for the next required mechanism; do not repeat capture/availability discovery. Complete effective code, DLL and resource mapping remain open. |
| Complete RNG `0x417170..<0x4171bd`: 77 bytes, 29 instructions; only five references to three state identities differ by `+0x50000`. Controlled Unicorn 2.1.4 pilot: 24 cases, 288 calls/version, all 29 instruction addresses and both returns, zero mismatches in results/registers/state/normalized ordered writes; tables unchanged. | Retain `OriginalRandom` arithmetic as a reuse candidate. This is source/source evidence on synthetic valid-domain tables, not Native execution or naturally observed initialization. Target table generation, ownership, callers and consumption order still gate production integration. No second unchanged-leaf pilot is the next priority. |
| Candidate camera path: `0x41b8d7` bound 400→1000; `0x41b617` World-relative table `0x194→0x3ec`. | Recover pool construction, ownership, aliases and callers before changing this consumer. Neither value defines the whole World/Actor layout. |
| Matched AI frame-index multiplies at `0x4045c0/0x404cd0`: `0x178→0x1b0` (376→432 bytes); object-relative fields `0x7ac→0x838`, `0x7d0→0x85c`. Actor object-reference **stays `+0x368`** in both contexts. | First changed engine contract is Frame/Object construction/loading/storage. The two accesses establish neither the whole record nor all AI semantics. Do not infer an Actor-reference relocation, a complete Object header, or globally replace constants. |
| Purpose-selected 32-anchor sample: three same-VA identical prefixes, five matching shapes with numeric changes, 24 unresolved identities. | These are neither 24 changed functions nor a reuse percentage. An old VA may lie in another function or mid-instruction; establish the chosen caller's identity before execution or transfer. |

The next order is **M0 minimal live content integration → D3 changed Frame/Object
contract and Native consumer → the next ready M1 startup/loading slice**. D2
observations join only where their inputs are needed. M0 provides a real runtime
acquisition seam; it does not justify a prolonged sequence of research-only
increments. Full resource access and a perfect global diff are not prerequisites
for M0 or an independently evidenced storage implementation. The packed-content
dependency below is unchanged by the successful code comparison and RNG pilot.

## Inputs and evidence limits

| Input | Pin and meaning |
| --- | --- |
| Original 2.4 | `downloads/NTSD_2.4_2.0a_clean/NTSD 2.4_2.0a`; EXE SHA-256 `3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c` |
| Supplied target | `/Users/michael/Downloads/NTSD2.8.3.3.zip`; SHA-256 `fca38bfe1391d969b9d29d1289c51bbf5270a384fa7da6d4a7c053da77c52b2d`; the exact package, including registered custom content, is the target |
| Target EXE member | `NTSD2.8.3.3/NTSD.exe`; SHA-256 `5eda51440039099069d041e5bd13fde8be9fd8c7b20983985b1712a59719d86b` |
| Working diagnostic dump | `/Volumes/T7/ntsd-2.4-artifacts/version-diff-20261017/windows-startup-fix1/NTSD-versus-selection-live1.dmp`; 476,556,770 bytes; SHA-256 `adb00fd69a252cd1d0def2ce21d4963b9853f7f963613785047ad4633ea7c303` |

The dump supplements the original ZIP/EXE. Saved validation and corrected reader
accounting report MDMP with 16 directory entries (five unused padding entries,
11 nonempty streams), 93 module entries including two identical NTSD records,
1,407 memory regions and NTSD at `0x400000`, image size 4,591,616. These are not
93 unique dependencies or proof of readable bytes for every path. On Windows 11
ARM64 with x86 compatibility, disabling hybrid execution
for this EXE allowed two starts; PID8092 was responding in Versus character
selection at `2026-10-17T15:54:33Z`. No seats were joined. These are actual Windows
guest observations, not physical x86 Windows, sound, arena loading or match proof.
The dump does not establish that every resource, late-loaded module or code path
was resident or readable. It does not supply initialization provenance for every
captured byte. Reuse the validation; do not rehash or recapture it for this plan.
Sources: [startup receipt](../evidence/ntsd-2.8.3.3-windows-startup-fix-20261017-run1.json#L24),
[environment and limits](NTSD_2_8_3_3_WINDOWS_MEMORY.md#L23),
[working memory](NTSD_2_8_3_3_WINDOWS_MEMORY.md#L143).

The packed-content incident remains open. Saved at commit
`107f2efc61f712b67e2f819556d0670068bb2db2`, path
`docs/evidence/claude-code-safety-2026-10-17.json`: Claude Opus 5.5, session
`7cdf4b7a-48cc-42fa-8222-ad2e4b98f332`, recorded `2026-10-17T14:37:28Z`
(16:37 CEST), request ID unavailable. Exact message:

> Your response above was stopped by a safety classifier — this is not a tool or API error. The rest of it was withheld, and tool calls in it that had not finished did not run.

It occurred while preparing automated packed-content access; the withheld action
and exact trigger are unknown. The preceding `vmpal_list_vms` is not proof of
cause. The historical commit was read, not restored. Fresh planning, the working
dump and a model/session change do not clear this incident. No affected operation
may be retried or rerouted through dump processing, another tool/model or a renamed
task. Any affected access route requires a separate permitted resolution on its
substance. Independent raw-file/IO work below does not require it. Preserve the
[other incident register](../evidence/codex-safety-incidents-2026-09-12.json) and
[WORKFLOW handling](WORKFLOW.md#L217).

## What the current 2.4 engine actually provides

This inventory separates implemented code from the scope of its evidence. Earlier
“Practice only”, “no complete match” and “network deferred” prose is historical;
the newer observations below supersede those status statements. Conversely,
the earlier reconciliation's “only missing implementation is networking” is
superseded by the subsequent developer-mode audit and current dispatch guards.

| Foundation | Current code / existing evidence | Limit for reuse and acceptance |
| --- | --- | --- |
| Real application and hosts | The default AppKit entry is `OriginalRuntimeDelegate`, not Practice: [main.swift:252](../../native/Sources/NTSDApp/main.swift#L252). `NTSDCore` + `NTSDRuntime` serve AppKit, headless and other hosts: [Package.swift:114](../../native/Package.swift#L114). | Host infrastructure is reusable; startup dispatch and provider answers still encode 2.4. A linked app is not parity. |
| Whole catalog and resource ownership | `OriginalLoadedCatalog` composes registry/Object/BG/Stage with shared file, sound, bitmap and allocation owners: [source:93](../../native/Sources/NTSDCore/OriginalLoadedCatalog.swift#L93). Full 137-object/17-background/25-stage studies and later app loading exist. | Raw pointers, aliases, definedness, repeated fields and checksum order are part of the contract. The old isolated frame exclusions remain historical; do not treat them as the latest whole-catalog result. [Archive:3155](../../AGENTS_HISTORY_2026-09-12.md#L3155). |
| Live gameplay, AI, results | `OriginalGameplayBody` composes controls → physics → links → contacts/hits → camera/drawing → post-draw/modes → results: [source:100](../../native/Sources/NTSDCore/OriginalGameplayBody.swift#L100). `OriginalObjectInput`, `OriginalCharacterAI` and `OriginalCharacterAISpecial` are real implementations. | Existing numerical/caller corpora and app matches cover declared domains, not every combination of content or new target rules. AI includes source ID exceptions; do not replace it with a generic approximation. |
| Modes and all 2.4 arenas | VS/computer VS, Demo, War, Mission/Stage, tournaments, Playback and Quit are integrated; 17 backgrounds plus Random have app checks. Stage ENDING has 581 source cases but had not been reached in live play. [Map:10](../RESEARCH_MAP.md#L10), [scope:31](SCOPE_RECONCILIATION_2026-10-02.md#L31). | Complete stage paths, rare states and per-feature independent reviews do not become accepted from the mode list. Developer modes 1/2 remain explicit stops: [dispatch:15,59](../../native/Sources/NTSDCore/OriginalApplicationDispatchEntry.swift#L15), [audit:150](EXE_COVERAGE_AUDIT_2026-10-03.md#L150). |
| Whole-match reference observations | Nine recordings spanning VS, War, Stage and human tournament matches reached equal player Summary rows/times in native and the original under CrossOver. The catalog checksum discrepancy was subsequently fixed; unmodified recordings exchanged. [Crossplay:8,76](CROSSOVER_REPLAY_CROSSPLAY.md#L8). | Summary/capture observations, not tick-by-tick full equivalence; a War cumulative-team-total difference is explained but the two-playback native sequence was not run. Wine is not Windows; sound/fonts/timing/heap are excluded. [Limits:111](CROSSOVER_REPLAY_CROSSPLAY.md#L111). |
| Networking | Socket transport seam exists: [OriginalRuntimeSockets:35](../../native/Sources/NTSDRuntime/OriginalRuntimeSockets.swift#L35). N1–N5 native localhost match/error/exit scope has independent review and actual two-app checks. [Review:53–94](NETWORK_PLAY_REVIEW_2026-10-02.md#L53). | Original Windows interoperability, partial-handshake unknown backing and stated spark-coordinate differences remain separate. No evidence that 2.8 packets, timing, checksums or lobby services match 2.4. |
| Menus, controls, saves and replays | Original front settings and recording info are integrated; writes use an owned overlay and committed effects: [overlay:4](../../native/Sources/NTSDRuntime/OriginalMacRuntimeStartup.swift#L4). Replay codec/start/tick/writer and playback camera are implemented. | Target settings, unlocks, save/replay formats, integrity checks and input modes are unknown. Never feed target replay bytes to the 2.4 parser based only on a suffix. |
| Presentation/audio and performance | DIB raster pipeline, sound voices, music graph/output, native input/window services exist. Current memory/read-ahead and real-time changes are in the branch: [handoff, 2026-10-11](CURRENT_WORK.md), [MEMORY_LOADING:25](MEMORY_LOADING.md#L25). | 2.4 DirectSound/heap/CRT answers include declared policies; physical output/latency and original Windows audio comparison are incomplete. Large target content needs new load/RAM measurements, not extrapolated promises. |
| Platform checks and approved accommodations | Cross-platform scenarios/frame comparisons, A12 device work and later Steam Deck observations exist. User approved scalable/native full-screen presentation and front-menu gamepad navigation; original-format/input flags remain: [window:3](WINDOW_SCALING.md#L3), [gamepad:3](MENU_GAMEPAD.md#L3). Substitute GDI font is an explicit temporary decision: [text:20](APPLICATION_GDI_TEXT.md#L20). | Preserve those choices for 2.4. Identical 2.8 validation uses target-observed geometry, input and text; 2.4 scaling, menu navigation/hit targets and font departures do not automatically carry over. A target convenience mode requires its own declared scope and applicable user choice. Browser work is a separate host, never a dependency of the native Mac app. Clean-Mac and particular hardware gates remain open where not actually observed. |

There is no justified completion percentage. “47%” and instruction/range area are
not coverage or readiness: [audit:73](EXE_COVERAGE_AUDIT_2026-10-03.md#L73).
Author source inspection here is not an independent review of these contracts.

## Target facts, coupling and unanswered questions

Saved inventories were checked for internal accounting in this pass, without
regenerating them: **112 outer files; 330 registered objects, including 158 type-0
entries; 24 backgrounds; seven loose object DAT files; 323 object paths and all
24 background paths opaque**. Type 0 is not a selectable-fighter count; entries
include forms, clones and helpers. Opaque registry paths do not enumerate every
missing image, audio, stage or configuration dependency.
Sources: [file census:29](../evidence/ntsd-2.4-to-2.8.3.3-static-20261017-run1.json#L29),
[registry:13367](../evidence/ntsd-2.4-to-2.8.3.3-static-20261017-run1.json#L13367),
[seven visible files:758](../evidence/ntsd-2.8.3.3-preparation-20261017-static2.json#L758).

The seven registered Genma-related files have 470 frame occurrences, 59 outside
0…399, maximum index 701. Their two type-0 entries are hidden; their custom unlock
and dependencies belong to this supplied package's scope. Actual visible DATs
use new header/input fields and PNG assets. Bundled manuals describe limits
(frame limit 998 with unverified index/count semantics, 1000 objects/live
objects, 100 itr/bdy, multiple opoints), alpha,
renderer/configuration, TU modes and DLL loading. These are investigation leads,
not measured parser layouts, shipped reachability or accepted numerical rules.
See [visible frames:809](../evidence/ntsd-2.8.3.3-preparation-20261017-static2.json#L809)
and [qualified source facts:119–158](NTSD_2_8_3_3_PREPARATION.md#L119).

| Current coupling inspected | Concrete consequence |
| --- | --- |
| `OriginalRuntimeSession.resourceBundle()` only selects a Bundle; start invokes the hard-pinned startup package; read-ahead and loading invoke hard-pinned packages again. [Session:146,235,382](../../native/Sources/NTSDRuntime/OriginalRuntimeSession.swift#L146). | `--resources` is not target-version support. Introduce an explicit content acquisition boundary at these live call sites before trying a target bundle. |
| Startup manifest pins 2.4 EXE, global base `0x44d000`, size `0xc3a8`, 45 entries; catalog pins manifest SHA, 1,198 entries and roles 521/669/8. [Startup:145](../../native/Sources/NTSDCore/OriginalApplicationStartupInputs.swift#L145), [Catalog:60](../../native/Sources/NTSDCore/OriginalApplicationCatalogInputs.swift#L60). | Retain exact 2.4 validation; a target package is separate, never a changed expected hash/count or permissive fallback. Target initial globals require provenance, not a wholesale dump import. |
| `OriginalRuntimeLoadingPackages` reads five packages into `Result`, then raises errors in bundled order. [Loading:31–53](../../native/Sources/NTSDRuntime/OriginalMacRuntimeLoading.swift#L31). | Preserve read-ahead and first-error behavior, immutable ownership and the single source across startup/loading; do not mix provider identities. |
| Frame indices `0..<400`, stride `0x178`; Object header `0x7a4`, tail `0x3c`, 400 frames; small Frame heap allocation bound 400 bytes. [Frame:100,183](../../native/Sources/NTSDCore/OriginalFrameLoader.swift#L100), [Object:164,283](../../native/Sources/NTSDCore/OriginalObjectLoader.swift#L164), [heap:43](../../native/Sources/NTSDCore/OriginalFrameStorage.swift#L43). | Target high-index DATs and two `0x1b0` frame accesses establish a real delta; constructor/defaults, full storage, frame count and parser semantics remain incomplete. Frame count, live Actor capacity and allocation bytes are separate contracts. No global replacement. |
| Actor input and AI traverse 400 slots and source-specific offsets/globals. [Input:52–91](../../native/Sources/NTSDCore/OriginalObjectInput.swift#L52), [AI:27–91](../../native/Sources/NTSDCore/OriginalCharacterAI.swift#L27). | Target candidate loop/table accesses establish specific changes; recover allocation, reuse, aliases, rest arrays and ordering before using them. Actor `+0x368` stays unchanged in the two audited contexts; 2.4 size `0x420` still does not establish target size. |
| Image input accepts only 4/8/24-bit DIB and 8-bit RLE; decoded storage is RGB plus definedness. [Bitmap:60–97](../../native/Sources/NTSDCore/OriginalApplicationStartupInputs.swift#L60), [pixels:1–24](../../native/Sources/NTSDCore/OriginalDIBPixels.swift#L1). | PNG decoding, alpha, mirror precedence, surface conversion and compositing require a connected target path. PNG screenshot output is not a PNG asset decoder; converting to opaque BMP would discard required information. |
| `OriginalMacRuntimeLoading` merges file images and embedded resources with distinct failure/retry meaning; one identity pool owns platform tokens. [Loading:148](../../native/Sources/NTSDRuntime/OriginalMacRuntimeLoading.swift#L148), [pool:1](../../native/Sources/NTSDRuntime/OriginalMacResourceIdentityPool.swift#L1). | Preserve file/resource identity, aliasing, lifetime and rollback. Identical bytes or reused filenames do not authorize merging live resource identities. |
| Packer verifies the baseline EXE and exact manifest before copying bytes; app packer is also baseline-specific. [packer:52](../../tools/package_catalog_inputs.py#L52), [assets:22](../../tools/package_assets.py#L22). | Add an explicit target input mode only for independently available data; do not pass the target tree as `--baseline`, ship an EXE, or overwrite OriginalCatalog. |

Critical unknowns: actual startup/system/configuration values; effective loaded
game/DLL behavior and late hooks; target CRT/FPU, RNG initialization and caller
sequences; complete raw layouts beyond the recorded accesses,
parser/decoder/checksum/EOF behavior; selectable roster/unlocks; complete assets;
input timing and combos; collision/effect/spawn rules; AI; modes and transitions;
replay/save/network compatibility; render/input/audio output. A successful menu
and structural binary similarity close none of these by themselves.

The target also needs its own basis for 2.4 application accommodations such as
zero-backed allocations, out-of-Object frame reads and full-pool fallback. Existing
2.4 policies remain protected; they are not target defaults inferred from the dump.

## Evidence method and finite implementation queue

Keep one mechanism ledger in this study's subsequent evidence, not a new runner
framework. Each row records target inputs/SHA, matching 2.4 evidence, effective
EXE/DLL/caller dependencies, status (proved same / changed / opaque / unsupported),
Native consumer, comparator and remaining gate. “Similar” is a search hint only.

1. **Data/assets:** reuse the saved inventories; add newly available files only.
   Keep raw bytes and exact registry order, duplicate fields/frames, lexical
   numbers and unknown tokens. Hash identity, decoded pixel/PCM identity and
   semantic object correspondence are separate columns. ID/path matches are
   candidates: Naruto ID2 and Sasuke ID11 changed paths; District's apparent
   target ID10 is inferred from an unread background path, not a proved arena.
2. **Effective code:** the first-section availability, 32 anchors and RNG pilot
   are complete. Extend comparison only for the next consumer's loaded code/DLL
   behavior, initialization, hooks, constants, field accesses, stores and calls. Pin module
   identity/base/RVA and provenance, distinguish file bytes from runtime changes.
   2.4 already has DLL-installed behavior; main-EXE matching is insufficient.
   Normalize proven relocation differences only. Same leaf bytes with different
   callers, globals or resource layouts do not prove equal behavior.
3. **Contracts and whole callers:** use 2.4 cases as candidate stimuli after
   validating corresponding target inputs. Generate separate target references;
   preserve old failures/expected/masks. Compare owned state, definedness, RNG,
   resource requests/lifetimes and event order through full caller return and
   subsequent calls. Different layouts require reviewed semantic mappings, not
   larger masks hiding differences or copied expected after-state.
4. **Application:** compare native target against original target, not against
   an assumed unchanged 2.4 result. Include continuous input, match restart,
   session-persistent state, files/replays, networking, frames, audio and timing.
   Synthetic API/memory/FPU observations remain distinct from Windows/device.

These are finite tasks with conditional admission, not authorization to resume
the affected packed-content operation. Every new execution uses TASK_TEMPLATE
with exact cases/commands/pins; use existing manifests, oracle/comparator tools,
`app_e2e.py`, crossplay and platform runners after auditing their 2.4 constants.

| Task | Bounded question/output | Pass / failure / stop and next consumer |
| --- | --- | --- |
| D1 initial availability/anchors — **done** | Saved inventories, readable first code section, 32-anchor classifications and concrete RNG/camera/frame-access observations are already recorded. | Do not requeue the same census, hashes or code-availability experiment. Remaining availability work is an exact missing dependency of a chosen consumer, ≤60 minutes/≤2 MiB per justified accounting pass, not a new global survey. |
| RNG source/source pilot — **done** | 24 cases/288 calls per version; passing declared domain and correction1 retained. | No new RNG algorithm study. Reuse the evidence for later Native arithmetic comparison and initialization/caller composition when those target inputs are ready; no accepted target Native RNG claim yet. |
| D2: target startup and configuration | Up to one 30-minute Windows observation session, ≤12 named screens/transitions and ≤1 GiB new artifacts; reuse the working environment after verifying process/VM identity. Title → mode → character selection, control/recording/online settings, back/cancel/quit; record dimensions, input delivery, visible settings and actual file effects. No new dump merely for a new session. | Pass only observed transitions and accessible inputs to M1. Unjoined/missing asset/unsupported tool/source fault are separate outcomes. Do not claim full sound or match from title. If needed content/behavior remains opaque, stop that chain without inventing configuration. |
| D3: changed Frame/Object contract — **next after M0** | Use the recorded `0x1b0`/field-access deltas to recover the connected constructor → continuous Object/frame loading → owned storage/read consumer described below. At most 24 declared cases; initial source execution ≤30 minutes/≤2 GiB. | First Native target storage increment, then direct M1 loading integration. Confirm actual entries/callers before execution; do not run old VAs by assumption. No arbitrary token acceptance, whole-layout inference or frame-limit change from the manual alone. Missing dependencies stop only their chain. |
| D4: first gameplay delta | Once M1 supplies a real selected catalog, choose one changed mechanism exercised by the first target match; ≤24 cases, one whole-tick/caller continuation, 30-minute source run and ≤2 GiB initial output. Include one preserved cross-call state and one relevant failure/rollback case. | Pass is target comparison plus affected 2.4 regressions and review; integrate into M2/M3 before another independent survey. Unknown heap/stack storage is not zero. Source fault is not a successful Native rejection. |
| D5: missing complete content | Not in the automatically executable queue while the affected access route is unresolved. A corresponding readable developer/source package or another independently permitted source can supply missing files; first prove correspondence to the exact ZIP/EXE, including custom entries. | Full dependency closure is required for complete catalog/application acceptance. Do not use a substitute release, speculative reconstruction, diagnostic snapshot or renamed extraction operation to declare this gate closed. M0 and other evidenced mechanisms can continue independently. |

If an actual task needs more cases/time/space, preserve its terminal result and
justify an extension from new evidence. Three correction rounds are counted per
mechanism across renamed runs, followed by diagnosis. No automatic identical
retry, no endless readiness stage and no repeat of completed successful captures.

## Prioritized implementation milestones

| Milestone and order | Implementation and ready consumer | Observable gate |
| --- | --- | --- |
| **M0 — explicit content acquisition (ready now)** | The task below wires owned content inputs into `OriginalRuntimeSession` and loading, with isolated target identity/data root. | Existing 2.4 caller still runs unchanged; target raw inputs are admitted and produce the exact unsupported-startup boundary before unproved game logic. This is IO integration, not target gameplay. |
| **M1 — target startup → loaded selection** | First implement D3's changed Frame/Object storage and its loading consumer; advance other ready startup/configuration, input/settings, resource/file, catalog and selection contracts. Add image operations when their consumers require them. Implement on-demand loading if established, not forced eager 2.4 loading. | Exact target title/settings/loading/selection flow, own menu state/RNG/resource lifetimes and outputs. Partial storage progress can be committed before this whole gate; missing dependencies stay explicit. Do not present a 2.4 title with target labels as target support. |
| **M2 — first complete target match** | Real target Naruto/Sasuke and verified District counterpart, actual starting state, common controls/physics/contacts/hits/spawns/scheduler/drawing, sound, KO/results/recording and return/restart. Choose another declared pair only if the target does not contain this pair; no baseline-asset substitution. | Original-target/native-target continuous match comparison through Summary, saved output and next match; state/RNG/events and presentation checks. A deterministic fixture or silent match alone is incomplete. This remains an intermediate milestone. |
| **M3 — complete content and shared mechanisms** | Cover every registered object and its transitive dependencies, all 24 arenas, reachable forms/helpers/techniques/effects/weapons, real selectable roster/unlocks/custom Genma. Extend common handlers and proved ID exceptions; include input innovations, AI, simultaneous actions, allocation/reuse and reachable unusual states. | Catalog closure with no unexplained token/asset/handler holes; mechanical coverage matrix tied to shipped data plus ordinary reachable error contracts; representative continuous matches and soaks across distinct mechanisms. Counts are not a fighter count or branch-coverage claim. |
| **M4 — modes, UI and persistence** | Every mode actually offered by target and its transitions, complete Stage progression/ending, War/tournaments/Demo/AI as applicable, menus/HUD/pause/settings/unlocks/saves, recording/playback and input modes. Investigate any reachable developer modes separately. | Whole mode paths and restart/reload, retained session state, replay record→playback and original interchange where the format permits, file bytes/failures, target UI/audio. No invented feature based solely on a generic manual. |
| **M5 — networking** | Reuse transport adapters; recover target handshake, identity/checksum, seats/input/RNG synchronization, partial reads, disconnect/reentry and any actual lobby dependency. Begin handshake work earlier when its own inputs are ready; it need not wait for all M3. | Native/native plus native/original Windows pairing through a full match and exit/error paths, ordered wire/input/state observations. Cross-version compatibility is tested only if original behavior establishes it; never silently accept mixed data. Network scope is already authorized. |
| **M6 — native release and complete acceptance** | Connect every checked mechanism to production consumers; finish render/text/PNG/alpha/mirror, geometry/fullscreen, keyboard/controller/touch where commissioned, sound/music/latency and performance. Produce self-contained native Mac package; then applicable other-host packages. | Installed package on a clean Mac without repository, SDK, research fixture paths, mounted research volumes or compatibility runtime; original-target window/input/audio/whole-game gates; reproducible resource/package identity; actual required device tests. Independent review and all named exceptions/gaps resolved or explicitly accepted. |

M3–M6 are work streams, not a demand to finish all extraction before any code.
Select the nearest ready consumer; every checked implementation is committed
before the next independent task. A missing manual/device check blocks its own
acceptance/dependents. Continue independent implementation while waiting. No
whole-goal “blocked” statement without checking all remaining ready directions.

## First implementation task: M0, owned content inputs at the live boundary

**Mechanism/result:** make resource origin explicit once per running session.
The baseline continues through its exact readers; the target branch can acquire
its known ordinary files, identify missing contracts accurately and cannot load
2.4 globals/catalog by fallback. This unblocks M1's actual startup/resource
consumer and prevents settings/replays crossing between the two applications.

**Dependencies ready:** the current `OriginalRuntimeSession`/loading call sites,
strict existing input types, overlay and immutable byte ownership, saved target
member hashes. No target parser/layout/PNG behavior or packed-content access is
needed. **Gated:** producing target startup state or executing startup/selection
requires its relevant D2/D3 contracts; it is not part of M0. Target startup inputs
need not share the 2.4 package's type or raw ABI.

**Small implementation, not a rules framework:** add one content-input object
or factory passed to the live session, carrying identity, immutable raw inputs,
the startup/loading acquisitions and the overlay root. The baseline factory wraps
the existing validated `.bundled` readers. Keep the existing typed 2.4 packages
and validators intact. Bind one content identity for the entire session; no
changing provider between startup, background read-ahead and first loading.
Avoid a version enum threaded through every Core rule.

The target adapter reads exactly nine ordinary outer-ZIP members: `data/data.txt`,
`data/control.txt` and the seven registered `custom/1genma/...dat` paths listed
in static2:758. Saved sizes total **161,202 bytes**. Preserve raw DAT bytes;
do not decode into 2.4 Frame/Object records. A build-time ordinary ZIP member
read can populate a new regular-file package, with exact names/sizes/hashes from
the saved inventory; exclude EXE/DLL/installers and opaque content. No in-game
ZIP/executable reading is needed. Missing, corrupt, unsupported and known-empty
inputs stay distinct. This selected input package is explicitly partial, not a
complete target distribution or a new census.

The live startup acquisition consumes this target identity and owned byte set,
then reports `unsupported target startup contract (2.8.3.3)` **before** invoking
the 2.4 startup driver, creating game state or writing settings. Tests must reach
this through the real session path, not only a standalone resource inspector.
There is no “fallback to baseline” option for target input. Native file/resource
tokens remain owned and non-recycled; target filesystem identity is not a source
pointer or a substitution for `OriginalMacResourceIdentityPool`.

**Writable paths for that later task:**

- `native/Sources/NTSDRuntime/OriginalRuntimeSession.swift` and
  `OriginalMacRuntimeLoading.swift`, plus one new `OriginalRuntimeContentInputs.swift`.
- One corresponding Runtime/Mac test file; affected existing startup/loading
  tests only to route the new injection through their current assertions.
- Extend `tools/package_catalog_inputs.py` with an explicitly separate external
  raw-input mode using its existing verified-copy facilities; preserve its exact
  baseline mode/manifest. A small new target partial-input manifest/package under
  a distinct target name; never overwrite `Resources/Original*`.
- A dated M0 evidence record and concise study/handoff update owned by the main
  implementer. Packaging/bundle identity changes only when this target package is
  actually bundled; no broad host, gameplay, comparator or build-system rewrite.

**Finite acceptance cases:** (1) default baseline route; (2) explicitly supplied
baseline route; (3) relocated complete baseline package without fallback;
(4) each of the nine target files is byte-exact and remains owned after a disposable,
task-owned source copy is removed (never the original ZIP, baseline or evidence);
(5) corrupt/missing/empty target member are distinguished;
(6) cross-origin startup/loading is refused before Core; (7) baseline read-ahead
still reads all five packages into Results and throws in the original order even
when multiple fail; (8) target startup boundary produces no game state, files,
audio or network effects; (9) target overlay is distinct from baseline and cannot
silently use the host's standard 2.4 root. No target default settings are invented.

**Checks in order:** compile changed tests first; focused ownership/error-order
cases; existing `OriginalApplicationStartupInputsTests` and
`OriginalApplicationCatalogInputsTests` (including relocated/corrupt packages);
`OriginalMacRuntimeStartupTests.testWholeWinMainWithRuntimeProvidersAndOverlay`;
`OriginalMacRuntimeLoadingTests.testStartLoadsCatalogPoolAndLoadedMenuInOneAttempt`.
Then use the existing app runner on the candidate binary with **all current
`SCENARIOS`**, including playback and title-joystick: [app_e2e.py:213](../../tools/app_e2e.py#L213).
Compare original milestone/state/frame/replay/overlay expectations unchanged.
Do not rerun original 2.4 captures. Select further host checks only if an actual
shared-host change requires them. Independent storage-contract review is required
for acceptance; absence leaves review open while implementation/checks continue.

**Bounds:** one coherent increment, initial implementation/checking timebox four
hours; at most three correction rounds with separate run IDs. This is a task
budget, not a delivery estimate. New partial inputs ≤1 MiB, logs/report ≤32 MiB;
build/test output ≤8 GiB in a task-owned X5 directory, subject to its existing
reserve. Verify mount/APFS UUID `3A4F5FA6-DC86-4C6E-87E2-EAC2C2D72548` and reserve
before builds. If unavailable, continue code/cheap checks and leave builds open;
do not move POSIX/APFS-dependent builds to T7. T7 can hold verified evidence
archives after verifying writable ExFAT UUID `7C9569C1-BC8F-3288-B3FD-8831A3F07FAA`
and ≥40 GiB free. No reserve reduction or evidence deletion.

Stop M0 on a baseline behavioral difference, identity mixing, changed error order,
required unknown startup semantics, tool refusal or exhausted declared resources.
Preserve the failure and diagnose; do not weaken baseline checks to make target
input pass. A passing M0 proves the acquisition seam and 2.4 regression scope,
**not any 2.8 game behavior**. After its checked local commit, start D3 below.
If a specific D3 dependency is unavailable, name it and advance a ready D2/M1
contract; do not replace implementation with another unchanged small-leaf survey.

## Next changed contract: Frame/Object construction → loading → owned reads

**Result and consumer:** implement target Frame/Object storage needed by M1,
including the observed 432-byte frame accesses, with native-owned backing and
lifetimes. The existing ready composition seam is
[OriginalLoadedCatalog's Object child](../../native/Sources/NTSDCore/OriginalLoadedCatalog.swift#L190),
which invokes [OriginalObjectLoader](../../native/Sources/NTSDCore/OriginalObjectLoader.swift#L119)
and its continuous [Frame loader](../../native/Sources/NTSDCore/OriginalFrameLoader.swift#L92).
On the target branch, connect the proved target counterpart to M0's identity/raw
inputs and the target loading path. Do not silently route target bytes through
the 2.4 loader. The next gameplay consumer is the loaded frame read used by
[special AI](../../native/Sources/NTSDCore/OriginalCharacterAISpecial.swift#L196);
the recorded target reads identify why the storage matters, not acceptance of
that whole AI caller. Keep target startup's explicit boundary until its own
dependencies are proved, even if this storage increment is checked.

**Evidence before new execution:** read [FRAME_LOADER](../FRAME_LOADER.md),
[OBJECT_LOADER](OBJECT_LOADER.md), [RAW_FRAME_STORAGE](RAW_FRAME_STORAGE.md) and
[LOADED_CATALOG](LOADED_CATALOG.md). The later full raw/whole-Object evidence
supersedes the old isolated Frame coverage for dependency selection; its historical
exclusions stay immutable. Use the pinned first code section and correction1
contexts to locate actual target allocation, constructor and parse caller entries,
sizes/counts, initialization stores, field uses and returns. Record exact source
bytes/addresses and each required CRT/device dependency. The old constructor
`0x40bbf0`, Object entry `0x40ef70` and frame fragment `0x4103f8` have unresolved
target identity: do not treat them as target entries or infer a common address shift.
Timebox this targeted source review to 60 minutes/≤8 MiB notes; an unresolved
entry is an exact integration blocker, not grounds for a whole-engine resurvey.

**Finite source plan:** freeze at most 24 cases before the first run using the
existing adapters/manifests. Pin the selected raw member and decoded-byte provenance;
an unproved target decoder/CRT contract cannot be replaced by the 2.4 answer.
Use these case families, concretized to the recovered target branches:

| Cases (maximum) | Input provenance and observable gate |
| --- | --- |
| 4 construction/reconstruction | Fresh and repeated construction over declared `0xa5`/`0x5a` backing. Compare all written bytes and defined masks, allocation size/count, untouched padding and retained aliases; these fills are synthetic, not Windows defaults. |
| 6 index boundaries | 0, 399, 400 and visible Genma index 701, plus the source-proven last admitted index and first boundary. Do not assume the manual's 998 means a count or largest index. Record returned, rejected, faulted or unsupported outcomes separately. |
| 4 repeated/continuous cases | Original-order repeated frame/field definitions, omitted fields, names/sound references, and sections read through the same stream. Preserve lexemes, partial conversions, checksum/EOF behavior and old allocations; never split a whole-file parse at an artificial `<frame_end>`. |
| 4 changed field/allocation cases | Actual new fields and point/box forms used by the chosen visible DAT, plus recovered allocation/count boundaries. Compare requests, owner identity, pointer aliasing, order and postprocessing. An unproved form remains explicit; no accepting and ignoring new tokens. |
| 2 failure/cross-call cases | A source-established file/allocation failure and a repeated call with live owners. Declare modeled API answers; retain source faults and partial effects separately from Native rejection/rollback. |
| 2 whole-Object cases | Start with a small visible file, `custom/1genma/a/shuriken.dat` (ID902, 14 frame occurrences), then `custom/1genma/genma.dat` (ID901, max observed index701) as dependencies become ready. Use exact raw files and continuous loader return with all required children accounted for; unavailable PNG/sound/CRT children block that case, not construction or an independent ready path. |
| 2 consumer cases | Read the newly loaded records through the recovered target loading parent and one proved field-access caller, preserving state into a subsequent call. A fragment read alone does not accept whole AI/gameplay. |

Initial execution budget is 30 minutes and ≤2 GiB output, with explicit per-case
limits and terminal outcomes. Synthetic API replies remain synthetic; missing
assets or unknown backing never become fabricated original answers. Normalized
references need a reviewed mapping; compare raw bytes/masks and ordered events
where meaningful. No captured Object/Frame after-state is a Native initializer.

**Implementation and integration gate:** extend or isolate only the proved
constructor, storage and loading paths in `native/`; retain shared helpers whose
contracts still apply. Native must create its own records/allocations, keep live
and retired owners, aliasing and partial pointer writes, preserve state across
calls and roll back the declared public transaction. Compare the connected
constructor/loader caller, not only a list of parsed fields. After compile and
focused checks, run the declared target caller comparisons plus affected 2.4
raw-Frame, whole-Object and catalog regressions; preserve their expected/masks.
Review new storage/numeric/comparator contracts independently. Then commit the
coherent checked increment and connect the nearest ready loading consumer before
opening an unrelated study. If full runtime loading is still gated, name the
exact missing startup/resource contract and implement its next ready piece.

This is one mechanism across discovery, implementation and corrections, not a
fresh research-only task per substep. First implementation/checking budget:
four hours, up to three correction rounds with preserved failures; apply the M0
X5 build/T7 evidence bounds. Extensions need a diagnosed dependency or new
evidence. Review or real-device gaps leave acceptance open while permitted code
and comparisons continue; success never implies the full target catalog is loaded.

## Branches, checks, estimates and completion

Keep this target work local in `exp/ntsd-2.8.3.3`; no push, PR publication, merge
to main or baseline replacement follows from this plan. Preserve actual working
inputs, not only HEAD; parent/other worktrees own unrelated files. Commit each
coherent checked increment locally with open gates stated. The shared Git config
uses `/Users/michael/Developer/ntsd-2.4/.githooks`, whose post-commit auto-push is
incompatible with this local-only task. Preserve that shared configuration and
existing LFS hooks. Before each commit verify the retained-LFS/no-push hook
directory and use this command-scoped override (with explicit staged paths):

```sh
git -c core.hooksPath=/Volumes/X5/ntsd-2.4-research/version-2.8.3.3-preparation-20261017-hooks commit
```

Do not commit through the shared auto-push hook or use an empty hook directory.
If the verified override is unavailable, leave only the commit pending while
resolving its local hook dependency. No push/publication is authorized by a
successful test, commit or milestone. Do not edit immutable
2.4 references, historical plans/failures or the instruction archive. Target
fixtures/manifests/run IDs and writable roots are separately named and pinned.
Shared-code changes carry affected 2.4 regressions; target behavior gets separate
target comparisons. Retain old failures when a comparator is corrected, and obtain
independent review of new numeric/storage rules and comparator mappings.

Performance acceptance comes after behavioral comparisons on the same candidate:
real-clock pacing/input latency, loading/RAM under full target content, long modes,
audio and packaging. Preserve the current concurrent rendering/read-ahead/receipt
contracts. Do not assume an enlarged catalog has the same time/RAM cost or solve
it by altering tick order, target limits or original assets.

No overall hours or completion percentage is supportable yet. The older
200–520-hour scenario is not carried forward as a forecast. The RNG pilot's
0.262-second execution and roughly 30-minute first-pass wall time do not measure
the cost of a changed loader, whole caller, integration or full game. First collect
measured work for M0, one target loader/storage mechanism, one changed whole gameplay caller
and the first match. Estimate remaining *mechanism groups and integration gates*
from that ledger with assumptions/ranges; report access uncertainty separately.
If code-volume estimation is later requested, follow [archive:4285](../../AGENTS_HISTORY_2026-09-12.md#L4285)
and use the existing estimator at an explicit revision/new dated output; do not
equate instruction area or registry counts to completion.

**Checks performed for the revision:** clean starting branch/worktree/HEAD;
WORKFLOW, PROGRESS_RULES, current handoff, map/template and applicable archived
loader/storage/estimate constraints; complete engine study and all three run/pilot/
correction records; live Session startup/read-ahead/loading, Object/Frame guards,
catalog composition, RNG formula and AI frame consumer; existing packer/runner
entry points and retained-LFS/no-push hook inspected. Prior input pins and census
are reused; no large artifact was rehashed and no successful experiment repeated.
Local links, document size and diff checked after writing. This document-only
revision executes no original or Native code and claims no new behavioral or
independent contract acceptance. It does not start a goal. An active full-port
goal continues after every checked local increment through M6, including original
content, AI, modes, UI/input/audio, saves/replays/networking and clean-device gates.
M0, a first match, or a running window is never full completion.
