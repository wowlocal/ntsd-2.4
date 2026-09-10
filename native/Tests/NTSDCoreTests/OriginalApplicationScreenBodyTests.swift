import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalApplicationScreenBodyTests: XCTestCase {
    typealias F = OriginalApplicationFrontScreenTests
    typealias B = OriginalBitmapSurfaceLoadingTests
    typealias Entry = OriginalApplicationDispatchEntryTests
    struct Spec: Decodable { let label: String,dcResult: Int32,dc: UInt32,methodResult: Int32,drawResults: [Int32],shellResult: UInt32 }
    struct State: Decodable { let globals: String,mask: String,local: String,localMask: String,retainedDC: UInt32,pc: UInt32,sp: UInt32,cw: UInt32,registers: [UInt32] }
    struct Case: Decodable { let spec: Spec,parent: String,before: State,panelReturn: State,after: State,events: [F.Event],records: [B.Record],end: String }
    struct Corpus: Decodable { let cases: [Case],blobs: [String:OriginalApplicationMessageLoopTests.Blob] }
    final class Resources {
        let c: Corpus,frontIndices: [Int]
        var cache: [String:[UInt8]] = [:]
        init(_ front: F.Resources) throws {
            let url = try ProcessInfo.processInfo.environment["NTSD_APPLICATION_SCREEN_BODY"].map { URL(fileURLWithPath:$0) } ?? XCTUnwrap(Bundle.module.url(forResource:"original-application-screen-body",withExtension:"json",subdirectory:"Fixtures"))
            let data = try MatchPreparationReference.unpack(Data(contentsOf:url),maximumCount:100_000_000)
            c = try JSONDecoder().decode(Corpus.self,from:data);XCTAssertEqual(c.cases.count,43)
            let raw = try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any]),parents = try XCTUnwrap(raw["frontParents"] as? [String:[String:Any]])
            XCTAssertEqual(parents.count,39)
            frontIndices = try c.cases.map { c in
                let parent = try XCTUnwrap(parents[c.parent])
                return try XCTUnwrap(front.rawCases.firstIndex { NSDictionary(dictionary:$0).isEqual(to:parent) })
            }
        }
        func blob(_ key: String) throws -> [UInt8] {
            if let b = cache[key] { return b }
            let z = try XCTUnwrap(c.blobs[key]),b = try MatchPreparationReference.inflate(z.deflate,count:z.count,maximumCount:10_000_000)
            XCTAssertEqual(MatchPreparationReference.digest(Data(b)),key);cache[key] = b;return b
        }
    }
    final class Adapter {
        let c: Case,r: Resources,fail: String?
        var index = 0,shadow: [UInt8],draws = 0
        var occurrences: [String:Int] = [:]
        init(_ c: Case,_ r: Resources,initial: [UInt8],fail: String?) { self.c = c;self.r = r;shadow = initial;self.fail = fail }
        func observe(_ q: OriginalFrontScreenEvent) throws {
            guard index < c.events.count else { XCTFail("Extra body event");throw B.Stop.late }
            let e = c.events[index];index += 1
            XCTAssertEqual(shadow,try r.blob(e.globals),c.spec.label+" globals at \(index)")
            XCTAssertEqual(e.kind,"front");XCTAssertEqual(q,try XCTUnwrap(e.event),c.spec.label+" event \(index)")
            occurrences[q.kind,default:0] += 1
            if q.kind == "write" {
                let at = Int(q.arguments[0])-0x44d000,n = Int(q.arguments[1]),v = q.arguments[2]
                shadow.replaceSubrange(at..<at+n,with:(0..<n).map { UInt8(truncatingIfNeeded:v >> ($0*8)) })
            }
            if fail == q.kind+"#\(occurrences[q.kind]!)" { throw B.Stop.late }
        }
    }
    func run(_ index: Int,_ r: Resources,_ fr: F.Resources,_ br: B.Resources,_ er: Entry.Resources,fail: String? = nil) throws {
        let c = r.c.cases[index];var reached = false
        try F().run(r.frontIndices[index],fr,br,er,fail:fail == nil ? nil : "body",continuation:{ owned in
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
            let input = OriginalFrontScreenBodyInput(dcResult:c.spec.dcResult,dc:c.spec.dc,methodResult:c.spec.methodResult,drawResults:c.spec.drawResults,shellResult:c.spec.shellResult)
            var all = owned.front.bitmaps
            for (token,bitmap) in owned.earlyScreen.bitmaps { XCTAssertNil(all.updateValue(bitmap,forKey:token)) }
            var surfaces = owned.frontSurfaces
            for (token,surface) in owned.earlyScreen.surfaces { XCTAssertNil(surfaces.updateValue(surface,forKey:token)) }
            let width = try globals.integer(at:0x44d78c-0x44d000,as:Int32.self),height = try globals.integer(at:0x44d790-0x44d000,as:Int32.self)
            let result = try OriginalFrontScreenBody.advanceOwnStartup(globals:&globals,target:target,libraryText:&library,input:input,draw:{ args in
                let bitmap = try XCTUnwrap(all[args[0]])
                func emit(_ kind: String,_ configure: (inout OriginalFrontScreenEvent) -> Void) throws {
                    var e = OriginalFrontScreenEvent(kind);configure(&e);try adapter.observe(e)
                }
                let drawInput = OriginalBitmapDrawInput(x:Int32(bitPattern:args[1]),y:Int32(bitPattern:args[2]),frame:Int32(bitPattern:args[3]),colorKey:args[4],mirrored:args[5],sourceSurface:try XCTUnwrap(surfaces[args[0]]),targetSurface:args[6],viewportWidth:width,viewportHeight:height)
                _ = try OriginalBitmapDrawing.draw(drawInput,bitmap:bitmap.storage,observeRead:{ read in try emit("read") { $0.read = read } },observeClip:{ clip in try emit("clip") { $0.clip = clip } },perform:{ b in
                    try emit("blit") { $0.blit = b };adapter.draws += 1;return c.spec.drawResults[0]
                })
            },observe:adapter.observe)
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
            XCTAssertEqual(c.after.pc,0x4275cb);XCTAssertEqual(c.after.sp,0x1000ea74);XCTAssertEqual(c.after.cw,0x37f)
            XCTAssertEqual(c.before.registers,c.after.registers);XCTAssertEqual(all.count,c.records.count)
            for record in c.records {
                let bitmap = try XCTUnwrap(all[record.address]);var bytes = try r.blob(record.bytes)
                bytes.replaceSubrange(0..<4,with:[surfaces[record.address] == 0 ? 0 : 1,0,0,0])
                XCTAssertEqual(bitmap.storage.bytes,bytes);XCTAssertEqual(bitmap.storage.defined,try r.blob(record.mask).map { $0 != 0 })
            }
            owned.base.globals = globals;owned.libraryText = library;owned.screenBody = result
            if fail == "bodyBoundary" { throw B.Stop.late }
        })
        XCTAssertTrue(reached)
    }
    func testOwnPanelAndBodyUseInstalledTextAndProducedLocalBytes() throws {
        let fr = try F.Resources(),r = try Resources(fr),br = try B.Resources(),er = try Entry.Resources()
        for i in r.c.cases.indices { try run(i,r,fr,br,er) }
        print("APPLICATION SCREEN BODY 43 own whole panel/body continuations through installed text; own target, produced local strings/DC/resources and outer rollback")
    }
    func testLateBodyFailuresRollBackWholePendingIteration() throws {
        let fr = try F.Resources(),r = try Resources(fr),br = try B.Resources(),er = try Entry.Resources()
        for failure in ["enter#1","leave#1","writeLocal#50","setBackgroundMode#2","releaseDC#3","blit#2","bodyBoundary"] { try run(0,r,fr,br,er,fail:failure) }
    }
}
