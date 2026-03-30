# NTSD 2.4 for macOS — Reverse Engineering & Port Plan

## Context

Port NTSD 2.4 (Naruto The Setting Dawn 2.4) to macOS by forking **F.LF**, an existing open-source clean-room JavaScript reimplementation of the LF2 engine, and loading NTSD 2.4's original data files into it. Wrap the result in **Tauri** for a native macOS desktop app.

This approach skips building a game engine from scratch — F.LF already implements the complete LF2 engine (state machine, 2.5D physics, hitbox system, AI, networking). Our work is: data conversion, NTSD-specific tweaks, and native packaging.

---

## Why This Approach

| | From-scratch (Godot) | Fork F.LF + NTSD data |
|---|---|---|
| Engine work | Build everything | Already done (v0.9.9) |
| Physics/combat | Reimplement | Already faithful to LF2 |
| Character import | Build importer + validate | Convert .dat → JSON (tooling exists) |
| Timeline | Months | Weeks |
| Accuracy risk | High (subtle feel differences) | Low (F.LF already matches LF2) |

---

## Key Components

### 1. F.LF Engine (existing)
- **Repo**: `Project-F/F.LF` on GitHub
- **Language**: JavaScript/HTML5 (56.6% JS, 41.6% HTML)
- **Status**: v0.9.9, 11 characters, networking, AI, near-complete
- **Runs**: Opens `game/game.html` in any browser — works on macOS already
- **Core modules** (22 files in `/LF`):
  - `mechanics.js` — game rules, physics
  - `character.js` — character data/properties
  - `livingobject.js` — base entity class
  - `specialattack.js` — special moves
  - `sprite.js` — sprite rendering
  - `AI.js` — bot logic
  - `network.js` — WebSocket multiplayer
  - `loader.js` / `loader-config.js` — asset loading
  - `manager.js` — game loop orchestration

### 2. lf2_codec (existing)
- **Repo**: `azriel91/lf2_codec` on GitHub
- **Language**: Rust
- **What it does**: Decrypts LF2 `.dat` files (Caesar cipher, 123-byte header skip)
- **Usage**: `lf2_codec decode character.dat > character.txt`
- **Output**: Human-readable text with frame definitions, hitboxes, etc.

### 3. NTSD 2.4 Data Files
- **Format**: Standard LF2 `.dat` (encrypted) + BMP sprite sheets (magenta transparency)
- **Sources**: ModDB, NTSD forums (ntsd.forumotion.com), Little Fighter Empire
- **Key fact**: NTSD 2.4 uses **unmodified LF2 engine** — no custom itr types or engine extensions. All standard LF2 frame states and interaction types work as-is in F.LF.

---

## Architecture

```
ntsd-macos/
├── src-tauri/                     # Tauri Rust backend
│   ├── Cargo.toml
│   ├── src/
│   │   └── main.rs               # Tauri app entry, window config
│   └── tauri.conf.json            # App metadata, window size, permissions
│
├── game/                          # F.LF fork (the actual game)
│   ├── LF/                        # Core engine modules (22 JS files)
│   │   ├── mechanics.js
│   │   ├── character.js
│   │   ├── livingobject.js
│   │   ├── sprite.js
│   │   ├── loader.js
│   │   ├── loader-config.js       # ← MODIFY: point to NTSD data
│   │   ├── AI.js
│   │   ├── network.js
│   │   └── ...
│   ├── core/                      # Engine infrastructure
│   ├── game/
│   │   └── game.html              # Entry point
│   ├── third_party/               # Dependencies
│   └── docs/
│
├── data/                          # NTSD 2.4 converted data
│   ├── characters/                # JSON character definitions
│   │   ├── naruto.json
│   │   ├── sasuke.json
│   │   └── ...
│   ├── stages/                    # Stage/background definitions
│   └── sounds/                    # Sound effects
│
├── assets/                        # NTSD 2.4 converted sprites
│   ├── sprites/
│   │   ├── naruto/                # PNG sprite sheets (converted from BMP)
│   │   ├── sasuke/
│   │   └── ...
│   └── backgrounds/
│
├── tools/                         # Conversion pipeline
│   ├── dat2json.js                # .dat (decrypted text) → F.LF JSON converter
│   ├── bmp2png.sh                 # BMP (magenta key) → PNG (alpha) batch converter
│   └── import_ntsd.sh             # Full pipeline: decrypt → convert → copy
│
├── package.json                   # Node deps (Tauri CLI, dev server)
└── README.md
```

