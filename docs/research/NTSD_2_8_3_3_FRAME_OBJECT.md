# NTSD 2.8.3.3 D3: Frame/Object construction and continuous loading

2026-10-17. Parent implementation increment `875a1783`; M0's unchanged
baseline/app comparison jobs are still live. Independent source-identification
work starts while their acceptance remains open.

Mechanism/result: target-native owned Frame/Object records and the continuous
loader required by M1. First identify actual target constructor/parse entries,
their incoming allocation/caller and the next field reader. The known two
432-byte AI accesses are observations, not a complete layout. Actor `+0x368`
remains unchanged in those contexts; interpretation correction1 takes precedence.

Read before selection: FRAME_LOADER, OBJECT_LOADER, RAW_FRAME_STORAGE and
LOADED_CATALOG, the implementation plan and its correction, relevant archived
loader/definedness/alias constraints. The later raw/whole-catalog evidence
supersedes old isolated exclusions for dependency selection, not by rewriting
their fixtures. Use the saved code-diff and RNG evidence within their boundaries.

## First bounded operation: source identity, not original execution

Timebox ≤60 minutes, notes/new artifacts ≤8 MiB. Read the already validated
614400-byte target instruction section `0x401000..<0x497000` from the pinned
saved MDMP through `compare_ntsd_engine.RecordedMemory`; SHA-256
`9364fc67c15991140a8d379987c23e70bb33660f104a1d6e9203a056a1079eb0`.
Reuse prior dump validation; no recapture or whole-dump rehash. Compare only
needed constructor/loader contexts with the pinned 2.4 EXE using the configured
PE/Capstone readers. Limit initial inspected contexts to64KiB; any subsequent
range must have an actual call/branch/store dependency, remaining within notes
and the60-minute bound. Record exact addresses/bytes and distinguish a verified
entry, call site, inferred identity and unresolved dependency.

Questions: where does target initialize the records read with stride432; what
bytes/counts/allocations does it actually write; which real Object/parse parent
constructs and consumes them; which CRT/resource children are required? Old
`40bbf0`, `40ef70`, `4103f8` are search context only, not target entries.
No common address shift or replacement of400/376 constants is assumed.

No EXE/DLL execution, heap-wide search, decoded-content extraction, unpacking,
devirtualization, new capture or Windows interaction in this operation. The
packed-content refusal dependency remains open; do not read packed assets through
dump processing or reroute that operation. Missing instruction bytes/identity
remain an integration blocker. Synthetic backing never becomes Windows data.

Task storage: new `frame-object1` under the verified T7 version-diff directory,
same writable ExFAT UUID and ≥40GiB reserve. Author owns new study/evidence and
task-local notes only in this phase. Core/runtime/fixtures and live M0 inputs are
protected. Independent review is unassigned/open; static author checks do not
accept new storage/numeric/comparator contracts.

## Next finite execution and transfer gate

Before any new original execution, freeze ≤24 concrete cases from the plan:
4 fresh/repeated constructors over declared a5/5a backing;6 proven index
boundaries;4 repeated/continuous streams;4 changed fields/allocations;2 failures/
cross-call lifetimes;2 exact whole Objects (ID902 shuriken, then ID901 Genma);
2 connected parent/field-reader cases. Actual entries, decoder/CRT provenance,
children, masks, ordered events, allocation requests and per-case limits must be
known first. Unknown children block their cases, not independent construction.

Implement only proved contracts in native-owned records and connect the nearest
ready loading consumer. Retain aliases, old allocations, untouched bytes/masks,
partial writes and public rollback. No after-state initializer. Compare the
connected caller and affected2.4 raw-Frame/Object/catalog regressions without
changing expected/masks. Whole target startup/AI/gameplay remains unaccepted
until its actual dependencies and comparisons pass. Static similarity alone
does not authorize a target rule or constructor initializer.

## Static identity checkpoint and the first required transfer

Target entries/call sites, established from the saved instructions:

- Actual catalog allocation at `44c571` requests `0x69e00`; `44c5a9` invokes
  Object body `40e540`, after header constructor `44c6b0`.
- `44c6b0` clears `0x830` header bytes, stores ID/type/ordinal at
  `6f4/6f8/7ac`, owns a freshly allocated filename at `7a8`, then parses a file.
- `40e55f..40e56c` clears `Object+7f8 ..< Object+69e00` with `0x1a582`
  dword stores. It then writes other header defaults; the old per-Frame
  constructor does not supply this target initialization.
- `41122b` compares the signed index against1000; `41124c/411252` multiply by
  `0x1b0` and add `0x830`. Thus999 records fit the observed allocation, while
  index999 passes this check. The latter's subsequent backing/outcome is not
  established Windows data. Do not invent an allocated1000th record or call
  the static range inconsistency an observed Windows memory fault.
- `411259` tests an entire presence dword; duplicate handling differs from the
  old loader. New allocations/counts/points need their full connected contract.
- File operations are custom: open `4143e0`, dispatch `414490`, string `414520`,
  integer `414570`, EOF `414920`, close `414950`, in-place decoder `414970`.
  This is a concrete integration blocker for reusing the2.4 scanner/decoder.
  For example `%s` writes four zero terminator bytes, and numeric conversion
  is not the previously recovered VC80 scanf contract.

