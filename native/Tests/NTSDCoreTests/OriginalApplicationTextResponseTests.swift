import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

/// Provider inputs come from saved source case specifications; after-state is
/// comparison-only. Native exception controls are not original fault matches.
final class OriginalApplicationTextResponseTests: XCTestCase {
    typealias F = OriginalApplicationFrontScreenTests
    typealias B = OriginalBitmapSurfaceLoadingTests
    typealias Entry = OriginalApplicationDispatchEntryTests
    typealias Resources = OriginalApplicationScreenBodyTests.Resources
    typealias Adapter = OriginalApplicationScreenBodyTests.Adapter
    typealias Response = OriginalLibSurfaceText.Response

    func testPerRequestRepliesMatchInstalledCorpusAndRetainedChain() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource:"original-lib-surface-text",withExtension:"json",subdirectory:"Fixtures"))
        let c = try JSONDecoder().decode(OriginalLibSurfaceTextTests.Corpus.self,
            from:MatchPreparationReference.unpack(Data(contentsOf:url),maximumCount:5_000_000))
        XCTAssertEqual(c.exeSHA256,"3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        XCTAssertEqual(c.libSHA256,"28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba")
        XCTAssertEqual(c.cases.count,276);XCTAssertEqual(c.retainedChain.count,6)
        var chain: OriginalLibSurfaceText?, totalEvents = 0, totalBytes = 0
        for item in c.cases {
            var state = c.retainedChain.contains(item.index) ? chain ?? .init(retainedDC:item.retainedDC) : .init(retainedDC:item.retainedDC)
            XCTAssertEqual(state.retainedDC,item.retainedDC)
            var events: [OriginalMenuPresentationEvent] = [], requests: [OriginalMenuPresentationEvent] = []
            var replies: [Response] = [], order: [String] = []
            let value = try state.draw(item.text,target:item.target,background:item.background,color:item.color,x:item.x,y:item.y,
                perform:{ q in
                    requests.append(q);order.append("request:"+q.kind.rawValue)
                    // Non-GetDC numeric replies are deliberate Native controls;
                    // original semantics ignores them. No device success claim.
                    return .init(result:q.kind == .getDC ? item.dcResult : Int32.min+Int32(requests.count),
                                 output:q.kind == .getDC ? item.dc : nil)
                },didRespond:{ q,r in
                    XCTAssertEqual(requests.last,q);replies.append(r);order.append("reply:"+q.kind.rawValue)
                },observe:{ q in events.append(q);order.append("event:"+q.kind.rawValue) })
            XCTAssertEqual(value,item.result);XCTAssertEqual(events,item.events,"case \(item.index)")
            XCTAssertEqual(state.retainedDC,item.retainedDCAfter)
            XCTAssertEqual(requests,item.events.filter { $0.kind != .stringLength })
            XCTAssertEqual(replies.count,requests.count)
            let expectedOrder = item.events.flatMap { q in q.kind == .stringLength ? ["event:"+q.kind.rawValue] : ["request:"+q.kind.rawValue,"reply:"+q.kind.rawValue,"event:"+q.kind.rawValue] }
            XCTAssertEqual(order,expectedOrder)
            for (i,r) in replies.enumerated() {
                XCTAssertEqual(r.result,i == 0 ? item.dcResult : Int32.min+Int32(i+1))
                XCTAssertEqual(r.output,i == 0 ? item.dc : nil)
            }
            var storage = try OriginalStateRecord(bytes:item.before,defined:[Bool](repeating:true,count:item.before.count))
            XCTAssertEqual(try storage.integer(at:0x6e,as:UInt32.self),item.retainedDC)
            try storage.write(state.retainedDC,at:0x6e);XCTAssertEqual(storage.bytes,item.after)
            totalEvents += events.count;totalBytes += storage.bytes.count
            if c.retainedChain.contains(item.index) { chain = state }
        }
        XCTAssertEqual(totalEvents,1106);XCTAssertEqual(totalBytes,44436)
    }

    func testMissingOutputIgnoredResultsAndEachLateFailureRollBack() throws {
        enum Stop: Error { case late }
        let seed = OriginalLibSurfaceText(retainedDC:0xaabbccdd)
        let api = ["getDC","setBackgroundMode","setTextColor","textOut","releaseDC"]
        for (result,output) in [(Int32(-7),UInt32?.none),(-7,.some(91)),(0,.some(0)),(7,.some(0xfedcba98))] {
            var state = seed, events: [OriginalMenuPresentationEvent] = [], replies: [Response] = []
            let returned = try state.draw([0xff],target:17,background:2,color:0xffffffff,x:Int32.min,y:Int32.max,
                perform:{ .init(result:$0.kind == .getDC ? result : Int32.min,output:$0.kind == .getDC ? output : nil) },
                didRespond:{ _,r in replies.append(r) },observe:{ events.append($0) })
            XCTAssertEqual(returned,result);XCTAssertEqual(state.retainedDC,result < 0 ? seed.retainedDC : output!)
            XCTAssertEqual(events.count,result < 0 ? 1 : 6);XCTAssertEqual(replies.count,result < 0 ? 1 : 5)
            if result >= 0 { XCTAssertEqual(events[1].arguments,[output!,1]);XCTAssertEqual(events.last?.arguments,[17,output!]) }
        }
        var state = seed, count = 0
        XCTAssertThrowsError(try state.draw([],target:1,background:0,color:0,x:0,y:0,
            perform:{ _ in count += 1;return .init(result:0) },observe:{ _ in }))
        XCTAssertEqual(count,1);XCTAssertEqual(state,seed)
        for (bytes,target) in [([UInt8(0)],UInt32(1)),([UInt8(65)],UInt32(0))] {
            count = 0
            XCTAssertThrowsError(try state.draw(bytes,target:target,background:0,color:0,x:0,y:0,
                perform:{ _ in count += 1;return .init(result:0,output:9) },observe:{ _ in }))
            XCTAssertEqual(count,0);XCTAssertEqual(state,seed)
        }
        let controls = api.map { "api:"+$0 } + api.map { "reply:"+$0 } + (api+["stringLength"]).map { "event:"+$0 }
        XCTAssertEqual(controls.count,16)
        for control in controls {
            state = seed;var stopped = false
            func fail(_ phase: String,_ q: OriginalMenuPresentationEvent) throws {
                if phase+q.kind.rawValue == control { stopped = true;throw Stop.late }
            }
            XCTAssertThrowsError(try state.draw([65],target:1,background:2,color:3,x:4,y:5,
                perform:{ q in try fail("api:",q);return .init(result:q.kind == .getDC ? 3 : -99,output:q.kind == .getDC ? 77 : nil) },
                didRespond:{ q,_ in try fail("reply:",q) },observe:{ try fail("event:",$0) })) { error in
                    guard case Stop.late = error else { return XCTFail("Unexpected boundary: \(error)") }
                }
            XCTAssertTrue(stopped);XCTAssertEqual(state,seed)
            var events: [OriginalMenuPresentationEvent] = []
            XCTAssertEqual(try state.draw([65],target:1,background:2,color:3,x:4,y:5,
                perform:{ .init(result:$0.kind == .getDC ? 3 : -99,output:$0.kind == .getDC ? 88 : nil) },observe:{ events.append($0) }),3)
            XCTAssertEqual(state.retainedDC,88);XCTAssertEqual(events.count,6)
        }
    }
    func run(_ index: Int,_ r: Resources,_ fr: F.Resources,_ br: B.Resources,_ er: Entry.Resources,fail: String? = nil,completion: B.LoopCompletion? = nil,continuation: ((inout B.OwnContext) throws -> Void)? = nil) throws {
        let c = r.c.cases[index];var reached = false, interrupted = false
        try F().run(r.frontIndices[index],fr,br,er,fail:fail == nil ? nil : "body",completion:completion,continuation:{ owned in
            reached = true
            XCTAssertEqual(owned.earlyScreen.retainedOperation,.sleep)
            let target = try XCTUnwrap(owned.settings?.target)
            var globals = owned.base.globals,library = owned.libraryText
            let full = globals.bytes+owned.outerAndWorldBytes
            XCTAssertEqual(full,try r.blob(c.before.globals));XCTAssertEqual(library.retainedDC,0);XCTAssertEqual(library.retainedDC,c.before.retainedDC)
            let adapter = Adapter(c,r,initial:full,fail:fail)
            // Own status0 remains from startup; no worker completion is injected.
            let panel = try OriginalMenuPanelUpdate.run(globals:&globals,content:{ _ in throw B.Stop.late },bitmap:{ _ in throw B.Stop.late },write:{ _,_ in throw B.Stop.late },observe:{ e,_ in
                try adapter.observe(.init(e.kind,e.arguments))
            })
            XCTAssertEqual(panel,.ready)
            XCTAssertEqual(globals.bytes+owned.outerAndWorldBytes,try r.blob(c.panelReturn.globals))
            let input = OriginalFrontScreenBodyInput(dcResult:c.spec.dcResult >= 0 ? -123 : 123,dc:c.spec.dc ^ 0xffffffff,methodResult:c.spec.methodResult,drawResults:c.spec.drawResults,shellResult:c.spec.shellResult)
            var all = owned.front.bitmaps
            for (token,bitmap) in owned.earlyScreen.bitmaps { XCTAssertNil(all.updateValue(bitmap,forKey:token)) }
            var surfaces = owned.frontSurfaces
            for (token,surface) in owned.earlyScreen.surfaces { XCTAssertNil(surfaces.updateValue(surface,forKey:token)) }
            let width = try globals.integer(at:0x44d78c-0x44d000,as:Int32.self),height = try globals.integer(at:0x44d790-0x44d000,as:Int32.self)
            let globalsBefore = globals, libraryBefore = library
            var counts: [String:Int] = [:], requests: [OriginalMenuPresentationEvent] = [], replies: [OriginalLibSurfaceText.Response] = []
            func failIf(_ prefix: String,_ q: OriginalMenuPresentationEvent) throws {
                let key = prefix+q.kind.rawValue
                counts[key,default:0] += 1
                if fail == key+"#\(counts[key]!)" { interrupted = true;throw B.Stop.late }
            }
            let result: OriginalFrontScreenBody.StartupResult
            do {
            result = try OriginalFrontScreenBody.advanceOwnStartup(globals:&globals,target:target,libraryText:&library,input:input,draw:{ args in
                let bitmap = try XCTUnwrap(all[args[0]])
                func emit(_ kind: String,_ configure: (inout OriginalFrontScreenEvent) -> Void) throws {
                    var e = OriginalFrontScreenEvent(kind);configure(&e);try adapter.observe(e)
                }
                let drawInput = OriginalBitmapDrawInput(x:Int32(bitPattern:args[1]),y:Int32(bitPattern:args[2]),frame:Int32(bitPattern:args[3]),colorKey:args[4],mirrored:args[5],sourceSurface:try XCTUnwrap(surfaces[args[0]]),targetSurface:args[6],viewportWidth:width,viewportHeight:height)
                _ = try OriginalBitmapDrawing.draw(drawInput,bitmap:bitmap.storage,observeRead:{ read in try emit("read") { $0.read = read } },observeClip:{ clip in try emit("clip") { $0.clip = clip } },perform:{ b in
                    try emit("blit") { $0.blit = b };adapter.draws += 1;return c.spec.drawResults[0]
                })
            },textPerform:{ q in
                try failIf("api:",q)
                requests.append(q)
                return .init(result:q.kind == .getDC ? c.spec.dcResult : c.spec.methodResult,
                             output:q.kind == .getDC ? c.spec.dc : nil)
            },textDidRespond:{ q,response in
                XCTAssertEqual(requests.last,q);replies.append(response)
                try failIf("reply:",q)
            },observe:adapter.observe)
            } catch {
                XCTAssertEqual(globals,globalsBefore);XCTAssertEqual(library,libraryBefore)
                throw error
            }
            XCTAssertEqual(requests.count,replies.count)
            let sourceRequests = c.events.compactMap { $0.event }.filter { ["getDC","setBackgroundMode","setTextColor","textOut","releaseDC"].contains($0.kind) }
            XCTAssertEqual(requests.map { $0.kind.rawValue },sourceRequests.map { $0.kind })
            for (request,event) in zip(requests,sourceRequests) {
                XCTAssertEqual(request.arguments,event.arguments);XCTAssertEqual(request.strings,event.strings)
            }
            XCTAssertEqual(result.continuation.rawValue,c.end);XCTAssertEqual(adapter.index,c.events.count)
            XCTAssertEqual(result.retainedSelector,try globals.integer(at:0x44d064-0x44d000,as:Int32.self))
            XCTAssertEqual(result.retainedSelector,0)
            XCTAssertEqual(globals.bytes+owned.outerAndWorldBytes,try r.blob(c.after.globals));XCTAssertEqual(library.retainedDC,c.after.retainedDC)
            let source = try r.blob(c.after.local),mask = try r.blob(c.after.localMask)
            var ownedBytes = 0
            for i in 0..<0xc0 {
                let produced = mask[i] != 0 || (0x20..<0x24).contains(i)
                XCTAssertEqual(result.local.defined[i],produced)
                XCTAssertEqual(result.local.bytes[i],produced ? source[i] : 0,"Caller-local field \(i)")
                if produced { ownedBytes += 1 }
            }
            XCTAssertEqual(ownedBytes,96);XCTAssertEqual(adapter.draws,2)
            XCTAssertEqual(c.after.pc,0x4275cb);XCTAssertEqual(c.after.sp,0x1000ea74);XCTAssertEqual(c.after.cw,r.sourceControlWord)
            XCTAssertEqual(c.before.registers,c.after.registers);XCTAssertEqual(all.count,c.records.count)
            for record in c.records {
                let bitmap = try XCTUnwrap(all[record.address]);var bytes = try r.blob(record.bytes)
                bytes.replaceSubrange(0..<4,with:[surfaces[record.address] == 0 ? 0 : 1,0,0,0])
                XCTAssertEqual(bitmap.storage.bytes,bytes);XCTAssertEqual(bitmap.storage.defined,try r.blob(record.mask).map { $0 != 0 })
            }
            owned.base.globals = globals;owned.libraryText = library;owned.screenBody = result
            if fail == "bodyBoundary" { interrupted = true;throw B.Stop.late }
            try continuation?(&owned)
        })
        XCTAssertTrue(reached)
        XCTAssertEqual(interrupted,fail != nil)
    }
    func testWholeOwnBodyUsesActualRepliesInsteadOfPreparedDC() throws {
        let fr = try F.Resources(),r = try Resources(fr),br = try B.Resources(),er = try Entry.Resources()
        for i in r.c.cases.indices { try run(i,r,fr,br,er) }
        print("TEXT RESPONSES 43 whole own body cases; poisoned prepared DC ignored; unchanged source events/globals/locals/resources")
    }
    func testLateRepliesRollBackWholeOwnStartupIteration() throws {
        let fr = try F.Resources(),r = try Resources(fr),br = try B.Resources(),er = try Entry.Resources()
        for failure in ["api:getDC#2","api:textOut#2","reply:getDC#1","reply:releaseDC#3","bodyBoundary"] {
            try run(0,r,fr,br,er,fail:failure)
        }
    }
}
