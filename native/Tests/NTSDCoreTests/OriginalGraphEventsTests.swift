import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalGraphEventsTests: XCTestCase {
    struct Blob: Decodable { let count: Int, base64: String }
    struct Response: Decodable {
        let result: Int32, pointer: UInt32?, code: UInt32?, first: UInt32?, second: UInt32?
        var graph: OriginalGraphEvents.Response { .init(result: result,code: code,first: first,second: second) }
        var music: OriginalMusicResponse { .init(result: result,pointer: pointer) }
    }
    struct Event: Decodable { let kind: String, arguments: [UInt32], strings: [[UInt8]], response: Response }
    struct Action: Decodable { let kind: String, region: String?, offset: Int?, bytes: [UInt8]?, event: Event? }
    struct Spec: Decodable { let label: String, initialize: Bool?, retain: Bool?, window: UInt32?, wParam: UInt32?, lParam: UInt32?, queue: [Response]? }
    struct Sample: Decodable {
        let index: Int, spec: Spec, before: String, after: String, globalWritten: String, localBefore: String?, localAfter: String?, localWritten: String, actions: [Action], events: [Event], result: UInt32
    }
    struct Corpus: Decodable { let exeSHA256: String, libSHA256: String, limited: Bool, cases: [Sample], blobs: [String:Blob] }
    final class Resources {
        let corpus: Corpus
        var cache: [String:[UInt8]] = [:]
        init(_ c: Corpus) { corpus = c }
        func blob(_ key: String) throws -> [UInt8] {
            if let b = cache[key] { return b }
            let b = try XCTUnwrap(corpus.blobs[key]),d = try XCTUnwrap(Data(base64Encoded: b.base64))
            XCTAssertEqual(d.count,b.count);XCTAssertEqual(MatchPreparationReference.digest(d),key)
            let value = [UInt8](d);cache[key] = value;return value
        }
        func record(_ key: String) throws -> OriginalStateRecord {
            let b = try blob(key);return try .init(bytes: b,defined: [Bool](repeating: true,count: b.count))
        }
    }
    private func resources() throws -> Resources {
        let url: URL
        if let path = ProcessInfo.processInfo.environment["NTSD_GRAPH_EVENTS_CORPUS"] { url = URL(fileURLWithPath: path) }
        else { url = try XCTUnwrap(Bundle.module.url(forResource: "original-graph-events.json",withExtension: nil,subdirectory: "Fixtures")) }
        let c = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(Data(contentsOf: url),maximumCount: 32_000_000))
        XCTAssertFalse(c.limited);XCTAssertEqual(c.cases.count,375)
        XCTAssertEqual(c.exeSHA256,"3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        XCTAssertEqual(c.libSHA256,"28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba")
        return Resources(c)
    }
    private func input(_ c: Sample) -> OriginalWindowInput.Message {
        .init(window: c.spec.window ?? 0x73000001,message: 0x400,wParam: c.spec.wParam ?? 0xaabbccdd,lParam: c.spec.lParam ?? 0x11223344)
    }
    func testWholeNotificationsAndOwnGraphProducer() throws {
        let r = try resources();var globals = try r.record(r.corpus.cases[0].before)
        var callbacks = 0,initializations = 0,retained = 0,requests = 0,stores = 0
        for c in r.corpus.cases {
            if c.spec.retain == true { retained += 1 } else { globals = try r.record(c.before) }
            XCTAssertEqual(globals,try r.record(c.before),"Case\(c.index) own before")
            var cursor = 0,globalMask = [UInt8](repeating: 0,count: OriginalMatchPreparation.globalSize),localMask = [UInt8](repeating: 0,count: 64)
            func store(_ region: String,_ offset: Int,_ bytes: [UInt8]) throws {
                guard cursor < c.actions.count else { throw OriginalStateError.invalidStorage("Extra graph store") }
                let a = c.actions[cursor];XCTAssertEqual(a.kind,"store");XCTAssertEqual(a.region,region);XCTAssertEqual(a.offset,offset);XCTAssertEqual(a.bytes,bytes)
                cursor += 1;stores += 1
                for i in offset..<offset+bytes.count { if region == "globals" { globalMask[i] = 1 } else { localMask[i] = 1 } }
            }
            func event(_ kind: String,_ args: [UInt32],_ strings: [[UInt8]]) throws -> Response {
                guard cursor < c.actions.count,let e = c.actions[cursor].event else { throw OriginalStateError.invalidStorage("Unexpected graph request case\(c.index) action\(cursor) \(kind)") }
                XCTAssertEqual(c.actions[cursor].kind,"request");XCTAssertEqual(e.kind,kind);XCTAssertEqual(e.arguments,args);XCTAssertEqual(e.strings,strings)
                cursor += 1;requests += 1;return e.response
            }
            let result: Int32
            if c.spec.initialize == true {
                initializations += 1
                result = try OriginalMusicPlayback.initializeGraph(globals: &globals,request: { q in
                    try event(q.kind.rawValue,q.arguments,q.strings).music
                },store: { a,b in try store("globals",a-OriginalMatchPreparation.globalBase,b) })
            } else {
                callbacks += 1
                var local = try r.record(XCTUnwrap(c.localBefore))
                result = try OriginalGraphEvents.receive(input(c),globals: globals,local: &local,request: { q in
                    try event(q.kind.rawValue,q.arguments,[]).graph
                },store: { o,b in try store("local",o,b) })
                XCTAssertEqual(local,try r.record(XCTUnwrap(c.localAfter)),"Case\(c.index) local")
            }
            XCTAssertEqual(UInt32(bitPattern: result),c.result);XCTAssertEqual(cursor,c.actions.count)
            XCTAssertEqual(globals,try r.record(c.after),"Case\(c.index) globals")
            XCTAssertEqual(globalMask,try r.blob(c.globalWritten));XCTAssertEqual(localMask,try r.blob(c.localWritten))
        }
        XCTAssertEqual(callbacks,371);XCTAssertEqual(initializations,4);XCTAssertEqual(retained,5)
        print("GRAPH EVENTS \(callbacks) whole callbacks \(initializations) graph initializations \(retained) own retained calls \(requests) requests \(stores) ordered stores")
    }
    func testGraphInitializationLateFailureRollsBack() throws {
        enum Stop: Error { case late }
        let r = try resources(),c = try XCTUnwrap(r.corpus.cases.first { $0.spec.label == "own-graph-initialize" })
        var globals = try r.record(c.before);let before = globals;var event = 0
        XCTAssertThrowsError(try OriginalMusicPlayback.initializeGraph(globals: &globals,request: { q in
            let e = c.events[event];event += 1;XCTAssertEqual(q.kind.rawValue,e.kind);XCTAssertEqual(q.arguments,e.arguments)
            if q.kind == .method && q.arguments[1] == 0x38 { throw Stop.late }
            return e.response.music
        }))
        XCTAssertEqual(event,c.events.count);XCTAssertEqual(globals,before)
    }
    func testLateCallbackAndProviderExhaustionRollBackLocals() throws {
        enum Stop: Error { case late }
        let r = try resources(),c = try XCTUnwrap(r.corpus.cases.first { $0.spec.label == "multi-event" && $0.spec.queue?.count == 3 })
        let globals = try r.record(c.before)
        for exhausted in [false,true] {
            var local = try r.record(XCTUnwrap(c.localBefore));let before = local;var event = 0,gets = 0,frees = 0
            XCTAssertThrowsError(try OriginalGraphEvents.receive(input(c),globals: globals,local: &local,request: { q in
                let e = c.events[event];event += 1;XCTAssertEqual(q.kind.rawValue,e.kind);XCTAssertEqual(q.arguments,e.arguments)
                if q.kind == .getEvent { gets += 1;if exhausted && gets == 2 { throw Stop.late } }
                if q.kind == .method && q.arguments[1] == 0x30 { frees += 1 }
                if q.kind == .windowDefault { throw Stop.late }
                return e.response.graph
            }))
            XCTAssertEqual(frees,exhausted ? 1 : 2);XCTAssertEqual(local,before)
        }
    }
    func testUnknownLocalsAreRequiredOnlyWhenRead() throws {
        let r = try resources(),empty = try XCTUnwrap(r.corpus.cases.first { $0.spec.label == "empty" })
        let globals = try r.record(empty.before),b = try r.blob(XCTUnwrap(empty.localBefore))
        var unknown = try OriginalStateRecord(bytes: b,defined: [Bool](repeating: false,count: 64));let before = unknown
        let returned = try OriginalGraphEvents.receive(input(empty),globals: globals,local: &unknown,request: { q in
            .init(result: q.kind == .getEvent ? Int32(bitPattern: 0x80004004) : -123)
        })
        XCTAssertEqual(returned,-123);XCTAssertEqual(unknown,before)
        for offset in [0x34,0x38,0x3c] {
            var defined = [Bool](repeating: true,count: 64);defined[offset] = false
            var local = try OriginalStateRecord(bytes: b,defined: defined);let old = local;var gets = 0,methods = 0
            XCTAssertThrowsError(try OriginalGraphEvents.receive(input(empty),globals: globals,local: &local,request: { q in
                if q.kind == .getEvent { gets += 1;return .init(result: -1,code: offset == 0x34 ? nil : 2) }
                methods += 1;return .init()
            }))
            XCTAssertEqual(gets,1);XCTAssertEqual(methods,0);XCTAssertEqual(local,old)
        }
    }
    func testMissingGraphInterfacesRollBackLocals() throws {
        let r = try resources(),c = try XCTUnwrap(r.corpus.cases.first { $0.spec.label == "multi-event" && $0.spec.queue?.count == 2 })
        for address in [0x44f048,0x44f04c] {
            var globals = try r.record(c.before)
            // Native-only missing-resource contract; no source null dereference
            // is manufactured or represented as an accepted source match.
            try globals.write(UInt32(0),at: address-OriginalMatchPreparation.globalBase)
            var local = try r.record(XCTUnwrap(c.localBefore));let before = local;var gets = 0,methods = 0
            XCTAssertThrowsError(try OriginalGraphEvents.receive(input(c),globals: globals,local: &local,request: { q in
                if q.kind == .getEvent { gets += 1;return .init(result: 0,code: 1,first: 17,second: 21) }
                methods += 1;return .init()
            }))
            XCTAssertEqual(gets,address == 0x44f048 ? 0 : 1);XCTAssertEqual(methods,0);XCTAssertEqual(local,before)
        }
    }
}
