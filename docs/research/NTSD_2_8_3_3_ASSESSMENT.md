# NTSD 2.4 → 2.8.3.3: static comparison and engine migration assessment

Date: 2026-10-17. Status: bounded analysis requested by the user; no runtime
changes or authorization to replace the 2.4 baseline. This is a separate version
assessment, not continuation of the full-port queue.

## Plan and evidence boundary

Consumer: a future version-selected catalog/loader/gameplay profile in
`native/Sources/NTSDCore` and `NTSDRuntime`. Integration is blocked by unknown
2.8.3.3 contracts and unavailable loose built-in content, not by platform hosts.
The original 2.4 contracts and fixtures remain authoritative for 2.4.

Question: identify content, format and engine changes in the user-provided
archive and estimate incremental work on the existing engine. Parent evidence:
[CURRENT_WORK](CURRENT_WORK.md), [RESEARCH_MAP](../RESEARCH_MAP.md),
[frame loader](../FRAME_LOADER.md), [cross-platform runtime](CROSS_PLATFORM.md),
[coverage audit](EXE_COVERAGE_AUDIT_2026-10-03.md), and the archive's own changelog
and modding documents. Historical decoder, loader and estimate constraints were
read in `AGENTS_HISTORY_2026-09-12.md`, including lines 4285–4312 and 4949–4954.

Inputs: pinned clean 2.4 tree; `/Users/michael/Downloads/NTSD2.8.3.3.zip`.
Starting commit: `5a6d3d3879a95be84be4e22b1e3c198cc1cb5eab`. Existing dirty Web
files are unrelated, preserved and pinned in the machine-readable evidence.
Existing safety incidents remain open under their original dependencies; this
task only reads files and does not reproduce an affected execution operation.

Finite cases: every regular baseline file and ZIP member; the two visible
`data/data.txt` registries; available external DAT files; PE headers/sections;
the bundled changelog and modding text. Use the existing `import_ntsd` decoder
and `inspect_original.PE` header reader without changing either. Original EXEs,
installers, DLLs and lobby utilities are not executed, patched or unpacked by
execution. No synthetic Windows/device observations or new behavioral matches
are claimed. Documentation describes possible features, not necessarily their
use by this distribution or exact implemented semantics.

Bounds: one static inventory, up to three cheap correction rounds with distinct
run IDs, no source captures/builds, 10 minutes per inventory, 512 MiB new output.
No full archive extraction is needed. Any larger follow-up needs its own finite
plan. T7 was verified mounted, writable ExFAT, UUID
`7C9569C1-BC8F-3288-B3FD-8831A3F07FAA`, approximately 1.25 TiB free; preserve
40 GiB. Task-owned artifacts, if needed, go in
`/Volumes/T7/ntsd-2.4-artifacts/version-diff-20261017/`. X5 has only about
21 GiB free and is not selected for new large IO. Small reports/tools remain in
the repository. Baseline assets, old evidence/expected/masks/plans, archive
instructions and pending files are protected.

Allowed writes: this card, a concise CURRENT_WORK entry, a static distribution
comparison tool, and dated task evidence. Acceptance: archive member CRC reads,
SHA-256 identity, complete inventory accounting, explicit missing/opaque content,
raw data retention for registry correspondence, and evidence-qualified estimates.
No whole-game, runtime, Windows or device acceptance follows from this analysis.
Author review is not independent review; a separate reviewer is unavailable in
this turn. No new game contract is accepted here.

## Preserved preflight outcome

`preflight1`: `inspect_original.PE` parsed the 2.8.3.3 headers, then its ordinary
import-table walk failed with `ValueError: RVA outside file-backed sections:
9f38185e` at `PE.offset`, called by `PE.string` / `PE.imports`. Original code was
not executed. Preserve this as an unsupported static-parser boundary; do not
treat a DLL-name string scan as a valid import table. The inventory will retain
headers and the exact error while reporting the import walk as unavailable.

## Result: feasible, but a substantial version port

The existing native engine is a useful base: portable Swift runtime, native
window/input/audio hosts, rendering, filesystem services, transport adapters,
deterministic simulation and reference-comparison tools already exist. However,
the new distribution needs version-specific loaders, storage and gameplay
contracts. An asset swap would both reject real files and silently lose new
fields. None of the following accepts new engine behavior based on a manual.

### Measured distribution and registry differences

The complete static inventory is
[run1](../evidence/ntsd-2.4-to-2.8.3.3-static-20261017-run1.json).
The [validation record](../evidence/ntsd-2.4-to-2.8.3.3-static-20261017-validation1.json)
contains 41 successful static checks and 26 source facts with document paths
and line numbers. These are author checks; independent review remains open.

| Item | Clean 2.4 | Supplied 2.8.3.3 |
| --- | ---: | ---: |
| Regular files visible in distribution / outer ZIP | 1,595 | 112 |
| Registered objects, all types | 137 | 330 |
| Type 0 entries, including transformations, clones and helpers | 42 | 158 |
| Type 3 entries | 63 | 150 |
| Registered backgrounds | 17 | 24 |
| Registered object files available loose | 137 | 7 |
| Registered background files available loose | 17 | 0 |
| Main EXE file bytes | 31,715,328 | 87,261,184 |

