# Owned first front-menu return

Status: accepted within two owned pristine first-menu returns, 2026-09-12;
implementation, comparison and independent review passed. Published
[evidence](../evidence/l2df-front-screen-session.json) binds the scope and inputs.
The pre-execution card is
preserved in both build input snapshots and `front-screen-plan-01.md`.
The next executable transition is `FRONT_SETTINGS_READY` → `FIRST_MENU_RETURN`
in the existing native owner. It completes the first pristine early-menu caller
through its retained actual `ret 4` witness. It does not establish a displayed
menu, an application/DLL join, catalog loading or a gameplay tick.

## Basis, ownership and limits

Follow [WORKFLOW](WORKFLOW.md), [CURRENT_WORK](CURRENT_WORK.md), the accepted
[loaded session](L2DF_LOADED_SESSION.md), [front-screen prelude](FRONT_SCREEN_PRELUDE.md),
[body](FRONT_SCREEN_BODY.md) and [completion](FRONT_MENU_COMPLETION.md).
Relevant preservation constraints are in the immutable history at lines3773–3798,
3890–3917,3983–4014 and4087–4105. Existing
[safety incidents](../evidence/codex-safety-incidents-2026-09-12.json) remain open.
There is no original EXE/DLL execution, new capture, emulation or affected-operation
retry in this task. We read retained evidence and execute only our native wrapper
and accepted Swift handlers.

Worktree baseline is `c7371e8671069803f46b7533cd0c12647676811a`; its native wrapper
is the accepted `9f2fc2c` version. Core/codec inputs remain immutable main
`ab0db06c6f0a6162f1935a1badbfc2a750822096`, individually byte/Git-blob checked.
The authoritative EXE SHA-256 is
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.
Its bytes are not shipped or executed. Resource inputs are the accepted exported
pack under `loaded-session-20260912/resources-01/resources`, manifest SHA
`49b323e944d0cef672eae2d7b45d36c759c73c30b060d5faa34422c0813a144a`.

Executor: `/root/l2df_prototype`; independent read-only reviewer:
`/root/l2df_reference_review`; root owns final artifact audit and commits.
Editable paths: this card and `prototypes/l2df/native_bridge/**`, except root-owned
`prepare_resources.py`. Accepted cards/evidence, main, fixtures, old apps/builds,
the resource pack and unrelated pending files are protected. Freeze actual code,
test producers, comparator and this plan before pre-execution review.

Use one new isolated build, at most300 seconds/2 GiB, and one LÖVE LuaJIT FFI run,
at most90 seconds. Reuse the existing build/job/package-audit tools with unique
`front-screen-01` labels under `build/l2df-prototype/loaded-session-20260912/`.
Verify the X5 mount/UUID `3A4F5FA6-DC86-4C6E-87E2-EAC2C2D72548` and preserve6 GiB.
Pin actual inputs and commands before execution; record PID/start/cwd, outputs,
exit/time and versions. Revalidate process identity before any action. Never
restart a completed run for silence or reporting. Preserve a new failure before
diagnosis; at most three repair rounds precede contract reassessment. No source
retry is part of repair. Missing provenance, harness error, Native mismatch,
unsupported boundary and safety refusal remain distinct outcomes.

## Two finite composed cases

Use only the first natural parent trajectory of these immutable retained files
in main `native/Tests/NTSDCoreTests/Fixtures/`:

| Fixture | Bytes | SHA-256 |
| --- | ---: | --- |
| original-menu-loading.json | 6557160 | c7aa707bb32d37837704b94d0afd98baac26f23f2f28b9d668f27fa2ca2a7e7f |
| original-menu-loading-control.json | 6570704 | 54334dd243f5c24ee52e47d386e07a214bc76dff209c30c1d954276ead7b6efd |

Their nested completion→alternate→body→panel→prefix→settings/front parents supply
the already observed complete first return. These are retained controlled D
comparisons, not new Windows/device observations. Each case begins with a fresh
owned boot/front/settings session under the accepted A5/ascending or ramp/reverse
allocation profile; no expected state, private stack or source pointer is loaded.

