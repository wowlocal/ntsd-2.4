import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalWindowRequestExchangeTests: XCTestCase {
    typealias E = OriginalWindowRequestExchange
    typealias W = OriginalWindowInitializationTests
    typealias P = OriginalWinMainStartupTests
    enum Harness: Error { case missingSuspension }
    final class Resource: OriginalWindowResponseResource { let token: UInt32; init(_ token: UInt32) { self.token = token } }

    private func needed(_ cursor: inout E.Cursor, _ request: E.Request) throws -> E.RequestNeeded {
        do { _ = try cursor.response(for: request); XCTFail("Missing request suspension"); throw Harness.missingSuspension }
        catch let ticket as E.RequestNeeded { return ticket }
    }
    private func rejects(_ expected: E.Boundary, file: StaticString = #filePath, line: UInt = #line,
        _ body: () throws -> Void) {
        XCTAssertThrowsError(try body(),file:file,line:line) { XCTAssertEqual($0 as? E.Boundary,expected,file:file,line:line) }
    }
    private func serve(_ exchange: E, _ ticket: E.RequestNeeded, _ response: E.Response) throws {
        let permit = try exchange.claim(ticket)
        try exchange.answer(permit,response:response)
    }

    func testEveryWholeWindowRequestSuspendsAndRetainsOriginalFailures() throws {
        let old = W(), corpus = try old.corpus(); var total = 0
        XCTAssertEqual(corpus.cases.count,280)
        for c in corpus.cases {
            let before = try old.initial(c), exchange = E(); var served = 0, returned = false
            for _ in 0...c.events.count {
                var state = before, cursor = try exchange.snapshot.cursor(), event = 0, frame = 0
                do {
                    let result = try OriginalWindowInitialization.initialize(instance:c.spec.instance ?? 0x400000,
                        show:c.spec.show ?? 10,globals:&state,backing:{ kind,count in
                            guard frame < c.backings.count else { throw Harness.missingSuspension }
                            let backing = c.backings[frame]; frame += 1
                            XCTAssertEqual(kind,backing.kind); XCTAssertEqual(count,backing.bytes.count)
                            return backing.bytes
                        },perform:{ request in
                            guard event < c.events.count else { throw Harness.missingSuspension }
                            XCTAssertEqual(request,c.events[event].request,"case \(c.index), request \(event)")
                            event += 1; return try cursor.response(for:request)
                        })
                    XCTAssertEqual(result.returnCode,c.result); XCTAssertEqual(result.written,c.written.map { $0 != 0 })
                    XCTAssertTrue(state.bytes == c.after,"whole window \(c.index)"); XCTAssertTrue(state.defined.allSatisfy { $0 })
                    XCTAssertEqual(event,c.events.count); XCTAssertEqual(frame,c.backings.count)
                    let journal = try exchange.finish(cursor)
                    XCTAssertEqual(journal.status,.finished); XCTAssertEqual(journal.receipts.count,c.events.count)
                    var counts: [String:Int] = [:], objects: [W.Object] = []
                    for (receipt,expected) in zip(journal.receipts,c.events) {
                        XCTAssertEqual(receipt.request,expected.request); XCTAssertEqual(receipt.response,expected.response)
                        let kind = receipt.request.kind; counts[kind,default:0] += 1
                        let key = kind+"#"+String(counts[kind]!); XCTAssertEqual(key,expected.key)
                        if let token = receipt.response.output {
                            XCTAssertFalse(objects.contains { $0.address == token })
                            let family = kind == "directDrawCreate" ? "draw" : kind == "createClipper" ? "clipper" : "surface"
                            objects.append(.init(address:token,family:family,releases:[]))
                        }
                        if kind == "release" {
                            let at = try XCTUnwrap(objects.firstIndex { $0.address == receipt.request.words[0] })
                            objects[at].releases.append(.init(key:key,result:UInt32(bitPattern:receipt.response.result)))
                        }
                    }
                    XCTAssertEqual(objects,c.objects); returned = true; break
                } catch let ticket as E.RequestNeeded {
                    XCTAssertEqual(state,before); XCTAssertTrue(cursor.isSuspended)
                    XCTAssertEqual(ticket.ordinal,served); XCTAssertEqual(event,served+1)
                    XCTAssertEqual(ticket.request,c.events[served].request)
                    try serve(exchange,ticket,c.events[served].response); served += 1
                }
            }
            XCTAssertTrue(returned); XCTAssertEqual(served,c.events.count); total += served
        }
        XCTAssertEqual(total,4574)
        print("WindowExchange: 280 whole windows; 4574 externally fulfilled declared requests, each served once")
    }

    func testWholeWinMainParentsAndDistinctBoundariesUseSuspendedResponses() throws {
        let old = P(), (corpus,raw) = try old.read(); var cache: [String:[UInt8]] = [:]
        XCTAssertEqual(corpus.exeSHA256,"3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        XCTAssertEqual(corpus.dllSHA256,"c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d")
        func blob(_ hash: String) throws -> [UInt8] {
            if let value = cache[hash] { return value }
            let entry = try XCTUnwrap(corpus.blobs[hash])
            let value = try MatchPreparationReference.inflate(entry.deflate,count:entry.count,maximumCount:10_000_000)
            XCTAssertEqual(MatchPreparationReference.digest(Data(value)),hash); cache[hash] = value; return value
        }
        let sources = Dictionary(uniqueKeysWithValues:corpus.sources.map { ($0.path,$0.sha256) })
        var whole = 0, stops = 0, unknown = 0, events = 0, waves = 0, served = 0
        for (c,r) in zip(corpus.cases,raw) {
            var before = try OriginalStateRecord(bytes:blob(c.initialGlobals),defined:[Bool](repeating:true,count:OriginalMatchPreparation.globalSize))
            for w in c.stimulus { for (i,b) in P.hex(w.bytes).enumerated() { try before.write(b,at:w.address-OriginalMatchPreparation.globalBase+i) } }
            XCTAssertTrue(before.bytes == (try blob(c.beforeGlobals)))
            let exchange = E(), windowCount = c.events.filter { $0.kind == "window" }.count
            var ended = false, count = 0
            for _ in 0...windowCount {
                var globals = before, engine = OriginalWinMainStartup(); let prior = engine
                let base = try P.Adapter(c,r,sources:sources,blob:blob,initial:before.bytes)
                base.windowExchange = try exchange.snapshot.cursor()
                let p = try base.stagedCopy()
                try p.calendar(engine.output.calendar,c.before)
                do {
                    try engine.run(instance:c.spec.instance ?? 0x400000,show:c.spec.show ?? 10,globals:&globals,platform:p,store:p.store)
                    XCTAssertEqual(c.end,"startupBoundary"); XCTAssertEqual(c.endPC,0x43d100); XCTAssertEqual(c.endSP,0x1000effc)
                    try p.complete(engine,globals); _ = try exchange.finish(XCTUnwrap(p.windowExchange)); whole += 1
                } catch let ticket as E.RequestNeeded {
                    XCTAssertEqual(globals,before); old.rollback(engine,prior)
                    XCTAssertEqual(ticket.ordinal,count); XCTAssertEqual(base.windowExchange?.position,0)
                    XCTAssertFalse(try XCTUnwrap(base.windowExchange).isSuspended)
                    let input = try XCTUnwrap(c.events[p.index-1].event)
                    XCTAssertEqual(c.events[p.index-1].kind,"window")
                    try serve(exchange,ticket,XCTUnwrap(input.response)); count += 1; continue
                } catch let error as OriginalWinMainStartup.Boundary {
                    XCTAssertEqual(error,.unknownFullscreenCursor)
                    let next = try XCTUnwrap(c.events[p.index].event), request = try XCTUnwrap(next.request)
                    XCTAssertEqual(request.kind,"registerClass"); XCTAssertEqual(request.defined.map { Array($0[24..<28]) },[false,false,false,false])
                    let cursor = 0x1000efd8
                    XCTAssertTrue(c.stackStores.prefix(try XCTUnwrap(next.stackStoreCount)).allSatisfy { $0.address >= cursor+4 || $0.address+P.hex($0.bytes).count <= cursor })
                    p.compareStores(count:try XCTUnwrap(next.globalStoreCount)); unknown += 1
                    XCTAssertEqual(globals,before); old.rollback(engine,prior); exchange.cancel()
                } catch OriginalStateError.undefinedBytes(let offset,let length) {
                    let b = try XCTUnwrap(c.panel.ownBoundary ?? c.input?.ownBoundary)
                    XCTAssertEqual(offset,b.offset); XCTAssertEqual(length,b.count); XCTAssertEqual(p.index,b.rootEventCount)
                    p.compareStores(count:b.globalStoreCount); XCTAssertTrue(p.shadow == (try blob(b.rootGlobals))); unknown += 1
                    XCTAssertEqual(globals,before); old.rollback(engine,prior); exchange.cancel()
                } catch let error as OriginalStartupOutput.Boundary {
                    XCTAssertEqual(c.end,"nullCalendarRead"); XCTAssertEqual(error,.nullCalendarRead(address:try XCTUnwrap(c.boundaryPC)))
                    p.compareStores(count:c.globalStores.count); XCTAssertEqual(p.index,c.events.count); stops += 1
                    XCTAssertEqual(globals,before); old.rollback(engine,prior); exchange.cancel()
                } catch let error as OriginalCalendarTime.Boundary {
                    XCTAssertEqual(c.end,"invalidParameter"); XCTAssertEqual(error,.invalidParameter)
                    p.compareStores(count:c.globalStores.count); XCTAssertEqual(p.index,c.events.count); stops += 1
                    XCTAssertEqual(globals,before); old.rollback(engine,prior); exchange.cancel()
                } catch OriginalStateError.invalidStorage(let message) {
                    XCTAssertEqual(message,"Original menu wave reaches invalid CreateSoundBuffer continuation")
                    XCTAssertEqual(c.end,"invalidCreateContinuation"); XCTAssertEqual(c.boundaryPC,0x40187a)
                    p.compareStores(count:c.globalStores.count); XCTAssertEqual(p.index,c.events.count); stops += 1
                    XCTAssertEqual(globals,before); old.rollback(engine,prior); exchange.cancel()
                }
                XCTAssertEqual(base.windowExchange?.position,0); XCTAssertEqual(base.index,0)
                XCTAssertEqual(exchange.snapshot.receipts.count,count)
                XCTAssertEqual(c.controlWord,0x37f); events += p.index; waves += p.waves; served += count
                ended = true; break
            }
            XCTAssertTrue(ended,c.spec.label)
        }
        XCTAssertEqual(corpus.cases.count,35); XCTAssertEqual(whole,23); XCTAssertEqual(stops,5); XCTAssertEqual(unknown,7)
        XCTAssertEqual(events,6325); XCTAssertEqual(waves,119)
        print("WindowExchange WinMain:",whole,"whole",stops,"source stops",unknown,"provenance rejections",served,"window replies")
    }

    func testLateWholeStartupFailuresRetryWithoutServingWindowAgain() throws {
        let old = P(), (corpus,raw) = try old.read(), c = try XCTUnwrap(corpus.cases.first), r = try XCTUnwrap(raw.first)
        func blob(_ h: String) throws -> [UInt8] { let p = try XCTUnwrap(corpus.blobs[h]); return try MatchPreparationReference.inflate(p.deflate,count:p.count,maximumCount:10_000_000) }
        let sources = Dictionary(uniqueKeysWithValues:corpus.sources.map { ($0.path,$0.sha256) })
        let before = try OriginalStateRecord(bytes:blob(c.initialGlobals),defined:[Bool](repeating:true,count:OriginalMatchPreparation.globalSize))
        let windowCount = c.events.filter { $0.kind == "window" }.count
        for phase in ["window-return","panel-return","secondDate","output-return","fifthWave","after"] {
            let exchange = E(); var reached = false
            for _ in 0...windowCount {
                var globals = before, engine = OriginalWinMainStartup(); let prior = engine
                let p = try P.Adapter(c,r,sources:sources,blob:blob,initial:before.bytes,fail:phase)
                p.windowExchange = try exchange.snapshot.cursor()
                do {
                    try engine.run(instance:0x400000,show:10,globals:&globals,platform:p,store:p.store,
                        after:{ _,_ in if phase == "after" { throw P.Trial.late } })
                    XCTFail("Missing late failure"); break
                } catch let ticket as E.RequestNeeded {
                    XCTAssertEqual(globals,before); old.rollback(engine,prior)
                    try serve(exchange,ticket,XCTUnwrap(c.events[p.index-1].event?.response))
                } catch P.Trial.late {
                    XCTAssertEqual(globals,before); old.rollback(engine,prior); reached = true; break
                }
            }
            XCTAssertTrue(reached); XCTAssertEqual(exchange.snapshot.receipts.count,windowCount)
            let saved = exchange.snapshot
            var globals = before, engine = OriginalWinMainStartup()
            let p = try P.Adapter(c,r,sources:sources,blob:blob,initial:before.bytes)
            p.windowExchange = try saved.cursor()
            try engine.run(instance:0x400000,show:10,globals:&globals,platform:p,store:p.store)
            try p.complete(engine,globals)
            let completed = try exchange.finish(XCTUnwrap(p.windowExchange))
            XCTAssertEqual(completed.receipts.count,windowCount)
            XCTAssertEqual(completed.receipts.map(\.request),saved.receipts.map(\.request))
            XCTAssertEqual(completed.receipts.map(\.response),saved.receipts.map(\.response))
        }
    }

    func testProtocolRejectsWrongOwnersReentryAndClosedOrIncompleteWork() throws {
        let a = E(), b = E(), q = E.Request("metric",[7]), next = E.Request("metric",[8])
        let empty = a.snapshot; var first = try empty.cursor(), sibling = first
        let ticket = try needed(&first,q), other = try needed(&sibling,next)
        rejects(.suspendedCursor) { _ = try first.response(for:q) }
        rejects(.suspendedCursor) { _ = try a.finish(first) }
        rejects(.foreignOwner) { _ = try b.claim(ticket) }
        let permit = try a.claim(ticket)
        rejects(.requestInFlight) { _ = try a.claim(ticket) }
        rejects(.requestInFlight) { _ = try a.claim(other) }
        rejects(.requestInFlight) { _ = try a.snapshot.cursor() }
        rejects(.foreignOwner) { try b.answer(permit,response:.init(result:99)) }
        try a.answer(permit,response:.init(result:-17,output:0x12345678,bytes:[1,2,3]))
        rejects(.invalidPermit) { try a.answer(permit,response:.init(result:0)) }
        rejects(.invalidPermit) { try a.fail(permit,diagnostic:"duplicate") }
        rejects(.staleRevision) { _ = try a.claim(ticket) }
        rejects(.staleRevision) { _ = try a.claim(other) }
        rejects(.staleRevision) { _ = try a.finish(try empty.cursor()) }
        var cursor = try a.snapshot.cursor(), copy = cursor
        rejects(.unconsumedReplies) { _ = try a.finish(cursor) }
        rejects(.requestMismatch(0)) { _ = try cursor.response(for:next) }
        XCTAssertEqual(cursor.position,0)
        XCTAssertEqual(try cursor.response(for:q),.init(result:-17,output:0x12345678,bytes:[1,2,3]))
        XCTAssertEqual(copy.position,0); XCTAssertEqual(try copy.response(for:q),a.snapshot.receipts[0].response)
        var foreign = try b.snapshot.cursor(); let foreignTicket = try needed(&foreign,q)
        rejects(.foreignOwner) { _ = try a.finish(foreign) }
        let end = try a.finish(cursor); XCTAssertEqual(end.status,.finished)
        rejects(.closed(.finished)) { _ = try a.finish(copy) }
        rejects(.closed(.finished)) { _ = try end.cursor() }
        rejects(.closed(.finished)) { _ = try a.claim(ticket) }
        b.cancel(); rejects(.closed(.cancelled)) { _ = try b.claim(foreignTicket) }
        let c = E(); var pending = try c.snapshot.cursor(); let need = try needed(&pending,next)
        let issued = try c.claim(need); c.cancel()
        rejects(.closed(.cancelled)) { _ = try c.claim(need) }
        try c.fail(issued,diagnostic:"physical result unavailable")
        XCTAssertEqual(c.snapshot.status,.indeterminate); XCTAssertEqual(c.snapshot.failure?.request,next)
        XCTAssertEqual(c.snapshot.failure?.diagnostic,"physical result unavailable"); XCTAssertEqual(c.snapshot.failure?.afterCancellation,true)
        XCTAssertTrue(c.snapshot.receipts.isEmpty)
        rejects(.closed(.indeterminate)) { _ = try c.snapshot.cursor() }
        rejects(.invalidPermit) { try c.answer(issued,response:.init(result:0)) }

        let d = E(); var d0 = try d.snapshot.cursor()
        let dt0 = try needed(&d0,q), dp0 = try d.claim(dt0)
        try d.answer(dp0,response:.init(result:1))
        var d1 = try d.snapshot.cursor(); _ = try d1.response(for:q)
        let dt1 = try needed(&d1,next), dp1 = try d.claim(dt1)
        rejects(.invalidPermit) { try d.answer(dp0,response:.init(result:2)) }
        rejects(.invalidPermit) { try d.fail(dp0,diagnostic:"out of order") }
        XCTAssertEqual(d.snapshot.outstandingRequest,next); XCTAssertEqual(d.snapshot.receipts.count,1)
        try d.answer(dp1,response:.init(result:3))
        var d2 = try d.snapshot.cursor()
        XCTAssertEqual(try d2.response(for:q).result,1); XCTAssertEqual(try d2.response(for:next).result,3)
        _ = try d.finish(d2)

        let structures = E()
        let raw = try OriginalStateRecord(bytes:[UInt8](repeating:0xa5,count:40),defined:[Bool](repeating:false,count:40))
        let request = E.Request("registerClass",strings:[[65]],structure:raw)
        var s0 = try structures.snapshot.cursor()
        try serve(structures,needed(&s0,request),.init(result:1))
        var bytes = raw.bytes; bytes[24] = 0
        var mask = raw.defined; mask[24] = true
        let changedBytes = try OriginalStateRecord(bytes:bytes,defined:raw.defined)
        let changedMask = try OriginalStateRecord(bytes:raw.bytes,defined:mask)
        var s1 = try structures.snapshot.cursor()
        for changed in [E.Request("registerClass",strings:[[66]],structure:raw),
                        E.Request("registerClass",strings:[[65]],structure:changedBytes),
                        E.Request("registerClass",strings:[[65]],structure:changedMask)] {
            rejects(.requestMismatch(0)) { _ = try s1.response(for:changed) }
            XCTAssertEqual(s1.position,0)
        }
        XCTAssertEqual(try s1.response(for:request).result,1); _ = try structures.finish(s1)
    }

    func testReceiptsAndSnapshotsOwnResourcesAcrossCompletionCancellationAndDeath() throws {
        let q = E.Request("createWindow"), response = E.Response(result:123)
        var exchange: E? = E(), resource: Resource? = Resource(123)
        weak var weakResource = resource
        var beginning = try XCTUnwrap(exchange).snapshot.cursor()
        let ticket = try needed(&beginning,q), permit = try XCTUnwrap(exchange).claim(ticket)
        try XCTUnwrap(exchange).answer(permit,response:response,retaining:[try XCTUnwrap(resource)])
        var saved: E.Snapshot? = try XCTUnwrap(exchange).snapshot
        var cursor: E.Cursor? = try XCTUnwrap(saved).cursor(), copy = cursor
        XCTAssertEqual(try cursor?.response(for:q),response)
        _ = try XCTUnwrap(exchange).finish(XCTUnwrap(cursor)); resource = nil; exchange = nil
        XCTAssertEqual(weakResource?.token,123); saved = nil; cursor = nil
        XCTAssertNotNil(weakResource); XCTAssertEqual(try copy?.response(for:q),response)
        copy = nil; XCTAssertNil(weakResource)

        var cancelled: E? = E(), late: Resource? = Resource(456)
        weak var weakLate = late
        var c = try XCTUnwrap(cancelled).snapshot.cursor()
        let t = try needed(&c,q), issued = try XCTUnwrap(cancelled).claim(t)
        let before = try XCTUnwrap(cancelled).snapshot
        cancelled?.cancel()
        try XCTUnwrap(cancelled).answer(issued,response:.init(result:456),retaining:[try XCTUnwrap(late)])
        var after: E.Snapshot? = try XCTUnwrap(cancelled).snapshot
        XCTAssertEqual(after?.status,.cancelled); XCTAssertEqual(after?.receipts.count,1)
        XCTAssertEqual(before.status,.open); XCTAssertTrue(before.receipts.isEmpty); XCTAssertEqual(before.outstandingRequest,q)
        rejects(.invalidPermit) { try XCTUnwrap(cancelled).answer(issued,response:.init(result:999)) }
        late = nil; cancelled = nil; XCTAssertEqual(weakLate?.token,456)
        after = nil; XCTAssertNil(weakLate)

        var failed: E? = E(), partial: Resource? = Resource(789)
        weak var weakPartial = partial
        var f = try XCTUnwrap(failed).snapshot.cursor()
        let ft = try needed(&f,q), fp = try XCTUnwrap(failed).claim(ft)
        try XCTUnwrap(failed).fail(fp,diagnostic:"partial backend work",retaining:[try XCTUnwrap(partial)])
        var failure: E.Snapshot? = try XCTUnwrap(failed).snapshot
        XCTAssertEqual(failure?.status,.indeterminate); XCTAssertTrue(try XCTUnwrap(failure).receipts.isEmpty)
        XCTAssertEqual(failure?.failure?.afterCancellation,false)
        partial = nil; failed = nil; XCTAssertEqual(weakPartial?.token,789)
        failure = nil; XCTAssertNil(weakPartial)
    }
}
