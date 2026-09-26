import AppKit
import XCTest
@testable import NTSDCore
@testable import NTSDMacPlatform

@MainActor final class OriginalMacWindowGeometryTests: XCTestCase {
    typealias D = OriginalMacDisplayBackendTests
    typealias O = OriginalApplicationObservedBitmapTests
    typealias B = OriginalApplicationBootstrapTests
    typealias A = OriginalApplicationBootstrap
    typealias S = OriginalApplicationMenuSession
    typealias P = OriginalApplicationPreparedStartupPlatform
    typealias Host = OriginalApplicationHostSession<P>
    typealias Driver = OriginalApplicationObservedLifecycleIteration<P>
    typealias E = OriginalLifecycleRequestExchange
    typealias API = OriginalWindowInitialization
    typealias Backend = OriginalMacWindowBackend
    enum Stop: Error { case limit, late }
    final class Marker: OriginalApplicationStartupResource {}
    struct Ready { let run: D.Run, menu: O.Packet, package: OriginalApplicationStartupInputs }
    func ready() throws -> Ready {
        let run = try D().run(late:false),package = try OriginalApplicationStartupInputs.bundled()
        let packets = try O().packets(run.setup.controls.window,package)
        _ = try run.host.takeCommitted()
        for packet in packets where !packet.dispatch { try O().previous(run.host,packet);_ = try run.host.takeCommitted() }
        return .init(run:run,menu:try XCTUnwrap(packets.first { $0.dispatch }),package:package)
    }
    func window(_ r: D.Run) throws -> NSWindow {
        let number = try r.setup.window.backend.observation(r.setup.controls.window).windowNumber
        return try XCTUnwrap(NSApp.windows.first { $0.windowNumber == number })
    }
    // Independent AppKit route: contentRect from frame, not backend view conversions.
    func rectangle(_ window: NSWindow) throws -> [Int32] {
        let screen = try XCTUnwrap(window.screen).frame,content = window.contentRect(forFrameRect:window.frame)
        return try [content.minX-screen.minX,screen.maxY-content.maxY,content.maxX-screen.minX,screen.maxY-content.minY].map {
            try XCTUnwrap(Int32(exactly:$0))
        }
    }
    func bytes(_ words: [Int32]) -> [UInt8] {
        words.flatMap { w in (0..<4).map { UInt8(truncatingIfNeeded:UInt32(bitPattern:w) >> ($0*8)) } }
    }
    func record(_ words: [Int32],known: Bool = true) throws -> OriginalStateRecord {
        let data = bytes(words);return try .init(bytes:data,defined:Array(repeating:known,count:data.count))
    }
    func stored(_ app: A) throws -> [Int32] {
        let g = try XCTUnwrap(app.session).state.full
        return try (0..<4).map { try g.integer(at:0x453ccc-0x44d000+$0*4,as:Int32.self) }
    }
    func message(_ r: Ready,kind: UInt32 = 3) throws -> Host.Inputs {
        var msg = try OriginalStateRecord(bytes:Array(repeating:0,count:28),defined:Array(repeating:true,count:28))
        try msg.write(r.run.setup.controls.window,at:0);try msg.write(kind,at:4)
        try msg.write(UInt32(74),at:8);try msg.write(UInt32(0x7fff8000),at:12) // WM_MOVE ignores these packed coordinates.
        return .init(responses:r.menu.responses,queue:[.init(result:1),.init(result:1,writes:[.init(offset:0,bytes:msg.bytes)]),.init(),.init()],windowDefault:kind == 3 ? [] : [0])
    }
    func compare(_ before: A,_ after: A,_ input: Host.Inputs,_ receipts: [E.Receipt]) throws {
        var expected = before
        guard case .committed = try expected.step(inputs:input.initialization,responses:input.responses,queue:input.queue,
            windowDefault:input.windowDefault,surface:input.surface,lifecycle:receipts.map(\.response)) else { throw Stop.limit }
        B.same(try XCTUnwrap(after.session),try XCTUnwrap(expected.session))
        try B.sameStartup(XCTUnwrap(after.startup),XCTUnwrap(before.startup))
    }
    func checkMove(_ batch: Host.Batch,_ driver: Driver) throws {
        guard case .iteration(let iteration) = batch.contents else { throw Stop.limit }
        let effects = iteration.effects.compactMap { e -> (API.Request,API.Response)? in
            if case .lifecycle(let q,let response) = e { return (q,response) };return nil
        }
        let receipts = driver.exchangeSnapshot.receipts
        XCTAssertEqual(effects.map { $0.0 },receipts.map(\.request));XCTAssertEqual(effects.map { $0.1 },receipts.map(\.response))
        XCTAssertEqual(receipts.map(\.request.kind),["clientRect","screenPoint","screenPoint","windowDefault"])
        XCTAssertEqual(receipts[0].request.words[1],0x453ccc);XCTAssertEqual(receipts[1].request.words[1],0x453ccc)
        XCTAssertEqual(receipts[2].request.words[1],0x453cd4)
        XCTAssertEqual(receipts[3].request.words,[receipts[0].request.words[0],3,74,0x7fff8000])
        if let client = receipts[0].response.bytes {
            XCTAssertEqual(receipts[1].request.bytes,Array(client[0..<8]));XCTAssertEqual(receipts[2].request.bytes,Array(client[8..<16]))
        }
        XCTAssertEqual(try batch.context.platformSnapshot().lifecycleDelivery.cursor?.position,4)
        XCTAssertEqual(driver.exchangeSnapshot.status,.finished)
    }
    func checkStores(_ observations: [OriginalFrontScreenEvent],_ receipts: [E.Receipt]) {
        let actual = observations.filter { $0.kind == "write" && $0.arguments[0] >= 0x453ccc && $0.arguments[0] < 0x453cdc }.map(\.arguments)
        let expected = receipts.flatMap { receipt -> [[UInt32]] in
            guard let output = receipt.response.bytes else { return [] }
            return stride(from:0,to:output.count,by:4).map { offset in
                let word = (0..<4).reduce(UInt32(0)) { $0 | UInt32(output[offset+$1]) << ($1*8) }
                return [receipt.request.words[1]+UInt32(offset),4,word]
            }
        }
        XCTAssertEqual(actual,expected)
    }
    func move(_ r: Ready,late: Bool = false,marker: Marker? = nil,onLate: () throws -> Void = {}) throws -> (Host.Batch,Driver) {
        let host = r.run.host,input = try message(r),before = host.snapshot,old = try XCTUnwrap(before.session)
        let driver = Driver(host:host),backend = r.run.setup.window.backend,service = OriginalMacWindowGeometryService(backend:backend)
        let priorPosition = try host.platformSnapshot().lifecycleDelivery.cursor?.position,operations = backend.operations.count
        var failed = false
        for _ in 0..<8 {
            var observations: [OriginalFrontScreenEvent] = []
            do {
                switch try driver.resume(prepare:{ _,_ in input },menuObserve:{ observations.append($0) },beforeCommit:{ _,_ in
                    XCTAssertThrowsError(try driver.cancel()) { XCTAssertEqual($0 as? Driver.Boundary,.reentrantAttempt) }
                },beforePublication:{ _ in if late && !failed { throw Stop.late } }) {
                case .request(let p):
                    B.same(try XCTUnwrap(host.snapshot.session),old);XCTAssertEqual(host.pendingBatchCount,0)
                    XCTAssertEqual(try host.platformSnapshot().lifecycleDelivery.cursor?.position,priorPosition)
                    if p.request.kind == "windowDefault" {
                        try driver.beginService(p);try driver.answer(p,response:.init(result:-17),retaining:marker.map { [$0] } ?? [])
                    } else { try service.serve(p,on:driver) }
                case .advanced(.committed):
                    let batch = try XCTUnwrap(host.takeCommitted());XCTAssertNil(try host.takeCommitted())
                    XCTAssertEqual(failed,late);try compare(before,host.snapshot,input,driver.exchangeSnapshot.receipts);try checkMove(batch,driver);checkStores(observations,driver.exchangeSnapshot.receipts)
                    let physical = Array(backend.operations.dropFirst(operations)),receipts = Array(driver.exchangeSnapshot.receipts.prefix(3))
                    XCTAssertEqual(physical.map(\.request),receipts.map(\.request));XCTAssertEqual(physical.map(\.response),receipts.map(\.response))
                    return (batch,driver)
                case .advanced:throw Stop.limit
                }
            } catch Stop.late {
                XCTAssertTrue(late);XCTAssertFalse(failed);failed = true
                B.same(try XCTUnwrap(host.snapshot.session),old);XCTAssertEqual(host.pendingBatchCount,0)
                XCTAssertEqual(try host.platformSnapshot().lifecycleDelivery.cursor?.position,priorPosition)
                XCTAssertEqual(driver.exchangeSnapshot.receipts.count,4);XCTAssertEqual(backend.operations.count-operations,3)
                try onLate()
            }
        }
        throw Stop.limit
    }
    func menu(_ r: Ready) throws -> O.Run {
        let host = r.run.host,before = host.snapshot,driver = O.Driver(host:host),service = O().service(r.run,r.package)
        for _ in 0..<1000 {
            var replies: [(A.Stage,OriginalBitmapSurfaceLoading.Request,OriginalBitmapSurfaceLoading.Response)] = []
            switch try driver.resume(prepare:{ _,_ in r.menu.host },observe:{ e in
                if case .bitmap(let stage,let q,let response) = e { replies.append((stage,q,response)) }
            }) {
            case .request(let p):try service.serve(p,on:driver)
            case .advanced(.committed):
                return .init(startup:r.run,packet:r.menu,driver:driver,batch:try XCTUnwrap(host.takeCommitted()),before:before,replies:replies)
            case .advanced:throw Stop.limit
            }
        }
        throw Stop.limit
    }
    func testWholeMoveOwnsGeometryAndFollowingMenuPresentation() throws {
        let r = try ready();defer { try? D().close(r.run) }
        XCTAssertEqual(try stored(r.run.host.snapshot),[0,0,0,0])
        let expected = try rectangle(window(r.run)),(batch,_) = try move(r)
        XCTAssertEqual(try stored(batch.context.application),expected)
        let front = try menu(r);try O().check(front)
        guard case .iteration(let iteration) = front.batch.contents else { throw Stop.limit }
        let presents = iteration.graphics.filter { $0.family == "front" && $0.event?.kind == "method" && $0.event?.arguments.dropFirst().first == 0x14 }
        XCTAssertFalse(presents.isEmpty)
        for command in presents { XCTAssertEqual(command.destinationRectangle,expected);XCTAssertNil(command.sourceRectangle) }
        XCTAssertEqual(try front.batch.context.platformSnapshot().lifecycleDelivery.cursor?.position,4)
        print("Whole WM_MOVE physical geometry",expected,"following first-menu presentations",presents.count)
    }
    func testMoveLateFailureRetriesSavedGeometryAndRetainsHistory() throws {
        weak var retained: Marker?;var saved: Host.DeliveryContext?
        func exercise() throws {
            let r = try ready();defer { try? D().close(r.run) }
            let w = try window(r.run),firstRect = try rectangle(w),stale = Driver(host:r.run.host),marker = Marker();retained = marker
            let (first,_) = try move(r,late:true,marker:marker,onLate:{ w.setFrameOrigin(.init(x:w.frame.minX+7,y:w.frame.minY-9)) })
            XCTAssertEqual(try stored(first.context.application),firstRect);XCTAssertNotEqual(try rectangle(w),firstRect)
            let (second,_) = try move(r);XCTAssertEqual(try stored(second.context.application),try rectangle(w))
            XCTAssertEqual(try second.context.platformSnapshot().lifecycleDelivery.retainedIterationCount,1)
            XCTAssertEqual(try stored(first.context.application),firstRect)
            let input = try message(r,kind:0x100)
            XCTAssertThrowsError(try stale.resume(prepare:{ _,_ in input })) { XCTAssertEqual($0 as? Host.Boundary,.staleSequence) }
            XCTAssertTrue(stale.exchangeSnapshot.receipts.isEmpty)
            for _ in 0..<2 {
                let driver = Driver(host:r.run.host)
                guard case .advanced(.committed) = try driver.resume(prepare:{ _,_ in input }) else { throw Stop.limit }
                saved = try XCTUnwrap(r.run.host.takeCommitted()).context
                XCTAssertEqual(try saved?.platformSnapshot().lifecycleDelivery.retainedIterationCount,2)
                XCTAssertEqual(try saved?.platformSnapshot().lifecycleDelivery.cursor?.position,0)
            }
            let inspection = try XCTUnwrap(saved).platformSnapshot();inspection.lifecycleDelivery = .init()
            XCTAssertEqual(try saved?.platformSnapshot().lifecycleDelivery.retainedIterationCount,2)
        }
        try exercise();XCTAssertNotNil(retained)
        XCTAssertEqual(try saved?.platformSnapshot().lifecycleDelivery.retainedIterationCount,2)
        saved = nil;XCTAssertNil(retained)
    }
    func ticket(_ exchange: E,_ q: API.Request) throws -> E.Permit {
        var cursor = try exchange.snapshot.cursor()
        do { _ = try cursor.response(for:q);throw Stop.limit }
        catch let needed as E.RequestNeeded { return try exchange.claim(needed) }
    }
    func testGeometryPayloadOwnershipAndServiceProtocol() throws {
        let r = try ready(),backend = r.run.setup.window.backend,w = try window(r.run),token = r.run.setup.controls.window
        var closed = false;defer { if !closed { try? D().close(r.run) } }
        let client = API.Request("clientRect",[token,0x453ccc],structure:try record([17,29,-1,-1],known:false))
        let prepared = try backend.prepare(client),n = backend.operations.count
        w.setFrameOrigin(.init(x:w.frame.minX-11,y:w.frame.minY-13))
        XCTAssertEqual(backend.operations.count,n)
        let result = try backend.perform(prepared),rect = try rectangle(w),size = [Int32(0),0,rect[2]-rect[0],rect[3]-rect[1]]
        XCTAssertEqual(result.response,.init(result:1,bytes:bytes(size)));XCTAssertFalse(result.resources.isEmpty)
        XCTAssertThrowsError(try backend.perform(prepared)) { XCTAssertEqual($0 as? Backend.Boundary,.repeatedPreparation) }
        for point: [Int32] in [[-12,7],[size[2]+8,size[3]+9],[0,0]] {
            let q = API.Request("screenPoint",[token,0x453ccc],structure:try record(point)),p = try backend.prepare(q)
            w.setFrameOrigin(.init(x:w.frame.minX+2,y:w.frame.minY-3))
            let current = try rectangle(w),output = try backend.perform(p)
            XCTAssertEqual(output.response,.init(result:1,bytes:bytes([current[0]+point[0],current[1]+point[1]])))
        }
        for value: CGFloat in [0,-1,CGFloat(Int32.min),CGFloat(Int32.max)] { XCTAssertEqual(try Backend.geometryInteger(value),Int32(value)) }
        for value: CGFloat in [0.5,-0.5,.infinity,-.infinity,.nan,CGFloat(Int32.max)+1,CGFloat(Int32.min)-1] {
            XCTAssertThrowsError(try Backend.geometryInteger(value)) { XCTAssertEqual($0 as? Backend.Boundary,.geometry) }
        }
        let malformed: [API.Request] = [
            .init("clientRect",[token,1]),.init("clientRect",[token],structure:try record([0,0,1,1])),
            .init("clientRect",[token,0],structure:try record([0,0,1,1])),
            .init("clientRect",[token,1],strings:[[65]],structure:try record([0,0,1,1])),
            .init("clientRect",[token,1],structure:try record([0,0])),
            .init("screenPoint",[token,1],structure:try record([0,0],known:false)),
            .init("screenPoint",[token,1],structure:try record([0,0,0])),
            .init("screenPoint",[UInt32.max,1],structure:try record([0,0]))]
        let count = backend.operations.count
        for q in malformed { XCTAssertThrowsError(try backend.prepare(q)) }
        let alien = Backend(instance:1)
        XCTAssertThrowsError(try alien.perform(backend.prepare(client))) { XCTAssertEqual($0 as? Backend.Boundary,.foreignPreparation) }
        let service = OriginalMacWindowGeometryService(backend:backend),driver = Driver(host:r.run.host),input = try message(r)
        guard case .request(let p) = try driver.resume(prepare:{ _,_ in input }) else { throw Stop.limit }
        let foreign = E(),foreignPermit = try ticket(foreign,p.request)
        XCTAssertThrowsError(try service.serve(foreignPermit,on:driver)) { XCTAssertEqual($0 as? E.Boundary,.foreignOwner) }
        foreign.cancel()
        let unsupported = E(),other = try ticket(unsupported,.init("windowDefault",[token,3,0,0]))
        XCTAssertThrowsError(try service.serve(other,on:driver)) { XCTAssertEqual($0 as? OriginalMacWindowGeometryService.Boundary,.notGeometry) }
        unsupported.cancel();XCTAssertEqual(backend.operations.count,count)
        try service.serve(p,on:driver)
        XCTAssertThrowsError(try service.serve(p,on:driver)) { XCTAssertEqual($0 as? E.Boundary,.invalidPermit) }
        guard case .request(let next) = try driver.resume(prepare:{ _,_ in input }) else { throw Stop.limit }
        try driver.beginService(next)
        XCTAssertThrowsError(try service.serve(next,on:driver)) { XCTAssertEqual($0 as? E.Boundary,.serviceAlreadyStarted) }
        try driver.cancel()
        XCTAssertThrowsError(try service.serve(next,on:driver)) { XCTAssertEqual($0 as? E.Boundary,.closed(.cancelled)) }
        try driver.fail(next,diagnostic:"No geometry service after cancellation")
        XCTAssertEqual(backend.operations.count,count+1)
        let broken = Driver(host:r.run.host)
        guard case .request(let bp) = try broken.resume(prepare:{ _,_ in input }) else { throw Stop.limit }
        let view = try XCTUnwrap(w.contentView),origin = view.bounds.origin;view.setBoundsOrigin(.init(x:1,y:0))
        XCTAssertThrowsError(try service.serve(bp,on:broken)) { XCTAssertEqual($0 as? Backend.Boundary,.geometry) }
        view.setBoundsOrigin(origin)
        XCTAssertEqual(broken.exchangeSnapshot.status,.indeterminate)
        XCTAssertFalse(try XCTUnwrap(broken.exchangeSnapshot.failure).resources.isEmpty)
        XCTAssertEqual(r.run.host.pendingBatchCount,0);XCTAssertEqual(backend.operations.count,count+1)
        try D().close(r.run);closed = true
        XCTAssertThrowsError(try backend.prepare(client)) { XCTAssertEqual($0 as? Backend.Boundary,.geometry) }
    }
    func testIgnoredNumericGeometryRepliesAndWholeMoveRollback() throws {
        let r = try ready();defer { try? D().close(r.run) }
        let host = r.run.host,input = try message(r),backend = r.run.setup.window.backend,operations = backend.operations.count
        let controls: [[API.Response]] = [
            [.init(result:0,bytes:bytes([0,0,61,43])),.init(result:-7,bytes:bytes([-17,-29])),.init(result:Int32.min,bytes:bytes([44,14])),.init(result:-11)],
            [.init(result:0),.init(result:0),.init(result:0),.init(result:0)],
            [.init(result:-1,bytes:bytes([0,0,71,53])),.init(result:0),.init(result:-2,bytes:bytes([99,111])),.init(result:37)]]
        let expected: [[Int32]] = [[-17,-29,44,14],[-17,-29,44,14],[0,0,99,111]]
        for (index,replies) in controls.enumerated() {
            let before = host.snapshot,driver = Driver(host:host);var late = false,finished = false
            for _ in 0..<8 {
                var observations: [OriginalFrontScreenEvent] = []
                do {
                    switch try driver.resume(prepare:{ _,_ in input },observe:{ e in
                        if case .lifecycleResponse(let q,_) = e,q.kind == "windowDefault",!late { throw Stop.late }
                    },menuObserve:{ observations.append($0) }) {
                    case .request(let p):try driver.answer(p,response:replies[p.ordinal])
                    case .advanced(.committed):
                        let batch = try XCTUnwrap(host.takeCommitted());try compare(before,host.snapshot,input,driver.exchangeSnapshot.receipts)
                        try checkMove(batch,driver);checkStores(observations,driver.exchangeSnapshot.receipts);XCTAssertEqual(try stored(host.snapshot),expected[index]);finished = true
                    case .advanced:throw Stop.limit
                    }
                } catch Stop.late {
                    XCTAssertFalse(late);late = true;B.same(try XCTUnwrap(host.snapshot.session),try XCTUnwrap(before.session))
                    XCTAssertEqual(host.pendingBatchCount,0);XCTAssertEqual(driver.exchangeSnapshot.receipts.count,4)
                }
                if finished { break }
            }
            XCTAssertTrue(finished);XCTAssertTrue(late)
        }
        var app = host.snapshot;let old = try XCTUnwrap(app.session);var callbacks = 0
        XCTAssertThrowsError(try app.step(responses:input.responses,queue:input.queue,windowDefault:[],surface:[],lifecycle:[.init()],
            lifecycleProvider:{ _ in callbacks += 1;return .init() }))
        XCTAssertEqual(callbacks,0);B.same(try XCTUnwrap(app.session),old)
        XCTAssertThrowsError(try app.step(responses:input.responses,queue:input.queue,windowDefault:[],surface:[],lifecycle:[.init(bytes:bytes([0,0]))]))
        B.same(try XCTUnwrap(app.session),old);XCTAssertEqual(backend.operations.count,operations)
    }
}