| Phase | Expected continuation | Ordered event counts, A5 / ramp |
| --- | --- | ---: |
| front/settings regression | FRONT_SETTINGS_READY | 6892 front +63 settings / same |
| first prefix | critical | 17 /24 |
| panel update | ready | 2 /2 |
| pristine body | alternateDispatch | 153 /153 |
| alternate | mainMenu | 0 /0 |
| main menu | present | 11 /11 |
| completion, including main events | semantic caller return | 20 /27 |

The unchanged full lower-level corpora retain their earlier acceptance; this new
owner claims precisely these two composed natural returns. Whole119-call menus,
World1/World2, hover/highlight/click, worker execution, live network/files, DLL
text/application dispatch and catalog loading are outside this finite check.

## Initialization and actual consumer sequence

Preserve the exact earlier boot/settings exports before adding platform bindings.
Then write five declared typed platform inputs: `455608`, `44eecc`, `453e0c` and
`455634` receive surface/device token `28002020`; `458348` receives profile1 or3.
The original adapters introduce these before resources
(`oracle_front_screen_prelude.py:26–28`, `oracle_menu_loading.py:30–34`). Independent
read-only comparison established that precisely this overlay relates both parent
globals, all53 settings globals checkpoints and final globals; scratch, World,
front records and other events already match. This justifies the late adapter
for these two trajectories without changing the prior settings contract.

Continue directly at the accepted post-settings `42709b` boundary:

1. `OriginalFrontScreenPrelude.advance` (lines56–107), with its real background
   constructor and bitmap drawing children, retaining typed `.sleep` at42711b.
2. `OriginalMenuPanelUpdate.run` (line11), using owned globals and live resource
   lookup. Natural status0 consumes no content/writer/worker input; an undeclared
   callback rejects the staged call rather than returning synthetic success.
3. `OriginalFrontScreenBody.advance` (lines46–51), the pristine handler. Its
   `advanceOwnStartup` helper selects the DLL-enabled path and is not this caller.
4. Capture the selector produced by the body immediately upon alternateDispatch,
   before another callback, then call `OriginalFrontScreenAlternate.advance`.
5. `OriginalMainMenu.run` (line70), followed by the real
   `OriginalMenuPresentation.apply` (line137), selecting tail/epilogue from the
   actual main result. Persist every owner mutation and observed request.

Do not use `OriginalFrontMenuLoop.run` for this first continuation: lines25–29
invoke initialization again and would repeat the existing resource/prologue phase
toggle. A future whole outer call may use that runner after this first return.
`FrontMenuCompletionReference.swift:163–169` verifies retained PC/SP/register/SEH
return witnesses, but has no separate source World EAX. C ABI success is a
transport status; do not invent `worldResult=0` or borrow application EAX rules.

## Runtime inputs and private read provenance

The existing named profiles explicitly remain developer/headless platform
contracts. Original constructors and raw DIB metadata produce bitmap records;
platform method replies are declared inputs, not recovered macOS device behavior.
The runtime has no expected-state reader. A build-only projection may retain the
selected parent input values as a typed platform table; exclude case labels,
snapshots, expected events, selector and owner-derived targets. Pin that table
against the selected input fields before packaging it as data.

The ABI takes an explicit UInt32 millisecond input. Both retained first prefixes
use0. `OriginalMenuBackground.load` selects unsigned `milliseconds %13 +1` only
when `4511ac==0`; a cached owner skips timer/format/allocation, with no RNG draw.
The resource provider looks up all13 original MENU_BACK keys in the existing
manifest on demand, verifies and owns the actually requested DIB, constructs the
next profile allocation, and retains its identity. It does not change the earlier
boot inventory. The two selected cases request MENU_BACK1 (809×547); other
milliseconds are not claimed as whole-case matches. Never freeze a live
clock to avoid a later loading-progress boundary.

