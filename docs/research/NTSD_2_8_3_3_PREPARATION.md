# NTSD 2.8.3.3 — preparation for an original-faithful branch

Date: 2026-10-17. Status: preparation complete, including attributed community
audio and located Discord sources; production plan pending. Requested reviewer:
`gpt-6-astra`, reasoning `xhigh`. This is preparation for a later implementation
plan; it does not create an implementation branch or accept new game contracts.

## Declared scope before further inspection

Consumer: a future 2.8.3.3 application/catalog/runtime identity. Its integration
is blocked by unavailable built-in content and unmeasured 2.8.3.3 behavior.
The immediate deliverable is evidence-qualified planning readiness, including
an independent review of the existing
[assessment](NTSD_2_8_3_3_ASSESSMENT.md). Recommendations newly authored here
are author analysis, not independently accepted contracts.

Read first: [WORKFLOW](WORKFLOW.md), [PROGRESS_RULES](PROGRESS_RULES.md),
[CURRENT_WORK](CURRENT_WORK.md), relevant [RESEARCH_MAP](../RESEARCH_MAP.md),
[TASK_TEMPLATE](TASK_TEMPLATE.md), [FRAME_LOADER](../FRAME_LOADER.md), and the
archive's decoder/loader/preservation/estimate constraints. Parent revision:
`2c5cb633`; unrelated pending Web work is protected. The existing
[safety incidents](../evidence/codex-safety-incidents-2026-09-12.json) remain
open; none of their affected execution operations is resumed by this task.

Question: what must be known to plan an identical-to-original 2.8.3.3 version,
which existing services can reasonably be reused, and can the supplied binary's
content be inspected with already configured static tools?

Reference inputs: the supplied `/Users/michael/Downloads/NTSD2.8.3.3.zip`, its
pinned main executable, the clean 2.4 distribution, saved static inventory and
validation, existing source and study documents. The supplied ZIP is the
candidate exact target; an official release identity or equivalence to any
other package has not been established. Original artifacts remain read-only.

Finite new cases: (1) verify the supplied archive identity and selected members
against saved hashes; (2) review the saved inventory/validation and original
registry, changelog and relevant modding/distribution instructions; (3) inspect
the main executable's existing header/section metadata and a bounded list of
container/signature strings; (4) discover configured static readers and, only
if a standard readable format is identified, try at most one read-only listing;
(5) inspect the relevant runtime/loader/host interfaces and existing acceptance
limits. No original code, installer, multiplayer utility, source harness or
capture is executed; no extraction by executing code or protection bypass is
attempted. No tools are installed. Failure or unsupported static format remains
an explicit boundary, not empty content or proof of encryption.

Limits: up to 30 minutes for new static checks; at most two cheap correction
rounds with separate records; at most 4 MiB of new text/JSON output in the
repository. Existing inventory is reused, not regenerated. No new large IO,
build, extraction, source execution, device run or network action is in scope.
Any necessary expansion needs a separate finite discovery task. Allowed writes
are this document and a small separately named preparation evidence JSON;
all existing evidence, tools, runtime, fixtures, baselines, historical plans,
archive instructions and unrelated pending files are protected. The parent
agent owns the handoff update and commit.

Preparation acceptance: exact input pins; corrected factual distinctions;
explicit fidelity/acceptance scope and inherited exceptions; concrete unresolved
questions and discovery outputs; bounded static results including failures;
links and document consistency checked. This does not imply a full content diff,
behavioral equivalence, implementation readiness for opaque contracts, or a
new whole-game/platform acceptance result.

## Readiness verdict

Use the current engine and **make the work diff-driven**. The reusable asset is
both native code and the recovered understanding of 2.4. We should identify
what survived, then spend reference work on changed mechanisms and their
consumers. Rebuilding every rule from scratch would discard that advantage.
However, the supplied 2.8.3.3 has not yet been shown to be a small engine patch.

We are ready to define the exact reference and perform finite discovery. We
are not yet ready to promise the cost or date of an identical full version.
The important missing inputs are readable built-in content/configuration,
inspectable effective engine code/dependencies, and observations of this exact
version. Only seven of 330 registered objects and none of 24 backgrounds are
currently visible outside the executable. No 2.8.3.3 game run was made here.

