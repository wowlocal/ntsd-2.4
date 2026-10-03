import AppKit
import XCTest
@testable import NTSDCore
@testable import NTSDMacPlatform

@MainActor final class OriginalApplicationObservedGraphicsTests: XCTestCase {
    typealias O = OriginalApplicationObservedBitmapTests
    typealias D = OriginalMacDisplayBackendTests
    typealias B = OriginalApplicationBootstrapTests
    typealias A = OriginalApplicationBootstrap
    typealias S = OriginalApplicationMenuSession
    typealias P = OriginalApplicationPreparedStartupPlatform
    typealias Host = OriginalApplicationHostSession<P>
    typealias Driver = OriginalApplicationObservedGraphicsIteration<P>
    typealias E = OriginalMenuGraphicsRequestExchange
    typealias Q = OriginalMenuGraphicsRequest
    typealias R = OriginalLibSurfaceText.Response
    enum Stop: Error { case limit, late }
    enum Profile { case normal, positive, negative, zeroDC, failedCleanup, varied }
    final class Marker: OriginalApplicationStartupResource {}
    struct Run {
        let startup: D.Run, packet: O.Packet, before: A, driver: Driver, batch: Host.Batch
        let profile: Profile, served: [Q], checkpoints: [(S.Checkpoint,Int32?)]
    }
    func reply(_ q: OriginalFrontScreenEvent,_ profile: Profile,_ pass: Int) -> R {
        let dc: UInt32 = profile == .zeroDC ? 0 : profile == .varied ? 41 : 0x12345678
        switch q.kind {
        case "getDC":
            if profile == .varied && pass == 3 { return .init(result:-7) }
            return .init(result:profile == .negative ? -7 : profile == .positive || (profile == .varied && pass == 2) ? 1 : 0,output:dc)
        case "blit":return .init(result:profile == .varied ? -17 : 0)
        case "fill":return .init(result:profile == .varied ? -31 : 0)
        case "method":return .init(result:profile == .varied && q.arguments[1] != 8 ? -72 : 0)
        case "releaseDC":return .init(result:profile == .failedCleanup ? -1 : profile == .varied && pass == 1 ? -9 : 0)
        default:return .init(result:profile == .failedCleanup ? -1 : profile == .varied ? -23 : 0)
        }
    }
    func setup() throws -> (D.Run,O.Packet) {
        let r = try D().run(late:false),package = try OriginalApplicationStartupInputs.bundled()
        let packets = try O().packets(r.setup.controls.window,package)
        _ = try r.host.takeCommitted()
        for p in packets where !p.dispatch { try O().previous(r.host,p);_ = try r.host.takeCommitted() }
        return (r,try XCTUnwrap(packets.first { $0.dispatch }))
    }
    func observed(_ p: O.Packet) -> Host.Inputs {
        let i = p.initialization
        let poisoned = A.MenuInputs(settings:i.settings,prefix:i.prefix,
            body:.init(dcResult:Int32.min,dc:0xeeeeeeee,methodResult:123,drawResults:i.body.drawResults,shellResult:i.body.shellResult),
            frontAllocations:i.frontAllocations,backgroundAllocation:i.backgroundAllocation,
            frontResponses:[],backgroundResponses:[],bitmapResources:i.bitmapResources)
        return .init(initialization:poisoned,responses:p.responses,queue:p.queue,windowDefault:p.window,surface:[],lifecycle:[])
    }
    func run(profile: Profile, failure: String? = nil) throws -> Run {
        let (r,p) = try setup(),host = r.host,before = host.snapshot,old = try XCTUnwrap(before.session)
        let service = O().service(r,try OriginalApplicationStartupInputs.bundled()),driver = Driver(host:host)
        var served: [Q] = [],pass = 0,window = 0,failed = false,checkpoints: [(S.Checkpoint,Int32?)] = []
        for _ in 0..<1200 {
            var attemptPoints: [(S.Checkpoint,Int32?)] = []
            do {
                switch try driver.resume(prepare:{ _,_ in self.observed(p) },observe:{ observation in
                    if failure == "response" && !failed,case .front(_,let e) = observation,e.kind == "getDC" { throw Stop.late }
                },graphicsObserve:{ command in
                    if failure == "graphics" && !failed && command.event?.kind == "textOut" { throw Stop.late }
                },checkpoint:{ checkpoint,_,value in attemptPoints.append((checkpoint,value)) },
                beforeCommit:{ _,_ in
                    XCTAssertThrowsError(try driver.cancel()) { XCTAssertEqual($0 as? Driver.Boundary,.reentrantAttempt) }
                },beforePublication:{ _ in if failure == "publication" && !failed { throw Stop.late } }) {
                case .request(let permit):
                    B.same(try XCTUnwrap(host.snapshot.session),old);XCTAssertEqual(host.pendingBatchCount,0)
                    XCTAssertNil(try host.platformSnapshot().graphicsDelivery.cursor)
                    switch permit.request {
                    case .bitmap:
                        try service.serve(permit,on:driver)
                    case .window:
                        XCTAssertTrue(p.surface.indices.contains(window))
                        try driver.beginService(permit)
                        try driver.answer(permit,response:.window(p.surface[window]));window += 1
                    case .front(_,let q):
                        if q.kind == "getDC" { pass += 1 }
                        // Controlled terminal replies, not GDI/device observations.
                        try driver.beginService(permit)
                        try driver.answer(permit,response:.front(reply(q,profile,pass)),retaining:[Marker()])
                    }
                    served.append(permit.request)
                case .advanced(let outcome):
                    guard case .committed(let sequence,_) = outcome else { throw Stop.limit }
                    let batch = try XCTUnwrap(host.takeCommitted());XCTAssertEqual(batch.sequence,sequence)
                    XCTAssertEqual(window,p.surface.count);XCTAssertEqual(failed,failure != nil)
                    XCTAssertNil(try host.takeCommitted());checkpoints = attemptPoints
                    XCTAssertEqual(served,driver.exchangeSnapshot.receipts.map(\.request))
                    return .init(startup:r,packet:p,before:before,driver:driver,batch:batch,profile:profile,served:served,checkpoints:checkpoints)
                }
            } catch Stop.late {
                XCTAssertFalse(failed);failed = true
                B.same(try XCTUnwrap(host.snapshot.session),old);XCTAssertEqual(host.pendingBatchCount,0)
                XCTAssertEqual(driver.exchangeSnapshot.status,.open)
                XCTAssertEqual(served,driver.exchangeSnapshot.receipts.map(\.request))
            }
        }
        try D().close(r);throw Stop.limit
    }
    func prepared(_ r: Run, profile: Profile) throws -> (A,S.Committed) {
        var app = r.before;let p = r.packet,i = p.initialization,receipts = r.driver.exchangeSnapshot.receipts
        func controls(_ stage: A.Stage) -> [OriginalBitmapSurfaceLoading.Response] {
            receipts.compactMap { receipt in
                guard case .bitmap(let s,_) = receipt.request,s == stage,case .bitmap(let response) = receipt.response else { return nil }
                return .init(result:response.result,output:response.output)
            }
        }
        let dc: UInt32 = profile == .zeroDC ? 0 : 0x12345678
        let input = A.MenuInputs(settings:i.settings,prefix:i.prefix,
            body:.init(dcResult:profile == .negative ? -7 : profile == .positive ? 1 : 0,dc:dc,
                methodResult:profile == .failedCleanup ? -1 : 0,drawResults:[0],shellResult:i.body.shellResult),
            frontAllocations:i.frontAllocations,backgroundAllocation:i.backgroundAllocation,
            frontResponses:controls(.resources),backgroundResponses:controls(.prefix),bitmapResources:i.bitmapResources)
        let surface = receipts.compactMap { receipt -> OriginalWindowInitialization.Response? in
            if case .window(let response) = receipt.response { return response };return nil
        }
        guard case .committed(let batch) = try app.step(inputs:input,responses:p.responses,queue:p.queue,
            windowDefault:p.window,surface:surface,lifecycle:p.lifecycle) else { throw Stop.limit }
        return (app,batch)
    }
    func normalized(_ effect: S.Effect) throws -> S.Effect {
        switch effect {
        case .bitmap(let q,let r):return .bitmap(q,.init(result:r.result,output:r.output))
        case .frontAPI(let q,let r):
            switch q.kind {
            case "blit":return .blit(try XCTUnwrap(q.blit),result:r.result)
            case "fill":return .fill(try XCTUnwrap(q.fill),result:r.result)
            case "method":return q.arguments[1] == 8 ? .release(q,ignoredResult:r.result) : .present(q,result:r.result)
            case "getDC":return .getDC(q,result:r.result,output:try XCTUnwrap(r.output))
            default:return .startupGraphics(q,result:r.result)
            }
        default:return effect
        }
    }
    func normalized(_ q: OriginalApplicationGraphics.Command) -> OriginalApplicationGraphics.Command {
        .init(family:q.family,request:q.request,windowResponse:q.windowResponse,
            bitmapResponse:q.bitmapResponse.map { .init(result:$0.result,output:$0.output) },event:q.event,result:q.result,
            output:q.output,bindings:q.bindings,dependencies:q.dependencies,opaqueReferences:q.opaqueReferences,
            sourceRectangle:q.sourceRectangle,destinationRectangle:q.destinationRectangle,sourceColors:q.sourceColors)
    }
    func checkJournal(_ r: Run) throws {
        guard case .iteration(let iteration) = r.batch.contents else { throw Stop.limit }
        let receipts = r.driver.exchangeSnapshot.receipts
        let projected: [S.Effect] = try receipts.map { receipt in
            switch (receipt.request,receipt.response) {
            case let (.window(q),.window(a)):return .surface(q,a)
            case let (.bitmap(_,q),.bitmap(a)):return .bitmap(q,a)
            case let (.front(_,q),.front(a)):return .frontAPI(q,a)
            default:throw Stop.limit
            }
        }
        let effects = iteration.effects.filter { e in
            switch e { case .surface,.bitmap,.frontAPI:return true;default:return false }
        }
        XCTAssertEqual(effects,projected)
        XCTAssertEqual(iteration.graphics.count,receipts.count)
        for (command,receipt) in zip(iteration.graphics,receipts) {
            switch (receipt.request,receipt.response) {
            case let (.window(q),.window(a)):
                XCTAssertEqual(command.request,q);XCTAssertEqual(command.windowResponse,a)
            case let (.bitmap(_,q),.bitmap(a)):
                XCTAssertEqual(command.request,q);XCTAssertEqual(command.bitmapResponse,a)
            case let (.front(_,q),.front(a)):
                XCTAssertEqual(command.event,q);XCTAssertEqual(command.result,a.result);XCTAssertEqual(command.output,a.output)
            default:throw Stop.limit
            }
        }
        let bitmap = receipts.compactMap { receipt -> OriginalMacDisplayBackend.BitmapOperation? in
            if case .bitmap(_,let q) = receipt.request,case .bitmap(let a) = receipt.response { return .init(request:q,response:a) }
            return nil
        }
        XCTAssertEqual(r.startup.setup.display.bitmapOperations,bitmap)
        let state = try XCTUnwrap(r.batch.context.application.session).state,bindings = try XCTUnwrap(state.bitmapInputs)
        XCTAssertEqual(bindings.surfaces.count,25)
        for (token,surface) in bindings.surfaces {
            let pixels = try r.startup.setup.display.pixels(token),colors = surface.sourceColors
            XCTAssertEqual(pixels.width,colors.width);XCTAssertEqual(pixels.height,colors.height);XCTAssertEqual(pixels.defined,colors.defined)
            XCTAssertEqual(pixels.values,stride(from:0,to:colors.rgb.count,by:3).map { i in UInt32(colors.rgb[i])*65536+UInt32(colors.rgb[i+1])*256+UInt32(colors.rgb[i+2]) })
        }
        let fill = try XCTUnwrap(receipts.firstIndex { if case .front(.prefix,let q) = $0.request { return q.kind == "fill" };return false })
        let background = try XCTUnwrap(receipts.firstIndex { if case .bitmap(.prefix,_) = $0.request { return true };return false })
        XCTAssertLessThan(fill,background)
        XCTAssertEqual(r.driver.exchangeSnapshot.status,.finished)
        XCTAssertEqual(try r.batch.context.platformSnapshot().graphicsDelivery.cursor?.position,receipts.count)
    }
    func testWholeMenuOrderedGraphicsMatchesPreparedStateAndActualBitmapWork() throws {
        for profile in [Profile.normal,.positive,.negative,.zeroDC,.failedCleanup] {
            let r = try run(profile:profile);defer { try? D().close(r.startup) }
            try checkJournal(r)
            guard case .iteration(let actual) = r.batch.contents else { throw Stop.limit }
            let (app,expected) = try prepared(r,profile:profile)
            B.same(try XCTUnwrap(r.batch.context.application.session),try XCTUnwrap(app.session))
            try B.sameStartup(XCTUnwrap(r.batch.context.application.startup),XCTUnwrap(r.before.startup))
            XCTAssertEqual(try actual.effects.map(normalized),try expected.effects.map(normalized))
            XCTAssertEqual(actual.graphics.map(normalized),expected.graphics.map(normalized))
        }
    }
    func sameNonTextState(_ actual: S,_ previous: S) {
        XCTAssertEqual(actual.state.full,previous.state.full)
        XCTAssertEqual(actual.state.memory.replayPointers,previous.state.memory.replayPointers)
        XCTAssertEqual(actual.state.memory.allocations,previous.state.memory.allocations)
        XCTAssertEqual(actual.state.front.bitmaps,previous.state.front.bitmaps)
        XCTAssertEqual(actual.state.earlyScreen.bitmaps,previous.state.earlyScreen.bitmaps)
        XCTAssertEqual(actual.state.earlyScreen.surfaces,previous.state.earlyScreen.surfaces)
        XCTAssertEqual(actual.state.earlyScreen.retainedOperation,previous.state.earlyScreen.retainedOperation)
        XCTAssertEqual(actual.state.random,previous.state.random)
        XCTAssertEqual(actual.state.screenBody,previous.state.screenBody)
        XCTAssertEqual(actual.state.settings,previous.state.settings)
        XCTAssertEqual(actual.state.bitmapInputs,previous.state.bitmapInputs)
        XCTAssertEqual(actual.loop.message,previous.loop.message)
        XCTAssertEqual(actual.loop.counter,previous.loop.counter)
        XCTAssertEqual(actual.loop.timer.baseline,previous.loop.timer.baseline)
    }
    func testVariableRepliesPreserveDCGenerationsAndActualPresentationResult() throws {
        let r = try run(profile:.varied);defer { try? D().close(r.startup) };try checkJournal(r)
        let (baseline,baselineBatch) = try prepared(r,profile:.normal)
        let actual = try XCTUnwrap(r.batch.context.application.session),reference = try XCTUnwrap(baseline.session)
        sameNonTextState(actual,reference)
        XCTAssertEqual(actual.state.libraryText.retainedDC,41)
        let graphics = try XCTUnwrap(actual.state.graphics),previous = try XCTUnwrap(reference.state.graphics)
        XCTAssertEqual(graphics.resources,previous.resources);XCTAssertEqual(graphics.currentResources,previous.currentResources)
        XCTAssertEqual(graphics.displayModes,previous.displayModes)
        XCTAssertEqual(graphics.nextTextGeneration,2);XCTAssertEqual(graphics.textLeases.count,1)
        let lease = try XCTUnwrap(graphics.textLeases[0])
        XCTAssertEqual(lease.ref,.init(kind:"textDC",token:41,generation:0));XCTAssertEqual(lease.acquireResult,0)
        XCTAssertEqual(lease.releaseResults,[-9])
        var copy = graphics
        XCTAssertThrowsError(try copy.front(.init("textOut",[41,0,0,1],[[65]]),result:1,inputs:actual.state.bitmapInputs)) {
            XCTAssertEqual($0 as? OriginalApplicationGraphics.Boundary,.dc(41))
        }
        XCTAssertEqual(copy,graphics)
        XCTAssertEqual(try XCTUnwrap(r.checkpoints.first { $0.0 == .worldReturn }).1,-72)
        XCTAssertEqual(try XCTUnwrap(r.checkpoints.first { $0.0 == .dispatchReturn }).1,1)
        let textKinds: Set<String> = ["getDC","setBackgroundMode","setTextColor","textOut","releaseDC"]
        guard case .iteration(let iteration) = r.batch.contents else { throw Stop.limit }
        let nonText: (OriginalApplicationGraphics.Command) -> Bool = { !textKinds.contains($0.event?.kind ?? "") }
        let expectedNonText = baselineBatch.graphics.filter(nonText).map { original -> OriginalApplicationGraphics.Command in
            let q = normalized(original),value = q.event.map { reply($0,.varied,0).result } ?? q.result
            return .init(family:q.family,request:q.request,windowResponse:q.windowResponse,bitmapResponse:q.bitmapResponse,
                event:q.event,result:value,output:q.output,bindings:q.bindings,dependencies:q.dependencies,
                opaqueReferences:q.opaqueReferences,sourceRectangle:q.sourceRectangle,destinationRectangle:q.destinationRectangle,sourceColors:q.sourceColors)
        }
        XCTAssertEqual(iteration.graphics.filter(nonText).map(normalized),expectedNonText)
        let text = r.driver.exchangeSnapshot.receipts.compactMap { receipt -> (OriginalFrontScreenEvent,R)? in
            if case .front(.body,let q) = receipt.request,textKinds.contains(q.kind),case .front(let a) = receipt.response { return (q,a) }
            return nil
        }
        let fr = try B.F.Resources(),body = try B.Body.Resources(fr)
        let target: UInt32 = try XCTUnwrap(r.before.session).state.full.integer(at:0x455608-0x44d000,as:UInt32.self)
        var expected: [OriginalFrontScreenEvent] = [],pass = 0
        for event in body.c.cases[0].events.compactMap({ $0.event }) where textKinds.contains(event.kind) {
            if event.kind == "getDC" { pass += 1 }
            if pass == 3 && event.kind != "getDC" { continue }
            var args = event.arguments
            if event.kind == "getDC" { args[0] = target }
            else if event.kind == "releaseDC" { args[0] = target;args[1] = 41 }
            else { args[0] = 41 }
            expected.append(.init(event.kind,args,event.strings))
        }
        XCTAssertEqual(pass,3);XCTAssertEqual(text.map { $0.0 },expected)
        XCTAssertEqual(text.map { $0.1.result },[0,-23,-23,-23,-9,1,-23,-23,-23,0,-7])
        XCTAssertEqual(text.map { $0.1.output },[41,nil,nil,nil,nil,41,nil,nil,nil,nil,nil])
    }
    func testLateFailuresRetryWholeIterationWithoutRepeatingService() throws {
        for failure in ["response","graphics","publication"] {
            let r = try run(profile:.normal,failure:failure);defer { try? D().close(r.startup) }
            try checkJournal(r)
            let (reference,_) = try prepared(r,profile:.normal)
            B.same(try XCTUnwrap(r.batch.context.application.session),try XCTUnwrap(reference.session))
            XCTAssertThrowsError(try r.driver.resume(prepare:{ _,_ in self.observed(r.packet) })) {
                XCTAssertEqual($0 as? E.Boundary,.closed(.finished))
            }
        }
    }
    func ticket(_ exchange: E,_ q: Q) throws -> E.Permit {
        var cursor = try exchange.snapshot.cursor()
        do { _ = try cursor.response(for:q);throw Stop.limit }
        catch let needed as E.RequestNeeded { return try exchange.claim(needed) }
    }
    func message(_ window: UInt32,_ responses: S.Responses) throws -> Host.Inputs {
        var msg = try OriginalStateRecord(bytes:Array(repeating:0,count:28),defined:Array(repeating:true,count:28))
        try msg.write(window,at:0);try msg.write(UInt32(0x100),at:4);try msg.write(UInt32(74),at:8)
        return .init(responses:responses,queue:[.init(result:1),.init(result:1,writes:[.init(offset:0,bytes:msg.bytes)]),.init(),.init()],windowDefault:[0])
    }
    func testProtocolFamiliesStaleHostCancellationAndIndeterminateService() throws {
        let getDC = Q.front(.body,.init("getDC",[1])),exchange = E(),other = E()
        let p = try ticket(exchange,getDC),foreign = try ticket(other,getDC)
        XCTAssertThrowsError(try exchange.answer(foreign,response:.front(.init(result:0,output:0)))) {
            XCTAssertEqual($0 as? E.Boundary,.foreignOwner)
        }
        for response in [Q.Reply.window(.init()),.bitmap(.init()),.front(.init(result:0))] {
            XCTAssertThrowsError(try exchange.answer(p,response:response)) { XCTAssertEqual($0 as? E.Boundary,.responseMismatch) }
        }
        XCTAssertTrue(exchange.snapshot.receipts.isEmpty);XCTAssertFalse(exchange.snapshot.serviceStarted)
        try exchange.beginService(p)
        XCTAssertThrowsError(try exchange.beginService(p)) { XCTAssertEqual($0 as? E.Boundary,.serviceAlreadyStarted) }
        exchange.cancel()
        try exchange.answer(p,response:.front(.init(result:0,output:0)),retaining:[Marker()])
        XCTAssertEqual(exchange.snapshot.status,.cancelled);XCTAssertEqual(exchange.snapshot.receipts.count,1)
        XCTAssertThrowsError(try exchange.answer(p,response:.front(.init(result:0,output:0)))) { XCTAssertEqual($0 as? E.Boundary,.invalidPermit) }
        try other.beginService(foreign);other.cancel()
        try other.fail(foreign,diagnostic:"controlled unknown outcome",retaining:[Marker()])
        XCTAssertEqual(other.snapshot.status,.indeterminate);XCTAssertEqual(other.snapshot.failure?.afterCancellation,true)
        XCTAssertFalse(Q.front(.body,.init("stringLength")).accepts(.front(.init(result:0))))
        var absent = OriginalMenuGraphicsDelivery()
        XCTAssertThrowsError(try absent.response(for:getDC)) { XCTAssertEqual($0 as? Driver.Boundary,.missingCursor) }
        let (r,packet) = try setup();defer { try? D().close(r) }
        let driver = Driver(host:r.host),service = O().service(r,try OriginalApplicationStartupInputs.bundled())
        guard case .request(let request) = try driver.resume(prepare:{ _,_ in self.observed(packet) }) else { throw Stop.limit }
        guard case .window = request.request else { throw Stop.limit }
        let operations = r.setup.display.bitmapOperations.count
        XCTAssertThrowsError(try service.serve(request,on:driver))
        XCTAssertEqual(r.setup.display.bitmapOperations.count,operations);XCTAssertFalse(driver.exchangeSnapshot.serviceStarted)
        try driver.cancel()
        XCTAssertThrowsError(try driver.beginService(request)) { XCTAssertEqual($0 as? E.Boundary,.closed(.cancelled)) }
        let stale = Driver(host:r.host),next = Driver(host:r.host),input = try message(r.setup.controls.window,packet.responses)
        guard case .advanced(.committed) = try next.resume(prepare:{ _,_ in input }) else { throw Stop.limit }
        XCTAssertThrowsError(try stale.resume(prepare:{ _,_ in input })) { XCTAssertEqual($0 as? Host.Boundary,.staleSequence) }
        XCTAssertTrue(stale.exchangeSnapshot.receipts.isEmpty)
    }
    func testRetainedHistoryInspectionCopiesAndContextResourceLifetime() throws {
        weak var marker: Marker?
        var saved: Host.DeliveryContext?
        func exercise() throws {
            let r = try run(profile:.normal);defer { try? D().close(r.startup) }
            marker = try XCTUnwrap(r.driver.exchangeSnapshot.receipts.flatMap(\.resources).compactMap { $0 as? Marker }.first)
            let host = r.startup.host,input = try message(r.startup.setup.controls.window,r.packet.responses)
            let next = Driver(host:host)
            guard case .advanced(.committed) = try next.resume(prepare:{ _,_ in input }) else { throw Stop.limit }
            XCTAssertEqual(try host.platformSnapshot().graphicsDelivery.retainedIterationCount,1)
            XCTAssertEqual(try host.platformSnapshot().graphicsDelivery.cursor?.position,0)
            saved = try XCTUnwrap(host.takeCommitted()).context
            let inspection = try XCTUnwrap(saved).platformSnapshot();inspection.graphicsDelivery = .init()
            XCTAssertEqual(try saved?.platformSnapshot().graphicsDelivery.retainedIterationCount,1)
            let empty = Driver(host:host)
            guard case .advanced(.committed) = try empty.resume(prepare:{ _,_ in input }) else { throw Stop.limit }
            XCTAssertEqual(try host.platformSnapshot().graphicsDelivery.retainedIterationCount,1)
            XCTAssertEqual(try saved?.platformSnapshot().graphicsDelivery.retainedIterationCount,1)
        }
        try exercise();XCTAssertNotNil(marker)
        saved = nil;XCTAssertNil(marker)
    }
}