The 330 objects include seven external custom Genma-related objects. The other
323 object paths and all 24 background paths are absent from the outer ZIP.
The much larger EXE and opaque PE layout suggest executable bundling, but the
contents and bundling method have **not** been recovered or verified. These
347 absent paths must not be classified as deleted game content or known empty
files. Likewise, the outer ZIP's smaller file count is not a smaller game.

Only two normalized paths are common to the two visible distributions:
`data/control.txt` and `data/data.txt`; both changed. The evidence contains
complete SHA-256 file manifests, both registries with original lines/order,
path partitions and ID correspondences. ID correspondence does not prove
equivalent content: paths and IDs can be reassigned. Examples:

| Registry entry | 2.4 | 2.8.3.3 |
| --- | --- | --- |
| Object ID 2 | `chars/naruto.dat` | `c/nar/nar.dat` |
| Object ID 11 | `chars/sasuke.dat` | `c/sasu/sasu.dat` |
| District | background ID 0, `bg/sys/District/bg.dat` | apparent counterpart ID 10, `b/Dis/b.dat` (inferred from path; file unavailable) |

The type-0 counts are **not selectable-character counts**. A byte-for-byte
asset reuse fraction, full built-in DAT semantic diff and executable function
diff cannot be calculated from the currently accessible files.

### Confirmed data requirements and documented engine changes

| Area | Evidence and status | Consequence for our engine |
| --- | --- | --- |
| Engine lineage | Bundled `2.8 full changelog.txt`, 2.8.3 section, explicitly describes changing from the Neora EXE to Darkfiren's custom EXE and lists replacement encodings. Documentation statement, not a binary equivalence result. | Re-establish changed contracts against this exact version; do not reuse 2.4 addresses or assume identical arithmetic/order. |
| Larger animation domain | Manual `frame/itr.txt` documents a frame limit of 998. Actual external Genma and clone files contain definitions up to 701, with 59 occurrences outside 0…399 between them. | `OriginalFrameLoader` enforces 0…399; `OriginalObjectLoader` builds 400 records of 0x178 bytes. The capacity and new record layout require version-specific work. Do not replace every `400`: the actor pool's 400 is a separate contract. |
| New inputs and object headers | Actual Genma data uses `hit_aj`, `hit_ad`, `hit_jd`, `hold_j`, `hold_d`, `hit_g`, walking/running frame lists, `<stats>` and `<menu_face>`. | Extend parser, owned state, command scheduling, locomotion and selection together; merely accepting tokens is insufficient. |
| Multiple spawns and more contacts | Manual `frame/opoint.txt` documents up to 20 opoints per frame; `frame/itr.txt` documents up to 100 itrs. Built-in use unknown. | Current opoint is a singleton; recover ordered multi-spawn/RNG/allocation behavior and contact storage before integration. |
| Changed combat semantics | Changelog 2.8.3/2.8.3.2 describes conversions for effects, MP drain/gain, kind 8, layer control, transformations and state 3007. Latest patch changes include ally filtering. | Revisit contact, projectile, resource, damage, frame-transition and AI consumers; map actual DAT use first. |
| Images and presentation | Actual external sheets/portraits use PNG. Changelog describes redesigned HUD/menus and animated selection; modding docs describe resource/menu/frame/minibar configuration. | Add portable image decoding and version-specific resource/UI loading; reuse host presentation facilities where contracts fit. Built-in UI layouts/assets remain unavailable. |
| Modes, stage, unlocks and persistence | Bundled docs describe system/mode/background-mode/stage configuration and saves; changelog includes stage progression/direction fixes, random selection and updated pause settings. | Extend application flow and version-separated user data; use shipped config to determine which optional features are required. |
| Timing and hitlag | Bundled hitlag-mode documentation describes selectable attacker/victim/block settings; system documentation describes configurable frame periods. Actual shipped config is unavailable. | Preserve exact tick/input/RNG behavior per version; host refresh rate is not the game's simulation rate. |
| Replays and networking | `tu mode.txt` documents 1TU `.mlfr` and 2TU `.lfr`; 2.8.3.2 changelog makes 2TU default with an offline/online switch. | Reuse socket/file services, then recover replay, checksum, TU/input and wire contracts. Same suffix does not establish 2.4 compatibility. |

All 137 baseline registered objects decoded for a lexical inventory using the
existing importer. All seven visible later-version objects also decode into
recognizable DAT with that decoder: 470 frame occurrences in total. This does
not prove the 2.8.3.3 executable's decoder, loader overflow behavior, defaults,
duplicate handling or numeric semantics. The lexical importer only inventories
its recognized fields/blocks. For example `itr.respond` is absent from the
baseline DAT inventory but already exists in the native parser: a new token in
data is not automatically a new engine rule.

The bundled changelog covers 2.8 through 2.8.3.3. It is not a complete 2.4→2.8
history, and the repeated Danzo entry in its new-character list is not corrected
or counted as an additional character. A final comparison must come from actual
content and original execution, not the completeness of release notes.

