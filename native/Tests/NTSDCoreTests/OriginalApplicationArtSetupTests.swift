import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalApplicationArtSetupTests: XCTestCase {
    struct Spec: Decodable {
        let index: Int, continued: Bool, querySurface: UInt32, initialTarget: UInt32
        let queryBacking: [UInt8], clearBacking: [UInt8], queryWrites: [OriginalApplicationArtSetup.Write]
        let queryResult: Int32, clearResult: Int32, debugResult: Int32
        let queryTarget: UInt32?, clearTarget: UInt32?
    }
    struct Snapshot: Decodable {
        let globals: String, query: [UInt8], queryMask: [UInt8], clear: [UInt8], clearMask: [UInt8]
        let result: Int32?
    }
    struct Event: Decodable {
        let kind: String, globals: String, target: UInt32?, flags: UInt32?, bytes: [UInt8], defined: [Bool]?, response: Int32
    }
    struct Case: Decodable { let spec: Spec, before: Snapshot, after: Snapshot, events: [Event] }
    struct Corpus: Decodable {
        let exeSHA256: String, globalTemplate: String, cases: [Case], blobs: [String: InputControlReference.Blob]
        func blob(_ key: String) throws -> [UInt8] {
            let b = try XCTUnwrap(blobs[key]), bytes = try MatchPreparationReference.inflate(b.deflate, count: b.count)
            XCTAssertEqual(MatchPreparationReference.digest(Data(bytes)), key); return bytes
        }
    }
    func corpus() throws -> Corpus {
        let url: URL
        if let p = ProcessInfo.processInfo.environment["NTSD_APPLICATION_ART_SETUP"] { url = URL(fileURLWithPath: p) }
        else { url = try XCTUnwrap(Bundle.module.url(forResource: "original-application-art-setup.json", withExtension: nil, subdirectory: "Fixtures")) }
        let c = try JSONDecoder().decode(Corpus.self, from: MatchPreparationReference.unpack(Data(contentsOf: url), maximumCount: 32_000_000))
        XCTAssertEqual(c.exeSHA256, "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c"); return c
    }
    func testWholeCallsAndOwnRetainedChain() throws {
        let c = try corpus(); XCTAssertEqual(c.cases.count, 231)
        var globals = try OriginalStateRecord(bytes: c.blob(c.globalTemplate), defined: Array(repeating: true, count: 0xc3a8))
        var local = try OriginalStateRecord(bytes: [], defined: []), backing: [UInt8] = []
        for item in c.cases {
            let s = item.spec
            if !s.continued {
                globals = try OriginalStateRecord(bytes: c.blob(c.globalTemplate), defined: Array(repeating: true, count: 0xc3a8))
                try globals.write(s.querySurface, at: 0x455634-0x44d000); try globals.write(s.initialTarget, at: 0x455608-0x44d000)
                local = try OriginalStateRecord(bytes: s.queryBacking, defined: Array(repeating: false, count: 32)); backing = s.clearBacking
            }
            XCTAssertEqual(globals.bytes, try c.blob(item.before.globals)); XCTAssertEqual(local.bytes, item.before.query)
            XCTAssertEqual(local.defined, item.before.queryMask.map { $0 != 0 }); XCTAssertEqual(backing, item.before.clear)
            var cursor = 0
            func event(_ kind: String, _ g: OriginalStateRecord) throws -> Event {
                let e = item.events[cursor]; cursor += 1; XCTAssertEqual(e.kind, kind)
                XCTAssertEqual(g.bytes, try c.blob(e.globals)); XCTAssertTrue(g.defined.allSatisfy { $0 }); return e
            }
            let result = try OriginalApplicationArtSetup.run(context: &globals, queryBacking: local, clearBacking: backing,
                querySurface: { try $0.integer(at: 0x455634-0x44d000, as: UInt32.self) },
                clearSurface: { try $0.integer(at: 0x455608-0x44d000, as: UInt32.self) }, query: { request, g in
                    let e = try event("query", g); XCTAssertEqual(request.target, e.target); XCTAssertEqual(request.bytes, e.bytes); XCTAssertEqual(request.defined, e.defined)
                    if let target = s.queryTarget { try g.write(target, at: 0x455608-0x44d000) }
                    return .init(result: s.queryResult, writes: s.queryWrites)
                }, clear: { request, g in
                    let e = try event("clear", g); XCTAssertEqual(request.target, e.target); XCTAssertEqual(request.flags, e.flags)
                    XCTAssertEqual(request.effects, e.bytes); XCTAssertEqual(request.defined, e.defined); backing = request.effects
                    if let target = s.clearTarget { try g.write(target, at: 0x455608-0x44d000) }
                    return s.clearResult
                }, debug: { bytes, g in
                    let e = try event("debug", g); XCTAssertEqual(bytes, e.bytes)
                })
            local = result.query
            XCTAssertEqual(cursor, 3); XCTAssertEqual(result.value, item.after.result)
            XCTAssertEqual(globals.bytes, try c.blob(item.after.globals)); XCTAssertTrue(globals.defined.allSatisfy { $0 })
            XCTAssertEqual(local.bytes, item.after.query); XCTAssertEqual(local.defined, item.after.queryMask.map { $0 != 0 })
            XCTAssertEqual(backing, item.after.clear)
        }
    }
    enum Trial: Error { case late }
    func testLateFailuresRollBackOwnValueContext() throws {
        struct Context: Equatable { var target: UInt32 = 1; var events: [String] = [] }
        let local = try OriginalStateRecord(bytes: Array(repeating: 165, count: 32), defined: Array(repeating: false, count: 32))
        for stage in 0..<4 {
            var context = Context(); let before = context
            XCTAssertThrowsError(try OriginalApplicationArtSetup.run(context: &context, queryBacking: local, clearBacking: Array(repeating: 90, count: 100),
                querySurface: { $0.target }, clearSurface: { $0.target }, query: { _, c in
                    c.target = 2; c.events.append("query"); if stage == 0 { throw Trial.late }
                    return .init(result: -1, writes: [.init(offset: 4, bytes: [1,2,3,4])])
                }, clear: { r, c in
                    XCTAssertEqual(r.target, 2); c.target = 3; c.events.append("clear"); if stage == 1 { throw Trial.late }; return -1
                }, debug: { _, c in c.events.append("debug"); if stage == 2 { throw Trial.late } },
                beforeCommit: { r, c in XCTAssertEqual(r.value, 0); XCTAssertEqual(c.target, 3); throw Trial.late }))
            XCTAssertEqual(context, before)
        }
    }
}
