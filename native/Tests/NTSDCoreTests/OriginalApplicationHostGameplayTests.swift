import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalApplicationHostGameplayTests: XCTestCase {
    typealias H = OriginalApplicationHostLoadingTests
    typealias Host = H.Host
    typealias D = OriginalApplicationLoadedTestDriver
    typealias C = OriginalApplicationLoadedCycleTests
    typealias I = OriginalApplicationActiveGameplayInput
    typealias N = OriginalApplicationGameplayProjectionTests
    typealias Q = OriginalApplicationPausedGameplayTests
    typealias M = OriginalApplicationLoadedMenuSession
    typealias G = OriginalApplicationGameplaySession
    typealias Ready = OriginalApplicationInputSession.PendingContinuation

    func sameReady(_ a: Ready,_ b: Ready) throws {
        XCTAssertTrue(a.loading.isSameAttempt(as:b.loading))
        try I.sameState(a.loading.state,b.loading.state);try I.sameState(a.entry.state,b.entry.state)
        try I.sameState(a.state,b.state);try I.sameMatch(a.match,b.match)
        XCTAssertEqual(a.commands,b.commands);XCTAssertEqual(a.playbackCommands,b.playbackCommands)
        XCTAssertEqual(a.paused,b.paused);XCTAssertEqual(a.round.continuation,b.round.continuation)
        XCTAssertEqual(a.round.stageDefeated,b.round.stageDefeated)
        XCTAssertEqual(a.inputContext.savedPlayback,b.inputContext.savedPlayback)
        XCTAssertEqual(a.inputContext.memory.allocations,b.inputContext.memory.allocations)
        XCTAssertEqual(a.inputContext.memory.replayPointers,b.inputContext.memory.replayPointers)
        XCTAssertEqual(a.music.allocations,b.music.allocations);XCTAssertEqual(a.operations,b.operations)
        XCTAssertEqual(a.graphics,b.graphics);XCTAssertEqual(a.menuResources.bitmaps,b.menuResources.bitmaps)
        XCTAssertEqual(a.menuBackgrounds,b.menuBackgrounds)
    }
    struct Saved {
        let core: C.A,platform: H.P,prefix: H.P,prepared: H.P?
        let loading: C.Session.PendingLoading,ready: Ready?,returned: M.PendingReturn?
        let batches: Int
        init(_ host: Host) throws {
            core = host.snapshot;platform = try host.platformSnapshot()
            prefix = try XCTUnwrap(host.pendingPlatformSnapshot());prepared = try host.preparedPlatformSnapshot()
            loading = try XCTUnwrap(host.pendingLoading);ready = host.preparedGameplayInput
            returned = host.preparedLoadedMenu;batches = host.pendingBatchCount
        }
    }
    func unchanged(_ host: Host,_ old: Saved) throws {
        try I.unchanged(host.snapshot,old.core)
        try OriginalApplicationBootstrapTests.sameStartup(XCTUnwrap(host.snapshot.startup),XCTUnwrap(old.core.startup))
        H().samePlatform(try host.platformSnapshot(),old.platform)
        H().samePlatform(try XCTUnwrap(host.pendingPlatformSnapshot()),old.prefix)
        XCTAssertTrue(try XCTUnwrap(host.pendingLoading).isSameAttempt(as:old.loading))
        XCTAssertEqual(host.pendingBatchCount,old.batches);XCTAssertNil(host.preparedMatchPrelude)
        if let p = old.prepared { H().samePlatform(try XCTUnwrap(host.preparedPlatformSnapshot()),p) }
        else { XCTAssertNil(try host.preparedPlatformSnapshot()) }
        if let ready = old.ready { try sameReady(XCTUnwrap(host.preparedGameplayInput),ready) }
        else { XCTAssertNil(host.preparedGameplayInput) }
        if let returned = old.returned {
            let actual = try XCTUnwrap(host.preparedLoadedMenu)
            try OriginalApplicationActiveLayoutTests.same(actual.snapshot,returned.snapshot)
            try sameReady(actual.entry,returned.entry)
            XCTAssertEqual(actual.graphics,returned.graphics);XCTAssertEqual(actual.exit,returned.exit)
            XCTAssertEqual(actual.dispatcherResult,returned.dispatcherResult)
        } else { XCTAssertNil(host.preparedLoadedMenu) }
    }
    func reentry(_ host: Host) {
        OriginalApplicationHostMatchLaunchTests().reentry(host)
        XCTAssertThrowsError(try host.prepareLoadedUntilBoundary(prepare:{ _,_ in
            XCTFail("Reentrant input provider ran");throw C.Stop.unexpected("reentry")
        })) { XCTAssertEqual($0 as? Host.Boundary,.reentrantAttempt) }
        XCTAssertThrowsError(try host.resumeGameplay(prepare:{ _,_ in
            XCTFail("Reentrant gameplay provider ran");throw C.Stop.unexpected("reentry")
        })) { XCTAssertEqual($0 as? Host.Boundary,.reentrantAttempt) }
    }
    func counts(_ driver: D,_ calls: Int) throws {
        XCTAssertEqual(driver.gameplayInputs,calls);XCTAssertEqual(driver.gameplayBodies,calls)
        XCTAssertEqual(driver.gameplayReturns,calls)
        let host = try XCTUnwrap(driver.host)
        XCTAssertNil(host.pendingLoading);XCTAssertNil(host.preparedGameplayInput)
        XCTAssertNil(host.preparedLoadedMenu);XCTAssertNil(host.preparedMatchPrelude)
        XCTAssertEqual(host.pendingBatchCount,0);XCTAssertNil(try host.takeCommitted())
    }
    func testHostNeutralGameplayRetainsSeventeenWholeReturns() throws {
        for reverse in [false,true] {
            let driver = try D.selectedHost(reverse)
            try N().sequence(reverse,driver:driver);try counts(driver,17)
        }
    }
    func testHostActiveGameplayRetainsBothFortyEightCallSchedules() throws {
        for reverse in [false,true] {
            let driver = try D.selectedHost(reverse)
            try OriginalApplicationActiveOutputTests().sequence(reverse,driver:driver)
            try counts(driver,65)
        }
    }
    func testHostPauseStepResumeRetainsBothFourteenCallSchedules() throws {
        for reverse in [false,true] {
            let driver = try D.selectedHost(reverse)
            try Q().sequence(reverse,driver:driver);try counts(driver,31)
        }
    }
    func testGameplayInputPreparationFailuresPreserveHostOwners() throws {
        let driver = try D.selectedHost(false)
        driver.retainGameplayParentBatch = true
        var failures = 0
        driver.atGameplayLoading = { d in
            guard d.gameplayInputs < 2 else { return }
            let host = try XCTUnwrap(d.host),old = try Saved(host)
            if d.gameplayInputs == 0 { XCTAssertEqual(old.batches,1) }
            let stops = d.gameplayInputs == 0 ? ["provider","prologue","local","replay","round","commit","hostPrepared"] : ["control0"]
            for stop in stops {
                XCTAssertThrowsError(try host.prepareLoadedUntilBoundary(prepare:{ context,p in
                    self.reentry(host);p.hostReservations.append(-700);p.hostQueuePosition += 17
                    if stop == "provider" { throw C.Stop.injected(stop) }
                    var cycle = try XCTUnwrap(context.cycle),env = C.InputEnvironment(stop:stop)
                    return .gameplayInput(try C.input(&cycle,&env))
                },beforePrepared:{ _,p in
                    self.reentry(host);p.hostReservations.append(-701)
                    throw C.Stop.injected("hostPrepared")
                })) { XCTAssertEqual($0 as? C.Stop,.injected(stop)) }
                try self.unchanged(host,old);failures += 1
            }
        }
        try N().sequence(false,driver:driver);try counts(driver,17)
        XCTAssertEqual(failures,8)
    }
    func body(_ ready: Ready,stop: String? = nil) throws -> M.PendingReturn {
        var child = try G(pending:ready),environment = 0
        do {
            return try child.advance(environment:&environment,outputInput:Q.output(ready),observe:{ event,n in
                n += 1
                if case .front(let value) = event {
                    if value.kind == stop || (stop == "sound" && value.kind == "method" && value.arguments.count > 1 && value.arguments[1] == 0x30) || (stop == "dispatcher" && value.kind == "dispatcherWrite") { throw C.Stop.injected(try XCTUnwrap(stop)) }
                }
                if case .gameplayCheckpoint(.output,_) = event,stop == "checkpoint" { throw C.Stop.injected("checkpoint") }
            },pausedCheckpoint:{ stage,_,n in
                n += 1;if stage == .output && stop == "checkpoint" { throw C.Stop.injected("checkpoint") }
            },beforeCommit:{ _,_ in if stop == "commit" { throw C.Stop.injected("commit") } })
        } catch {
            XCTAssertEqual(environment,0);XCTAssertNil(child.pendingReturn)
            try sameReady(child.entry,ready);throw error
        }
    }
    func testGameplayBodyAndOuterFailuresRetainStagesAndRetry() throws {
        let driver = try D.selectedHost(false)
        driver.retainGameplayParentBatch = true
        var bodyFailures = 0,tailFailures = 0,pausedSeen = 0
        driver.atGameplayReady = { d,ready in
            guard d.gameplayInputs == 1 || d.gameplayInputs == 20 else { return }
            let host = try XCTUnwrap(d.host),old = try Saved(host)
            XCTAssertEqual(ready.paused,d.gameplayInputs == 20)
            if ready.paused { pausedSeen += 1 } else { XCTAssertEqual(old.batches,1) }
            let inspection = try XCTUnwrap(host.preparedPlatformSnapshot())
            inspection.hostReservations.append(-999);inspection.hostQueuePosition += 99
            try self.unchanged(host,old)
            let stops = ready.paused ? ["blit","dispatcher","checkpoint","commit","hostPrepared"] : ["blit","textOut","sound","dispatcher","checkpoint","commit","hostPrepared"]
            for stop in stops {
                XCTAssertThrowsError(try host.resumeGameplay(prepare:{ retained,p in
                    self.reentry(host);try self.sameReady(retained,ready)
                    p.hostReservations.append(-710);p.hostQueuePosition += 21
                    return try self.body(retained,stop:stop)
                },beforePrepared:{ _,p in
                    self.reentry(host);p.hostReservations.append(-711);throw C.Stop.injected("hostPrepared")
                })) { XCTAssertEqual($0 as? C.Stop,.injected(stop)) }
                try self.unchanged(host,old);bodyFailures += 1
            }
            // The complete existing comparison immediately retries from this Ready.
        }
        driver.atGameplayReturn = { d,returned in
            guard d.gameplayInputs == 1 || d.gameplayInputs == 20 else { return }
            let host = try XCTUnwrap(d.host),old = try Saved(host)
            let time = Int32(bitPattern:try XCTUnwrap(host.snapshot.session).loop.timer.baseline &+ 1000)
            XCTAssertThrowsError(try host.resumeGameplay(prepare:{ _,_ in XCTFail("Repeated body");return returned })) {
                XCTAssertEqual($0 as? Host.Boundary,.noPreparedGameplayInput)
            }
            for stop in ["time","sleep","commit"] {
                var calls: [String] = []
                XCTAssertThrowsError(try host.finishLoadedMenu(perform:{ q,p in
                    self.reentry(host);p.hostQueuePosition += 1;p.hostReservations.append(-720)
                    calls.append(q.kind.rawValue)
                    if q.kind == .sleep { XCTAssertEqual(q.arguments,[5]);throw C.Stop.injected("sleep") }
                    if stop == "time" { throw C.Stop.injected("time") }
                    return .init(result:stop == "sleep" ? 1_000_000 : time)
                },beforeCommit:{ _,_,p in self.reentry(host);p.hostReservations.append(-721);throw C.Stop.injected("commit") })) {
                    XCTAssertEqual($0 as? C.Stop,.injected(stop))
                }
                XCTAssertEqual(calls,stop == "sleep" ? ["time","sleep"] : ["time"])
                try self.unchanged(host,old);tailFailures += 1
            }
            // The driver retries only this tail and compares its complete batch.
        }
        try Q().sequence(false,driver:driver);try counts(driver,31)
        XCTAssertEqual(bodyFailures,12);XCTAssertEqual(tailFailures,6);XCTAssertEqual(pausedSeen,1)
    }
    func firstLoading(_ reverse: Bool) throws -> D {
        let driver = try D.selectedHost(reverse),host = try XCTUnwrap(driver.host)
        _ = try OriginalApplicationLoadedSelectionTests().sequence(reverse,driver:driver,onStart:{ _,pending in
            let reference = try OriginalApplicationLoadedLaunchComparison(reverse,pending)
            let returned = try OriginalApplicationHostMatchLaunchTests().launch(host,reference)
            try driver.finish(returned)
        })
        try driver.next();return driver
    }
    // Controlled negative inputs derive from an actual acquired Ready. These are
    // not natural host entries and never initialize a success trajectory.
    func changedReady(_ ready: Ready,match: OriginalMatchPreparation? = nil,
                      round: OriginalMatchRoundResult? = nil,historical: Bool = false) -> Ready {
        .init(entry:ready.entry,state:ready.state,match:match ?? ready.match,inputContext:ready.inputContext,
            music:ready.music,commands:ready.commands,playbackCommands:ready.playbackCommands,
            paused:ready.paused,round:round ?? ready.round,operations:ready.operations,graphics:ready.graphics,
            loading:historical ? nil : ready.loading,menuResources:ready.menuResources,menuBackgrounds:ready.menuBackgrounds)
    }
    func testGameplayTicketsAndReentryRejectForeignSiblingAndConsumedInputs() throws {
        let foreign = try firstLoading(true)
        let foreignReady = try foreign.prepareGameplay { cycle in var e = C.InputEnvironment();return try C.input(&cycle,&e) }
        let foreignReturn = try foreign.gameplay(foreignReady) { try self.body($0) }
        let driver = try D.selectedHost(false),host = try XCTUnwrap(driver.host)
        var previous: Ready?,sibling: M.PendingReturn?,preparations = 0,bodies = 0,controls = 0
        driver.beforeGameplayInput = { _,_ in self.reentry(host);preparations += 1 }
        driver.beforeGameplayBody = { _,_ in self.reentry(host);bodies += 1 }
        driver.atGameplayLoading = { d in
            guard d.gameplayInputs < 2 else { return }
            let old = try Saved(host)
            XCTAssertThrowsError(try host.resumeGameplay(prepare:{ _,_ in XCTFail("Body before Ready");return foreignReturn })) {
                XCTAssertEqual($0 as? Host.Boundary,.noPreparedGameplayInput)
            }
            var copy = host.snapshot
            let ticket = try C.next(&copy)
            XCTAssertFalse(ticket.isSameAttempt(as:old.loading))
            var cycle = try copy.makeLoadedCycle(pending:ticket),e = C.InputEnvironment()
            let alternate = try C.input(&cycle,&e)
            var bad = [foreignReady,alternate]
            if let previous { bad.append(previous) }
            for value in bad {
                XCTAssertThrowsError(try host.prepareLoadedUntilBoundary(prepare:{ _,p in p.hostReservations.append(-730);return .gameplayInput(value) })) {
                    XCTAssertEqual($0 as? Host.Boundary,.differentLoadingAttempt)
                }
                try self.unchanged(host,old);controls += 1
            }
            if d.gameplayInputs == 0 {
                sibling = try self.body(alternate)
                var actualCycle = try host.snapshot.makeLoadedCycle(pending:old.loading),actualEnv = C.InputEnvironment()
                let actual = try C.input(&actualCycle,&actualEnv)
                let historical = self.changedReady(actual,historical:true)
                XCTAssertFalse(historical.loading.isSameAttempt(as:old.loading))
                XCTAssertThrowsError(try host.prepareLoadedUntilBoundary(prepare:{ _,_ in .gameplayInput(historical) })) {
                    XCTAssertEqual($0 as? Host.Boundary,.differentLoadingAttempt)
                }
                var missingLibrary = actual.match;missingLibrary.libraryCommands = nil
                for value in [self.changedReady(actual,match:missingLibrary),self.changedReady(actual,round:.init(continuation:.menu,stageDefeated:actual.round.stageDefeated))] {
                    XCTAssertThrowsError(try host.prepareLoadedUntilBoundary(prepare:{ _,_ in .gameplayInput(value) })) {
                        XCTAssertEqual($0 as? M.Boundary,.dependency("Installed gameplay continuation"))
                    }
                    try self.unchanged(host,old);controls += 1
                }
            }
        }
        driver.atGameplayReady = { d,ready in
            previous = ready
            guard d.gameplayInputs == 1 else { return }
            let old = try Saved(host)
            XCTAssertThrowsError(try host.prepareLoadedUntilBoundary(prepare:{ _,_ in XCTFail("Repeated acquisition");return .gameplayInput(ready) })) {
                XCTAssertEqual($0 as? Host.Boundary,.alreadyPreparedLoading)
            }
            XCTAssertThrowsError(try host.finishLoadedMenu(perform:{ _,_ in XCTFail("Tail before body");return .init() })) {
                XCTAssertEqual($0 as? Host.Boundary,.noPreparedLoading)
            }
            XCTAssertThrowsError(try host.resumeMatchLaunch(prepare:{ _,_ in XCTFail("Start consumer for Ready");return foreignReturn })) {
                XCTAssertEqual($0 as? Host.Boundary,.noPreparedMatchPrelude)
            }
            for value in [foreignReturn,try XCTUnwrap(sibling)] {
                XCTAssertThrowsError(try host.resumeGameplay(prepare:{ _,p in p.hostReservations.append(-731);return value })) {
                    XCTAssertEqual($0 as? Host.Boundary,.differentLoadingAttempt)
                }
                try self.unchanged(host,old);controls += 1
            }
            let actual = try self.body(ready)
            let unreturned = M.PendingReturn(entry:actual.entry,snapshot:actual.snapshot,exit:actual.exit,dispatcherResult:nil,graphics:actual.graphics)
            XCTAssertThrowsError(try host.resumeGameplay(prepare:{ _,_ in unreturned })) {
                XCTAssertEqual($0 as? Host.Boundary,.unreturnedLoading)
            }
            try self.unchanged(host,old)
        }
        try N().sequence(false,driver:driver);try counts(driver,17)
        XCTAssertEqual(preparations,17);XCTAssertEqual(bodies,17);XCTAssertEqual(controls,9)
        XCTAssertThrowsError(try host.prepareLoadedUntilBoundary(prepare:{ _,_ in XCTFail("Consumed acquisition");return .gameplayInput(foreignReady) })) {
            XCTAssertEqual($0 as? Host.Boundary,.noPendingLoading)
        }
        XCTAssertThrowsError(try host.resumeGameplay(prepare:{ _,_ in XCTFail("Consumed body");return foreignReturn })) {
            XCTAssertEqual($0 as? Host.Boundary,.noPendingLoading)
        }
        XCTAssertThrowsError(try host.finishLoadedMenu(perform:{ _,_ in XCTFail("Consumed tail");return .init() })) {
            XCTAssertEqual($0 as? Host.Boundary,.noPendingLoading)
        }
    }
}