Declared first-prefix replies are draw target28002020, thread handle12345678,
thread IDabcd, last error5, fill result0 and draw results[0]. Background surface
is28006400 and ColorKey result0. Body replies are DC result0/DC12345678, method
result0, draws[0], shell result33. Alternate retains its own selector/target and
declared timer values[100,100,100] (none consumed naturally). Main/presentation
responses come from the selected declared inputs; draw results[0,1], audio
volume−1234 and method/query/get/set/post/DC result0 remain explicit. Natural
network callbacks are not invoked. Fresh owned CRT state uses the accepted
constructor; its state and actual consumption are compared, not replenished.

Fill scratch is100 own zero/unknown bytes. `OriginalSurfaceFilling.request`
(lines10–14) defines only size DWORD+0 and color DWORD+50: exact8-byte known mask.
Compare those source-written bytes and every semantic fill field; require the
other92 native bytes to remain zero/false. The old source private fill backing
stays immutable and is outside this explicitly projected byte equality. This
uses the accepted own-fill rule in `OriginalApplicationFrontScreenTests:53–64`,
without claiming its different application caller.

Body scratch is192 own zero/unknown bytes plus an explicitly owned target DWORD
at+20. Source writes define92 bytes in the natural body; the final native mask
must equal source write mask OR +20..<24 (96 known bytes). All those bytes match
source; all remaining96 bytes must be zero/false. This follows the own-storage
projection in `OriginalApplicationScreenBodyTests:89–97`, not its DLL execution.

Mask projection alone is insufficient: audit pristine raw reads at
`OriginalFrontScreenBody.swift:83–90,129`. Literal copies at79–81/137 produce
28/31/29 bytes including NUL at+48/+84/+64 before decode and text; target+20 has
the owned producer. Independently replay ordered `writeLocal` events into a
second own record. Check all decoded/string operands and NUL terminators are
known, text matches that record, and every draw target has known owned provenance.
Require the final record to equal both this reconstruction and the source mask
projection. Undeclared/unknown reads reject the transaction; do not silently use
the native zero backing as a value. Hover/highlight extensions need their own
read-provenance review before acceptance.

## Persistent ABI owner, observations and rollback

Add `ntsd_bridge_continue_front_screen(handle, uint32_t milliseconds)`, available
only in FRONT_SETTINGS_READY; successful semantic completion commits one revision
and lifecycle4 FIRST_MENU_RETURN. Add capability4 to the existing1|2 bits, without
a gameplay bit or tick function. Existing Actor and front/settings APIs remain.
The operation runs the whole sequence on a staged copy, including all five
bindings, background allocation, scratch, globals, World, CRT, live/dead resource
records, typed retained operation and effect queue. Failure restores all of them.

Use `OriginalMenuPresentationMemory` as the live raw-record/resource owner and
derive canonical bitmap views only at the drawing boundary. Keep old observations
as history, not competing mutable aliases. Store semantic bitmap owner/resource
identity separately from target role: equal synthetic raw surface tokens do not
establish image/backbuffer aliasing. Preserve all ramp-dependent additional or
inverted/out-of-bounds requests and masks for comparison; never filter them to
make a future window look better. Native export includes complete phase state,
ordered raw semantic events and typed owner associations for future presentation.

Buffer external requests through commit. No graphics/audio/network/thread/file
or shell side effect executes during this headless call. A developer late-failure
trial runs the actual complete sequence then rejects before commit; compare the
entire pre/post session, then perform the valid continuation and compare it with
an independent fresh owner. Wrong lifecycle/handle and second return calls reject
without mutation. Source fault, boundary and Native rollback are separate results.

## Acceptance gates and immediate continuation

The external comparator retains expected data outside runtime. Compare exact
typed event order, globals/World bytes+masks, every live/dead bitmap allocation,
resource bindings, CRT/replay state, each phase and final return; apply only the
two documented private-storage projections above. Assert complete sets/counts and
boolean/numeric JSON types. Old two-profile boot/front/settings comparison remains
byte/mask exact, including63 events and53 source-observed globals/scratch pairs;
retain the full Actor suite. Verify rollback, ownership and subsequent calls.

