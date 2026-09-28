import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

/// Test transport only. The existing character/selection comparators run inside
/// the actual host preparation. No Bootstrap snapshot is installed into a host.
final class OriginalApplicationLoadedTestDriver {
    typealias H = OriginalApplicationHostLoadingTests
    typealias C = OriginalApplicationLoadedCycleTests
    typealias M = OriginalApplicationLoadedMenuTests
    typealias A = OriginalApplicationBootstrap
    typealias Ready = M.S.Input.PendingContinuation
    let host: H.Host?
    private var original: A
    private var initial: Ready?
    private var loading: C.Session.PendingLoading?
    var beforePrepared: ((M.S.Outcome,H.P) throws -> Void)?
    var retainSelectionBatch = false
    var retainGameplayParentBatch = false
    var atGameplayLoading: ((OriginalApplicationLoadedTestDriver) throws -> Void)?
    var atGameplayReady: ((OriginalApplicationLoadedTestDriver,Ready) throws -> Void)?
    var atGameplayReturn: ((OriginalApplicationLoadedTestDriver,M.S.PendingReturn) throws -> Void)?
    var beforeGameplayInput: ((Ready,H.P) throws -> Void)?
    var beforeGameplayBody: ((M.S.PendingReturn,H.P) throws -> Void)?
    var gameplayInputs = 0,gameplayBodies = 0,gameplayReturns = 0

    private var batchChecks: [(UInt64,(H.Host.Batch) throws -> Void)] = []
    var core: A { host?.snapshot ?? original }