---

## Implementation Phases

### Phase 1: Setup & Proof of Concept
**Goal**: F.LF running in browser with one NTSD character

1. **Fork F.LF** into `game/` directory
2. **Get F.LF running** locally — open `game/game.html`, verify base LF2 works
3. **Install lf2_codec**: `cargo install lf2_codec`
4. **Download NTSD 2.4** data files from community sources
5. **Decrypt one character** (Naruto): `lf2_codec decode naruto.dat > naruto.txt`
6. **Build `dat2json.js`** — parse the decrypted text format into F.LF's JSON schema:
   - Parse `<bmp_begin>` section → sprite file references
   - Parse `<frame>` blocks → frame array (pic, state, wait, next, dvx, dvy, centerx, centery)
   - Parse `bdy:` blocks → body/hurtbox rects
   - Parse `itr:` blocks → interaction/hitbox data (kind, x, y, w, h, dvx, dvy, injury, fall, bdefend)
   - Parse `opoint:` blocks → projectile spawn points
   - Parse `cpoint:` blocks → grab/catch points
7. **Convert Naruto's BMP sprites** → PNG with alpha (ImageMagick: `convert input.bmp -transparent "#FF00FF" output.png`)
8. **Modify `loader-config.js`** to load NTSD character data from `data/characters/`
9. **Test**: Naruto playable in browser with original sprites and moveset

**Deliverable**: Naruto fighting in F.LF with exact original frame data

### Phase 2: Full Data Import
**Goal**: All NTSD 2.4 characters and stages converted and loaded

1. **Batch decrypt** all `.dat` files
2. **Batch convert** all BMP sprite sheets → PNG
3. **Run `dat2json.js`** on every character
4. **Import stages/backgrounds** — same decrypt + convert pipeline
5. **Update `loader-config.js`** with full NTSD roster
6. **Modify character select UI** to show NTSD character grid
7. **Test each character** — verify sprites display correctly, moves work, hitboxes land

**Deliverable**: All 20+ characters playable in browser

### Phase 3: NTSD-Specific Features
**Goal**: Anything NTSD adds beyond vanilla LF2

1. **Hell Moves** — verify F.LF's command input system handles NTSD's longer sequences (D>v>A>D>^>A). If not, extend `mechanics.js` input buffer
2. **Chakra system** — verify F.LF's MP system maps correctly to NTSD's chakra mechanics
3. **Character transformations** — Naruto Kyubi form, Sasuke Curse Mark (mid-match form switches via opoint or state transitions)
4. **Stage Mode** — NTSD's campaign following Naruto Part 2 storyline; script encounter sequences
5. **Tournament modes** — 1v1 and 2v2 bracket UI
6. **NTSD main menu** — recreate the original menu layout and flow
7. **Sound effects** — import NTSD audio files, wire into `soundpack.js`

**Deliverable**: Feature-complete NTSD 2.4 in browser

### Phase 4: Tauri Desktop App
**Goal**: Native macOS app with DMG installer

1. **Init Tauri project**: `npm create tauri-app`
2. **Configure `tauri.conf.json`**:
   - Window size matching LF2 resolution (794×550 or scaled up)
   - App title: "NTSD 2.4"
   - macOS bundle identifier
   - Disable browser dev tools in production
3. **Point Tauri at `game/game.html`** as the frontend
4. **Keyboard input** — ensure all LF2 key mappings work through Tauri's webview
5. **Fullscreen toggle** — F11 or ⌘F for macOS fullscreen
6. **App icon** — NTSD-themed icon for dock/Finder
7. **Build**: `npm run tauri build` → produces `.dmg`
8. **Code sign & notarize** for macOS Gatekeeper

**Deliverable**: `NTSD-2.4.dmg` that installs and runs natively

### Phase 5: Polish & Multiplayer
**Goal**: Production-ready experience

1. **Performance** — profile in Tauri webview, optimize sprite rendering if needed
2. **Retina/HiDPI** — scale canvas for macOS Retina displays (2x pixel density)
3. **Gamepad support** — map gamepad input via Gamepad API (already available in webview)
4. **Online multiplayer** — F.LF already has WebSocket networking; set up a relay server or use WebRTC for P2P
5. **Save state** — persist settings, unlocked characters, tournament progress to local storage
6. **Auto-update** — Tauri's built-in updater for future patches