Pin sources, recipes, resources, fixture inputs and immutable expected files;
snapshot the exact comparator and test program. Independently review code and
comparator before the build/FFI run. Audit the exact compiled input set, exports,
library identity and post-run input preservation separately from exit0. Publish
actual counts, errors, timing and SHA only after checks, preserving all old jobs.
No claim of pixels, physical input, audible output or clean-Mac acceptance follows.

The next composed dependency after this accepted return is the existing repeated
outer-menu consumer leading to World2, then real catalog loading in the same
owner. Existing catalog resource mapping is input evidence only. This card does
not implement those calls or declare the complete game ready.

## Implementation, corrections and retained result

`LoadedFrontScreen.swift` implements the direct continuation in the existing
owner; `LoadedSession.swift` commits its state only after completion. ABI1 adds
capability4 and two symbols: the actual continuation and a developer late-failure
trial. The successful lifecycle is2→3→4 with revision0→1→2; no tick or source EAX
is invented. Owned resource records retain raw surface words and known masks;
draw views are canonical only at the shared drawing boundary. An immutable draw
view spans the first body/completion, whose declared path does not allocate or
release; an unexpected release rejects. Future outer calls require a live-owner
review before reusing that bounded callback contract.

The request-time provider verifies the unchanged create-time manifest digest,
contained regular-file path, DIB SHA/extent/dimensions and the selected key among
all13 MENU_BACK resources. It copies only requested bytes and leaves the earlier
23-DIB boot inventory unchanged. The owner retains the extra DIB and its resource
identity after the generated test copy is removed. No original pack is modified.

Independent pre-execution review covered code, input provenance, both private
storage projections, complete typed comparison and package/input gates. Before
execution, root found synthesized `panelWord:nil` encoding would omit the explicit
null required by the declared input export. A custom encoder corrected that
observation field; prior bytes and the recursive null audit are preserved in
`front-screen-prebuild-01/`. It was not a Native execution failure.

Build `front-screen-01` ended1 after83.6556 s (PID20791, start13:58:15 Moscow).
Swift inferred the nested presentation dictionary as `[String:UInt32]` and
rejected the original signed audio volume−1234. `compile-diagnosis.json`, the
exact compiler log, plan and all199 frozen copies remain unchanged. Independent
review approved only explicit heterogeneous dictionary/Int32 typing and the
named observer argument; no Core rule, input value or expected result changed.

The separate repair `front-screen-02` ended0 after85.9358 s (PID21527,
start14:01:40 Moscow), using95,970,235 bytes. Its arm64 dylib is6,822,664 bytes,
SHA `0c0f5a49b82b922386600602ecca230233c6a0e586e6bc021bf16e754fdb1064`.
All187 compiled source/manifest files match frozen inputs; the library has15
bridge symbols, no tick and Apple system/Swift dependencies. Local
`codesign --verify --strict` passed. Host macOS26.6.2/25G83, Swift6.3.3; this is
not universal/x86_64, notarized release or clean-Mac acceptance.

One Native LÖVE11.5/LuaJIT arm64 FFI run, `front-screen-02/ffi/ffi-01`, ended0 in
3.0183 s (PID21914, start14:03:28 Moscow), passing336 assertions. Both late-return
failures preserved the whole earlier state; valid continuation then matched an
independent fresh owner exactly. Wrong lifecycle/kind/stale handles rejected;
all owners were released. Only three generated input copies changed: control.txt
became the declared test string, LF2_CURSOR DIB was removed after create, and
MENU_BACK1 DIB was removed after its successful constructor request. Original
resources, other copies and all runtime/input snapshots remain pinned.

