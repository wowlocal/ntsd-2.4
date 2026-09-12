# NTSD native macOS port

Build a standalone native macOS game preserving the original Windows game's
behavior, presentation, input, sound and feel. No browser engine, Windows EXE,
CrossOver, Wine or emulation in the shipping runtime. The first complete
Naruto/Sasuke match on District is an intermediate milestone, not the full goal.

## Start and scope

Read these before choosing or extending a study:

1. [WORKFLOW](docs/research/WORKFLOW.md): bounded evidence, review, acceptance,
   process ownership and refusal handling. Applies to new and unfinished work.
2. [CURRENT_WORK](docs/research/CURRENT_WORK.md): current accepted frontier,
   unaccepted work, known incidents and the first permissible next task.
3. The relevant sections of [RESEARCH_MAP](docs/RESEARCH_MAP.md), the chosen
   study and its direct dependencies. Use [TASK_TEMPLATE](docs/research/TASK_TEMPLATE.md).
4. Search [AGENTS_HISTORY_2026-09-12.md](AGENTS_HISTORY_2026-09-12.md) for the study,
   source/native filenames and dependencies; read the matching constraints before
   changing them. Detailed historical preservation/ownership/numeric rules remain
   binding. Resolve older NEXT/status prose using newer verified study evidence,
   not by silently discarding a conflict.

The archive is the exact previous 4,954-line AGENTS.md (SHA-256
`1f124556e757a1f1efe7dabbc19df76bc482ca9a316df2295eb86beeae1f5dff`). Keep it immutable.
Its relative links still resolve from the repository root. It is a record of
instructions and dated states, not an instruction to restart historical work.
Keep this file concise; put new detailed results in study documents and update
CURRENT_WORK with links. Do not paste the whole archive into every task.

## Authoritative reference

