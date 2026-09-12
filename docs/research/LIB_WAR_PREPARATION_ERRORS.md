# War preparation: retained resource-error evidence

All 29 capture2 scenarios are terminal. Their 37 new calls contain **28 normal
returns and nine source memory faults**. Read-only audit3 verifies the saved
record corpus; this is a source-evidence milestone, **not Native acceptance**.
No original execution or Native build/test occurred in this continuation.
Full preparation and the full-game goal remain open.

## Scope and immutable references

The [frozen plan](LIB_WAR_PREPARATION_ERRORS_PLAN.md) studies preparation when
an arena bitmap, graphics API, music operation or replay allocation fails, and
the next release of partially loaded arena owners in eight scenarios. It uses the pinned NTSD EXE
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`, lib.dll
`28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba`, VC80
`c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d`, original
DAT/BMP resources and accepted bound-preflight inputs.

The historical capture2 producer ran Unicorn 2.1.4, CW023f, C locale, explicit
flat 32-bit code/data/stack segments and a separate synthetic FS head. Linear
NULL stayed unmapped. Allocation/Win32/COM results were declared harness inputs.
Memory, allocation, API and instruction observations recover ordering and owner
lifetimes; they do not describe actual Windows/device/host heap behavior.
Next-Start99 bridges are controlled inputs, not intervening played fights.
EXE/DLL execution remains development tooling, outside the shipping runtime.

Each of 29 independent historical chains constructed a World and 400 Actors,
then reproduced ten accepted calls. Their 290 prefix comparisons overlap 20
distinct accepted prefix files; they are not 290 distinct startup states.
The producer compared complete canonical cases after the declared FS relocation
and complete constructor parents. The new audit checks saved proof references
and digests; it does not repeat those historical executions or independently
reconstruct fresh prefixes that were retained only as proof records.

## Recorded outcomes

| Scenarios | First Start | Declared next Start99 |
| --- | --- | --- |
| s00/s01 normal controls | Both return | Not requested |
| s02 first wrapper allocation NULL | Returns with four later wrappers live | Returns; all four remain live, no Release/free |
| s03 last wrapper allocation NULL | Returns with four earlier wrappers live | Four Release/free pairs, then NULL wrapper read at40c116 |
| s04/s05 first/last image missing | Return with a wrapper but no surface | NULL surface read at40c118; last-layer case first releases four preceding wrappers |
| s06/s07 first/last CreateSurface failure | Return with a wrapper but no surface | Same40c118 boundary and preceding-owner distinction |
| s08/s09 first/last SetColorKey failure | Return after releasing the failed surface and clearing its wrapper marker | Same40c118 boundary and preceding-owner distinction |
| s10 GetObject0, s11 GetSurfaceDesc-1 | Both return using retained private output backing | Not requested |
| s12–s19 GetDC/Restore/CreateDC/SelectObject/StretchBlt/ReleaseDC/DeleteDC/DeleteObject failures | All eight return | Not requested |
| s20 music create, s21 query0, s23 query2, s24 query3 | All four return | Not requested |
| s22 music query1 | NULL event-interface read at401cfe after three queries | No continuation |
| s25 wide allocation NULL, s26 RenderFile failure, s27 conversion without writes | All three return | Not requested |
| s28 replay calloc NULL | Frees/clears old recording, records calloc result0, then NULL write at43d2fd | No continuation |

The release helper tests only the first layer pointer. Thus s02's four live
owners must survive the next call; silently clearing them would lose an observed
normal-return behavior. By contrast, s03 releases the preceding four before
reaching its missing fifth wrapper. Retained dead-owner records remain evidence.
The nine source faults are preserved with their original sidecars, partial
effects, invalid-access observations and failed write-hook attempts.

## Audit and preservation

The unchanged `tools/verify_war_preparation_errors.py` passes all 29 reports and
37 calls in112.291s. It checks1,894 checkpoints /2,036,730 records /
7,971,924,220 record bytes and masks,3,611,059 stores,829,068 instruction reads,
11,080 API reads and33,060 helper returns. All1,451 distinct blobs /
80,575,112 decoded bytes verify. There are3,408 observed instruction starts;
this union is not all branch outcomes or a re-executed instruction sequence.

The auditor reconstructs records from before-state, declared allocations and
saved stores, compares all saved reads/checkpoints/after-state, and checks
declared failing API results and terminal outcomes. Allocation/free events agree
with recorded checkpoint/after live flags. Unknown masks remain unknown.
It checks EXE bytes with declared installation patches, CRT bytes from the
pinned PE, and lib instructions against captured storage inherited through the
accepted parent join. It does not independently derive installed lib bytes,
every API model, full FPU state or fault address formation anew.

The separate `tools/verify_war_preparation_error_inventory.py` requires the exact
29 scenario identities /37 calls, terminal job/config/input provenance,290
prefix-proof sidecars,37 cross-call live-owner joins and nine failure sidecars.
Inventory2 also compares all6,516 sidecar blob entries with the blobs already
verified by audit3. Inventory1 and its producer remain unchanged; the added
comparison addresses the independent reviewer's identified verification gap.
Read-only review of both the audit and Native contracts was performed by the
separate `war_contract_review` agent. Review establishes the stated boundaries;
it is not a Native comparator result.

Machine-readable pins, commands, outcomes and verification references are in
[lib-war-preparation-errors.json](../evidence/lib-war-preparation-errors.json).
Raw calls total1,171,470,808 bytes. Canonical local evidence is under
`build/research/lib-war-preparation/war-errors-completion-20260912/` on task-owned
X5. Its195,387,246-byte source archive preserves623 members /1,698,034,920 raw
bytes, each independently reread and hash-checked; it is not a Native fixture
package or a bundled Native test. All325 accepted fixtures and the31 initially
pending files are protected by byte checks. Nine of those pending files belong
to this study and are committed unchanged;22 unrelated files remain pending.

## Historical failures and the interrupted turn

The first producer inherited a mapped linear zero page for its synthetic FS
head. Its replay NULL writes therefore reached a later fault, not the intended
unmapped-NULL boundary. Three old terminal captures remain separate. The first
FS correction then failed on the initial stack push because flat stack/code/data
segments were not explicitly set. That failed capture and both environment
probe versions are retained. The [FS](LIB_WAR_PREPARATION_ERRORS_FS.md) and
[FS/stack](LIB_WAR_PREPARATION_ERRORS_FS_STACK.md) plans document the corrections.
Frozen plans/producers keep their historical instructions; they are not a request
to rerun any completed capture.

The original Codex turn ended with `cyber_policy` at2026-09-12T00:30:32.397Z.
Some already-running capture jobs completed after that time. Their terminal
records, not the model response, determine their execution status. The
[incident register](../evidence/codex-safety-incidents-2026-09-12.json) preserves
the error and session/turn identifiers. Its exact triggering output is unknown.
This continuation read saved data and retained the incident; no model change,
blocked-operation retry or resolution of that incident is claimed.

## Open Native contracts and next work

1. `OriginalBackgroundSurfaceLayers.loadLayersWithSurface` requires a non-null
   wrapper. It must represent ordinary NULL allocation without creating an
   owner, while retaining s02's later four live wrappers across the next Start.
   s02's two returns and s03's first return are not source faults.
2. The War graphics adapter assumes every allocation request produces a wrapper
   and surface. Request ordinals, actual owner identities, missing surfaces,
   release history and defined masks need separate faithful comparisons.
3. s10/s11 need owned provenance for retained private dimensions. Saved s10
   requests show0/0 surface dimensions; s11 uses0/0x370000d0 destination sizes.
   These observations do not authorize importing source stack bytes, expected
   dimensions or a coincidentally equal token into Native.
4. The preparation music adapter currently supplies successful wide allocation
   and conversion. It needs the declared s25/s27 stimuli. Other returned
   graphics/music paths also require whole-War comparison, even where shared
   helpers already contain the corresponding rules.
5. Nine source faults need explicit Native rejection with whole coupled rollback;
   that rejection must stay separate from successful source/native matches.
   Existing guards alone do not establish those new War rollback comparisons.

The next bounded independent task can implement and compare the owned nullable
bitmap allocation contract using exactly s02/call-00, s02/call-01 and
s03/call-00, all returned. The faulted s03/call-01 remains separate. It must preserve
the accepted256-call matrix and22-call preflight and run affected shared-resource
regressions. Missing private provenance remains a separate open dependency.
Do not launch another source capture to fill a format or adapter gap. New Native
comparison, lossless Native packaging and bundled tests remain distinct gates.
War gameplay43a860, own catalog/startup/outer loop/app, full matches, content,
network, Windows/device and clean-Mac verification also remain open.
