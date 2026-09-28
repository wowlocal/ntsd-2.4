import Foundation
import XCTest
@testable import NTSDCore

final class OriginalApplicationHostLoadingTests: XCTestCase {
    typealias H = OriginalApplicationHostSessionTests
    typealias Host = H.Host
    typealias S = H.S
    typealias C = OriginalApplicationLoadedCycleTests
    typealias M = OriginalApplicationLoadedMenuTests
    typealias Q = OriginalApplicationMenuInputTests
    typealias P = H.Parent.Adapter
    typealias Returned = M.S.PendingReturn
    enum Stop: Error, Equatable { case injected(String) }

    func atLoading(before: ((Host,Host.Inputs) throws -> Void)? = nil) throws -> Host {
        let f = try H.Bootstrap.F.Resources(),b = try H.Bootstrap.Body.Resources(f)
        let m = try H.Bootstrap.M.Resources(b,f),r = try Q.Resources(m)
        let br = try H.Bootstrap.B.Resources(),er = try H.Bootstrap.Entry.Resources()
        var result: Host?
        // Finish every unchanged source-parent comparison before continuing.
        try Q().run(47,r,m,b,f,br,er,useHost:true,hostAtLoading:{ result = $0 },beforeHostLoading:before)
        let host = try XCTUnwrap(result)
        XCTAssertNotNil(host.pendingLoading);XCTAssertNil(host.preparedLoadedMenu)
        XCTAssertEqual(host.pendingBatchCount,0)
        return host
    }
    func samePlatform(_ a: P,_ b: P) {
        XCTAssertEqual(a.hostQueuePosition,b.hostQueuePosition)
        XCTAssertEqual(a.hostReservations,b.hostReservations)
        XCTAssertEqual(a.index,b.index);XCTAssertEqual(a.waves,b.waves);XCTAssertEqual(a.shadow,b.shadow)
    }
    func reentry(_ host: Host) {
        XCTAssertThrowsError(try host.takeCommitted()) { XCTAssertEqual($0 as? Host.Boundary,.reentrantAttempt) }
        XCTAssertThrowsError(try host.prepareLoadedMenu(prepare:{ _,_ in throw Stop.injected("unexpected preparation") })) {
            XCTAssertEqual($0 as? Host.Boundary,.reentrantAttempt)
        }
        XCTAssertThrowsError(try host.finishLoadedMenu(perform:{ _,_ in throw Stop.injected("unexpected tail") })) {
            XCTAssertEqual($0 as? Host.Boundary,.reentrantAttempt)
        }
    }
    func child(_ context: Host.LoadingContext,_ platform: P,reverse: Bool,cycleIndex: Int? = nil) throws -> Returned {
        platform.hostReservations.append(-100)
        let ready: M.S.Input.PendingContinuation
        if var cycle = context.cycle {
            let index = try XCTUnwrap(cycleIndex),owners = cycle.owners
            var input = C.InputEnvironment()
            ready = try C.input(&cycle,&input)
            XCTAssertEqual(input.phases,[Int32](repeating:Int32(index % 2),count:6))
            XCTAssertEqual(input.requests.count,index % 2 == 0 ? 4 : 0)
            let controls = input.requests.enumerated().map { i,q in
                C.C.Input.Operation.control(q,.init(result:[-1,1,-1,0][i],bytes:i == 3 ? [120,86,52,18] : []))
            }
            XCTAssertEqual(Array(ready.operations.dropFirst(context.entry.stagedEffects.count)),controls)
            XCTAssertEqual(ready.match.frameAllocations,owners.match.frameAllocations)
            XCTAssertEqual(ready.match.backgrounds,owners.match.backgrounds)
            XCTAssertEqual(ready.music.allocations,owners.music.allocations)
            XCTAssertEqual(ready.match.arithmeticPrecision,.bits53)
            XCTAssertEqual(try ready.match.actors[0].integer(at:0xd1,as:UInt8.self),index >= 2 ? 1 : 0)
            platform.hostQueuePosition += input.requests.count
        } else {
            XCTAssertNil(cycleIndex)
            ready = try C.firstInput(context.entry,context.startup)
        }
        XCTAssertTrue(ready.loading.isSameAttempt(as:context.entry))
        let prefix = context.entry.stagedEffects.map { effect -> M.S.Input.Operation in
            if context.cycle != nil { return .menu(effect) }
            return .preceding(.preceding(.preceding(.menu(effect))))
        }
        XCTAssertEqual(Array(ready.operations.prefix(context.entry.stagedEffects.count)),prefix)
        var menu = try M.S(pending:ready),env = M.Environment(reverse:reverse)
        if cycleIndex == 3 {
            XCTAssertEqual(try ready.match.globals.integer(at:0x20,as:Int32.self),3)
            let initial = env
            XCTAssertThrowsError(try M.advance(&menu,&env,character:{ _,_,_ in throw Stop.injected("selected input boundary") })) {
                XCTAssertEqual($0 as? Stop,.injected("selected input boundary"))
            }
            XCTAssertNil(menu.pendingReturn);XCTAssertEqual(env,initial)
            throw Stop.injected("selected input boundary")
        }
        let returned = try M.advance(&menu,&env)
        XCTAssertEqual(returned.exit,.returned);XCTAssertEqual(returned.dispatcherResult,1)
        XCTAssertEqual(Array(returned.snapshot.operations.prefix(ready.operations.count)),ready.operations.map(M.S.Operation.preceding))
        XCTAssertEqual(Array(returned.graphics.prefix(ready.graphics.count)),ready.graphics)
        if let index = cycleIndex,let cycle = context.cycle {
            XCTAssertEqual(Array(returned.snapshot.operations.dropFirst(ready.operations.count)),env.expectedOperations)
            XCTAssertEqual(env.index,-1);XCTAssertEqual(env.api,0);XCTAssertTrue(env.music.isEmpty)
            XCTAssertEqual(returned.snapshot.resources.bitmaps,cycle.owners.resources.bitmaps)
            XCTAssertEqual(returned.snapshot.music.allocations,cycle.owners.music.allocations)
            XCTAssertEqual(try returned.snapshot.match.globals.integer(at:0x20,as:Int32.self),index == 2 ? 3 : 10)
            if index == 2 {
                let events = env.front
                let draw = try XCTUnwrap(events.firstIndex { $0.kind == "blit" && $0.blit?.sourceSurface == 0x7f2000b0 })
                let release = try XCTUnwrap(events.firstIndex { $0.kind == "method" && $0.arguments == [0x7f2000b0,8] })
                let free = try XCTUnwrap(events.firstIndex { $0.kind == "free" && $0.arguments == [0x7e230020] })
                XCTAssertLessThan(draw,release);XCTAssertLessThan(release,free)
                XCTAssertEqual(returned.snapshot.state.memory.allocations[0x7e230020]?.live,false)
                XCTAssertEqual(try returned.snapshot.state.memory.allocations[0x7e230020]?.storage.integer(at:0,as:UInt32.self),0)
                XCTAssertEqual(try returned.snapshot.match.globals.integer(at:0x4511ac-0x44d000,as:UInt32.self),0)
            } else {
                XCTAssertEqual(returned.snapshot.state.memory.allocations[0x7e230020],context.entry.state.memory.allocations[0x7e230020])
            }
        } else {
            try M().compareSavedBitmaps(returned,env)
            XCTAssertEqual(env.index,11);XCTAssertEqual(env.api,204)
            XCTAssertEqual(returned.snapshot.match.actors,ready.match.actors)
            XCTAssertEqual(returned.snapshot.match.world,ready.match.world)
            XCTAssertEqual(returned.snapshot.match.frameAllocations,ready.match.frameAllocations)
            XCTAssertEqual(returned.snapshot.state.random,ready.state.random)
            for (token,allocation) in ready.state.memory.allocations {
                XCTAssertEqual(returned.snapshot.state.memory.allocations[token],allocation)
            }
        }
        try M().compareGraphics(returned,env)
        return returned
    }
    @discardableResult
    func prepare(_ host: Host,reverse: Bool = false,cycleIndex: Int? = nil,
        fail: Bool = false) throws -> Returned {
        let before = host.snapshot,platform = try host.platformSnapshot(),batches = host.pendingBatchCount
        let returned = try host.prepareLoadedMenu(prepare:{ context,p in
            self.reentry(host)
            return try self.child(context,p,reverse:reverse,cycleIndex:cycleIndex)
        },beforePrepared:{ _,p in
            p.hostReservations.append(-101)
            if fail { throw Stop.injected("prepared") }
        })
        try C.unchanged(host.snapshot,before);samePlatform(try host.platformSnapshot(),platform)
        XCTAssertEqual(host.pendingBatchCount,batches)
        XCTAssertTrue(try XCTUnwrap(host.preparedLoadedMenu).loading.isSameAttempt(as:returned.loading))
        return returned
    }
    @discardableResult
    func finish(_ host: Host,olderSequence: UInt64? = nil) throws -> Returned {
        let child = try XCTUnwrap(host.preparedLoadedMenu),before = host.snapshot
        let prepared = try XCTUnwrap(host.preparedPlatformSnapshot())
        let time = try XCTUnwrap(before.session).loop.timer.baseline &+ 1000
        let oldCount = host.pendingBatchCount
        let outcome = try host.finishLoadedMenu(perform:{ q,p in
            XCTAssertEqual(q.kind,.time);p.hostQueuePosition += 1
            return .init(result:Int32(bitPattern:time))
        },beforeCommit:{ _,_,p in
            self.reentry(host);p.hostReservations.append(-200)
        })
        guard case .committed(let sequence,let result) = outcome else { throw Stop.injected("missing loaded commit") }
        XCTAssertEqual(result,.continued);XCTAssertEqual(host.pendingBatchCount,oldCount+1)
        if let olderSequence {
            let older = try XCTUnwrap(host.takeCommitted());XCTAssertEqual(older.sequence,olderSequence)
            guard case .iteration(let key) = older.contents else { throw Stop.injected("lost prior batch") }
            XCTAssertEqual(key.effects.count,1);XCTAssertEqual(key.result,.continued)
        }
        let batch = try XCTUnwrap(host.takeCommitted());XCTAssertEqual(batch.sequence,sequence)
        guard case .loaded(let value) = batch.contents else { throw Stop.injected("wrong loaded batch") }
        try C.checkFinished(host.snapshot,child,value,time:time)
        let after = try host.platformSnapshot()
        XCTAssertEqual(after.hostQueuePosition,prepared.hostQueuePosition+1)
        XCTAssertEqual(after.hostReservations,prepared.hostReservations+[-200])
        XCTAssertNil(host.pendingLoading);XCTAssertNil(host.preparedLoadedMenu)
        XCTAssertNil(try host.pendingPlatformSnapshot());XCTAssertNil(try host.preparedPlatformSnapshot())
        XCTAssertNil(try host.takeCommitted())
        try H.Bootstrap.sameStartup(XCTUnwrap(host.snapshot.startup),XCTUnwrap(before.startup))
        return child
    }
    func next(_ host: Host) throws {
        let before = host.snapshot,time = Int32(bitPattern:try XCTUnwrap(before.session).loop.timer.baseline &+ 1000)
        let result = try host.step(prepare:{ p,_ in
            p.hostQueuePosition += 4;p.hostReservations.append(-90)
            return .init(responses:C.responses,queue:[.init(),.init(result:time),.init(result:time),.init(result:time)],surface:[.init()])
        })
        guard case .loading = result else { throw Stop.injected("missing loading") }
        try C.unchanged(host.snapshot,before)
    }
    @discardableResult
    func key(_ host: Host,_ message: UInt32,drain: Bool = true) throws -> UInt64 {
        let state = try XCTUnwrap(host.snapshot.session).state
        let status = try state.full.integer(at:0x450b4c-0x44d000,as:UInt32.self)
        let key = try state.full.integer(at:0x44fb20-0x44d000+Int(status)*80+20,as:UInt32.self)
        XCTAssertEqual(key,74)
        var bytes = [UInt8](repeating:0,count:28)
        for (offset,value) in [(0,try state.full.integer(at:0x4546f4-0x44d000,as:UInt32.self)),(4,message),(8,key)] {
            for i in 0..<4 { bytes[offset+i] = UInt8(truncatingIfNeeded:value >> (8*i)) }
        }
        let result = try host.step(prepare:{ p,_ in
            p.hostQueuePosition += 4
            return .init(responses:C.responses,queue:[.init(result:1),.init(result:1,writes:[.init(offset:0,bytes:bytes)]),.init(),.init()],windowDefault:[0])
        })
        guard case .committed(let sequence,_) = result else { throw Stop.injected("key not committed") }
        XCTAssertEqual(try host.snapshot.session?.state.full.integer(at:0x455378-0x44d000+Int(key),as:UInt8.self),message == 0x100 ? 100 : 117)
        if drain {
            let batch = try XCTUnwrap(host.takeCommitted());XCTAssertEqual(batch.sequence,sequence)
            guard case .iteration(let value) = batch.contents else { throw Stop.injected("key batch") }
            XCTAssertEqual(value.effects.count,1);XCTAssertNil(try host.takeCommitted())
        }
        return sequence
    }

