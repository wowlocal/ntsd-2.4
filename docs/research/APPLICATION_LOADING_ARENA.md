# Front storage in the complete audio-loading test

The candidate corrects the synthetic address collision diagnosed in
[decimal materialization](APPLICATION_DECIMAL_MATERIALIZATION.md). The old full
test rejected Object64 at0x51000020 because its front wrappers occupied that
range. That failure, the earlier timeout and both frozen candidates remain intact.
The production overlap guard was correct; this candidate changes only two test
files. [Finite plan](APPLICATION_LOADING_ARENA_PLAN.md).

OriginalApplicationObservedBitmapTests.packets now accepts a frontBase argument
whose default remains0x51000000. The newer Mac audio-loading composition supplies
0x6f000000. All25 wrapper backings and all earlier test method bodies are retained.
This is declared test storage, not a Windows heap rule. Runtime/Core/Reference/
MacPlatform files, original inputs, expected bytes and masks are unchanged.

The static audit reads the pinned saved catalog, verifying its95,289,959 raw bytes
and SHA8ff43ea70036d84dbbea5309387176595658b0246aa3ff5773e8e22d08f12dee.
It checks137 Object and15,545 child allocations, the catalog outer storage,
621 file buffers,400 Actors,10 interface wrappers and12 later menu/background
wrappers:16,726 future addressed inputs. None intersects0x6f000000..<0x6f030ed0;
the old arena still intersects Object64. Opaque audio/graphics handles remain
resource identities, not byte ranges. No original or Windows execution occurred.

One new first selector checks the old default/backing/collision, the proposed
range, all future inputs and actual earlier Native memory/music/global owners.
It is a fast environment control; the complete caller still checks behavior.
All166 retained methods follow in their original order with unchanged limits,
including the3600-second full catalog/pool/menu/Host method and its3000-request/
3002-attempt bounds. The queue stops at its first nonpass and preserves the rest.

Preparation39108 completed with exit0 in14.657884834 seconds and is absent.
The2291-file exact clone retains210Core/61Reference/11Mac/292Tests,385 fixtures
and1301 runtime resources. Manifest SHA:
`0f0a5c61c3c97c96bd804043ab9b1abe97b88cd04a6563783d50cff379deac2f`.
Both changed Swift files parse; author inspection verifies every retained test
method body and limit. Author inspection is not independent review.

Fresh build40576 completed with exit0 in311.872075375 seconds and is absent,
without a guard, signal or remaining process. Sampled peak process-tree RSS was
7,050,117,120 bytes. Package verification checks fresh source membership/outputs
and all1686 resource bodies; the XCTest binary is69,549,832 bytes.

The [progress receipt](../evidence/application-loading-arena-progress.json) records
14 terminal passing methods at2026-09-27T05:59:03.177748+00:00. The new first selector passes
in16.583060792 process seconds (14.506 XCTest seconds), verifying actual ready
owners as well as the saved future ranges. Queue51788 continues the167 fixed
methods; complete comparison and final archives remain separate pending gates. Root1034/prior2257/parent2291/source55 remain
protected. X5 keeps its121GiB combined reserve; no evidence was deleted or old
producer restarted. The new129GiB preparation threshold is that reserve plus the
declared8GiB task allowance, with the same6GiB observed-decrease stop.

The host lock was observed at05:52:47 UTC; no guest or UI input occurred. Windows
installer approval persists. Independent review, root promotion, complete source
application return, runtime playback/device behavior, Windows font/cursor,
clean-Mac acceptance, first full match and full game remain open. NTSDApp still
runs Practice. Existing safety incidents stay open; EXE envelope is unchanged.

Next: observe this same bounded queue, verify complete results,
then archive/publish. Preserve and diagnose any nonpass without restarting this
candidate, changing source expectations, removing the full caller or increasing
its deadline.
