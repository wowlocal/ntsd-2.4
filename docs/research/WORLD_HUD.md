# Complete World HUD

`OriginalWorldHUD` implements the complete caller421a15..421a2d and
41ae60..41b12d/ret4 using the existing original bitmap, clipping and rectangle
mechanisms. All1,753 controlled original passes match native full World/Actor
bytes and masks, globals and276,106 ordered renderer events. The223 instruction
starts of the HUD function are all exercised; this is not every branch outcome,
Windows rasterization, or a complete game tick.

[PAUSED_HUD](PAUSED_HUD.md) separately compares the whole callee with EDI1
and preserved command flags. `drawPreservingCommands` omits only the two
unpaused caller stores; it does not yet compose the complete paused caller.

The [initialized match comparison](GAMEPLAY_HUD.md) separately connects this
public API to independently reconstructed startup, catalog, menu and gameplay
state. No character-specific implementation is introduced.

## Recovered behavior

The caller loads retainedSP+68, pushes it, clears450bc0 and450bb8 using the
preceding pass's EDI0, and calls41ae60. The callee never reads that argument;
ret4 merely discards it. Actual rendering reads targetglobal455608 at the
original call sites. Do not bind the native target from arbitrary stack bytes.

There are eight cells, laid out at x=(cell&3)*198,y=(cell>>2)*54. Each first
draws interface bitmapglobal4511a8, even when no participant is selected.
A nonzero activity byte selects primary slotcell; otherwise a nonzero byte
selects fallbackcell+10. Other slots do not participate. Primary activity need
not be1. Multiple slots referring to the same Actor are not deduplicated.

The selected Actor's Object header+728 supplies its small portrait, drawn at
x+9,y+7 with picture−1. Object loader normalization already preserves this field
as a catalog bitmap ordinal. No Object ID, name, or individual character rule
is used to select the portrait or resource geometry.

When HP+2fc is positive, the source draws these rectangles fromglobal44fd7c:

| Resource | Source row | Width | Destination |
| --- | --- | --- | --- |
| Recoverable HP+300 |30|wrapped31*value/125|x+57,y+16|
| HP+2fc |20|wrapped31*value/125|x+57,y+16|
| Healing overlay |40|wrapped31*HP/125|x+57,y+16|
| MP backdrop |10|124|x+57,y+36|
| MP+308 |0|wrapped31*value/125|x+57,y+36|

Each sourceX is0 and height is10. The overlay appears only when
`(E0/1000==1 || E4>0) && global450bd0%2==0`, with signed division/remainder.
Widths use wrapping signed32 multiplication followed by truncation toward zero.
They are not a ratio to maximumHP+304, are not clamped, and can be negative or
zero. The rectangle helper preserves these dimensions without bitmap clipping.
HP<=0 skips all bars, including MP, but still draws the team mark.

Team1/2/3/4 select globals44f888/44fcbc/44fb68/44faf8; all other values use
44faf4. The mark uses picture254,key1,mirror0 atx+5,y. It does not inherit the
resource-bar x+57. Every HUD bitmap call has mirror0; the portrait/interface use
picture−1,key0. Reuse the real43f010 fallthrough: a negative picture can cause
both a whole-image draw and a second metadata-based draw. Do not sanitize this
into a single request. HRESULTs, including failures, are ignored by this caller.

## Source and native contract

`tools/oracle_world_hud.py` executes the original caller, whole HUD,43f010,
43ef70 and43f310. Actor/World constructors are real; their memset and declared
COM Blt responses remain host boundaries. The400-slot World uses a controlled
full pool, four Objects,13 bitmap records and explicit viewport/resources.
CW027f is set before the pass; CW, status and empty tag word are checked after
it. There are no floating-point instructions in the HUD itself.