The requested **separate branch** is the intended isolation boundary. The
earlier assessment's same-binary version selector is an optional design idea,
not a requirement or a prerequisite to branch work. Preserve the 2.4 branch,
baseline, fixtures and accepted contracts. Share proven implementation where
appropriate; choose any further profile/module separation from actual changes.
The static review creates no implementation branch.
The user's later instruction makes the version work **local only and
unpublished**: no further push/publication is authorized. The isolated target
implementation branch is prospective, after preparation and planning. The parent
will deliver these documents on a separate local preparation branch,
`prep/ntsd-2.8.3.3`, without switching or publishing concurrent `main` work.
A later message spelled
the version `2.8.8.3`; the supplied archive and established target remain
2.8.3.3 in this analysis, as the parent explicitly communicated.

## Exact target and factual review

| Reference | Identity |
| --- | --- |
| Supplied ZIP | `fca38bfe1391d969b9d29d1289c51bbf5270a384fa7da6d4a7c053da77c52b2d` |
| `NTSD2.8.3.3/NTSD.exe` | `5eda51440039099069d041e5bd13fde8be9fd8c7b20983985b1712a59719d86b` |
| Clean 2.4 `NTSD 2.4.exe` | `3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c` |

The target is the **user-supplied package identified by these bytes**, including
its active custom entries. Its filename and bundled release notes identify it
as 2.8.3.3; correspondence to a separately published pristine release was not
verified. A more readable developer package would be a candidate dependency,
not an automatic replacement reference. Establish its correspondence to this
package before using it to explain behavior. Preserve both raw identities.

The earlier assessment is substantially sound as a *visible-file inventory*.
Independent selected-source review confirms its 330 object / 24 background
registry census, seven loose registered objects, 470 loose frame occurrences,
59 occurrences outside 0…399 and maximum defined frame 701. Counts preserve
duplicate definitions. The saved 2.4 census remains 137 objects / 17 backgrounds;
that complete inventory was reused rather than regenerated. Type-0 counts
remain record counts, not selectable-character counts.

Several qualifications matter before planning:

- Absent outer paths are **opaque**, not deleted. The 323 object and 24
  background paths do not enumerate all missing sprites, audio, UI, stage,
  configuration or dynamically selected dependencies.
- The frame-domain difference is directly supported by loose data. A different
  per-frame byte layout is **not** established by that fact; layout, capacity,
  numeric handling and pointer ownership require their own evidence. The
  previous assessment's statement that a new record layout is required should
  be read as an unresolved design risk, not a measured binary fact.
- The 2.4 lexical decoder yields recognizable loose DAT text; it does not
  establish the 2.8.3.3 executable's decoder, parser, repeated-field semantics,
  checksums, defaults or loader error behavior. Parser inventories must retain
  unknown tokens, raw bytes and occurrence order.
- The generic engine manuals include capabilities whose shipped use is
  unknown. They supply a search checklist, not automatically 330 required
  implementations or a license to infer numeric semantics.
- Platform reuse is plausible, but startup/application orchestration and the
  present raster pipeline contain 2.4-specific contracts. Calling all runtime
  services already compatible would be too broad.

### New material beyond the initial assessment

The following are **bundled-document statements**, not measured executable
contracts. Paths are relative to `NTSD2.8.3.3/` in the pinned ZIP; line numbers
refer to decoded text and are retained in the new evidence.

| Question raised | Source | Planning consequence |
| --- | --- | --- |
| Object registry and live gameplay capacity are documented as 1000; the latter changes from 400 | `instructions/special features for modding/other stuff.txt`: 11–12 | Audit catalog limits and the live actor pool separately from frame capacity. Existing 400-slot loops, masks and identity/ownership tables cannot be enlarged by blanket replacement. |
| Both itr and bdy capacity are documented as 100, frame limit as 998, sound limit removed | Same file: 13–15 | Determine exact index/count interpretation and ordinary exhaustion/error behavior; do not infer that all upper limits are exercised by shipped content. |
| 32-bit PNG alpha, `_mirror` image precedence and a changed image API | Same file: 5–9 | Image decoding alone is insufficient: establish alpha/color-key, mirroring, compositing order and output pixels. |
| Configurable DirectDraw/GDI renderer and resolution | `instructions/special features for modding/window control and dll loading.txt`: 17–26 | The current 2.4 presentation size/backend cannot be assumed to be the new reference. Recover shipped configuration. |
| Configured DLL loading and `ddraw.dll` precedence | Same file: 4–12 | Compare the effective EXE **plus loaded dependencies**, not the main executable in isolation. Which modules the shipped game uses is unknown. |
| Selected-on-demand data loading and image sharing options | `instructions/special features for modding/system dat.txt`: 36, 49, 51 | Obtain the actual system file; initialization, cache lifetimes, checksum inputs and resource release may differ. |
| 1TU and 2TU use different replay suffixes/directories | `instructions/special features for modding/tu mode.txt`: 5–13 | Treat each input mode, recording/playback and networking as explicit compatibility domains. Even the manual's `recordings/` spelling differs from outer `recording/`; actual IO decides. |

