import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalApplicationMenuReturnTests: XCTestCase {
    typealias B = OriginalBitmapSurfaceLoadingTests
    typealias F = OriginalApplicationFrontScreenTests
    typealias Body = OriginalApplicationScreenBodyTests
    typealias Entry = OriginalApplicationDispatchEntryTests
    struct Spec: Decodable { let label: String,drawResult: Int32,presentResult: Int32,time: UInt32 }
    struct State: Decodable {
        let globals: String,mask: String,local: String,localMask: String,retainedDC: UInt32
        let pc: UInt32,sp: UInt32,eax: UInt32,cw: UInt32,seh: UInt32,registers: [UInt32],baseline: UInt32,counter: UInt32
    }
    struct Case: Decodable {
        let spec: Spec,parent: String,parentKind: String,before: State,mainEntry: State?,tailEntry: State?,worldReturn: State?,dispatchReturn: State?,after: State
        let events: [F.Event],records: [B.Record],end: String
    }
    struct Corpus: Decodable { let cases: [Case],blobs: [String:OriginalApplicationMessageLoopTests.Blob] }
    final class Resources {
        let c: Corpus,indices: [Int],rawCases: [[String:Any]]
        var cache: [String:[UInt8]] = [:]
        init(_ body: Body.Resources,_ front: F.Resources) throws {
            let url = try ProcessInfo.processInfo.environment["NTSD_APPLICATION_MENU_RETURN"].map { URL(fileURLWithPath:$0) } ?? XCTUnwrap(Bundle.module.url(forResource:"original-application-menu-return",withExtension:"json",subdirectory:"Fixtures"))
            let data = try MatchPreparationReference.unpack(Data(contentsOf:url),maximumCount:100_000_000)
            c = try JSONDecoder().decode(Corpus.self,from:data);XCTAssertEqual(c.cases.count,48)
            let raw = try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any])
            rawCases = try XCTUnwrap(raw["cases"] as? [[String:Any]])
            let bp = try XCTUnwrap(raw["bodyParents"] as? [String:[String:Any]]),fp = try XCTUnwrap(raw["frontParents"] as? [String:[String:Any]])
            XCTAssertEqual(bp.count,43);XCTAssertEqual(fp.count,40)
            indices = try c.cases.map { c in
                let parent = try XCTUnwrap((c.parentKind == "body" ? bp : fp)[c.parent])
                return try XCTUnwrap((c.parentKind == "body" ? body.rawCases : front.rawCases).firstIndex { NSDictionary(dictionary:$0).isEqual(to:parent) })
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
        var index = 0,shadow: [UInt8],mask = [UInt8](repeating:0,count:0xc3a8),occurrences: [String:Int] = [:]
        init(_ c: Case,_ r: Resources,initial: [UInt8],fail: String?) { self.c = c;self.r = r;shadow = initial;self.fail = fail }
        func observe(_ q: OriginalFrontScreenEvent) throws {
            guard index < c.events.count else { XCTFail("Extra return event \(q.kind)");throw B.Stop.late }
            let e = c.events[index];index += 1
            XCTAssertTrue(shadow == (try r.blob(e.globals)),c.spec.label+" globals at \(index)")
            XCTAssertEqual(e.kind,"front");XCTAssertEqual(q,try XCTUnwrap(e.event),c.spec.label+" event \(index)")
            occurrences[q.kind,default:0] += 1
            if q.kind == "write" {
                let at = Int(q.arguments[0])-0x44d000,n = Int(q.arguments[1]),v = q.arguments[2]
                shadow.replaceSubrange(at..<at+n,with:(0..<n).map { UInt8(truncatingIfNeeded:v >> ($0*8)) });mask.replaceSubrange(at..<at+n,with:repeatElement(1,count:n))
            }
            if fail == q.kind+"#\(occurrences[q.kind]!)" { throw B.Stop.late }
        }
        func store(_ address: Int,_ bytes: [UInt8]) throws {
            let v = bytes.enumerated().reduce(UInt32(0)) { $0 | UInt32($1.element) << ($1.offset*8) }
            try observe(.init("write",[UInt32(address),UInt32(bytes.count),v]))
        }
    }
    func run(_ index: Int,_ r: Resources,_ body: Body.Resources,_ front: F.Resources,_ br: B.Resources,_ er: Entry.Resources,fail: String? = nil,continuation: ((OriginalApplicationMessageLoop,B.OwnContext) throws -> Void)? = nil) throws {
        try OriginalApplicationBootstrapTests().runMenu(index,r,body,front,br,er,fail:fail,continuation:continuation)
    }
    func testOwnMenusReturnDispatcherAndCommitFirstDueIteration() throws {
        let front = try F.Resources(),body = try Body.Resources(front),r = try Resources(body,front),br = try B.Resources(),er = try Entry.Resources()
        for i in r.c.cases.indices { try run(i,r,body,front,br,er) }
        print("APPLICATION MENU RETURN 47 own whole menu/World/dispatcher/loop returns;1 pre-NULL cursor rejection with whole iteration rollback;48 full parents and resource registries")
    }
    func testLateMenuReturnFailuresRollBackWholeIteration() throws {
        let front = try F.Resources(),body = try Body.Resources(front),r = try Resources(body,front),br = try B.Resources(),er = try Entry.Resources()
        for fail in ["blit#1","panel#1","blit#2","method#1","write#2","dispatchReturn","time#1","write#3","commit"] { try run(0,r,body,front,br,er,fail:fail) }
    }
}