- Use only the original Windows NTSD distribution as the behavioral reference.
- Baseline: `downloads/NTSD_2.4_2.0a_clean/NTSD 2.4_2.0a`.
- Baseline EXE SHA-256: `3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.
- The user rejected the previous JavaScript implementation. Do not copy its
  behavior or use F.LF/another LF2 reimplementation as a source of engine rules.
- Never modify baseline assets to accommodate an incomplete new engine.
- Full scope includes original content, modes, AI, menus, settings, saves,
  replays, networking and game-reachable unusual states and original errors.
  Exhaustive behavior under arbitrary artificial memory corruption is not a
  completion criterion. This does not exclude necessary ordinary resource-error
  contracts or justify dropping an already required compatibility dependency.

## Fidelity and evidence

- Recover rules from the pinned EXE/DLL and reproducible original execution.
  Record hashes, instruction addresses, input provenance and declared boundaries.
  Distinguish static evidence, inference, controlled differential comparison and
  actual Windows/device observations. No unobserved storage becomes known zero.
- Do not guess physics, combo timing, damage, AI, randomness or standard engine
  behavior. Preserve raw numeric literals, repeated fields/frames, auxiliary
  hitboxes, parser overflow, signedness, intermediate stores and operation order.
- Build common DAT-driven handlers; retain ID-specific exceptions established by
  the EXE. Prototype restrictions are not original game rules.
- Keep reference bytes, expected results, masks, frozen producers/plans and
  historical failures immutable. A correction gets separately identified evidence;
  never change an old expected value or exclude a mismatch to accept a candidate.
- Native state must own its storage, resource identities, lifetimes and rollback.
  Do not import an expected after-state, unknown backing or private source ABI.
  Preserve aliases and live state across calls under their recovered contracts.
- Review contract completeness independently for new rules, storage models,
  numeric semantics and comparator changes. A separate read-only reviewer may be
  delegated when the session permits agents; one owner edits each path. If none
  is available, record the review gap and continue permitted implementation/checks;
  do not label author self-review independent. Models do not replace the comparator.
- A returned source case, source memory fault, unsupported boundary, harness error,
  Native mismatch, missing evidence and safety refusal have distinct outcomes.
  Native rejection with rollback is not a successful match to a source fault.
- Retain required regressions and whole-caller comparisons. Isolated function
  tests and instruction counts do not establish a whole tick, match or game.
- A resource inspector, linked binary or native window alone is not a playable,
  validated port. Test window/input/audio and Windows comparison as applicable;
  unavailable environments leave those checks open. Keep tooling out of runtime.

## Low-level compatibility research

Reverse engineering supports game compatibility and preservation. Targets are
only the declared original game artifacts, dependencies and controlled reference
harnesses. It does not authorize actions against unrelated systems.

Disassembly and execution hooks recover control flow and update order. Memory,
stack, register and allocation observations establish provenance, aliasing and
lifetimes. FPU/CRT/compression/file-stream comparisons recover numerical and
observable IO behavior. Failure cases establish compatibility boundaries and
Native rollback; reproducing a fault does not require an exploit or bypass.

For each new or extended study and relevant tool operation state: the game
behavior being recovered; reference artifacts and environment; actual operation
and why it is needed; observable comparison or failure boundary. Distinguish
synthetic mappings/API responses from actual Windows, host or device behavior.
Describe memory faults and protection checks accurately; do not hide evidence
or rename operations to seek a different safety decision. Use existing evidence
first and limit new experiments to questions required by the declared contract.

## Refusals and process state

If `cyber_policy` or another safety refusal occurs, preserve the exact error,
timestamp/time zone, session/turn/request identifiers when available, model,
relevant operation and log references. If the rejected output is unavailable,
record that the exact trigger/action is unknown; adjacency to a tool call is
not proof of causality. Existing incidents are in
[the refusal register](docs/evidence/codex-safety-incidents-2026-09-12.json).

Stop automatic retries and new queued executions of the affected operation.
Do not reroute it through another model, provider, tool, new session, renamed
command or fragmented request to bypass the refusal. A new goal or this
methodology does not clear an incident. Keep its dependency open and continue
independent permitted work; do not claim that such work resolves the blocked path.
Follow WORKFLOW for review and process handling. Project context and legitimate
purpose do not override safeguards or guarantee fewer false positives.

Revalidate PID, process start time, command, cwd and job record before acting.
A model refusal, compaction or quiet log does not mean a capture/build stopped.
Never restart a completed capture or a live job for silence. Preserve terminal
outputs and partial/failure records; do not modify pinned running producers.

## Working files, storage and delivery

- Preserve unrelated pending files and pin the actual working inputs, including
  relevant uncommitted changes. A HEAD-only worktree may omit required code.
- Reuse existing study manifests, job files, capture/audit tools and comparators.
  A packet/reviewer/acceptance checklist is not a new execution framework.
- Use task-owned X5 storage for new large research/builds after verifying mount,
  APFS UUID `3A4F5FA6-DC86-4C6E-87E2-EAC2C2D72548`, free space and the original
  reserve. Do not lower reserves, delete evidence or restart sources to get space.
  If unavailable, pause dependent IO and continue independent permitted work.
  Shipping/runtime fixtures remain regular, self-contained local files.
- Treat source/audit publication, Native tests, package byte verification and
  archive verification as separate gates. Process exit 0 alone is not acceptance.
- Do not install ReAgent or change model/safety settings as a side effect of
  adopting its workflow ideas. Routine authorized read-only actions and reversible
  fixes do not require a new permission exchange.
- For code-volume estimates read the archive's Progress estimates section and
  `docs/estimates/2026-09-08-code-progress.md`; use `tools/estimate_port_progress.py`
  with an explicit revision/new dated output. Range area is not completion or
  branch coverage; preserve historical reports and disclose planning assumptions.

## Implementation entry points

`native/` contains Swift/AppKit/SpriteKit practice and recovered shared handlers.
Before gameplay changes read `docs/MOVEMENT.md`, `docs/COMBAT.md` and
`docs/PROJECTILES.md`, plus the current study. Read `docs/FRAME_LOADER.md` before
extending the frame loader. Practice uses replay-supplied RNG; unsupported combat
ticks roll back. Actor allocation is 0x420; source harness spacing 0x500 is not a
native or Windows heap rule. Historical exclusions remain historical.

Use [PLAN](PLAN.md) for product scope, RESEARCH_MAP for dependencies,
[ADDRESS_BOOK](docs/research/ADDRESS_BOOK.md) for address evidence, and CURRENT_WORK
for the current handoff. Report analysis, implementation and validation separately.
The complete game, native app integration and clean-Mac acceptance remain open
until their actual criteria pass. A ready-to-use next goal is in
[CONTINUE_GOAL](docs/CONTINUE_GOAL.md).