Genma is not an irrelevant example downloaded separately: IDs 901–907 are
registered in this supplied package. Its two type-0 files contain `hidden: 1`;
`custom/Custom Characters.txt` lines 18–19 describes the `Kanchoo` unlock and
hidden values. The shipped Genma, clone, projectiles, graphics, sounds and
unlock behavior belong in exact-package acceptance. The document's online
warning at line 23 makes data identity a networking question, not proof of a
particular checksum algorithm.

`Multiplayer.exe`, lobby/server/name-changing utilities, recording-summary
utilities, the side-by-side runtime installer, guides and modding templates
also exist in the ZIP. They were inventoried and left unexecuted. Keep a
disposition for every item: game-reachable functionality, optional external
workflow, documentation/template, or installation dependency. Determine whether
`Multiplayer.exe` is necessary to an original play path and how it interacts
with the engine before sizing network work. Shipping these Windows programs
would not satisfy the native-runtime requirement; silently omitting their
game-reachable function would not satisfy identical behavior. Recreating every
standalone modding tool is not inferred from the game-port request. No
external service availability or interoperability is established here.

## Can existing tools expose the built-in content now?

Static inspection reads the exact main EXE as data. It is a PE32 GUI executable
for x86 according to `/usr/bin/file`. Its seven saved section records account
for all 87,261,184 bytes through their last raw section end; there is no trailing
overlay after that end. One section has 86,147,072 raw bytes but 2,920,448
virtual bytes. These are file-layout observations, not an executable loader
model or a count of contained assets.

The bounded signature scan found the literal `ENIGMA` at file offset
87,246,788, followed by binary fields. It found none of the selected ZIP local
header/end, 7z or CAB signatures. This is a useful container-family clue;
it does **not** establish a particular product/version, encryption/protection,
an extraction algorithm, or the correspondence between payload and registry.
Marker absence is not proof that some other encoding/container is absent.

Configured readers include `7zz`, `bsdtar`, `unzip`, `file`, `strings` and LLVM
object tools. Presence does not establish support for this opaque payload.
No standard inner archive was identified, so the conditional archive-listing
case was not attempted. No tool was installed, main executable extracted to
disk, or code unpacked/executed. The prior `inspect_original.PE` import/resource
walk failures remain preserved, not retried:

```text
ValueError: RVA outside file-backed sections: 9f38185e
ValueError: RVA outside file-backed sections: ac724
```

The answer is therefore: existing tools can inspect **headers, literal markers
and outer resources**; readable built-in game files and effective code have not
been obtained. The next discovery must identify a permitted, reproducible
content/reference access route. A corresponding developer/modding package is
one candidate. Container documentation or an already supported static reader
is another if its applicability is demonstrated. No assumption that unpacking
will be easy is included in the estimate, and no affected refused operation
is reopened by this recommendation.

## Community audio: useful leads, with their evidence boundary

The user subsequently supplied four Russian recordings named
`2026-10-17 15.42.{02,14,18,25}.ogg` (16m42.72s total). The parent transcribed
them locally, then this Astra review read the relevant timestamped segments.
The [community evidence](../evidence/ntsd-2.8.3.3-preparation-20261017-community-leads1.json)
retains input/output hashes, local paths, attribution limits and verification
questions. The separate
[parent intake evidence](../evidence/ntsd-2.8.3.3-community-audio-20261017.json)
pins the four bounded transcripts; their hashes were checked here. Voices and
full transcripts stay outside Git. No audio was uploaded
and no community member was contacted.

These are ASR-derived claims from a mixed conversation, not a source-behavior
measurement or reliably identified speakers. Names/spellings may be wrong.
The repeated tail in clip `25` from segment start 527.16s through 549.16s
extends beyond the 527.26s audio and is excluded as unreliable; the raw output
is retained. Clip `02` also has one nonempty segment at 80.34–81.12s beyond
its actual 79.86s duration; it is excluded, and empty repeated segments carry
no evidence. The parent's bounded transcripts exclude all six flagged nonempty
segments; every lead below lies outside them.