    func testOwnFreshLoadingAndThreeCachedCyclesUseHostHandoff() throws {
        for reverse in [false,true] {
            let host = try atLoading();try prepare(host,reverse:reverse);try finish(host)
            for index in 0..<4 {
                if index == 1 { try key(host,0x100) }
                if index == 3 { try key(host,0x101) }
                try next(host)
                if index == 3 {
                    let before = host.snapshot,pending = try XCTUnwrap(host.pendingLoading)
                    let platform = try XCTUnwrap(host.pendingPlatformSnapshot())
                    XCTAssertThrowsError(try prepare(host,reverse:reverse,cycleIndex:index)) {
                        XCTAssertEqual($0 as? Stop,.injected("selected input boundary"))
                    }
                    try C.unchanged(host.snapshot,before);samePlatform(try XCTUnwrap(host.pendingPlatformSnapshot()),platform)
                    XCTAssertNil(host.preparedLoadedMenu);XCTAssertEqual(host.pendingBatchCount,0)
                    XCTAssertTrue(try XCTUnwrap(host.pendingLoading).isSameAttempt(as:pending))
                } else {
                    try prepare(host,reverse:reverse,cycleIndex:index);try finish(host)
                }
            }
        }
    }
    func testPreparedChildAndPlatformSurviveLateFailuresAndRetry() throws {
        let host = try atLoading();try prepare(host);try finish(host)
        let older = try key(host,0x101,drain:false);try next(host)
        let before = host.snapshot,platform = try host.platformSnapshot()
        let pending = try XCTUnwrap(host.pendingLoading),pendingPlatform = try XCTUnwrap(host.pendingPlatformSnapshot())
        XCTAssertThrowsError(try prepare(host,cycleIndex:0,fail:true)) { XCTAssertEqual($0 as? Stop,.injected("prepared")) }
        XCTAssertNil(host.preparedLoadedMenu);samePlatform(try XCTUnwrap(host.pendingPlatformSnapshot()),pendingPlatform)
        try C.unchanged(host.snapshot,before);samePlatform(try host.platformSnapshot(),platform)
        XCTAssertEqual(host.pendingBatchCount,1)
        let child = try prepare(host,cycleIndex:0),prepared = try XCTUnwrap(host.preparedPlatformSnapshot())
        prepared.hostReservations.append(-999)
        XCTAssertFalse(try XCTUnwrap(host.preparedPlatformSnapshot()).hostReservations.contains(-999))
        let saved = try XCTUnwrap(host.preparedPlatformSnapshot())
        XCTAssertThrowsError(try host.prepareLoadedMenu(prepare:{ _,_ in XCTFail("Repeated child ran");return child })) {
            XCTAssertEqual($0 as? Host.Boundary,.alreadyPreparedLoading)
        }
        for stop in ["time","sleep","commit"] {
            var calls: [String] = []
            XCTAssertThrowsError(try host.finishLoadedMenu(perform:{ q,p in
                calls.append(q.kind.rawValue);p.hostQueuePosition += 1;p.hostReservations.append(-300)
                if q.kind == .sleep { XCTAssertEqual(q.arguments,[5]);throw Stop.injected("sleep") }
                if stop == "time" { throw Stop.injected("time") }
                return .init(result:stop == "sleep" ? 1_000_000 : 123_499_999)
            },beforeCommit:{ _,_,p in p.hostReservations.append(-301);throw Stop.injected("commit") })) {
                XCTAssertEqual($0 as? Stop,.injected(stop))
            }
            XCTAssertEqual(calls,stop == "sleep" ? ["time","sleep"] : ["time"])
            try C.unchanged(host.snapshot,before);samePlatform(try host.platformSnapshot(),platform)
            samePlatform(try XCTUnwrap(host.pendingPlatformSnapshot()),pendingPlatform)
            samePlatform(try XCTUnwrap(host.preparedPlatformSnapshot()),saved)
            XCTAssertTrue(try XCTUnwrap(host.preparedLoadedMenu).loading.isSameAttempt(as:child.loading))
            XCTAssertTrue(try XCTUnwrap(host.pendingLoading).isSameAttempt(as:pending))
            XCTAssertEqual(host.pendingBatchCount,1)
        }
        try finish(host,olderSequence:older)
        XCTAssertThrowsError(try host.finishLoadedMenu(perform:{ _,_ in XCTFail("Repeated tail ran");return .init() })) {
            XCTAssertEqual($0 as? Host.Boundary,.noPendingLoading)
        }
    }
    func testDifferentSameRevisionTicketsAndRepeatedCompletionAreRejected() throws {
        let host = try atLoading(),entry = try XCTUnwrap(host.pendingLoading)
        XCTAssertTrue(entry.isSameAttempt(as:entry))
        XCTAssertThrowsError(try host.finishLoadedMenu(perform:{ _,_ in XCTFail("Unprepared tail ran");return .init() })) {
            XCTAssertEqual($0 as? Host.Boundary,.noPreparedLoading)
        }
        var siblingOwner = host.snapshot
        let sibling = try C.next(&siblingOwner)
        XCTAssertFalse(sibling.isSameAttempt(as:entry))
        let before = host.snapshot,staged = try XCTUnwrap(host.pendingPlatformSnapshot())
        var alternate: Returned?
        XCTAssertThrowsError(try host.prepareLoadedMenu(prepare:{ context,p in
            p.hostReservations.append(-777)
            let ready = try C.firstInput(sibling,context.startup)
            var menu = try M.S(pending:ready),env = M.Environment()
            let child = try M.advance(&menu,&env);alternate = child;return child
        })) { XCTAssertEqual($0 as? Host.Boundary,.differentLoadingAttempt) }
        XCTAssertTrue(alternate != nil);XCTAssertNil(host.preparedLoadedMenu)
        try C.unchanged(host.snapshot,before);samePlatform(try XCTUnwrap(host.pendingPlatformSnapshot()),staged)
        let child = try prepare(host)
        XCTAssertTrue(child.loading.isSameAttempt(as:entry))
        let foreign = try atLoading()
        XCTAssertThrowsError(try foreign.prepareLoadedMenu(prepare:{ _,_ in child })) {
            XCTAssertEqual($0 as? Host.Boundary,.differentLoadingAttempt)
        }
        XCTAssertNil(foreign.preparedLoadedMenu);XCTAssertEqual(foreign.pendingBatchCount,0)
        try finish(host)
        XCTAssertThrowsError(try host.prepareLoadedMenu(prepare:{ _,_ in child })) {
            XCTAssertEqual($0 as? Host.Boundary,.noPendingLoading)
        }
        XCTAssertThrowsError(try host.finishLoadedMenu(perform:{ _,_ in XCTFail("Consumed tail ran");return .init() })) {
            XCTAssertEqual($0 as? Host.Boundary,.noPendingLoading)
        }
        try next(host)
        let fresh = try XCTUnwrap(host.pendingLoading)
        XCTAssertThrowsError(try host.prepareLoadedMenu(prepare:{ _,_ in child })) {
            XCTAssertEqual($0 as? Host.Boundary,.differentLoadingAttempt)
        }
        XCTAssertTrue(try XCTUnwrap(host.pendingLoading).isSameAttempt(as:fresh))
        XCTAssertNil(host.preparedLoadedMenu);XCTAssertEqual(host.pendingBatchCount,0)
    }
    func testLoadingPrefixRequiresExactlyItsPreparedReplies() throws {
        var controls = 0
        let host = try atLoading(before:{ driver,packet in
            let before = driver.snapshot,platform = try driver.platformSnapshot(),batches = driver.pendingBatchCount
            XCTAssertFalse(packet.queue.isEmpty);XCTAssertFalse(packet.surface.isEmpty)
            for kind in ["extraQueue","extraWindow","extraSurface","extraLifecycle","missingQueue","missingSurface"] {
                let bad = Host.Inputs(initialization:packet.initialization,responses:packet.responses,
                    queue:kind == "extraQueue" ? packet.queue+[.init()] : kind == "missingQueue" ? Array(packet.queue.dropLast()) : packet.queue,
                    windowDefault:packet.windowDefault+(kind == "extraWindow" ? [0] : []),
                    surface:kind == "extraSurface" ? packet.surface+[.init()] : kind == "missingSurface" ? [] : packet.surface,
                    lifecycle:packet.lifecycle+(kind == "extraLifecycle" ? [.init()] : []))
                XCTAssertThrowsError(try driver.step(prepare:{ p,_ in p.hostReservations.append(-888);return bad })) { error in
                    let expected = kind == "missingQueue" ? "Bootstrap queue response" : kind == "missingSurface" ? "Bootstrap surface response" : "Unused bootstrap iteration responses"
                    XCTAssertEqual(error as? S.Boundary,.dependency(expected))
                }
                try C.unchanged(driver.snapshot,before);self.samePlatform(try driver.platformSnapshot(),platform)
                XCTAssertNil(driver.pendingLoading);XCTAssertNil(driver.preparedLoadedMenu)
                XCTAssertEqual(driver.pendingBatchCount,batches);controls += 1
            }
        })
        XCTAssertEqual(controls,6);XCTAssertNotNil(host.pendingLoading);XCTAssertNil(host.preparedLoadedMenu)
    }
}