    init(application: A,initial: Ready? = nil) { host = nil;original = application;self.initial = initial }
    init(host: H.Host) { self.host = host;original = A() }
    static func selected(_ reverse: Bool) throws -> OriginalApplicationLoadedTestDriver {
        let (app,ready) = try OriginalApplicationLoadedCharacterTests.selected(reverse)
        return .init(application:app,initial:ready)
    }
    static func selectedHost(_ reverse: Bool) throws -> OriginalApplicationLoadedTestDriver {
        let checks = H(),host = try checks.atLoading()
        try checks.prepare(host,reverse:reverse);try checks.finish(host)
        for index in 0..<4 {
            if index == 1 { try checks.key(host,0x100) }
            if index == 3 { try checks.key(host,0x101) }
            try checks.next(host)
            if index < 3 { try checks.prepare(host,reverse:reverse,cycleIndex:index);try checks.finish(host) }
        }
        return .init(host:host)
    }
    @discardableResult
    func next() throws -> C.Session.PendingLoading {
        if let host { try H().next(host);return try XCTUnwrap(host.pendingLoading) }
        loading = try C.next(&original);return try XCTUnwrap(loading)
    }
    func prepareGameplay(_ input: (inout OriginalApplicationLoadedCycleSession) throws -> Ready) throws -> Ready {
        try atGameplayLoading?(self)
        let ready: Ready
        if let host {
            let result = try host.prepareLoadedUntilBoundary(prepare:{ context,p in
                var cycle = try XCTUnwrap(context.cycle)
                let value = try input(&cycle)
                XCTAssertTrue(value.loading.isSameAttempt(as:context.entry))
                p.hostReservations.append(-600)
                return .gameplayInput(value)
            },beforePrepared:{ outcome,p in
                guard case .gameplayInput(let value) = outcome else { throw M.Stop.unexpected("Gameplay Ready outcome") }
                try self.beforeGameplayInput?(value,p)
            })
            guard case .gameplayInput(let value) = result else { throw M.Stop.unexpected("Gameplay not retained") }
            ready = value
            XCTAssertTrue(host.preparedLoadedMenu == nil && host.preparedMatchPrelude == nil)
            XCTAssertTrue(try XCTUnwrap(host.preparedGameplayInput).loading.isSameAttempt(as:ready.loading))
        } else {
            var cycle = try original.makeLoadedCycle(pending:XCTUnwrap(loading))
            ready = try input(&cycle)
        }
        gameplayInputs += 1;return ready
    }
    func gameplay(_ ready: Ready,_ body: (Ready) throws -> M.S.PendingReturn) throws -> M.S.PendingReturn {
        try atGameplayReady?(self,ready)
        let result: M.S.PendingReturn
        if let host {
            result = try host.resumeGameplay(prepare:{ retained,p in
                XCTAssertTrue(retained.loading.isSameAttempt(as:ready.loading))
                p.hostReservations.append(-601)
                return try body(retained)
            },beforePrepared:{ returned,p in try self.beforeGameplayBody?(returned,p) })
            XCTAssertTrue(host.preparedGameplayInput == nil && host.preparedMatchPrelude == nil)
        } else { result = try body(ready) }
        gameplayBodies += 1
        try atGameplayReturn?(self,result)
        return result
    }
    @discardableResult
    func key(_ message: UInt32,_ key: UInt32,drain: Bool = true) throws -> UInt64? {
        guard let host else { try C.key(&original,message,key);return nil }
        let state = try XCTUnwrap(core.session).state
        var bytes = [UInt8](repeating:0,count:28)
        for (offset,value) in [(0,try state.full.integer(at:0x4546f4-0x44d000,as:UInt32.self)),(4,message),(8,key)] {
            for i in 0..<4 { bytes[offset+i] = UInt8(truncatingIfNeeded:value >> (8*i)) }
        }
        var windowCalls = 0
        let result = try host.step(prepare:{ p,_ in
            p.hostQueuePosition += 4
            return .init(responses:C.responses,queue:[.init(result:1),.init(result:1,writes:[.init(offset:0,bytes:bytes)]),.init(),.init()],windowDefault:[0])
        },observe:{ event in
            if case .windowResponse(let q,let r) = event {
                windowCalls += 1;XCTAssertEqual(q.kind,.windowDefault)
                XCTAssertEqual(q.arguments,[try state.full.integer(at:0x4546f4-0x44d000,as:UInt32.self),message,key,0])
                XCTAssertEqual(r,0)
            }
        })
        XCTAssertEqual(windowCalls,1)
        guard case .committed(let sequence,_) = result else { throw M.Stop.unexpected("Host key not committed") }
        XCTAssertEqual(try host.snapshot.session?.state.full.integer(at:0x455378-0x44d000+Int(key),as:UInt8.self),message == 0x100 ? 100 : 117)
        if drain {
            let batch = try XCTUnwrap(host.takeCommitted());XCTAssertEqual(batch.sequence,sequence)
            guard case .iteration(let value) = batch.contents else { throw M.Stop.unexpected("Host key batch") }
            XCTAssertEqual(value.effects.count,1);XCTAssertTrue(try host.takeCommitted() == nil)
        }
        return sequence
    }
    func acquire(_ acquired: [CharacterScreenReference.Acquired]) throws {
        for input in acquired {
            let state = try XCTUnwrap(core.session).state.full
            let status = try state.integer(at:0x450b4c-0x44d000+input.seat*4,as:UInt32.self)
            let config = 0x44fb20-0x44d000+Int(status)*80
            XCTAssertEqual(try state.integer(at:config,as:UInt32.self),0)
            let key = try state.integer(at:config+4+input.button*4,as:UInt32.self)
            XCTAssertEqual(input.address,0x455378+key);XCTAssertEqual(input.bytes,input.pressed ? "64" : "75")
            try self.key(input.pressed ? 0x100 : 0x101,key)
        }
    }
    func prepare(phase: Int32,_ body: (Ready) throws -> M.S.Outcome) throws -> M.S.Outcome {
        if let host {
            return try host.prepareLoadedMenuUntilBoundary(prepare:{ context,p in
                var cycle = try XCTUnwrap(context.cycle),input = C.InputEnvironment()
                let ready = try C.input(&cycle,&input)
                XCTAssertEqual(input.phases,[Int32](repeating:phase,count:6))
                XCTAssertTrue(ready.loading.isSameAttempt(as:context.entry))
                p.hostQueuePosition += input.requests.count;p.hostReservations.append(-400)
                return try body(ready)
            },beforePrepared:{ outcome,p in try self.beforePrepared?(outcome,p) })
        }
        let ready: Ready
        if let initial { ready = initial;self.initial = nil }
        else {
            var cycle = try original.makeLoadedCycle(pending:XCTUnwrap(loading)),input = C.InputEnvironment()
            ready = try C.input(&cycle,&input)
            XCTAssertEqual(input.phases,[Int32](repeating:phase,count:6))
        }
        return try body(ready)
    }
    func finish(_ returned: M.S.PendingReturn,stop: String? = nil,retainBatch: Bool = false) throws {
        if let host {
            XCTAssertTrue(try XCTUnwrap(host.preparedLoadedMenu).loading.isSameAttempt(as:returned.loading))
            let before = host.snapshot,prepared = try XCTUnwrap(host.preparedPlatformSnapshot())
            let time = try XCTUnwrap(before.session).loop.timer.baseline &+ 1000
            let count = host.pendingBatchCount
            if let stop {
                _ = try host.finishLoadedMenu(perform:{ q,p in
                    p.hostQueuePosition += 1;p.hostReservations.append(-602)
                    if q.kind.rawValue == stop { throw C.Stop.injected(stop) }
                    guard q.kind == .time || q.kind == .sleep else { throw C.Stop.unexpected("Outer gameplay tail") }
                    return .init(result:stop == "sleep" ? 1_000_000 : Int32(bitPattern:time))
                },beforeCommit:{ _,_,p in p.hostReservations.append(-603);if stop == "commit" { throw C.Stop.injected(stop) } })
                throw C.Stop.unexpected("Requested outer failure did not occur")
            }
            let outcome = try host.finishLoadedMenu(perform:{ q,p in
                XCTAssertEqual(q.kind,.time);p.hostQueuePosition += 1
                return .init(result:Int32(bitPattern:time))
            },beforeCommit:{ _,_,p in p.hostReservations.append(-200) })
            guard case .committed(let sequence,let result) = outcome else { throw M.Stop.unexpected("Loaded host commit") }
            XCTAssertEqual(result,.continued);XCTAssertEqual(host.pendingBatchCount,count+1)
            let committed = host.snapshot
            batchChecks.append((sequence,{ batch in
                XCTAssertEqual(batch.sequence,sequence)
                guard case .loaded(let value) = batch.contents else { throw M.Stop.unexpected("Loaded host batch") }
                try C.checkFinished(committed,returned,value,time:time)
            }))
            let platform = try host.platformSnapshot()
            XCTAssertEqual(platform.hostQueuePosition,prepared.hostQueuePosition+1)
            XCTAssertEqual(platform.hostReservations,prepared.hostReservations+[-200])
            XCTAssertTrue(host.pendingLoading == nil);XCTAssertTrue(host.preparedLoadedMenu == nil)
            XCTAssertTrue(host.preparedMatchPrelude == nil);XCTAssertTrue(host.preparedGameplayInput == nil)
            XCTAssertTrue(try host.pendingPlatformSnapshot() == nil);XCTAssertTrue(try host.preparedPlatformSnapshot() == nil)
            try OriginalApplicationBootstrapTests.sameStartup(XCTUnwrap(committed.startup),XCTUnwrap(before.startup))
            if !retainBatch {
                for (_,check) in batchChecks { try check(XCTUnwrap(host.takeCommitted())) }
                batchChecks.removeAll();XCTAssertTrue(try host.takeCommitted() == nil)
            }
        } else { try C.finish(&original,returned,stop:stop) }
        if returned.entry.round.continuation == .gameplay || returned.entry.round.continuation == .pausedRendering { gameplayReturns += 1 }
    }
    func rejectConsumed(_ returned: M.S.PendingReturn) throws {
        if let host {
            XCTAssertThrowsError(try host.finishLoadedMenu(perform:{ _,_ in XCTFail("Consumed tail ran");return .init() })) {
                XCTAssertEqual($0 as? H.Host.Boundary,.noPendingLoading)
            }
        } else { XCTAssertThrowsError(try C.finish(&original,returned)) }
    }
}