| Attributed lead | Source clip and time | What it changes in preparation |
| --- | --- | --- |
| A participant says the LF2 Unified author privately imported later NTSD and wrote a message about obtaining its data/dumps | `25`, 1:10–1:50 and 6:17–6:38 | Highest-value content-access lead. Obtain the exact message URL, date, version/hash and original provenance; assess its actual procedure before relying on it. Neither extraction success nor equivalence to this ZIP is established. |
| Little Fighter Empire, LF2 Unified and OpenLF2 are named; Little Fighter Forever and NTSD Online are suggested community/guide locations | `02`, 0:17–1:15; `18`, 1:55–2:12; `14`, 0:19–0:51 | Leads to primary material and knowledgeable people. These projects' rules are not the behavioral reference, and no outreach is authorized merely by their mention. |
| One participant expects small assembly patches; another emphasizes substantial Neora/Darkfiren additions | `25`, 1:59–2:50 and 5:29–6:09 | Test the small-delta hypothesis with the proposed diff. The conversation does not establish consensus, patch size or a shorter schedule. |
| NTSD CE/CS is described as a separate 2.4-derived mod and newer 2.5–2.8 as PvP-focused | `18`, 0:08–0:30 | Avoid confusing lineages/builds. The uncertain name and PvP description do not remove stages, other modes or original errors from the target. |
| Networking is described as delay-based/slowest-player paced, with lobby, a Steam-related tool and direct Radmin paths | `18`, 2:36–3:43 | Identify exact tools/guides and recover the supplied version's TU/wire/helper contracts. Claims about old netcode or practical ping thresholds are not accepted engine facts. |
| Rollback multiplayer is promised for LF2 Unified | `18`, 4:10–4:29 | Keep that other project's proposed feature separate from NTSD 2.8.3.3 fidelity; do not add rollback based on the conversation. |
| Another workflow reportedly used DLL injection, log comparison, Ghidra and Cheat Engine address mapping | `25`, 7:42–8:19 | Methodology lead only. No such operation ran here; inspect the original description, target and existing refusal boundaries before proposing a bounded operation. |

At audio intake, the exact LF2 Unified message URL was missing. The later
Safari review below locates the methodology thread and an NTSD access claim,
while the reproducible target access procedure remains missing. These sources
are leads to original artifacts and reproducible evidence; copying an LF2
reimplementation's rules would violate the project's reference policy. The
discussion strengthens the reason to try diffing, while leaving the measured
delta and effort unknown.

The audio intake is a separate, parent-declared operation from the static
review's no-install scope. It used task-owned T7 binary wheels/model only:
`mlx-whisper 0.4.3`, `MLX 0.32.4`, local `mlx-community/whisper-turbo` revision
`ec8e501925a1e2e85b082740a208c37ff6c4f59a`. Four transcriptions completed in
236.77s including model acquisition. The initial 4 GiB allocation allowance
was exceeded because ExFAT allocation units magnified the package files;
the preserved storage addendum raises the bound to 14 GiB with the 40 GiB
reserve unchanged. No global packages, original game artifacts or running
game processes were changed. Provenance and full transcripts are under
`/Volumes/T7/ntsd-2.4-artifacts/version-diff-20261017/community-audio/`.
Use the four `2026-10-17 15.42.XX.bounded-transcript1.txt` files for this
preparation; raw ASR JSON remains available to audit the excluded tail.

## Located Discord sources: access testimony is now concrete

The user then supplied the exact Discord conversation with The Scar and
authorized Computer Use in Safari to locate the shared links. The parent
alone inspected three shared links and three bounded server searches (`NTSD`,
`enigma`, `NTSD decrypt`); this Astra task did not control the browser.
The [Discord evidence](../evidence/ntsd-2.8.3.3-preparation-20261017-discord1.json)
records URLs, relevant authors, displayed dates/times and the inspected scope.
Dates/times below are as displayed by Discord; their timezone was not established.
No message/reaction, invite, download, code execution or private API fetch was
performed. Unrelated DM/sidebar content is not copied into this preparation.

