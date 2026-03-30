# NTSD 2.4 Full Recreation in Godot 4 for macOS

## Context

Recreate NTSD 2.4 (Naruto The Setting Dawn 2.4) — a 2.5D fighting game mod of Little Fighter 2 — as a native Godot 4 game targeting macOS. The goal is an exact faithful reproduction of the original gameplay feel, mechanics, character roster, and game modes. Assets will be sourced from the LF2/NTSD modding community. The original game's `.dat` character data files can be imported directly.

## Key Insight: LF2 `.dat` Import Pipeline

The original NTSD 2.4 characters are defined in LF2 `.dat` files (lightly XOR-encrypted text) that specify every frame's sprite, timing, hitboxes, hurtboxes, knockback values, and state transitions. By building an importer, we can bring over all 20+ characters semi-automatically with exact original frame data — this is the fastest path to "exact experience."

Reference: [lf2_codec](https://github.com/azriel91/lf2_codec), [LF2 Data Changing docs](https://www.lf-empire.de/27-lfe-v10/data-changing)

---

## Project Structure

```
ntsd_godot/
├── project.godot
├── addons/godot_rollback_netcode/     # Snopek rollback addon
├── assets/
│   ├── sprites/characters/{name}/     # Per-character sprite sheets (PNG)
│   ├── sprites/projectiles/
│   ├── sprites/effects/
│   ├── audio/{sfx,bgm,voice}/
│   ├── fonts/
│   └── backgrounds/
├── data/
│   ├── characters/{name}.tres         # CharacterData resources
│   └── stages/{name}.tres
├── src/
│   ├── autoload/                      # Singletons: game_manager, input_manager, audio_manager, network_manager
│   ├── characters/
│   │   ├── fighter.gd / .tscn         # Base fighter (CharacterBody2D)
│   │   ├── fighter_animator.gd        # Custom frame driver (not AnimatedSprite2D)
│   │   ├── character_data.gd          # Resource: sprites, stats, frames, commands
│   │   ├── frame_data.gd             # Resource: per-frame sprite/hitbox/state data
│   │   ├── itr_data.gd              # Resource: hitbox interaction data
│   │   ├── hitbox_component.gd
│   │   ├── hurtbox_component.gd
│   │   ├── chakra_component.gd
│   │   └── states/                    # Node-based state machine
│   │       ├── state_machine.gd, state.gd (base)
│   │       ├── idle, walk, run, jump, fall, attack, special_attack, hell_move
│   │       ├── hit, knockdown, recovery, block, charge, grab, grabbed
│   ├── combat/
│   │   ├── combat_system.gd           # Hit detection, damage calc, combo tracking
│   │   ├── input_buffer.gd            # 60-frame ring buffer
│   │   ├── command_parser.gd          # D>J>A sequence detection for specials/hell moves
│   │   └── projectile.gd
│   ├── physics/
│   │   └── movement_2_5d.gd           # Custom deterministic: X(horizontal), Y(depth), Z(height)
│   ├── ai/
│   │   ├── ai_controller.gd           # Utility-based, replaces human input
│   │   └── ai_difficulty.gd           # Configurable reaction time, combo chance, aggression
│   ├── ui/
│   │   ├── hud/ (battle_hud, health_bar, chakra_bar)
│   │   ├── menus/ (main_menu, character_select, stage_select, pause, results)
│   ├── modes/
│   │   ├── mode_base.gd, vs_mode, stage_mode, tournament_mode, battle_mode
│   ├── stages/
│   │   ├── arena.gd/.tscn, arena_camera.gd
│   └── tools/
│       ├── lf2_dat_importer.gd        # Decrypt + parse .dat -> CharacterData .tres
│       └── sprite_sheet_slicer.gd
```

---

## Core Architecture Decisions

| Decision | Choice | Why |
|---|---|---|
| Physics | Custom deterministic (integer math, no Godot physics) | Required for rollback netcode; LF2 mechanics are too specific |
| State machine | Node-based (one GDScript per state) | Clean, debuggable, Godot 4 best practice |
| Animation | Custom frame driver reading frame_data | LF2 frames have conditional branching, variable wait, hit callbacks — too custom for AnimatedSprite2D |
| Character data | Custom Resources (.tres) imported from LF2 .dat | Inspector-editable + faithful import from originals |
| 2.5D depth | Fake Z-axis: screen_y = depth_y - height_z, Y-sort for draw order | Faithful to LF2 movement model |
| Netcode | Rollback via Snopek addon | Fighting games demand it |
| AI | Utility-based with difficulty params | Simple, effective for fighting games |

---

## 2.5D Movement System

LF2's coordinate system (critical to get right):
- **X**: horizontal position (maps directly to screen X)
- **Y**: depth on ground plane (forward/backward)
- **Z**: vertical height (jumping, knockback up)
- **Screen position**: `screen_x = X`, `screen_y = Y - Z`
- **Draw order**: higher Y = drawn in front
- **Shadow**: always drawn at `(X, Y)` on the ground
- **Gravity** pulls Z back to 0; landing when Z ≤ 0
- All values integer for determinism

---

## Combat System

- **Hitboxes** (itr) active only during attack frames, driven by frame data
- **Hurtboxes** (bdy) per-frame, also from data
- **Damage**: `injury * multiplier - defense`
- **Knockback**: `dvx`, `dvy` from itr data applied to victim
- **Combos**: counter increments until victim hits ground; floating combo counter UI
- **Blocking**: if defending + facing attacker → chip damage + pushback only
- **Chakra**: charged via Defend+Jump+Attack held; spent on specials/hell moves
- **Command input**: ring buffer + pattern matcher for `D>J>A`, `D>v>A>D>^>A` etc.

---

## Character Roster (import order)

**Batch 1** (core): Naruto, Sasuke, Sakura, Rock Lee, Neji, Kakashi
**Batch 2**: Tenten, Shikamaru, Kiba, Shino, Gaara, Kankuro, Temari
**Batch 3**: Yamato, Jiraiya, Chiyo, Hinata
**Batch 4** (variants): Naruto Kyubi, Sasuke Curse Mark
**Batch 5** (secret): Yondaime, Tobi, Haku, Kimimaro, Tonton, Master Hand, God

---

## Game Modes

- **VS Mode**: Char select → Stage select → Fight → Results. 1-8 fighters, local/online, team/FFA
- **Stage Mode**: Linear campaign with scripted encounters, boss fights, story screens, unlocks
- **Tournament**: 1v1 and 2v2 bracket, auto-generated, progression to finals
- **Battle Mode**: Survival / endless waves with scoring

---

## Asset Pipeline

1. Source NTSD 2.4 `.dat` files + BMP sprite sheets from community
2. Convert BMP (magenta transparency) → PNG with alpha via script
3. Import PNGs into Godot with Nearest filter, no mipmaps (pixel art)
4. Run `lf2_dat_importer.gd` to decrypt `.dat` → parse → generate `.tres` resources
5. Each character's `CharacterData.tres` references its sprite sheets and contains all frame data

---

## Implementation Phases

### Phase 1: Core Foundation
- Godot 4 project setup with full folder structure
- `movement_2_5d.gd` with X/Y/Z, gravity, ground collision
- `state_machine.gd` + Idle, Walk, Run, Jump, Fall states
- `fighter_animator.gd` with test sprites
- `input_manager.gd` for P1
- `Arena` scene with background + camera
- **Deliverable**: One character moving and jumping

### Phase 2: Combat Foundation
- Attack states with 3-hit basic combo chain
- Hitbox/hurtbox system
- `combat_system.gd`: hit detection, damage, knockback
- Hit, Knockdown, Recovery, Block states
- Health bars in HUD
- **Deliverable**: P1 vs P2 local fighting

### Phase 3: Data-Driven Characters
- `CharacterData`, `FrameData`, `ItrData` Resource classes
- `lf2_dat_importer.gd` (decrypt + parse LF2 .dat files)
- Sprite sheet pipeline (BMP→PNG converter)
- Import Naruto from actual NTSD 2.4 data
- `command_parser.gd` + `input_buffer.gd` for specials
- Chakra system
- **Deliverable**: Naruto with full original moveset

### Phase 4: Full Roster Import
- Import all characters batch by batch (see roster order above)
- Implement `opoint` (projectile spawning) and `cpoint` (grabs)
- Character transformation system (Kyubi, Curse Mark)
- Test and validate each character against original
- **Deliverable**: All 20+ characters playable

### Phase 5: Game Modes
- VS Mode with full char/stage select flow
- Tournament Mode with bracket system
- Stage Mode with campaign data format and scripted encounters
- Battle Mode survival

### Phase 6: AI
- `ai_controller.gd` utility-based decision making
- Difficulty levels (Easy → Insane)
- Per-character AI tuning

### Phase 7: UI/Audio Polish
- Main menu, character select with portraits, stage select
- Full HUD polish (animations, transitions)
- Sound effects and background music integration
- Settings menu (controls, volume, display)

### Phase 8: Networking
- Audit all game code for determinism
- Integrate Snopek rollback netcode
- State serialization for all game objects
- Lobby system (WebRTC peer-to-peer)
- Scale to 4+ players, spectator mode

### Phase 9: macOS Release
- Export config, code signing, notarization
- DMG installer, app icon
- Performance optimization
- Controller/gamepad support
- Retina/HiDPI support

---

## Verification Plan

- **Phase 1-2**: Run project, verify character movement/combat feels responsive
- **Phase 3**: Import original Naruto `.dat`, compare frame timings and hitboxes frame-by-frame against original NTSD 2.4
- **Phase 4**: Play-test each character; record and compare combos/damage values to originals
- **Phase 5**: Complete each game mode flow start-to-finish
- **Phase 6**: AI plays itself for extended sessions; no softlocks
- **Phase 8**: Network play test with simulated latency (200ms+); verify rollback smoothness
- **Phase 9**: macOS build runs at 60fps stable; DMG installs cleanly

---

## References

- [LF2 .dat file format](https://www.lf-empire.de/27-lfe-v10/data-changing)
- [lf2_codec (dat decryptor)](https://github.com/azriel91/lf2_codec)
- [F.LF open source LF2](https://github.com/Project-F/F.LF)
- [Snopek Rollback Netcode](https://gitlab.com/snopek-games/godot-rollback-netcode)
- [NTSD on ModDB](https://www.moddb.com/mods/ntsd-naruto-the-setting-dawn)
- [LF2 Empire data changing reference](https://www.lf-empire.de/lf2-empire/data-changing/frame-elements)
