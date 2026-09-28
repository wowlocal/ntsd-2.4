import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalApplicationHostMatchLaunchTests: XCTestCase {
    typealias H = OriginalApplicationHostLoadingTests
    typealias Host = H.Host
    typealias D = OriginalApplicationLoadedTestDriver
    typealias C = OriginalApplicationLoadedCycleTests
    typealias M = OriginalApplicationLoadedMenuTests
    typealias S = OriginalApplicationLoadedSelectionTests
    typealias L = OriginalApplicationLoadedLaunchTests
    typealias R = OriginalApplicationLoadedLaunchComparison
    typealias Start = M.S.PendingMatchPrelude
    typealias Returned = M.S.PendingReturn
    typealias Stop = M.Stop

    func sameSnapshot(_ a: M.S.Snapshot,_ b: M.S.Snapshot) {
        OriginalApplicationCatalogSessionTests.retained(a.state,b.state)
        XCTAssertEqual(a.state.earlyScreen.bitmaps,b.state.earlyScreen.bitmaps)
        XCTAssertEqual(a.state.earlyScreen.surfaces,b.state.earlyScreen.surfaces)
        XCTAssertEqual(a.state.earlyScreen.retainedOperation,b.state.earlyScreen.retainedOperation)
        XCTAssertEqual(a.match.globals,b.match.globals);XCTAssertEqual(a.match.world,b.match.world)
        XCTAssertEqual(a.match.actors,b.match.actors);XCTAssertEqual(a.match.arithmeticPrecision,b.match.arithmeticPrecision)
        XCTAssertTrue(a.match.loadedObjects == b.match.loadedObjects)
        XCTAssertEqual(a.match.frameAllocations,b.match.frameAllocations)
        XCTAssertEqual(a.match.backgrounds,b.match.backgrounds);XCTAssertEqual(a.match.bitmaps,b.match.bitmaps)
        XCTAssertEqual(a.match.bitmapOwners,b.match.bitmapOwners);XCTAssertEqual(a.match.bitmapSurfaceOwners,b.match.bitmapSurfaceOwners)
        XCTAssertEqual(a.match.interface.bitmaps,b.match.interface.bitmaps);XCTAssertEqual(a.match.libraryCommands,b.match.libraryCommands)
        XCTAssertEqual(a.match.releasedBitmaps,b.match.releasedBitmaps);XCTAssertEqual(a.match.releasedBitmapOrder,b.match.releasedBitmapOrder)
        XCTAssertEqual(a.music.allocations,b.music.allocations);XCTAssertEqual(a.resources.bitmaps,b.resources.bitmaps)
        XCTAssertEqual(a.backgrounds,b.backgrounds);XCTAssertEqual(a.local,b.local);XCTAssertEqual(a.operations,b.operations)
    }
    func sameStart(_ a: Start,_ b: Start) {
        XCTAssertTrue(a.loading.isSameAttempt(as:b.loading));sameSnapshot(a.snapshot,b.snapshot)
        XCTAssertEqual(a.confirmation,b.confirmation);XCTAssertEqual(a.locals,b.locals);XCTAssertEqual(a.graphics,b.graphics)
    }
    func reentry(_ host: Host) {
        H().reentry(host)
        XCTAssertThrowsError(try host.prepareLoadedMenuUntilBoundary(prepare:{ _,_ in throw Stop.unexpected("Reentrant preparation") })) {
            XCTAssertEqual($0 as? Host.Boundary,.reentrantAttempt)
        }
        XCTAssertThrowsError(try host.resumeMatchLaunch(prepare:{ _,_ in throw Stop.unexpected("Reentrant launch") })) {
            XCTAssertEqual($0 as? Host.Boundary,.reentrantAttempt)
        }
        XCTAssertThrowsError(try host.preparedPlatformSnapshot()) { XCTAssertEqual($0 as? Host.Boundary,.reentrantAttempt) }
    }
    func unlaunched(_ host: Host,_ pending: Start) throws {
        sameStart(try XCTUnwrap(host.preparedMatchPrelude),pending)
        XCTAssertTrue(host.preparedLoadedMenu == nil)
        XCTAssertThrowsError(try host.finishLoadedMenu(perform:{ _,_ in XCTFail("Unreturned Start tail");return .init() })) {
            XCTAssertEqual($0 as? Host.Boundary,.noPreparedLoading)
        }
        XCTAssertThrowsError(try host.prepareLoadedMenuUntilBoundary(prepare:{ _,_ in XCTFail("Repeated Start");return .matchPrelude(pending) })) {
            XCTAssertEqual($0 as? Host.Boundary,.alreadyPreparedLoading)
        }
    }
    func launch(_ host: Host,_ r: R,stop: String? = nil,failPrepared: Bool = false) throws -> Returned {
        var observed: L.Environment?
        let result = try host.resumeMatchLaunch(prepare:{ pending,p in
            self.sameStart(pending,r.initial);self.reentry(host)
            p.hostReservations.append(-500);p.hostQueuePosition += 1
            var session = try L.L(pending:pending),env = L.Environment(stop:stop)
            let returned = try L().launch(&session,&env,r)
            p.hostReservations += [env.layers,env.api,env.music,env.recordings,env.clocks]
            observed = env;return returned
        },beforePrepared:{ _,p in
            self.reentry(host);p.hostReservations.append(-501)
            if failPrepared { throw Stop.injected("hostPrepared") }
        })
        try L().compare(result,XCTUnwrap(observed),r)
        XCTAssertTrue(host.preparedMatchPrelude == nil)
        XCTAssertTrue(try XCTUnwrap(host.preparedLoadedMenu).loading.isSameAttempt(as:r.initial.loading))
        return result
    }
    func nextInput(_ driver: D,_ returned: Returned,_ r: R) throws {
        let host = try XCTUnwrap(driver.host)
        try driver.next()
        let before = host.snapshot,platform = try XCTUnwrap(host.pendingPlatformSnapshot())
        var checked = false
        // Inspect the actual next input inside its host context. Gameplay body
        // retention is a later API; this injected stop is not a completed tick.
        XCTAssertThrowsError(try host.prepareLoadedMenuUntilBoundary(prepare:{ context,p in
            var cycle = try XCTUnwrap(context.cycle),input = C.InputEnvironment()
            let next = try C.input(&cycle,&input)
            let snapshot = M.S.Snapshot(state:next.state,match:next.match,music:next.music,resources:next.menuResources,
                backgrounds:next.menuBackgrounds,local:returned.snapshot.local,operations:[])
            try r.state(7,snapshot)
            XCTAssertEqual(next.round.continuation,.gameplay);XCTAssertFalse(next.paused)
            XCTAssertEqual(input.phases,[Int32](repeating:1,count:6));XCTAssertTrue(input.requests.isEmpty)
            XCTAssertEqual(next.commands,[UInt8](repeating:0,count:10));XCTAssertEqual(next.match.libraryCommands?.requestedObjectID,0)
            XCTAssertEqual(next.match.bitmapOwners,returned.snapshot.match.bitmapOwners)
            XCTAssertEqual(next.match.backgrounds,returned.snapshot.match.backgrounds);XCTAssertEqual(next.match.bitmaps,returned.snapshot.match.bitmaps)
            XCTAssertEqual(next.music.allocations,returned.snapshot.music.allocations)
            let recording = try XCTUnwrap(next.state.memory.allocations[R.replay]).storage
            var expected = try XCTUnwrap(returned.snapshot.state.memory.allocations[R.replay]).storage
            try expected.write(Int32(1000),at:0x14b8);try r.equal(recording,expected,"host first gameplay recording")
            XCTAssertEqual(try next.match.globals.integer(at:0x450bd0-0x44d000,as:Int32.self),1)
            p.hostReservations.append(-600);checked = true;throw Stop.injected("next gameplay input")
        })) { XCTAssertEqual($0 as? Stop,.injected("next gameplay input")) }
        XCTAssertTrue(checked);try C.unchanged(host.snapshot,before)
        H().samePlatform(try XCTUnwrap(host.pendingPlatformSnapshot()),platform)
        XCTAssertTrue(host.preparedMatchPrelude == nil);XCTAssertTrue(host.preparedLoadedMenu == nil)
        XCTAssertEqual(host.pendingBatchCount,0)
    }
    func testActualHostStartLaunchAndNextInputRetainWholeOwners() throws {
        for reverse in [false,true] {
            let driver = try D.selectedHost(reverse),host = try XCTUnwrap(driver.host)
            driver.beforePrepared = { _,_ in self.reentry(host) }
            _ = try S().sequence(reverse,driver:driver,onStart:{ before,pending in
                try self.unlaunched(host,pending);try C.unchanged(host.snapshot,before)
                let platform = try host.platformSnapshot(),count = host.pendingBatchCount,r = try R(reverse,pending)
                let returned = try self.launch(host,r)
                try C.unchanged(host.snapshot,before);H().samePlatform(try host.platformSnapshot(),platform)
                XCTAssertEqual(host.pendingBatchCount,count)
                try driver.finish(returned);try driver.rejectConsumed(returned)
                try self.nextInput(driver,returned,r)
            })
        }
    }
    func testStartLaunchAndOuterTailFailuresRetainHostStages() throws {
        let driver = try D.selectedHost(false),host = try XCTUnwrap(driver.host)
        driver.retainSelectionBatch = true
        _ = try S().sequence(false,driver:driver,atStartLoading:{ _ in
            let before = host.snapshot,platform = try host.platformSnapshot()
            let prefix = try XCTUnwrap(host.pendingPlatformSnapshot()),ticket = try XCTUnwrap(host.pendingLoading)
            XCTAssertEqual(host.pendingBatchCount,1)
            for stop in ["provider","matchPrelude","commit","hostPrepared"] {
                XCTAssertThrowsError(try host.prepareLoadedMenuUntilBoundary(prepare:{ context,p in
                    p.hostReservations.append(-700)
                    if stop == "provider" { throw Stop.injected(stop) }
                    var cycle = try XCTUnwrap(context.cycle),input = C.InputEnvironment()
                    let ready = try C.input(&cycle,&input)
                    var menu = try M.S(pending:ready),env = M.Environment(stop:stop)
                    return try M.advanceUntilBoundary(&menu,&env)
                },beforePrepared:{ _,p in p.hostReservations.append(-701);throw Stop.injected("hostPrepared") })) {
                    XCTAssertEqual($0 as? Stop,.injected(stop))
                }
                try C.unchanged(host.snapshot,before);H().samePlatform(try host.platformSnapshot(),platform)
                H().samePlatform(try XCTUnwrap(host.pendingPlatformSnapshot()),prefix)
                XCTAssertTrue(try XCTUnwrap(host.pendingLoading).isSameAttempt(as:ticket))
                XCTAssertTrue(host.preparedMatchPrelude == nil);XCTAssertTrue(host.preparedLoadedMenu == nil)
                XCTAssertTrue(try host.preparedPlatformSnapshot() == nil);XCTAssertEqual(host.pendingBatchCount,1)
            }
        },onStart:{ before,pending in
            let r = try R(false,pending),platform = try host.platformSnapshot()
            let prefix = try XCTUnwrap(host.pendingPlatformSnapshot()),startPlatform = try XCTUnwrap(host.preparedPlatformSnapshot())
            startPlatform.hostReservations.append(-999)
            XCTAssertFalse(try XCTUnwrap(host.preparedPlatformSnapshot()).hostReservations.contains(-999))
            let staged = try XCTUnwrap(host.preparedPlatformSnapshot())
            for stop in ["localTime","soundMethod","allocate14","createSurface14","colorKey14","music2","music7","music18","music19","resetInput","calloc","recording","method","clock","heldCleared","commit","hostPrepared"] {
                XCTAssertThrowsError(try self.launch(host,r,stop:stop,failPrepared:stop == "hostPrepared")) {
                    XCTAssertEqual($0 as? Stop,.injected(stop))
                }
                try self.unlaunched(host,pending);try C.unchanged(host.snapshot,before)
                H().samePlatform(try host.platformSnapshot(),platform);H().samePlatform(try XCTUnwrap(host.pendingPlatformSnapshot()),prefix)
                H().samePlatform(try XCTUnwrap(host.preparedPlatformSnapshot()),staged);XCTAssertEqual(host.pendingBatchCount,1)
            }
            let returned = try self.launch(host,r),prepared = try XCTUnwrap(host.preparedPlatformSnapshot())
            XCTAssertThrowsError(try host.resumeMatchLaunch(prepare:{ _,_ in XCTFail("Repeated successful launch");return returned })) {
                XCTAssertEqual($0 as? Host.Boundary,.noPreparedMatchPrelude)
            }
            let commitTime = Int32(bitPattern:try XCTUnwrap(before.session).loop.timer.baseline &+ 1000)
            for stop in ["time","sleep","commit"] {
                var calls: [String] = []
                XCTAssertThrowsError(try host.finishLoadedMenu(perform:{ q,p in
                    self.reentry(host);calls.append(q.kind.rawValue);p.hostQueuePosition += 1;p.hostReservations.append(-800)
                    if q.kind == .sleep { XCTAssertEqual(q.arguments,[5]);throw Stop.injected("sleep") }
                    if stop == "time" { throw Stop.injected("time") }
                    return .init(result:stop == "sleep" ? 1_000_000 : commitTime)
                },beforeCommit:{ _,_,p in self.reentry(host);p.hostReservations.append(-801);throw Stop.injected("commit") })) {
                    XCTAssertEqual($0 as? Stop,.injected(stop))
                }
                XCTAssertEqual(calls,stop == "sleep" ? ["time","sleep"] : ["time"])
                let retained = try XCTUnwrap(host.preparedLoadedMenu)
                self.sameSnapshot(retained.snapshot,returned.snapshot);XCTAssertEqual(retained.graphics,returned.graphics)
                XCTAssertTrue(host.preparedMatchPrelude == nil);try C.unchanged(host.snapshot,before)
                H().samePlatform(try host.platformSnapshot(),platform);H().samePlatform(try XCTUnwrap(host.pendingPlatformSnapshot()),prefix)
                H().samePlatform(try XCTUnwrap(host.preparedPlatformSnapshot()),prepared);XCTAssertEqual(host.pendingBatchCount,1)
            }
            try driver.finish(returned);try driver.rejectConsumed(returned)
            XCTAssertEqual(host.pendingBatchCount,0)
        })
    }
    func testMatchPreludeRejectsDifferentTicketsAndReentry() throws {
        var foreign: Start?
        _ = try S().sequence(true,onStart:{ _,pending in foreign = pending })
        let other = try XCTUnwrap(foreign),foreignReference = try R(true,other)
        var foreignLaunch = try L.L(pending:other),foreignEnvironment = L.Environment()
        let foreignReturn = try L().launch(&foreignLaunch,&foreignEnvironment,foreignReference)
        try L().compare(foreignReturn,foreignEnvironment,foreignReference)
        let driver = try D.selectedHost(false),host = try XCTUnwrap(driver.host)
        var sibling: Start?,siblingReturn: Returned?
        driver.beforePrepared = { _,_ in self.reentry(host) }
        _ = try S().sequence(false,driver:driver,atStartLoading:{ _ in
            var copy = host.snapshot
            let ticket = try C.next(&copy)
            XCTAssertFalse(ticket.isSameAttempt(as:try XCTUnwrap(host.pendingLoading)))
            var cycle = try copy.makeLoadedCycle(pending:ticket),input = C.InputEnvironment()
            let ready = try C.input(&cycle,&input)
            var menu = try M.S(pending:ready),env = M.Environment()
            guard case .matchPrelude(let alternate) = try M.advanceUntilBoundary(&menu,&env) else { throw Stop.unexpected("Sibling Start") }
            sibling = alternate
            let r = try R(false,alternate);var launch = try L.L(pending:alternate),e = L.Environment()
            siblingReturn = try L().launch(&launch,&e,r);try L().compare(XCTUnwrap(siblingReturn),e,r)
            let before = host.snapshot,prefix = try XCTUnwrap(host.pendingPlatformSnapshot())
            let outcomes: [M.S.Outcome] = [.matchPrelude(other),.matchPrelude(alternate),.returned(foreignReturn),.returned(try XCTUnwrap(siblingReturn))]
            for outcome in outcomes {
                XCTAssertThrowsError(try host.prepareLoadedMenuUntilBoundary(prepare:{ _,p in p.hostReservations.append(-900);return outcome },
                    beforePrepared:{ _,_ in XCTFail("Different ticket reached observer") })) {
                    XCTAssertEqual($0 as? Host.Boundary,.differentLoadingAttempt)
                }
                try C.unchanged(host.snapshot,before);H().samePlatform(try XCTUnwrap(host.pendingPlatformSnapshot()),prefix)
                XCTAssertTrue(host.preparedMatchPrelude == nil);XCTAssertTrue(host.preparedLoadedMenu == nil)
            }
        },onStart:{ before,pending in
            XCTAssertTrue(sibling != nil);try self.unlaunched(host,pending)
            let staged = try XCTUnwrap(host.preparedPlatformSnapshot())
            for wrong in [foreignReturn,try XCTUnwrap(siblingReturn)] {
                XCTAssertThrowsError(try host.resumeMatchLaunch(prepare:{ actual,p in
                    self.sameStart(actual,pending);p.hostReservations.append(-901);return wrong
                },beforePrepared:{ _,_ in XCTFail("Different launch ticket reached observer") })) {
                    XCTAssertEqual($0 as? Host.Boundary,.differentLoadingAttempt)
                }
                self.sameStart(try XCTUnwrap(host.preparedMatchPrelude),pending)
                H().samePlatform(try XCTUnwrap(host.preparedPlatformSnapshot()),staged);try C.unchanged(host.snapshot,before)
            }
            let returned = try self.launch(host,R(false,pending));try driver.finish(returned)
            XCTAssertThrowsError(try host.prepareLoadedMenuUntilBoundary(prepare:{ _,_ in .matchPrelude(pending) })) {
                XCTAssertEqual($0 as? Host.Boundary,.noPendingLoading)
            }
            XCTAssertThrowsError(try host.resumeMatchLaunch(prepare:{ _,_ in returned })) {
                XCTAssertEqual($0 as? Host.Boundary,.noPendingLoading)
            }
            try driver.rejectConsumed(returned);try driver.next()
            let fresh = try XCTUnwrap(host.pendingLoading)
            let staleOutcomes: [M.S.Outcome] = [.matchPrelude(pending),.returned(returned)]
            for stale in staleOutcomes {
                XCTAssertThrowsError(try host.prepareLoadedMenuUntilBoundary(prepare:{ _,_ in stale })) {
                    XCTAssertEqual($0 as? Host.Boundary,.differentLoadingAttempt)
                }
            }
            XCTAssertThrowsError(try host.resumeMatchLaunch(prepare:{ _,_ in returned })) {
                XCTAssertEqual($0 as? Host.Boundary,.noPreparedMatchPrelude)
            }
            XCTAssertTrue(try XCTUnwrap(host.pendingLoading).isSameAttempt(as:fresh))
            XCTAssertTrue(host.preparedMatchPrelude == nil);XCTAssertTrue(host.preparedLoadedMenu == nil)
            XCTAssertEqual(host.pendingBatchCount,0)
        })
    }
}