| Located source | What was actually observed | Consequence |
| --- | --- | --- |
| [Dan, May 6, 2026 methodology thread](https://discord.com/channels/224499203714449409/507147497672671233/1501641838535119040), 19:48 and 22:49 | Dan describes rebuilding from original LF2 logs using DLL instrumentation/parity tests, Ghidra C/header output, raw addresses and Cheat Engine mapping. The discussion concerns LF2/LF2 Remastered and proposed 60 FPS/rollback. | Concrete methodology testimony; no NTSD 2.8.3.3 content-access recipe or measured parity is supplied by this thread. |
| [Dan and The Scar, September 13, 2026 NTSD discussion](https://discord.com/channels/224499203714449409/754960391603355668/1548732509754232895), inspected context 18:23–18:57 | Dan describes C++20, intended LF2/LF2R/DBZ/NTSD/SGB support, separate per-mod C++ simulation libraries and a Linux-first original-game harness/log comparison. He says NTSD/DBZ release waits on handling their encryption. The Scar notes that modified EXE features must transfer alongside DAT. | Relevant explanation of the intended approach, with no target hash or published comparison evidence. It supports investigating whole per-version mechanisms; it does not prove a small patch or prescribe our module design. |
| [JohnMuffin, September 13, 2026, 18:57](https://discord.com/channels/224499203714449409/754960391603355668/1548739293240098950), including the following same-time message | JohnMuffin says Dan showed him NTSD/DBZ decryption and that he knows at least one method. | The strongest located access lead. It is attributed testimony about a method, not the method itself, readable assets, a particular NTSD build/hash, or independently demonstrated equivalence. |
| [The Scar's Lutris guide, September 20, 2025](https://discord.com/channels/253945813774893056/253945813774893056/1419012211799756882) | Installation guide for 2.7.2, with a note to use 2.8.1. | Different-version installation guidance; no supplied-2.8.3.3 access contract. No installation instructions were executed. |
| [Forwarded video's original message, October 17, 2026, 14:41](https://discord.com/channels/224499203714449409/257435658333716480/1560996159412244520) | Dan replies about a new mod in a WillemNl/Julia-thumbnail context. | This forwarded clip is not evidence of an identical NTSD 2.8.3.3 import. |
| [JohnMuffin, December 9, 2025, 17:27](https://discord.com/channels/224499203714449409/408894698585980928/1447987982932901991), found by `enigma` | Tool discussion appears in an NTSD 2.4/1.9, Lee on Road and Molebox context. | Version-mismatched lead. It does not connect a specific method to this ZIP's `ENIGMA` marker. No tool was downloaded or run. |

The user's later credits screenshot also has a **primary-package match**:
`instructions/movelist&credits.txt`, UTF-16 with BOM, SHA-256
`913c9754888af9d3f6338ead42262519c0aea0a8c1f8460a6f06d8d3e9aa586f`.
A bounded read of that exact ZIP member confirms John Muffin's sprite/sound/menu
credit (line 1619), TheScar's Anko and EXE/DLL credit (1624), multiple EXE/DLL
contributors including Darkfiren and TheScar (1634), Neora contributors (1635),
and NTSD 2.4 Patched/RE between 2.4 and 2.5 (1642). The evidence retains these
exact lines and the parent’s initial wrong-encoding search outcome. This makes
the named contacts more relevant than an unconnected community claim, but
Discord-account/credited-person identity was not independently established.
Credits do not prove an access recipe, artifact correspondence or behavioral
parity, and do not authorize contacting anyone.

The final `NTSD decrypt` query returned one result, the exact JohnMuffin
message linked above; Safari was left there for the user's inspection. The
broader `NTSD` search showed 416 results, of which the relevant first-page
September discussion was opened, and `enigma` showed seven. This was not an
exhaustive review of server history, so absence of a recipe in these inspected
contexts is not a claim that no recipe exists elsewhere.

Current readiness is now precise: **the methodology source and actual NTSD
access testimony are located; a reproducible procedure and correspondence to
the supplied 2.8.3.3 artifacts are still missing.** The next content-access
discovery can use these exact messages as leads and evaluate any underlying
original materials against the pinned ZIP. It must establish the actual
operation and version before attempting it. The sources do not change refusal
boundaries, authorize third-party code execution/outreach, turn rollback into
an original NTSD feature, or make a full-version hour estimate reliable.

## Diffing to accelerate production

The useful comparison has three layers, with a fourth layer for integration.
It should be an addition to the existing inventory/study evidence, not a new
parallel execution framework.

1. **Content correspondence.** Preserve encrypted/raw bytes, decoded bytes,
   names, ordered registry entries, repeated frames/fields and unknown tokens.
   Match assets by exact hash first, then candidate semantic identity. A renamed
   file may be unchanged; a reused ID or path may represent a different object.
   Compare DAT tokens/values, states, transitions, effects, helper references,
   configuration, images, audio and all reachable dependencies. For images and
   audio, record byte identity separately from decoded pixel/PCM identity.
   Never normalize away order, duplicate definitions or numeric spellings
   before preserving and understanding their observable effects.
2. **Effective engine correspondence.** Once readable, map 2.4 mechanisms to
   2.8.3.3 using code bytes, instruction/control flow, constants, call targets,
   data accesses and dependencies. Normalize relocation addresses only with
   explicit provenance; retain sizes, signedness, literal values, stores and
   ordering. Compare 2.4's installed DLL effects too. The same function bytes
   can behave differently with different globals, layouts, callees or caller
   initialization. Compressed on-disk EXE similarity is not this comparison.
3. **Differential contract checks.** Use the existing 2.4 cases to ask whether
   the corresponding 2.8.3.3 mechanism agrees under justified corresponding
   inputs. Newly generated 2.8.3.3 expected results receive their own identity;
   old expected/masks/failures remain frozen. Include changed-domain cases,
   actual DAT use, retained live state, numerical boundaries relevant to that
   contract and whole callers. A new record layout needs an explicit mapping
   of comparable semantic values/resources, not blindly equal private bytes
   or a mask that conceals a mismatch. Such a comparator mapping needs review.
4. **Whole application checks.** Compare original 2.8.3.3 against the native
   candidate: continuous inputs, state/RNG, resources, events, UI/pixels,
   audio, save/replay output and network outcomes. 2.4→2.8.3.3 differences are
   expected at changed features; the acceptance comparison is native 2.8.3.3
   **against original 2.8.3.3**, not forcing both original versions to agree.

A compact mechanism ledger should retain the following distinctions:

| Finding | What may be reused | What remains necessary |
| --- | --- | --- |
| Exact content bytes | Store/deduplicate identical resources without rewriting them | Loader/consumer compatibility; equal bytes do not guarantee equal interpretation |
| Same behavior established for a declared mechanism/domain, with matched inputs, dependencies and callers | Existing native handler and valid 2.4 evidence for that unchanged domain; no redundant old capture | Target-version provenance and representative composition check; retain domain boundary |
| Structurally similar code or matching signatures | Analysis labels, candidate correspondence and implementation starting point | Changed dependencies/data/numeric review and targeted 2.8.3.3 original comparisons before acceptance |
| Demonstrably changed rule/content | Shared unaffected primitives and test infrastructure | New contract/expected results, affected consumers and regressions |
| Opaque, unmatched or unsupported | Documentation and investigation leads only | Resolve the named evidence gap; do not label it unchanged or known empty |

This avoids proving every unchanged rule from scratch while preventing a
similar-looking leaf function from carrying an unproven whole engine. An old
PASS remains valid only for its pinned inputs/code/dependencies. It becomes
evidence about the new version only through a justified correspondence.

**A complete global diff is not a prerequisite to all implementation.** Once
a finite mechanism has its target inputs, original contract, ready consumer
and comparison gate, transfer it on the new branch while independent opaque
areas remain open. Do not implement the generic manual wholesale first. A
full dependency inventory and declared disposition of every original feature
are required for eventual whole-version acceptance, not for the first bounded
increment. After a checked candidate, transfer to its ready native consumer
under PROGRESS_RULES rather than continuing an unlimited diff survey.

Existing entry points are `tools/compare_ntsd_distributions.py`,
`tools/import_ntsd.py`, `tools/inspect_original.py`, saved mechanism studies,
`tools/app_e2e.py` and mode-specific frozen references,
`tools/crossplay_replays.py`, `tools/crossover_drive/compare_*`,
`tools/lfr_checksum.py`, and cross-platform state/frame comparators. Reuse
their mechanisms and adapt configuration only after checking their contracts;
many contain fixed 2.4 addresses, formats or UI coordinates. The old checksum
patch utility is not evidence of a valid 2.8.3.3 replay format. No existing
function-diff framework was identified by the bounded filename search, and
none was created. Completed 2.4 captures are not restarted for a fresh report.
The [coverage audit](EXE_COVERAGE_AUDIT_2026-10-03.md) remains binding: range or
instruction percentages do not establish completion or a reusable-code fraction.

## Architecture implications of a separate branch

Reuse candidates with concrete existing seams are host window/input delivery
(`OriginalRuntimeWindowHost`, `OriginalRuntimeSessionHost`), socket transports
(`OriginalRuntimeSockets`), audio output, filesystem overlays, framebuffer
presentation, packaging and scenario automation. Their platform work has value
even if the game's command contract changes. Reuse is conditional at the seam,
not a statement that each backend's current policy matches the new game.

Known 2.4 coupling is visible in:

- `OriginalFrameLoader.swift`: 0…399 guards and 0x178-byte word/storage model.
- `OriginalObjectLoader.swift` and `OriginalLoadedCatalog.swift`: 400 frame
  records, 0x7a4 header and backing requirements.
- `OriginalMacRuntimeLoading.swift`: 400 live actors, 0x420 allocation stride
  and the recovered 2.4 catalog/checksum path.
- `OriginalMacRuntimeStartup.swift`: recovered 2.4 startup driver, five fixed
  menu-sound bindings, fixed image identity and prepared graphics assumptions.
- `native/Package.swift`: packaged `OriginalStartup`, `OriginalCatalog`, menu,
  arena and sound resource families. Package identity and content selection
  must change deliberately; old fixtures remain on their original version.

A larger documented limit does not justify replacing every literal `400`;
frame count, actor count, allocation byte lengths and unrelated numerical
constants have different contracts. Expanded storage can affect scheduler order,
allocation reuse, contacts, RNG, AI and rollback throughout a whole caller.
The 2.8.3.3 actor allocation size and raw layouts are still unknown.

Give the branch's application/bundle/package, resource manifest and writable
settings/save/replay roots an explicit target identity so it can coexist with
2.4 without corrupting its data. Do not automatically migrate saves/replays or
allow mixed-version networking. Whether original 2.8.3.3 intentionally supports
another version is itself a compatibility question. This requires version
identity at interfaces, not necessarily a universal runtime rules switch.

## What “identical” must mean in acceptance

The target is observable original behavior under declared original inputs and
environment, implemented natively. Native machine code, private host allocation
addresses and macOS window chrome need not duplicate Windows internals; their
game-visible consequences do. Avoid inventing tolerances while planning.

| Acceptance area | Required evidence for the target version |
| --- | --- |
| Content and configuration | Every registered/shipped reachable object, helper/form/unlock, arena, stage, mode, menu, font/image/audio and config dependency accounted for; exact bytes or justified faithful decoding; opaque inputs stay open |
| Simulation and input | Movement, combos/hold inputs, hitlag/timing, combat, spawns, transformations, AI, RNG and allocation/update order; continuous whole matches and relevant reachable unusual/error states |
| Presentation and audio | Menus/HUD/selection/ending transitions, fonts, clipping, mirroring, transparency, camera, cursor/input mapping, ordered sounds/music and timing against the original under a declared configuration |
| Persistence and replay | Settings/unlocks/saves, path and failure behavior, real round trips, both shipped TU modes and their formats; no silent mixing with 2.4 |
| Networking | Actual supported player/mode/topology behavior, local/original interoperability where required, sync checks, input scheduling, disconnect/reentry and relevant helper workflows; external dependencies explicit |
| Application and delivery | Startup/loading/shutdown, native window/input/audio, packaged regular files and dependency audit, clean-Mac execution; each other commissioned host has its own actual acceptance |

Original errors reachable through ordinary play/resource conditions remain
part of fidelity. Exhaustive arbitrary corruption is not a completion target.
Source fault, harness boundary, unsupported input, native mismatch and missing
evidence remain distinct; rollback rejection is not a successful fault match.
First Naruto/Sasuke match, isolated functions, screenshots, or agreement of
Summary totals alone do not establish all of these areas.

Existing accepted **2.4 departures cannot silently carry over**:

- [MENU_GAMEPAD](MENU_GAMEPAD.md) adds controller navigation to formerly
  mouse-only front screens; `--original-menu-input` disables that extension.
- [WINDOW_SCALING](WINDOW_SCALING.md) defaults to resizable/scaled presentation
  and host full screen; `--original-window` preserves that version's original
  format. The correct 2.8.3.3 geometry and Alt+Enter behavior must be observed.
- [APPLICATION_GDI_TEXT](APPLICATION_GDI_TEXT.md) explicitly uses substitute
  font shapes/advances under a 2.4 user decision. This cannot prove identical
  2.8.3.3 text; the supplied package's custom font/template materials do not by
  themselves establish the game's selected font.

The requested identical version therefore starts with original-observed
policies for its fidelity checks. Any desired convenience mode is separately
named and requires an explicit choice if it changes that target. No new user
decision is needed merely to continue read-only discovery. CrossOver evidence
must remain labelled CrossOver; it does not close actual Windows/device or
clean-Mac gates. Pending platform checks block their dependent acceptance,
not all independent implementation.

## Outputs needed before the production plan and estimate

The next task should be **bounded reference/content-access discovery**, with
these concrete exit artifacts. These are preparation dependencies, not a
production schedule or a demand to finish all research first.

1. A target-reference manifest including executable, all required loaded
   modules, full built-in content/configuration and loose/custom overrides;
   a reproducible permitted access method and correspondence to this ZIP.
   If access is unavailable, record the exact unavailable input and the
   independent work still possible, rather than assuming empty files.
2. An initial semantic difference ledger covering every resolved registry
   entry and its immediate dependencies, plus named unresolved paths. Identify
   used new tokens/states/kinds, true capacities, startup/config choices,
   graphics/audio formats and candidate unchanged mechanisms. Broaden it
   incrementally as further consumers require, keeping the full census visible.
3. A finite target-original observation/comparison design: environment and
   provenance, actual startup/menu/selection to a match, timing/input/TU modes,
   replay/network interfaces, observable state/pixel/audio outputs and remaining
   manual/device checks. Execute only under its own declared scope; none ran here.
4. One representative ready mechanism that tests the reuse proposition:
   correspondence established, native candidate transferred, whole-caller
   comparison completed and actual analysis/implementation/check time recorded.
   Choose it from resolved dependencies, not merely because Genma is loose.
5. A branch-start inventory of shared versus changed paths, preserved 2.4
   evidence and known host deviations, with versioned assets/user data and the
   first consumer gate. Include relevant uncommitted inputs explicitly if they
   are needed; a HEAD-only checkout does not contain concurrent pending work.

Items 1–3 support a defensible staged plan; item 4 calibrates implementation
allowances rather than delaying every useful change. If some whole-version
unknowns remain, the plan can carry a discovery allowance and explicit revision
gate, but it cannot promise an identical complete version within a fixed cap.

The previous **40–100 hours for a first compared match** and **200–520 hours
for the full version** remain historical, low-confidence planning assumptions.
They were not measured throughput, a probability interval or a completion cap.
The newly highlighted capacity, image/backend, loader and helper uncertainties
make them unsuitable for committing a schedule. The earlier **8–24-hour
discovery allowance** is likewise a timebox idea, not evidence that content will
be available within it. No replacement total is manufactured in this review.
Diffing should save work where correspondence is proved; neither a savings
percentage nor a speed multiplier can yet be justified. Re-estimate after
observing the changed mechanism count/dependencies and a completed pilot,
separating active work, waiting, shared 2.4 blockers and platform acceptance.

## Checks and remaining gates

The [static evidence](../evidence/ntsd-2.8.3.3-preparation-20261017-static2.json)
records 24 passing checks, selected member identities, a direct
registry/frame census, exact manual lines, PE/signature observations, current
source pins, configured readers and preserved preflight outcomes. Both EXE
identities and the immutable AGENTS history hash were checked. The earlier
complete 112-member/1,595-baseline-file inventory and its 41 author checks were
reused; they were not promoted into behavioral evidence.

One check against the *earlier inventory's* complete dirty-file pin map failed:
that map includes the assessment document itself while it was still being
written. Its final committed bytes differ from that old intermediate pin.
The [failure](../evidence/ntsd-2.8.3.3-preparation-20261017-preflight1.json)
is preserved. The first interpretation incorrectly attributed it to concurrent
Web changes; the
[review correction](../evidence/ntsd-2.8.3.3-preparation-20261017-review-correction1.json)
establishes that the only differing old-map path is the assessment, equal to
current HEAD. All other earlier dirty pins matched at static2. The 24 static
checks and original/source identities remain valid; no binary check was
repeated to correct the interpretation. Separately, current status includes
unrelated concurrent Web/TVOS work. No task-owned write targets those paths.
The parent stages only this card, its new evidence and the handoff entry.

No runtime implementation, build, game execution, source capture, baseline
modification, new acceptance comparison or implementation branch creation
occurred. Independent
review of the prior assessment was performed by this Astra task; newly authored
recommendations remain analysis. Actual 2.8.3.3 behavior, full asset mapping,
recovered code/dependencies, original/native comparisons and final platform
acceptance remain open. The full 2.4 queue was not resumed.
