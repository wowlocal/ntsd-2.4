# Object input child 406ba0 for the runtime match

2026-09-28. Parent: [live District match](APPLICATION_RUNTIME_MATCH.md) (455afeb).
Rules: [WORKFLOW](WORKFLOW.md), [PROGRESS_RULES](PROGRESS_RULES.md). Written in
the same session as the port, before the evidence runs finished; limits below
were fixed before any comparison result.

**Consumer and criterion:** the app's cached cycle (`OriginalMacRuntimeLoading.runCycle`)
serves `objectInput` requests of `OriginalLocalInput` with a Native
implementation instead of stopping. **Proven blocker (parent card):** two
scripted fights stopped at object id 219 frame 51 (hit_Fa 5).
**Round:** 1. **Executor/reviewer:** Claude; independent review open.

## Static decode (no original code executed)

406ba0(World, slot), ret 4. hit_Fa = Frame+0x30 of the called Actor's current
frame. Dispatch: 11 → 14 fixed 406a20 spawns; 8 → clay-bird burst (Object
0xe1); 13 → Object 0xe4; 5 → Object 0xdb per living ally; 6/9 → 0xdc / 0xdd+r
fans; 7 → a copy of the own Object at frame 40, then steering; 10 → drift;
every other value → target keep/search (40704d; values 4..7 skip it), then
steering (407fcf..408910): cases 1, 3, 4 and a shared path for 2/4/7/12/14
with a fallback when the Object is dead or inactive.

Values used by the original DAT for non-character Objects: 1, 3, 4, 5, 7, 8,
10, 12, 14 (248 frames). 2, 6, 9, 11, 13 are unused and stay explicit Native
boundaries (`outsideVerifiedDomain`), as does any other positive value.
A target of −1 read by 4/7 (the EXE reads World+0x190 as an Actor pointer) is
also a boundary.

## Finite changes

- NTSDCore `OriginalObjectInput.apply(slot:state:observe:)`: x87 arithmetic
  through `OriginalExtended` at the match precision, RNG 417170 with its tag and
  range, constructor 4061d0 through `reconstructActor`, fld/fstp copies that
  quiet signaling NaNs. Unused values throw.
- NTSDMacPlatform: `runCycle` dispatch serves `objectInput`; `characterAI`
  keeps the diagnostic boundary.
- NTSDReferenceChecks `ObjectInputReference`, `NTSDCatalogCheck --object-input`,
  `OriginalObjectInputTests`.

## Checks and limits

1. `tools/oracle_object_input.py` (Unicorn): the verified first loading is
   reproduced byte for byte, then real 406ba0 is called directly for every
   loaded non-character frame with a recovered hit_Fa (≥3 cases per frame,
   ≥40 per value), declared seeded stimuli (activity, bindings to real
   characters/lying frames, teams, HP, positions, velocities, owner/target,
   free-slot pressure, RNG words). Main corpus CW027f (startup precision),
   control corpus CW037f over the control loading. The oracle asserts the
   allowed code ranges, callee-saved registers, ret 4, a balanced x87 stack,
   no reads of undefined World/Actor bytes and globals changed only in the RNG
   words.
2. Native comparison per case: RNG calls (tag, range, result), constructor
   slots, globals, World, changed Actors byte/mask, all other Actors unchanged.
3. Executed body blocks are reported; blocks reached only by unused values
   are expected to stay unexecuted.
4. App (release): scripted District fight past the earlier stop.
Each run ≤ 3600 s. Out of scope: character AI 4094b0, KO/result, text,
music, other arenas. EXE envelope not recalculated.
