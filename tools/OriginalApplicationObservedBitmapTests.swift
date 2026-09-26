import AppKit
import XCTest
@testable import NTSDCore
@testable import NTSDMacPlatform

@MainActor final class OriginalApplicationObservedBitmapTests: XCTestCase {
    typealias D = OriginalMacDisplayBackendTests
    typealias B = OriginalApplicationBootstrapTests
    typealias A = OriginalApplicationBootstrap
    typealias S = OriginalApplicationMenuSession
    typealias P = OriginalApplicationPreparedStartupPlatform
    typealias Host = OriginalApplicationHostSession<P>
    typealias Driver = OriginalApplicationObservedBitmapIteration<P>
    typealias Service = OriginalMacBitmapService
    typealias E = OriginalBitmapRequestExchange
    typealias API = OriginalBitmapSurfaceLoading
    enum Stop: Error { case limit, late, diagnostic }
    struct Packet {
        let initialization: A.MenuInputs,responses: S.Responses
        let queue: [S.Loop.Response],window: [Int32],surface: [OriginalWindowInitialization.Response],lifecycle: [OriginalWindowInitialization.Response]
        let dispatch: Bool
        var host: Host.Inputs { .init(initialization:initialization,responses:responses,queue:queue,windowDefault:window,surface:surface,lifecycle:lifecycle) }
    }
    /// Non-bitmap inputs are the existing declared case0 controls. Wrapper
    /// storage is a disjoint test-owned logical arena, not source heap addresses.
    func packets(_ window: UInt32,_ package: OriginalApplicationStartupInputs) throws -> [Packet] {
        let f = try B.F.Resources(),b = try B.Body.Resources(f),r = try B.M.Resources(b,f)
        let br = try B.B.Resources(),er = try B.Entry.Resources(),c = r.c.cases[0]
        let body = c.parentKind == "body" ? b.c.cases[r.indices[0]] : nil
        let fi = c.parentKind == "body" ? b.frontIndices[r.indices[0]] : r.indices[0]
        let fc = f.c.cases[fi],si = try XCTUnwrap(f.settingKeys.firstIndex(of:fc.parent)),sc = f.settings.c.cases[si]
        let raw = try XCTUnwrap(f.settings.rawParents[sc.parent]) as NSDictionary
        let bi = try XCTUnwrap(br.rawCases.firstIndex { NSDictionary(dictionary:$0).isEqual(to:raw) })
        let bc = br.c.cases[bi],lc = try XCTUnwrap(bc.parents).loop
        let input = A.MenuInputs(settings:.init(bytes:try OriginalApplicationStartupInputsTests.control(sc.spec.label,package),file:0x52000000,
                scratchAddress:0x53000000,closeResult:sc.spec.close ?? 0),
            prefix:.init(drawTarget:0,milliseconds:fc.spec.milliseconds ?? 123456900,threadHandle:fc.spec.thread ?? 0x50010000,
                threadID:0xabcd,lastError:5,fillResult:fc.spec.fillResult ?? 0,drawResults:[fc.spec.drawResult ?? 0]),
            body:.init(dcResult:body?.spec.dcResult ?? 0,dc:body?.spec.dc ?? 0x12345678,methodResult:body?.spec.methodResult ?? 0,
                drawResults:body?.spec.drawResults ?? [0],shellResult:body?.spec.shellResult ?? 0),
            frontAllocations:(0..<24).map { .init(address:0x51000000+UInt32($0)*0x1f50,backing:Array(repeating:0xa5,count:0x1f50)) },
            backgroundAllocation:.init(address:0x51000000+24*0x1f50,backing:Array(repeating:0xa5,count:0x1f50)),
            frontResponses:[],backgroundResponses:[],bitmapResources:package.bitmaps)
        let replies = S.Responses(draw:c.spec.drawResult,presentation:c.spec.presentResult,sound:0,release:0,
            dcResult:body?.spec.dcResult ?? 0,dc:body?.spec.dc ?? 0x12345678)
        return try lc.iterations.map { step in
            let events = Array(lc.events[step.before.events..<step.after.events]),dispatch = step.end == "requiredDispatcher"
            let loopKinds: Set<String> = ["peek","get","translate","dispatchMessage","time","sleep"]
            var queue = try events.filter { loopKinds.contains($0.request.kind) }.map { event -> S.Loop.Response in
                let response = try XCTUnwrap(event.response)
                // The input MSG belongs to our actual window; other fields remain
                // the declared source controls, not a saved Core after-state.
                let writes = response.writes.map { write -> S.Loop.Write in
                    var bytes = write.bytes
                    if event.request.kind == "get" {
                        for i in bytes.indices where (0..<4).contains(write.offset+i) {
                            bytes[i] = UInt8(truncatingIfNeeded:window >> ((write.offset+i)*8))
                        }
                    }
                    return .init(offset:write.offset,bytes:bytes)
                }
                return .init(result:response.result,writes:writes)
            }
            if dispatch { queue.append(.init(result:Int32(bitPattern:c.spec.time))) }
            let defaults = try events.filter { $0.request.kind == "windowDefault" }.map { try XCTUnwrap($0.response).result }
            let lifecycle = try events.filter { !loopKinds.contains($0.request.kind) && !["windowDefault","gameDispatch"].contains($0.request.kind) }.map { OriginalWindowInitialization.Response(result:try XCTUnwrap($0.response).result) }
            let surface = dispatch ? er.c.cases[bc.spec.windowParam == 1 ? 1 : 0].events.compactMap { $0.event?.response } : []
            return Packet(initialization:input,responses:replies,queue:queue,window:defaults,surface:surface,lifecycle:lifecycle,dispatch:dispatch)
        }
    }
    func service(_ r: D.Run,_ inputs: OriginalApplicationStartupInputs,missing: String? = nil,
        diagnostic: Service.Diagnostic? = nil) -> Service {
        var resources = inputs.bitmaps;if let missing { resources.removeValue(forKey:missing) }
        return .init(backend:r.setup.display,inputs:.init(resources:resources,
            files:Dictionary(uniqueKeysWithValues:inputs.bitmaps.keys.map { ($0,OriginalMacDisplayBackend.BitmapInputs.File.missing) })),diagnostic:diagnostic)
    }
    func previous(_ host: Host,_ packet: Packet) throws {
        guard case .committed = try host.step(prepare:{ _,_ in packet.host }) else { throw Stop.limit }
    }
    struct Run {
        let startup: D.Run,packet: Packet,driver: Driver,batch: Host.Batch,before: A
        let replies: [(A.Stage,API.Request,API.Response)]
    }
    func run(late: Bool = false) throws -> Run {
        let d = D(),r = try d.run(late:false),package = try OriginalApplicationStartupInputs.bundled(),service = service(r,package)
        let packets = try packets(r.setup.controls.window,package)
        let host = r.host
        _ = try host.takeCommitted()
        for p in packets where !p.dispatch { try previous(host,p);_ = try host.takeCommitted() }
        let packet = try XCTUnwrap(packets.first { $0.dispatch }),before = host.snapshot,old = try XCTUnwrap(before.session)
        let driver = Driver(host:host);var failed = false
        for _ in 0..<1200 {
            var replies: [(A.Stage,API.Request,API.Response)] = []
            do {
                switch try driver.resume(prepare:{ _,_ in packet.host },observe:{ e in
                    if case .bitmap(let stage,let q,let response) = e { replies.append((stage,q,response)) }
                },beforeCommit:{ _,_ in
                    XCTAssertThrowsError(try driver.cancel()) { XCTAssertEqual($0 as? Driver.Boundary,.reentrantAttempt) }
                },beforePublication:{ _ in if late && !failed { throw Stop.late } }) {
                case .request(let permit):
                    B.same(try XCTUnwrap(host.snapshot.session),old);XCTAssertEqual(host.pendingBatchCount,0)
                    XCTAssertNil(try host.platformSnapshot().bitmapDelivery.cursor)
                    try service.serve(permit,on:driver)
                case .advanced(let outcome):
                    guard case .committed(let sequence,_) = outcome else { throw Stop.limit }
                    let batch = try XCTUnwrap(host.takeCommitted());XCTAssertEqual(batch.sequence,sequence)
                    XCTAssertEqual(failed,late);XCTAssertNil(try host.takeCommitted())
                    return .init(startup:r,packet:packet,driver:driver,batch:batch,before:before,replies:replies)
                }
            } catch Stop.late {
                XCTAssertTrue(late);XCTAssertFalse(failed);failed = true
                B.same(try XCTUnwrap(host.snapshot.session),old);XCTAssertEqual(host.pendingBatchCount,0)
                XCTAssertEqual(driver.exchangeSnapshot.status,.open)
                XCTAssertEqual(service.backend.bitmapOperations.count,driver.exchangeSnapshot.receipts.count)
            }
        }
        try d.close(r);throw Stop.limit
    }
    func prepared(_ r: Run) throws -> A {
        var app = r.before;let p = r.packet,i = p.initialization
        let controls: (A.Stage) -> [API.Response] = { stage in r.replies.filter { $0.0 == stage }.map { .init(result:$0.2.result,output:$0.2.output) } }
        let packet = A.MenuInputs(settings:i.settings,prefix:i.prefix,body:i.body,frontAllocations:i.frontAllocations,
            backgroundAllocation:i.backgroundAllocation,frontResponses:controls(.resources),backgroundResponses:controls(.prefix),bitmapResources:i.bitmapResources)
        guard case .committed = try app.step(inputs:packet,responses:p.responses,queue:p.queue,windowDefault:p.window,surface:p.surface,lifecycle:p.lifecycle) else { throw Stop.limit }
        return app
    }
    func check(_ r: Run) throws {
        guard case .iteration(let iteration) = r.batch.contents else { throw Stop.limit }
        let actual = try XCTUnwrap(r.batch.context.application.session),expected = try XCTUnwrap(prepared(r).session)
        B.same(actual,expected);try B.sameStartup(XCTUnwrap(r.batch.context.application.startup),XCTUnwrap(r.before.startup))
        let receipts = r.driver.exchangeSnapshot.receipts
        let effects = iteration.effects.compactMap { e -> (API.Request,API.Response)? in if case .bitmap(let q,let response) = e { return (q,response) };return nil }
        XCTAssertEqual(effects.map { $0.0 },receipts.map { $0.request.value });XCTAssertEqual(effects.map { $0.1 },receipts.map(\.response))
        XCTAssertEqual(r.startup.setup.display.bitmapOperations.map(\.request),receipts.map { $0.request.value })
        XCTAssertEqual(r.startup.setup.display.bitmapOperations.map(\.response),receipts.map(\.response))
        XCTAssertEqual(actual.state.front.bitmaps.count,24);XCTAssertEqual(actual.state.earlyScreen.bitmaps.count,1)
        let bindings = try XCTUnwrap(actual.state.bitmapInputs);XCTAssertEqual(bindings.surfaces.count,25)
        for (token,surface) in bindings.surfaces {
            let pixels = try r.startup.setup.display.pixels(token),colors = surface.sourceColors
            XCTAssertEqual(pixels.width,colors.width);XCTAssertEqual(pixels.height,colors.height);XCTAssertEqual(pixels.defined,colors.defined)
            XCTAssertEqual(pixels.values,stride(from:0,to:colors.rgb.count,by:3).map { i in UInt32(colors.rgb[i])*65536+UInt32(colors.rgb[i+1])*256+UInt32(colors.rgb[i+2]) })
            XCTAssertNil(try r.startup.setup.display.bitmapObservation(token).activeDC)
        }
        XCTAssertTrue(bindings.activeMemoryDCs.isEmpty);XCTAssertTrue(bindings.activeSurfaceDCs.isEmpty)
        let context = try r.batch.context.platformSnapshot()
        XCTAssertEqual(context.bitmapDelivery.cursor?.position,receipts.count)
        XCTAssertEqual(r.driver.exchangeSnapshot.status,.finished)
        // Context inspection can replace its value delivery owner without affecting
        // the batch or host's private platform copy.
        context.bitmapDelivery = .init()
        XCTAssertEqual(try r.batch.context.platformSnapshot().bitmapDelivery.cursor?.position,receipts.count)
        print("Whole first-menu physical bitmap replies",receipts.count,"surfaces",bindings.surfaces.count)
    }
    func testWholeFrontRetainsPhysicalBitmapRepliesOnHost() throws {
        let r = try run();defer { try? D().close(r.startup) };try check(r)
    }
    func testLateFailuresRetryWithoutRepeatingPhysicalWork() throws {
        let r = try run(late:true);defer { try? D().close(r.startup) };try check(r)
        XCTAssertThrowsError(try r.driver.resume(prepare:{ _,_ in r.packet.host })) { XCTAssertEqual($0 as? E.Boundary,.closed(.finished)) }
    }
    func testMissingResourceDiagnosticsRemainOrderedAcrossRollback() throws {
        let d = D(),r = try d.run(late:false);defer { try? d.close(r) }
        let package = try OriginalApplicationStartupInputs.bundled(),packets = try packets(r.setup.controls.window,package)
        _ = try r.host.takeCommitted()
        for p in packets where !p.dispatch { try previous(r.host,p);_ = try r.host.takeCommitted() }
        let packet = try XCTUnwrap(packets.first { $0.dispatch }),old = try XCTUnwrap(r.host.snapshot.session),driver = Driver(host:r.host)
        var delivered: [API.Request] = []
        let service = service(r,package,missing:"MENU_CLIP",diagnostic:{ q in delivered.append(q);return .init(result:q.kind == "message" ? 1 : 0) })
        var stopped = 0
        for _ in 0..<120 {
            do {
                switch try driver.resume(prepare:{ _,_ in packet.host },observe:{ e in
                    if case .bitmap(_,let q,_) = e,q.kind == "debug" { throw Stop.diagnostic }
                }) {
                case .request(let p):try service.serve(p,on:driver)
                case .advanced:XCTFail("Injected diagnostic boundary committed");throw Stop.limit
                }
            } catch Stop.diagnostic {
                stopped += 1;B.same(try XCTUnwrap(r.host.snapshot.session),old);XCTAssertEqual(r.host.pendingBatchCount,0)
                XCTAssertEqual(delivered.map(\.kind),["message","debug"])
                XCTAssertEqual(delivered[0].strings,[Array("Couldn't create art surface.".utf8),Array("MENU_CLIP".utf8)])
                if stopped == 2 { break }
            }
        }
        XCTAssertEqual(stopped,2);try driver.cancel();XCTAssertEqual(driver.exchangeSnapshot.status,.cancelled)
    }
    func testObservedOutputBoundsAndAtomicRegistry() throws {
        let package = try OriginalApplicationStartupInputs.bundled(),name = try XCTUnwrap(package.bitmaps.keys.sorted().first)
        let bitmap = try XCTUnwrap(package.bitmaps[name]);var owner = OriginalApplicationBitmapInputs(resources:package.bitmaps)
        _ = try owner.observed(.init("image",[1,0,0,0,0x2000],strings:[Array(name.utf8)]),response:.init(result:99))
        let q = API.Request("getObject",[99,24]),bytes = try bitmap.objectBytes(),old = owner
        let partial = API.Response(result:24,writes:[.init(offset:4,bytes:Array(bytes[4..<12]))])
        XCTAssertEqual(try owner.observed(q,response:partial),partial);XCTAssertEqual(owner,old)
        for reply in [API.Response(result:24,writes:[.init(offset:0,bytes:[0])]),.init(result:24,writes:[.init(offset:20,bytes:[0])]),
                      .init(result:24,writes:[.init(offset:Int.max,bytes:[0])]),.init(result:24,writes:[.init(offset:4,bytes:[bytes[4]^255])])] {
            XCTAssertThrowsError(try owner.observed(q,response:reply));XCTAssertEqual(owner,old)
        }
        XCTAssertThrowsError(try owner.response(q,control:partial));XCTAssertEqual(owner,old)
        var r = try OriginalStateRecord(bytes:Array(repeating:0,count:108),defined:Array(repeating:true,count:108))
        try r.write(UInt32(108),at:0);try r.write(UInt32(7),at:4);try r.write(UInt32(2),at:8);try r.write(UInt32(3),at:12)
        _ = try owner.observed(.init("createSurface",[1,0],structure:r),response:.init(output:100))
        let description = API.Response(writes:[.init(offset:8,bytes:Array(r.bytes[8..<16]))])
        XCTAssertEqual(try owner.observed(.init("description",[100]),response:description),description)
        let known = owner;XCTAssertThrowsError(try owner.observed(.init("description",[100]),response:.init(writes:[.init(bytes:r.bytes)])))
        XCTAssertEqual(owner,known)
    }
    func testProtocolStaleHostAndRetainedHistory() throws {
        weak var lease: OriginalMacDisplayBackend.Resource?
        var saved: Host.DeliveryContext?
        func exercise() throws {
            let r = try run();defer { try? D().close(r.startup) }
            let host = r.startup.host,receipts = r.driver.exchangeSnapshot.receipts
            let token = try XCTUnwrap(receipts.first { $0.request.value.kind == "createSurface" }?.response.output)
            lease = try r.startup.setup.display.lease(token)
            var msg = try OriginalStateRecord(bytes:Array(repeating:0,count:28),defined:Array(repeating:true,count:28))
            try msg.write(r.startup.setup.controls.window,at:0);try msg.write(UInt32(0x100),at:4);try msg.write(UInt32(74),at:8)
            let packet = Host.Inputs(responses:r.packet.responses,queue:[.init(result:1),.init(result:1,writes:[.init(offset:0,bytes:msg.bytes)]),.init(),.init()],windowDefault:[0])
            let stale = Driver(host:host),next = Driver(host:host)
            let foreign = E(),permit = try OriginalMacBitmapBackendTests().ticket(foreign,.init("module",[0]))
            let service = service(r.startup,try OriginalApplicationStartupInputs.bundled())
            let operations = r.startup.setup.display.bitmapOperations.count
            XCTAssertThrowsError(try service.serve(permit,on:next)) { XCTAssertEqual($0 as? E.Boundary,.foreignOwner) }
            XCTAssertEqual(r.startup.setup.display.bitmapOperations.count,operations);foreign.cancel()
            guard case .advanced(.committed) = try next.resume(prepare:{ _,_ in packet }) else { throw Stop.limit }
            XCTAssertEqual(try host.platformSnapshot().bitmapDelivery.retainedIterationCount,1)
            XCTAssertEqual(try host.platformSnapshot().bitmapDelivery.cursor?.position,0)
            XCTAssertThrowsError(try stale.resume(prepare:{ _,_ in packet })) { XCTAssertEqual($0 as? Host.Boundary,.staleSequence) }
            XCTAssertTrue(stale.exchangeSnapshot.receipts.isEmpty)
            let cancelled = Driver(host:host);try cancelled.cancel()
            XCTAssertThrowsError(try cancelled.resume(prepare:{ _,_ in packet })) { XCTAssertEqual($0 as? E.Boundary,.closed(.cancelled)) }
            let batch = try XCTUnwrap(host.takeCommitted());saved = batch.context
            let empty = Driver(host:host)
            guard case .advanced(.committed) = try empty.resume(prepare:{ _,_ in packet }) else { throw Stop.limit }
            XCTAssertEqual(try host.platformSnapshot().bitmapDelivery.retainedIterationCount,1)
            XCTAssertEqual(try saved?.platformSnapshot().bitmapDelivery.retainedIterationCount,1)
        }
        try exercise();XCTAssertNotNil(lease)
        XCTAssertEqual(try saved?.platformSnapshot().bitmapDelivery.retainedIterationCount,1)
        saved = nil;XCTAssertNil(lease)
    }
}