Detailed raw instruction contexts, hashes and caller searches are in
`frame-object1/`; no original execution has occurred in the static phase.

The first ready dependency is the changed **ordinary-file byte acquisition and
decode**. `414970..4149d9` transforms the entire raw DAT buffer in place, then
returns a logical cursor offset123; non-DAT suffixes return0 unchanged. This
does not perform the2.4 text-mode temporary-file/lookahead transformations.
The relevant37-byte key is a direct constant dependency, not captured content.
Verify the complete routine on exactly the9 packaged ordinary files and finite
synthetic suffix/extent controls before implementing it. Empty DAT and short
filename boundary reads remain distinct from returned cases.

Use the existing `compare_ntsd_engine` controlled-Unicorn adapter and its
stack/return conventions; add only this necessary case adapter because the
baseline frame/CRT harnesses initialize incompatible2.4 state. Freeze ≤24 cases,
code/key/file pins, synthetic mappings, per-call limits and output bounds before
execution. No packed path, original Windows process or file API is invoked.
Then transfer the byte owner into Core and the actual target content owner;
keep target startup stopped and the full FileOpen/Object caller comparison open.
The decoder comparison alone cannot accept construction, loading, AI or a game.

## Ordinary-buffer source run1 and Native candidate

Frozen `frame-object1/ordinary-dat-buffer-plan1.json`:20 cases (all9 ordinary
inputs plus11 synthetic suffix/extent controls), Unicorn2.1.4,2M instructions/
10s per call,15-minute/4MiB output bound. Complete108-byte routine SHA-256
`b30e1b40aeb621deedd56c1ac52bb226ccee4537bc60da7a48fe81dde03f2d6e`;
the37-byte source constant is `SiuHungIsAGoodBearBecauseHeIsVeryGood`.
Source result:18 complete returns,2 declared unsupported input reads (empty DAT
and filename shorter than3). Neither boundary is an observed Windows fault or
a successful match to Native rejection. All returned calls preserve the named
callee-saved registers, filename/key bytes and expected stack return. Buffer
writes are individually observed in ascending single-byte order.

Native candidate `NTSD2833FileBytes` owns its transformed buffer and the separate
cursor offset. It preserves the decoded header and offset123 for short nonempty
DATs, leaves non-DAT bytes untouched, and does no CRLF/CTRL-Z/lookahead conversion.
Its input interface covers nonnegative Int32 extents; larger/short file-API
responses remain an enclosing FileOpen dependency. Raw target bytes stay immutable.
The actual `OriginalRuntimeContentInputs.decodedTargetFile` consumer admits only
its pinned ordinary files and calls this target handler; no2.4 fallback is used.
Target startup still stops before Core. This connects a ready acquisition
dependency; it does not accept the full loader or whole source FileOpen caller.

The regular Native test fixture is the byte-exact source result (SHA-256
`f755a7d652b58de5cc3b480f371f275d48f2e7d1393c6da5851b88667072003d`),
never a runtime initializer. New checks compare all buffers/cursors and source
outcomes, raw ownership and the real content consumer. Compile these first;
retain the8 M0 focused tests and relevant existing DAT decoder regressions.
The baseline whole-startup/loading10-test gate passed on875a1783; its11-scenario
app job continues on the unchanged875a1783 binary. Do not restart it for new HEAD.

Native build uses task-owned `frame-object1/native1` on user-authorized T7,
≤2GiB logical/8GiB allocated,40GiB reserve. Reuse the configured SwiftPM recipes
and unchanged objects read-only; emit the updated Core module and compile the new
Core file, Runtime/Mac consumers and new test class. Preserve commands/pins/logs.
No previously compiled body is substituted for either new target implementation.
Independent storage/numeric/comparator review and whole FileOpen/Object remain
open; author checks are not independent review.

Native run1 is terminal:13 tests passed in15.786s. The3 new tests compare all18
returned source buffers/cursors, retain both non-returned source boundaries as
separate outcomes, and exercise all9 files through the actual content owner.
The8 M0 focused tests plus baseline translation/lookahead checks also pass on
the new linked candidate. Neither baseline decoder nor its consumers changed.
The test fixture is byte-identical to the source result. Compilation uses the
new Core object and Runtime/Mac objects, not an old implementation of the target
handler. The full2.4 app gate remains the separately pinned875a1783 result.

Next permitted task in this same D3 mechanism: freeze and run the actual
`40e540..412e7b` Object-body constructor/continuous caller with4 fresh/repeated
Frame-free synthetic streams first, then the declared index/repeat/field cases
as custom-scanner dependencies become ready. Use the actual `414490/414520/
414570/414920` scanner code, a declared owned file-buffer response only at open,
and real close/lifetime observation; do not supply the2.4 CRT answer. Pin every
required token constant and stop on any unknown read/helper. Compare the whole
Object bytes/masks and repeated owners to a new Native-owned target storage,
then connect its Frame reads. No unknown PNG/packed child is fabricated; real
ID902/901 whole-file cases retain their actual resource gates.