The source verifies every helper return, stack cleanup and saved register;
all Object/bitmap records remain unchanged. Each case compares424,408 bytes
of World/400Actors, their masks and46,144 globals bytes. The complete argument
access trace is one read at421a15/SP+68 and one write at421a19/SP−4. The callee
has no access to the passed word. Caller cases vary that word, real target
binding and successful/failing HRESULTs independently.

Other controls cover all eight primary/fallback selections, nonzero activity,
all400 active slots, aliased Actors, irrelevant slots, signed overflow, dead
Actors, healing thresholds/parity, arbitrary teams, zero/inverted viewport and
bitmap sizes/counts, resource aliases, null source surfaces and a fully clipped
null-target path. Resource aliases cover the opaque resource namespace; they
are not a claim that every possible catalog/resource alias is validated.
Seventy undefined bitmap read events retain their supplied backing values.
Those memory patterns are controls, not observed Windows heap contents.

Native builds every controlled input independently, normalizing only known
Actor/Object/catalog references and the bitmap surface word. It compares the
entire ordered draw/read/clip/rectangle/Blt stream, including undefined-read
masks, numeric values and dimensions. Shared renderer algorithms were unchanged.

The public API keeps catalog ordinals separate from resource tokens and commits
command-flag writes only after success. A resolver failure in the second cell
and an observer failure at the seventh Blt both preserve the input globals.
Ordinary COM failure is different and does not throw. Device callbacks and
observers must be buffered until the enclosing whole tick commits; the API
does not undo external drawing already performed by a caller.

## Coverage and reproduction

| Function | Instruction starts | Executed |
| --- | ---: | ---: |
| Caller421a15..421a28 |6|6|
| HUD41ae60..41b12d |223|223|
| Clip43ef70..43f000 |57|45|
| Bitmap43f010..43f2fe |214|171|
| Rectangle43f310..43f37a |38|38|

The483 executed PCs exclude COM and terminal boundaries. Missing clipping PCs
are left/top paths; HUD coordinates do not enter them. Missing bitmap PCs are
mirror paths; HUD always supplies mirror0. Alignment INT3 bytes are excluded
from the inventories. All223 HUD PCs does not prove every branch outcome.

The59,625 helper returns comprise1,753 HUD,17,912 bitmap,33,856 clip and6,104
rectangle calls. Events comprise17,912 draw,178,772 read,33,856 clip,39,462 Blt
and6,104 rectangle events. The raw corpus is34,689,334 bytes, pinned by
[evidence](../evidence/world-hud.json).

```sh
uv run --script tools/oracle_world_hud.py
python3 tools/accept_world_hud.py
swift test --package-path native -c release --filter OriginalWorldHUDTests
```

Run SwiftPM sequentially and never mutate fixtures during a SwiftPM build.
Acceptance verifies source identity, corpus hash, case/event/ABI inventories,
all prior fixture pins, the new native comparison and retained command chains
before publishing the lossless fixture. Packaged verification is separate.

The raw native comparison passed all three tests in6.564s after its test-only
Zip2Sequence diagnostic compile fix. Acceptance passed the three HUD and two
retained command tests in45.951s after a137.16s build. The final packaged run
passed all five HUD/own-chain tests in46.123s after a137.47s build, including
all1,753 controlled cases and both late-failure rollback checks. It linked
NTSDNative but did not open an app window.

The packed controlled fixture is727,640 bytes. All165 older fixture hashes
remain unchanged;168 current pins include this corpus and both own HUD chains.
Independent inflation verified raw/packed byte equality, complete JSON, length
and SHA256, plus every own-chain blob. The report is retained at
build/research/hud-artifact-verification.json. All source/SwiftPM jobs were
terminal before the milestone commit. Python compilation,1,200 local Markdown
links and git diff checks passed.

The next whole consumer begins421a2d; [TICK_TAIL_PLAN](TICK_TAIL_PLAN.md)
separates diagnostics/results, labels/presentation/sound and actual422ab8/ret4. First-tick return, natural repeated gameplay, native window
integration, pixels/audio/latency and an actual Windows comparison remain open.
