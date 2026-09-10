import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalApplicationSettingsTests: XCTestCase {
    typealias Bitmap = OriginalBitmapSurfaceLoadingTests
    typealias Entry = OriginalApplicationDispatchEntryTests
    typealias Loop = OriginalApplicationMessageLoopTests
    struct Spec: Decodable { let label: String,chunk: Int?,present: Bool?,close: Int32? }
    struct State: Decodable { let globals: String,scratch: String,scratchMask: String,pc: UInt32,sp: UInt32,cw: UInt32,registers: [UInt32] }
    struct Event: Decodable {
        let kind: String,arguments: [UInt32]?,strings: [String]?,format: String?,before: Int?,position: Int?,eof: Bool?,result: UInt32?,state: State?
    }
    struct Case: Decodable { let spec: Spec,parent: String,input: String,before: State,after: State,events: [Event],end: String }
    struct Corpus: Decodable { let cases: [Case],blobs: [String:Loop.Blob],scratchAddress: UInt32,scratchCount: Int }
    final class Resources {
        let c: Corpus,rawParents: [String:[String:Any]]
        var cache: [String:[UInt8]] = [:]
        init(supplied: Data? = nil) throws {
            let data: Data
            if let supplied { data = supplied }
            else {
                let url = try ProcessInfo.processInfo.environment["NTSD_APPLICATION_SETTINGS"].map { URL(fileURLWithPath:$0) } ?? XCTUnwrap(Bundle.module.url(forResource:"original-application-settings",withExtension:"json",subdirectory:"Fixtures"))
                data = try MatchPreparationReference.unpack(Data(contentsOf:url),maximumCount:80_000_000)
            }
            c = try JSONDecoder().decode(Corpus.self,from:data)
            rawParents = try XCTUnwrap((JSONSerialization.jsonObject(with:data) as? [String:Any])?["parents"] as? [String:[String:Any]])
            if supplied == nil { XCTAssertEqual(c.cases.count,18) }
            XCTAssertEqual(c.scratchAddress,0x1000e878);XCTAssertEqual(c.scratchCount,500)
        }
        func blob(_ key: String) throws -> [UInt8] {
            if let b = cache[key] { return b }
            let z = try XCTUnwrap(c.blobs[key]),b = try MatchPreparationReference.inflate(z.deflate,count:z.count,maximumCount:10_000_000)
            XCTAssertEqual(MatchPreparationReference.digest(Data(b)),key);cache[key] = b;return b
        }
        func compare(_ expected: State,_ globals: OriginalStateRecord,_ scratch: OriginalStateRecord) throws {
            XCTAssertEqual(globals.bytes,Array(try blob(expected.globals).prefix(0xb440)))
            XCTAssertTrue(globals.defined.allSatisfy({ $0 }))
            let bytes = try blob(expected.scratch),mask = try blob(expected.scratchMask).map { $0 != 0 }
            XCTAssertEqual(scratch.defined,mask)
            XCTAssertEqual(scratch.bytes,zip(bytes,mask).map { $0.1 ? $0.0 : 0 },"Unknown scratch backing must not be imported")
            XCTAssertEqual(expected.cw,0x37f)
        }
    }
    func compare(_ index: Int,_ r: Resources,_ br: Bitmap.Resources,_ er: Entry.Resources,fail: String? = nil,
                 completion: Bitmap.LoopCompletion? = nil,continuation: ((inout Bitmap.OwnContext) throws -> Void)? = nil) throws {
        let c = r.c.cases[index],rawParent = try XCTUnwrap(r.rawParents[c.parent]) as NSDictionary
        let parentIndex = try XCTUnwrap(br.rawCases.firstIndex { ($0 as NSDictionary) == rawParent })
        XCTAssertEqual(try XCTUnwrap(r.rawParents[c.parent]) as NSDictionary,br.rawCases[parentIndex] as NSDictionary,"Fresh full source parent must reproduce")
        var eventIndex = 0,counts: [String:Int] = [:],reached = false
        try Bitmap().own(parentIndex,br,er,fail:fail == nil ? nil : "applicationSettings",completion:completion,continuation:{ owned in
            reached = true
            XCTAssertEqual(owned.base.globals.bytes,Array(try r.blob(c.before.globals).prefix(0xb440)))
            let resources = owned.front.bitmaps,graphics = owned.graphics,prior = owned.base.globals
            do {
                let output = try OriginalSettingsLoading.loadOwnStartup(globals:&owned.base.globals,translatedBytes:r.blob(c.input),file:c.spec.present == false ? 0 : 0x20001000,scratchAddress:r.c.scratchAddress,target:XCTUnwrap(owned.gameEntry).target,closeResult:c.spec.close ?? 0,observe:{ e,g,s in
                    guard eventIndex < c.events.count else { XCTFail("Extra settings event");throw Bitmap.Stop.late }
                    let expected = c.events[eventIndex];eventIndex += 1
                    XCTAssertEqual(e.kind.rawValue,expected.kind);XCTAssertEqual(e.arguments,expected.arguments ?? [])
                    XCTAssertEqual(e.strings,expected.strings ?? []);XCTAssertEqual(e.format,expected.format)
                    XCTAssertEqual(e.before,expected.before);XCTAssertEqual(e.position,expected.position);XCTAssertEqual(e.eof,expected.eof);XCTAssertEqual(e.result,expected.result)
                    if let state = expected.state { try r.compare(state,g,s) }
                    counts[e.kind.rawValue,default:0] += 1
                    let key = e.kind.rawValue+"#"+String(counts[e.kind.rawValue]!)
                    if fail == key || (fail == "flagStore" && e.kind == .write && e.arguments[0] == 0x44d068) { throw Bitmap.Stop.late }
                })
                let result = output.continuation,scratch = output.scratch
                XCTAssertEqual(result.rawValue,c.end);XCTAssertEqual(eventIndex,c.events.count)
                try r.compare(c.after,owned.base.globals,scratch);owned.settings = output
                XCTAssertEqual(owned.front.bitmaps,resources);XCTAssertEqual(owned.graphics,graphics)
                if result == .ready {
                    XCTAssertEqual(c.after.pc,0x42709b);XCTAssertEqual(c.after.sp,0x1000ea74)
                    XCTAssertEqual(output.target,c.after.registers[3]);XCTAssertEqual(output.retainedESI,c.after.registers[2])
                    XCTAssertEqual(try owned.base.globals.integer(at:0x44d068-0x44d000,as:UInt32.self),0)
                } else {
                    XCTAssertEqual(c.after.pc,0x4234db);XCTAssertEqual(owned.base.globals,prior)
                    XCTAssertFalse(scratch.defined.contains(true))
                    XCTAssertNil(output.target);XCTAssertNil(output.retainedESI)
                }
                if fail == "screenBoundary" { throw Bitmap.Stop.late }
            } catch {
                if fail != "screenBoundary" { XCTAssertEqual(owned.base.globals,prior,"Whole settings failure rollback") }
                throw error
            }
            try continuation?(&owned)
        })
        XCTAssertTrue(reached)
        if fail == nil { XCTAssertEqual(eventIndex,c.events.count) }
    }
    func testOwnSettingsPreserveParentsAndUseProducedScratch() throws {
        let r = try Resources(),br = try Bitmap.Resources(),er = try Entry.Resources()
        for i in r.c.cases.indices { try compare(i,r,br,er) }
        print("APPLICATION SETTINGS 17 whole own settings returns and1 missing-FILE stop;18 full pending-loop rollbacks; no source scratch imported")
    }
    func testLateSettingsFailuresRollBackWholePendingLoop() throws {
        let r = try Resources(),br = try Bitmap.Resources(),er = try Entry.Resources()
        for fail in ["scan#47","gets#3","eof#2","close#1","settingsReturn#1","flagStore","screenBoundary"] { try compare(0,r,br,er,fail:fail) }
    }
}
