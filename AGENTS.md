# NTSD native macOS port

The user's requirement is a native macOS game without a browser engine,
CrossOver, or Wine at runtime, preserving the original Windows game's feel.

## Authoritative reference

- Use **only the original Windows NTSD distribution** as the behavioral reference.
- Baseline: `downloads/NTSD_2.4_2.0a_clean/NTSD 2.4_2.0a`.
- Baseline EXE SHA-256: `3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.
- The user rejected the previous JavaScript implementation. Do not copy its
  behavior, or use F.LF/another LF2 reimplementation as a source of engine rules.
- Never modify the baseline assets to accommodate an incomplete new engine.

## Fidelity and evidence

- Recover behavior from this EXE and/or observations of this EXE running on Windows.
- Record the EXE hash and instruction addresses or a reproducible reference
  capture for each recovered rule. Distinguish a static observation, an inference,
  and behavior verified by differential tests.
- Do not substitute guessed physics, combo timing, damage, AI, randomness, or
  standard game-engine physics. Unrecovered behavior remains explicitly incomplete.
- Preserve raw numeric literals, repeated frame definitions, and auxiliary hitboxes.
  Original parser behavior (including overflow and repeated fields) is part of compatibility.
- A native resource inspector is development tooling, not a playable port.
- Keep reference/test tooling separate from the shipping runtime. No Windows EXE,
  JavaScript engine, or emulation/compatibility layer in the final native game.

## Current implementation

`native/` contains Swift/AppKit/SpriteKit Naruto/Sasuke practice with snake and
Chidori needles, the
earlier movement slice (`--movement`) and a resource inspector (`--inspect`).
Read `docs/MOVEMENT.md`, `docs/COMBAT.md` and `docs/PROJECTILES.md` before
extending gameplay. The original
functions match the retained movement and bounded melee corpora; see evidence
JSON for counts/hashes. Full-match behavior, other techniques/projectiles, regeneration and AI remain
incomplete. Unsupported combat ticks roll back completely. Sprite drawing
precedes frame scheduling and post-scheduler recovery in the original. Practice
RNG comes from the supplied replay; do not substitute host randomness.
See `PLAN.md` and `docs/ORIGINAL_ENGINE.md` for further evidence.

`NTSDCore/OriginalFrameLoader.swift` implements the recovered frame-section
loader. Read `docs/FRAME_LOADER.md` before extending it. Do not silently coerce
unsupported numeric overflow or treat the isolated frame tests as whole-file
equivalence. The inspector still shows raw occurrences, not normalized records.
