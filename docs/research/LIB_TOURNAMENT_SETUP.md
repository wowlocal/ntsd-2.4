# Tournament roster, draw and settings

OriginalTournamentSetup and the shared CharacterScreen dispatcher match all373
controlled original calls:372 actual422ab8ret4 returns and one unreturned Start
boundary. Raw and packaged comparisons, both late rollbacks and retained Stage/VS
checks pass. The finite contract is [LIB_TOURNAMENT_SETUP_PLAN](LIB_TOURNAMENT_SETUP_PLAN.md);
full receipts and hashes are in [the evidence](../evidence/lib-tournament-setup.json).

Mode2 enters menu20 and432ab0 through429ebc..429ed8. It does not enter the
ordinary menu3 character screen. Menu20 initializes eight Random choices,
Computer controllers and identity draw order. Menu21 uses the shared eight-seat
431b70 input/latches, then processes character and controller phases in one
call. Character confirmation clears attack before the controller phase. A
controller confirmation advances the current fighter, and completing fighter7
opens the confirmation dialog in that same call. Backtracking retains choices
and renumbers only the already completed positive controllers as1,2,... .

The main portrait and name render after character input but before controller
input. Completed icons use draw order44d0e0 and Object+728, with target455608;
the unfinished icon uses the current selection but its controller follows the
order table. The mutable label44d31c receives only one byte: C or a digit. Its
NUL at44d31d is the retained file-backed EXE byte. The native implementation
uses its own label storage and loaded Object/bitmap ordinals, not source stack
or expected Object inputs. Raw DAT/BMP supply42 small-portrait declarations in
addition to the42 existing heads. These controlled surfaces and the aliased
synthetic45116c/451178 atlas do not establish original pixels or Windows output.

Menu22 draws the confirmation dialog before applying its input. Menu23 performs
50 pairs of f7/f8 draws per call, then increments its counter. Counter5/10 plays
the tick sound; counter11 returns to menu22 and jumps directly to the function
epilogue. Thus eleven passes contain550 swaps and1100 RNG calls per chain.
The displayed ordering belongs to the state before that call's swaps.

Menu24 selects each flag==1 fighter in sequence. Its f9 candidates start at
catalog ordinal1, require type0 and signedID<30, and exclude every current choice
across all eight places. Each result becomes live before the next candidate
list. This changes selected ordinals without binding gameplay Actors. Menu24
then enters menu25 and runs settings in the same call. Reroll in menu25 instead
sets menu24 and returns; its next call performs Random even if attack is held.
Music's Random choice also consumes a draw on every settings call.

Settings render music first, then the options/arena/difficulty. Arena selection
cycles through17 ordinary records, Random100 and Lee On Road99. The primary's21
presses visit Random/Lee/District and end on arena2. Difficulty cycles2/1/0;
the static existing-1 branch says Difficult, unlike the VS CRAZY! label. Arena
and difficulty confirmation each play the confirmation sound twice. Reselect
sets menu20 and returns. Back clears only Random selections and retains draw
order; Quit returns to mode menu10 and resets input, without exiting the app.

Primary229 calls retain Naruto17/Sasuke21 as two humans plus six Random CPUs;
control144 uses eight Random CPUs. Initial menu, blink, unlock and seeded RNG
states are declared controlled operands. All later calls retain complete
World/400Actor/catalog/globals/resources/library DC/source stack and change only
buttons and three ABI words. There are372 actual422ab8ret4 returns. Primary
Start clears attack and plays its sound, then stops BEFORE4338c3, the first
write entering bracket menu26. This is a separate boundary from42cf8a.

The source73-second run completed without a source fault. Its expected raw
1268449644 bytes remain unchanged. The first Native compile omitted try in the
second throwing guard clause; only that syntax was corrected. The first audit
used19 as the ordinary arena count in its final Start assertion; raw catalog
count17 plus two special positions gives arena2 after21 presses. The failure
and original auditor are preserved, and the corrected audit calculates the
result from the catalog. Neither correction edits source expected bytes.

Independent acceptance verifies6107 checkpoints/5190950 records/15613950110
bytes,317050 final records/953660290 bytes,334197 stores/1320013 bytes,
423419 instruction reads/1590631 bytes,5910 API reads/32412 bytes and15781
helper returns.5824 semantic words are recovered from actual defined caller
storage; tournament20/24 coordinates use the432ab0 frame, distinct from the
outer human-screen counters.2710 observed starts=2324 EXE+51lib+335CRT. This is
observed execution, not every branch.51113 ordered events include3120 undefined
bitmap reads with their unchanged bytes/masks.56 f9 lists,2200 shuffle RNG calls,
100 music RNG calls and1992 one-byte labels all verify independently.

Source1 finished72.981s. Native1's compile failure and source-auditor1's failed
final assertion remain separate retained attempts. Native2 built259.46s and
passed6 tests206.504s: Tournament70.375s, Stage71.264s and VS64.865s. Packaged
acceptance built0.36s and passed2 tests66.058s, without raw overrides. Both
rollbacks preserve the whole current call and all preceding calls/resources/DC.
The game rules and test comparator needed no correction after the first build.

All267 old fixtures remain unchanged; the index and three new parts total
165387326 bytes and recover all1268449644 original raw bytes/JSON/SHA. All2782
blobs and674 package files plus recursive input archives independently verify.
Frozen886/887/887/890/890 manifests,14 pending Native/3 pending source/6 foreign
files are unchanged. Source and all study SwiftPM jobs are terminal. NTSDNative
linked, but no window or device was exercised. Research data/builds use the
new task-owned X5 directory via build/research/lib-tournament-setup; shipping
fixtures are regular repository files. The final acceptance file is frozen;
mutable job/next-work index is build/research/lib-tournament-setup/
lib-tournament-setup-work.json. Catalog5 is still the same Python78863, last12
Objects; its own full return and new whole Native comparison are not complete.

Bracket progression/menu26 onward, Team Tournament, War, simultaneous multi-seat
input coverage, unlocked roster traversal, whole own library/catalog/menu
initialization, match preparation/outer loop and application integration remain
open. No full match, device/window, Windows, network or clean-Mac acceptance
follows from this controlled setup study. Catalog5 remains an independent live
source process and must not be restarted for silence.