### Reuse and implementation route

Keep both versions available in one native codebase, with explicit version and
asset-package selection and separate settings/saves/replay identities. Preserve
the 2.4 profile, fixtures and regressions throughout. Share platform services and
primitives whose contracts actually agree; introduce a 2.8.3.3 loader/storage
and rules profile where they differ. The current source is closely tied to the
recovered 2.4 address/storage model, so this includes refactoring callers and
resource ownership, not just adding a version flag.

1. Obtain readable built-in DAT/image/audio/config files and a reference
   executable that can be inspected. A matching unpacked/modding distribution
   is the easiest route if available; otherwise identify the supplied bundle
   format in a separately bounded compatibility study. Pin exact provenance and
   establish correspondence rather than assuming a different download matches.
2. Inventory every registered object and arena, preserve repeated fields/frames,
   then enumerate **used** states, input fields, kinds, effects, capacities and
   configuration. This distinguishes the game's actual needs from optional
   features in the generic engine manual. It produces the real content diff.
3. Extend version-specific loading, image resources and storage. Recover whole
   caller contracts for changed input/combat/spawn behavior with the original
   2.8.3.3, using existing tools where applicable and new pins/expectations.
4. Bring up a native Naruto/Sasuke match, preferably on the corresponding
   District arena, and compare inputs, ordered state/RNG, damage, audio and
   presentation. This is the first vertical milestone, not acceptance of 330
   objects or the complete version.
5. Expand to the actual roster, forms, AI, stages, other modes, UI, unlocks,
   settings/saves, both input modes, replays and networking. Run 2.4 regressions
   and required platform/device/Windows comparisons. CrossOver can serve as a
   declared research environment; it remains absent from shipping runtime and
   does not count as actual Windows/device evidence.

### Preliminary effort estimate

These are **planning allowances**, in engineering/research hours, for one owner
working with the existing tooling and fidelity requirements. They are not
measured throughput, a confidence interval, calendar deadlines, API cost or an
estimate derived from executable bytes/LOC/old coverage percentages. No code
volume forecast is made, so the historical code-volume estimator was not run.

| Work package | Assumed hours |
| --- | ---: |
| Readable reference/content acquisition and complete semantic inventory | 8–24 |
| Version isolation, loader/storage changes, image/resource pipeline | 24–64 |
| Changed input, combat, spawns, movement/AI and whole-caller comparisons | 64–160 |
| Menus/HUD, selection, modes/stage, unlocks and persistence | 40–96 |
| TU modes, replay formats and networking | 24–64 |
| Integration, regressions and version/platform acceptance | 40–112 |
| **Full 2.8.3.3 incremental scope** | **200–520** |

The sum is about **25–65 eight-hour working days** of effort; waiting for
reference access, reviews or devices can increase elapsed time. The upper value
is not a cap: unreadable content or substantially different engine internals can
force a revised estimate. Finishing every outstanding 2.4 acceptance gate is not
included as a separate project in this incremental estimate; shared blockers
discovered during this work still have to be resolved.

A **first compared Naruto/Sasuke native VS match** has a separate preliminary
allowance of **40–100 hours after readable content/reference access**, covering
only its required subset of loader/resource/input/combat/UI work. It is included
in, not added to, the full-version estimate. It is not a claim that the other
characters or modes would work. Re-estimate both milestones after the 8–24-hour
discovery package; that is the largest current uncertainty reduction.

### Identity, verification and open gates

- ZIP SHA-256: `fca38bfe1391d969b9d29d1289c51bbf5270a384fa7da6d4a7c053da77c52b2d`.
- Main 2.8.3.3 EXE SHA-256: `5eda51440039099069d041e5bd13fde8be9fd8c7b20983985b1712a59719d86b`.
- 2.4 EXE SHA-256 was checked against the baseline pin. There are no LFS
  placeholders in the 1,595 inventoried baseline files.
- All 112 regular ZIP members were read with CRC verification. Inventory
  partitions account for every path. A separate direct token scan checks that
  all active registry lines and all visible later-version frame definitions
  were retained. All 1,595 baseline hashes and unrelated pending-file pins were
  checked after analysis; unchanged.
- Python compilation passed. No Native files, fixtures, expected results,
  baseline assets or old tools were changed. No game/installer/helper executable
  was launched; no new behavioral/regression/device acceptance is claimed.
- `preflight1` import error is retained above and in validation evidence.
  The final static inventory additionally preserves the unsupported resource
  walk: `ValueError: RVA outside file-backed sections: ac724`. It reports
  unavailable imports/resources explicitly instead of assigning empty known
  values. Main PE headers/section tables are readable; these errors and the
  87 MB file do not identify a particular packer or the executable's actual
  behavior. DLL-name strings are labelled as strings only.

The user's requested preliminary comparison/estimate is complete within this
static boundary. No 2.8.3.3 implementation or full asset/behavior diff has been
accepted. The next permitted task, if migration is commissioned, is the bounded
readable-content/reference acquisition in step 1; no unrelated full-port queue
or running producer was resumed for this assessment.