**Deliverable**: Polished, shippable macOS app

---

## Data Conversion Details

### .dat File Format (after decryption)

```
<bmp_begin>
file(0-69): sprite\naruto_0.bmp  w: 79  h: 79  row: 10  col: 7
file(70-139): sprite\naruto_1.bmp  w: 79  h: 79  row: 10  col: 7
<bmp_end>

<frame> 0 standing
   pic: 0  state: 0  wait: 3  next: 1  dvx: 0  dvy: 0  centerx: 39  centery: 79
   bdy:
      kind: 0  x: 22  y: 16  w: 33  h: 62
   bdy_end:
<frame_end>

<frame> 60 punch1
   pic: 60  state: 3  wait: 2  next: 61  dvx: 5  dvy: 0  centerx: 39  centery: 79
   bdy:
      kind: 0  x: 20  y: 14  w: 30  h: 64
   bdy_end:
   itr:
      kind: 0  x: 50  y: 20  w: 30  h: 30  dvx: 8  dvy: 0  fall: 20  injury: 30
   itr_end:
<frame_end>
```

### F.LF JSON Target Format

```json
{
  "name": "Naruto",
  "file": [
    { "file": "sprites/naruto/naruto_0.png", "w": 79, "h": 79, "row": 10, "col": 7 }
  ],
  "frame": {
    "0": {
      "pic": 0, "state": 0, "wait": 3, "next": 1,
      "dvx": 0, "dvy": 0, "centerx": 39, "centery": 79,
      "bdy": { "kind": 0, "x": 22, "y": 16, "w": 33, "h": 62 }
    },
    "60": {
      "pic": 60, "state": 3, "wait": 2, "next": 61,
      "dvx": 5, "dvy": 0, "centerx": 39, "centery": 79,
      "bdy": { "kind": 0, "x": 20, "y": 14, "w": 30, "h": 64 },
      "itr": { "kind": 0, "x": 50, "y": 20, "w": 30, "h": 30, "dvx": 8, "dvy": 0, "fall": 20, "injury": 30 }
    }
  }
}
```

### BMP → PNG Conversion

```bash
# Single file
convert input.bmp -transparent "#FF00FF" output.png

# Batch (all BMPs in a directory)
for f in *.bmp; do
  convert "$f" -transparent "#FF00FF" "${f%.bmp}.png"
done
```

Requires ImageMagick: `brew install imagemagick`

---

## Verification Plan

- **Phase 1**: Naruto walks, jumps, attacks in browser — compare side-by-side with original NTSD 2.4 footage
- **Phase 2**: Every character loads without errors; spot-check 5 characters' full movesets
- **Phase 3**: Hell moves execute with correct input sequences; Stage Mode plays through at least 3 stages
- **Phase 4**: `.dmg` installs on clean macOS; app launches, plays, and quits cleanly
- **Phase 5**: Two players can fight over network with <100ms perceived latency; gamepad works

---

## Tools & Dependencies

| Tool | Purpose | Install |
|---|---|---|
| lf2_codec | Decrypt .dat files | `cargo install lf2_codec` |
| ImageMagick | BMP → PNG conversion | `brew install imagemagick` |
| Node.js | dat2json converter, Tauri CLI | `brew install node` |
| Rust/Cargo | Tauri backend, lf2_codec | `brew install rust` |
| Tauri CLI | Build macOS app | `npm install @tauri-apps/cli` |

---

## References

- [F.LF — open source LF2 engine](https://github.com/Project-F/F.LF)
- [F.LF live demo](https://project-f.github.io/F.LF/)
- [lf2_codec — .dat file decoder](https://github.com/azriel91/lf2_codec)
- [LF2 .dat file format](https://www.lf-empire.de/27-lfe-v10/data-changing)
- [LF2 frame elements (itr, bdy, opoint, cpoint)](https://www.lf-empire.de/lf2-empire/data-changing/frame-elements)
- [LF2 states reference](https://www.lf-empire.de/lf2-empire/data-changing/reference-pages/182-states)
- [NTSD on ModDB](https://www.moddb.com/mods/ntsd-naruto-the-setting-dawn)
- [NTSD forums](https://ntsd.forumotion.com/)
- [Tauri — Rust desktop app framework](https://tauri.app/)