The first external comparator stopped on `prefix complete semantic events`.
`comparison-error.txt`, V1 and `schema-diagnosis.json` preserve that result. The
diagnosis found two typed JSON representation differences: synthesized
`OriginalBitmapBlit.effects:nil` is omitted, while the source spells null;
`OriginalMenuPanelUpdateEvent` has only kind/arguments, while the wrapper's common
event explicitly includes empty strings. This was an export-schema comparison
mismatch, not a source fault or an accepted whole Native match.

The separately retained `front_screen_reference_v2.py` decodes only these two
established type boundaries. Blit payload keys must be exact; omitted effects
maps to nil and still differs from every non-null source value. Only the panel
phase may remove an exactly empty array under exact source/Native key sets.
All other keys, types, numbers, events, bytes and masks remain exact. Fourteen
positive/negative controls cover non-null effects, required/extra fields,
boolean/numeric distinction, panel type/content, phase isolation and unchanged
input objects. Reviewer approved this decoder; V1, Native, Core and expected
bytes were not edited or rerun to obtain agreement.

One read-only `front-screen-02/comparison-01` ended0 in1.0050 s (PID24394,
start14:14:02 Moscow). Its36 pins and the original87 FFI pins were checked before
and after comparison. Final `verification.json` SHA is
`dc6313a3a7e92db093184ecfbda5657e5abba874f385eadaba8979e668dc3c2c`.
V2 SHA is `59b2a916202a02f7480bf4cf40d1842381d44cfb270bef097a5ca88034a06716`.
Both first returns passed202 record comparisons each:1,740,888 record bytes and
the same number of mask bytes, all25 owners, platform inputs, draw associations,
globals/World/CRT/replay, complete phase events and110 ordered local stores.
The local audit checks24 literal stores, the y store,85 numeric decode stores,
three known strings/NULs and two known targets; final own body mask has96 known
bytes. Fill has exactly8 known bytes. Main's11-event checkpoint is included in
completion's20/27 events and is not an additional source call. Across both profiles
there are420 checkpoint event entries but398 unique continuation events; the
two11-event main checkpoints account for the duplication.

Both old settings trajectories remain byte-for-byte equal to the previous
accepted outputs:144 comparisons and2,949,520 record bytes plus the same mask
count per profile,6,892 front events,63 settings events and53 observed source
globals/scratch pairs. The full two Actor constructor records/masks also match.
The immutable FFI `result.json` still labels the shared report ACTOR_STORAGE;
actual loaded exports establish the additional2→3→4 lifecycle, not that label.

Root's independent artifact audit is `root-build-audit-02.json`, SHA
`9bc722ca5f63933350bc905162ed3abf66738266a34e1ebeeb2ecb791a586b68`:
184 main Git files,199 frozen copies,187 compiled inputs,87 FFI pins and15 exports.
The first root audit compared symlink versus resolved `otool` header spellings;
its error is preserved in `root-audit-error-01.json`. Both paths bind the same
library and all dependency lines match. Old session artifacts, Actor outputs,
libraries and the existing app remain unchanged.

Final independent review accepted the retained comparison and the separate
future-driver diff. Root's [build audit](../../build/l2df-prototype/loaded-session-20260912/front-screen-02/root-build-audit-02.json)
and [comparison audit](../../build/l2df-prototype/loaded-session-20260912/front-screen-02/root-comparison-audit-01.json)
bind actual artifacts, input snapshots and the preserved failures.

After terminal comparison, the future `check_ffi.py` was changed only to copy/
select V2 and include its14 controls. `future-driver-01.json` binds the original
frozen driver, new tool bytes and completed verification; no Native/FFI repeat
was made for that tool change. Completed commands and library location are in
the [bridge README](../../prototypes/l2df/native_bridge/README.md).

The full game remains open. Root selected the owned DLL-aware application first
menu-loop return as the next finite consumer, using its existing47+1 retained
cases and separate provenance plan. Repeated outer menus/World2/catalog remain
subsequent dependencies. None of those calls, or window/pixels/physical input/
audio/device behavior, is accepted by this pristine first-return comparison.
