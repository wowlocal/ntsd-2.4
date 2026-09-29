import AppKit
import XCTest
@testable import NTSDCore
@testable import NTSDMacPlatform

/// The whole-iteration permit driver against the existing prepared-array path:
/// identical saved first-menu values, no new expected state.
@MainActor final class OriginalApplicationObservedIterationTests: XCTestCase {
    typealias O = OriginalApplicationObservedBitmapTests
    typealias G = OriginalApplicationObservedGraphicsTests
    typealias D = OriginalMacDisplayBackendTests
    typealias B = OriginalApplicationBootstrapTests
    typealias A = OriginalApplicationBootstrap
    typealias S = OriginalApplicationMenuSession
    typealias P = OriginalApplicationPreparedStartupPlatform
    typealias Host = OriginalApplicationHostSession<P>
    typealias Driver = OriginalApplicationObservedIteration<P>
    typealias R = OriginalApplicationIterationRequest
    enum Stop: Error { case limit, late }
    static let lifecycleKinds: Set<String> = ["clientRect","screenPoint"]

    struct Result { let batch: Host.Batch, receipts: [OriginalApplicationIterationExchange.Receipt], retried: Bool }
    func drive(_ host: Host,_ p: O.Packet,_ inputs: Host.Inputs,bitmap: OriginalMacBitmapService,lateFailure: Bool = false) throws -> Result {
        let driver = Driver(host:host),old = try XCTUnwrap(host.snapshot.session)
        var qi = 0,wi = 0,li = 0,si = 0,pass = 0,failed = false
        for _ in 0..<3000 {
            do {
                switch try driver.resume(prepare:{ _,_ in inputs },beforePublication:{ _ in
                    if lateFailure && !failed { throw Stop.late }
                }) {
                case .request(let permit):
                    B.same(try XCTUnwrap(host.snapshot.session),old); XCTAssertEqual(host.pendingBatchCount,0)
                    switch permit.request {
                    case .queue:
                        guard qi < p.queue.count else { throw Stop.limit }
                        try driver.beginService(permit); try driver.answer(permit,response:.queue(p.queue[qi])); qi += 1
                    case .windowDefault:
                        guard wi < p.window.count else { throw Stop.limit }
                        try driver.beginService(permit); try driver.answer(permit,response:.windowDefault(p.window[wi])); wi += 1
                    case .graphics(.bitmap): try bitmap.serve(permit,on:driver)
                    case .graphics(.window(let q)):
                        let response: OriginalWindowInitialization.Response
                        if Self.lifecycleKinds.contains(q.kind) { guard li < p.lifecycle.count else { throw Stop.limit }; response = p.lifecycle[li]; li += 1 }
                        else { guard si < p.surface.count else { throw Stop.limit }; response = p.surface[si]; si += 1 }
                        try driver.beginService(permit); try driver.answer(permit,response:.graphics(.window(response)))
                    case .graphics(.front(_,let q)):
                        if q.kind == "getDC" { pass += 1 }
                        // Existing controlled profile replies, not GDI/device observations.
                        try driver.beginService(permit); try driver.answer(permit,response:.graphics(.front(G().reply(q,.normal,pass))))
                    case .graph: throw Stop.limit
                    }
                case .advanced(let outcome):
                    guard case .committed(let sequence,_) = outcome else { throw Stop.limit }
                    XCTAssertEqual([qi,wi,li,si],[p.queue.count,p.window.count,p.lifecycle.count,p.surface.count])
                    XCTAssertEqual(failed,lateFailure); XCTAssertEqual(driver.exchangeSnapshot.status,.finished)
                    let batch = try XCTUnwrap(host.takeCommitted()); XCTAssertEqual(batch.sequence,sequence)
                    XCTAssertNil(try host.takeCommitted())
                    return .init(batch:batch,receipts:driver.exchangeSnapshot.receipts,retried:failed)
                }
            } catch Stop.late {
                XCTAssertFalse(failed); failed = true
                B.same(try XCTUnwrap(host.snapshot.session),old); XCTAssertEqual(host.pendingBatchCount,0)
                XCTAssertEqual(driver.exchangeSnapshot.status,.open)
            }
        }
        throw Stop.limit
    }
    func reference(_ before: A,_ p: O.Packet,_ r: Result,dispatch: Bool) throws -> (A,S.Committed) {
        var app = before
        var input = p.initialization,surface: [OriginalWindowInitialization.Response] = []
        if dispatch {
            func controls(_ stage: A.Stage) -> [OriginalBitmapSurfaceLoading.Response] {
                r.receipts.compactMap { receipt in
                    guard case .graphics(.bitmap(let s,_)) = receipt.request,s == stage,case .graphics(.bitmap(let a)) = receipt.response else { return nil }
                    return .init(result:a.result,output:a.output)
                }
            }
            let i = p.initialization
            input = A.MenuInputs(settings:i.settings,prefix:i.prefix,body:.init(dcResult:0,dc:0x12345678,methodResult:0,drawResults:[0],shellResult:i.body.shellResult),
                frontAllocations:i.frontAllocations,backgroundAllocation:i.backgroundAllocation,
                frontResponses:controls(.resources),backgroundResponses:controls(.prefix),bitmapResources:i.bitmapResources)
            surface = r.receipts.compactMap { receipt in
                guard case .graphics(.window(let q)) = receipt.request,!Self.lifecycleKinds.contains(q.kind),case .graphics(.window(let a)) = receipt.response else { return nil }
                return a
            }
        }
        guard case .committed(let batch) = try app.step(inputs:input,responses:p.responses,queue:p.queue,
            windowDefault:p.window,surface:surface,lifecycle:p.lifecycle) else { throw Stop.limit }
        return (app,batch)
    }
    func compare(_ r: Result,_ reference: (A,S.Committed)) throws {
        guard case .iteration(let actual) = r.batch.contents else { throw Stop.limit }
        B.same(try XCTUnwrap(r.batch.context.application.session),try XCTUnwrap(reference.0.session))
        XCTAssertEqual(try actual.effects.map(G().normalized),try reference.1.effects.map(G().normalized))
        XCTAssertEqual(actual.graphics.map(G().normalized),reference.1.graphics.map(G().normalized))
        XCTAssertEqual(actual.result,reference.1.result)
    }
    func testWholeFirstMenuThroughIterationPermitsMatchesPreparedPath() throws {
        for late in [false,true] {
            let r = try D().run(late:false);defer { try? D().close(r) }
            let package = try OriginalApplicationStartupInputs.bundled(),packets = try O().packets(r.setup.controls.window,package)
            let bitmap = O().service(r,package),host = r.host
            _ = try host.takeCommitted()
            var queueRequests = 0,windowRequests = 0
            for p in packets {
                let before = host.snapshot
                let inputs = p.dispatch ? Host.Inputs(initialization:G().observed(p).initialization,responses:p.responses,queue:[])
                    : Host.Inputs(initialization:p.initialization,responses:p.responses,queue:[])
                let result = try drive(host,p,inputs,bitmap:bitmap,lateFailure:late && p.dispatch)
                try compare(result,try reference(before,p,result,dispatch:p.dispatch))
                for receipt in result.receipts {
                    if case .queue = receipt.request { queueRequests += 1 }
                    if case .windowDefault = receipt.request { windowRequests += 1 }
                }
                // Receipt order equals the committed loop/window observation order.
                let loop = result.receipts.compactMap { r -> OriginalApplicationMessageLoop.Request? in if case .queue(let q) = r.request { return q };return nil }
                XCTAssertEqual(loop.count,p.queue.count)
            }
            XCTAssertEqual(queueRequests,packets.map(\.queue.count).reduce(0,+))
            XCTAssertEqual(windowRequests,packets.map(\.window.count).reduce(0,+))
            XCTAssertGreaterThan(queueRequests,0)
        }
    }
    func testPreparedArraysCannotMixWithIterationPermits() throws {
        let r = try D().run(late:false);defer { try? D().close(r) }
        let package = try OriginalApplicationStartupInputs.bundled(),packets = try O().packets(r.setup.controls.window,package)
        _ = try r.host.takeCommitted()
        let p = try XCTUnwrap(packets.first { !$0.dispatch && !$0.queue.isEmpty }),driver = Driver(host:r.host),before = r.host.committedSequence
        XCTAssertThrowsError(try driver.resume(prepare:{ _,_ in p.host }))
        XCTAssertEqual(r.host.committedSequence,before)
    }
    // Static 43b4fd/43bc88/43bc74 decode: these messages only return DefWindowProcA.
    func testDecodedDefaultMessagesReturnDefWindowProcWithoutStores() throws {
        var globals = try OriginalStateRecord(bytes:[UInt8](repeating:0,count:OriginalMatchPreparation.globalSize),defined:[Bool](repeating:true,count:OriginalMatchPreparation.globalSize))
        var local = try OriginalStateRecord(bytes:[UInt8](repeating:0,count:OriginalWindowInput.localCount),defined:[Bool](repeating:true,count:OriginalWindowInput.localCount))
        var memory = OriginalMenuPresentationMemory(replayPointers:try .init(bytes:[UInt8](repeating:0,count:8),defined:[Bool](repeating:true,count:8)))
        let before = (globals.bytes,local.bytes)
        for message in Array(0x102...0x104)+Array(0x106...0x111) {
            var requests: [OriginalWindowInput.Request] = [],stores = 0
            let result = try OriginalWindowInput.receive(.init(window:7,message:UInt32(message),wParam:0x61,lParam:0x1e0001),
                globals:&globals,local:&local,memory:&memory,request:{ q in requests.append(q);return -123 },store:{ _,_ in stores += 1 })
            XCTAssertEqual(result,-123); XCTAssertEqual(stores,0)
            XCTAssertEqual(requests,[.init(.windowDefault,[7,UInt32(message),0x61,0x1e0001])])
        }
        XCTAssertEqual(globals.bytes,before.0); XCTAssertEqual(local.bytes,before.1)
        // WM_SYSKEYUP's own handler is outside this route.
        XCTAssertThrowsError(try OriginalWindowInput.receive(.init(window:7,message:0x105,wParam:0,lParam:0),
            globals:&globals,local:&local,memory:&memory,request:{ _ in 0 }),"261")
        // WM_SYSCOMMAND (43b519, APPLICATION_WINDOW_CLOSE.md): SC_KEYMENU returns 1
        // without a request; other commands take this default route.
        for (command,expected) in [(UInt32(0xf100),[OriginalWindowInput.Request]()),(0xf060,[.init(.windowDefault,[7,0x112,0xf060,0])])] {
            var requests: [OriginalWindowInput.Request] = []
            let result = try OriginalWindowInput.receive(.init(window:7,message:0x112,wParam:command,lParam:0),
                globals:&globals,local:&local,memory:&memory,request:{ q in requests.append(q);return -123 })
            XCTAssertEqual(result,command == 0xf100 ? 1 : -123); XCTAssertEqual(requests,expected)
        }
    }
}
