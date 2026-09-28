# End of the District match in the app: replay save, summary, return

2026-09-28. Parent: [character AI](APPLICATION_CHARACTER_AI.md) (2c02e5b).
Rules: [WORKFLOW](WORKFLOW.md), [PROGRESS_RULES](PROGRESS_RULES.md). Written
while connecting (same session); the policies below were fixed before the
recorded runs.

**Consumer and criterion:** after KO the app completes the original match end
— replay recording, the Summary screen, the post-KO epilogue and the return
to the menus — on runtime providers, and a new match can be started.
**Proven blocker (parent card):** `Gameplay replay codec allocation` right
after KO. **Round:** 1. **Executor/reviewer:** Claude; independent review open.

## Finite changes and declared runtime policies

- Gameplay body providers in `OriginalMacRuntimeLoading.gameplay()`:
  replay codec buffer from the runtime heap (`reserve(OriginalReplayWriter.capacity)`);
  processor signature 0x600 (only family bits ≥ 0x600 matter to 4428b0; every
  x86 CPU Windows runs on reports family 6 or 0xf); `_wfsopen("recording\\…","wb",0x40)`
  succeeds for single-level `recording\` paths (the package ships that folder),
  other paths fail and are reported; writes and close are buffered and applied
  to the user overlay only after the Host batch commits; music resume is
  IMediaControl::Run through the runtime COM emulation.
- Caller formatter locals (root44c..5bf) declared unknown per body, as Core's
  provider test does; formatting must produce every byte it reads.
- Round continuations: `pausedRendering` goes to the gameplay session (which
  already implements it); `epilogue` gets a new Core composition
  `OriginalApplicationEpilogueSession` — no body, graphics unchanged, the
  accepted dispatcher return (41bc90's exit 422a95, see MATCH_ROUND and
  GAMEPLAY_RETURN).
- Catalog block backing (registry, background and stage records) is declared
  initialized zero in the runtime: after a match the AI reads the width of the
  "Random" background (index 100 → catalog+0x4d819f0), never written by the
  loader; the 81 MB block is fresh demand-zero pages on Windows. Verification
  paths keep undefined provenance (`allocationDefined` defaults to false).

## Checks

1. Existing Core tests for the changed shared files (catalog session,
   gameplay/provider suites) and the runtime loading suite.
2. App (release): scripted fights through KO, replay file in the overlay,
   Summary screen, epilogue and the next menu/match; captures.
EXE envelope not recalculated. Out of scope: GDI text (Summary numbers),
music output, other arenas, computer-player special moves.
