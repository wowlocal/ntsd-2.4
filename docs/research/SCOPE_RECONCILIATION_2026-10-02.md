# Full-scope reconciliation (2026-10-02)

The "Next after this gate" step of the
[offline acceptance follow-up](APPLICATION_PACKAGING.md#offline-acceptance-follow-up-2026-10-02):
CONTINUE_GOAL's full-scope criteria and the open reviews, reconciled with the
newest evidence. Classes:

- **V**: verified by Native comparison and/or app checks.
- **M**: implemented, with a specific missing check.
- **G**: an implementation gap.
- **E**: externally blocked, with evidence.

Stale status text alone proves neither completion nor a gap. Independent
review is not available in these sessions: every card's review stays open and
is not counted as done. The original is not executed.

## Criteria

| Criterion | Class | Newest evidence | Missing check or blocker |
| --- | --- | --- | --- |
| Characters, techniques, states, objects, weapons, effects | V, then M | Catalog/Object loaders; actor physics, hits, contacts, cpoints, opoints and lifecycle corpora; [special moves](APPLICATION_SPECIAL_MOVES.md) 7,770 calls; [object input](APPLICATION_OBJECT_INPUT.md) 880; Demo soaks with random characters (225 matches over four seeds, [soaks](APPLICATION_SOAKS.md)) | Windows observation of whole matches (E: no Windows machine here) |
| AI | V | [Character AI](APPLICATION_CHARACTER_AI.md) 3,770 calls (CW027f/037f); computer VS, Demo, War, Stage soaks | — |
| Arenas | V | [All arenas](APPLICATION_ARENAS.md): 17 backgrounds and Random launch and play | — |
| Modes: VS, computer VS, Stage 1-1..5-1, Survival, Demo, War, tournaments, Playback, Quit | V | e2e scenarios vs/mission/demo/war/playback/tournament/tournament-win/team-tournament; [offline candidate](APPLICATION_PACKAGING.md#result-2026-10-02) passes all ten on its bundle | — |
| Mode: ONLINE GAME (network play) | G | N1 in 7727346; N2 WIP uncommitted ([NETWORK_PLAY](NETWORK_PLAY.md)) | Deferred by the user (2026-10-01); [refusal](../evidence/claude-code-network-safety-2026-10-01.json) open. Resume when the user lifts the deferral |
| Menus, settings, saves | V | Front menu F1–F3 corpora (CONTROL SETTINGS 106 cases, RECORDING INFO 129); e2e controls and recording checks (`control.txt`, recording flag) | — |
| Replays | V | [Playback](APPLICATION_PLAYBACK.md) P1–P4 corpora; pixel-identical playback (e2e playback); recordings saved per match | — |
| Physics, combos, priorities, RNG, numeric quirks, update order | V | Gameplay-body corpora at CW027f/037f (x87 precision), the hit corpus (7,845 pools), RNG streams compared per event | Windows observation (E) |
| Timings | V, then M | [Tick speed](APPLICATION_TICK_SPEED.md): 30.3 ticks/s with three fighters on this host | Input latency and feel on a device (E: manual) |
| Camera | V | Gameplay camera and playback camera (F6) corpora | — |
| Interface (HUD, GDI text) | V, with a declared deviation | HUD corpora; [GDI text](APPLICATION_GDI_TEXT.md) in all paths; [code-page survey](APPLICATION_GDI_TEXT.md#addendum-code-page-survey-2026-10-01) | The SYSTEM_FONT glyphs are a temporary deviation (user decision 2026-10-01; the font cannot be redistributed) |
| Sound | M | [Sound effects](APPLICATION_SOUND_EFFECTS.md) (declared DirectSound policy, 1,835 calls with none rejected); [music](APPLICATION_MUSIC.md) (lossless decode) | Windows audio comparison (E); the Demo music residue is a temporary declared choice (E: needs a Windows register observation) |
| EXE ID exceptions | V | Ported inside the compared passes (e.g. IDs 50/51, 122, 217/218, 998/999 and the 0x270b/0x270c states) | — |
| Full-pool behaviour | V, with declared stops | [F8 slot word](APPLICATION_REQUESTED_ITEMS_SLOT.md) (oracle-agreeing initial value; 88-press real-play case); [hit word](APPLICATION_HIT_ITEM_SLOT.md) | Heap-address cases are declared stops (E: Windows heap layout) |
| Window: launch, close, ESC, Alt+Enter | V | Default launch of the original (80c83c1); [window close](APPLICATION_WINDOW_CLOSE.md) 74 calls; [Alt+Enter](APPLICATION_FULL_SCREEN.md) e2e `altenter` with its fault check | Alt+Enter's display-mode answers are declared (E: Windows) |
| Window: macOS full screen | M | [Mac full screen](APPLICATION_MAC_FULL_SCREEN.md): hold test, e2e | The real AppKit transition is unobserved: on 2026-10-01 and again on 2026-10-02 the display was asleep (black idle screenshot) and no entry was reported. Resume on an awake display |
| Input: keyboard, function keys, joystick | V, then M | Keyboard throughout e2e; F7/F8 in real play; **F1, F2, F3, F5, F6 and F9 in a VS fight (2026-10-02): no stop, the original's "Function Keys Locked" state shown**; [joysticks](APPLICATION_JOYSTICKS.md) e2e `joystick` (declared WinMM answers) | A physical controller (E) |
| Packaging and offline build | V (host) | [Offline candidate](APPLICATION_PACKAGING.md#result-2026-10-02): inputs pinned, binary ec5afcc1…, ad-hoc signature valid | Clean-Mac acceptance (E: a clean Mac) |

## Stale texts found

- RESEARCH_MAP's packaged-app entry: "Default launch is still Practice (user
  decision)" is superseded by the 2026-10-01 decision and 80c83c1 (corrected
  with this record).
- RESEARCH_MAP's match-end entry ("Remaining in that match: GDI text, music
  output, special moves") is superseded by the GDI text, music and
  special-move cards. It is historical text; the rows above carry the
  current state.

## Result

The only implementation gap is network play, which the user has deferred.
Every M row's missing check is external: an awake display, Windows, a
device, or a clean Mac. The function-key row was the one permitted concrete
check this reconciliation found; it was done above with no stop. No other
permitted implementation task remains until the user lifts the network
deferral or one of the external checks becomes available.
