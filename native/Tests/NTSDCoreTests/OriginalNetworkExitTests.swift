import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalNetworkExitTests: XCTestCase {
    typealias Blob = OriginalNetworkClientTests.Blob
    typealias Resources = OriginalNetworkClientTests.Resources
    typealias Action = OriginalNetworkClientTests.Action
    typealias Event = OriginalNetworkClientTests.Event
    struct Spec: Decodable { let label: String, retain: Bool?, parentClient: Int? }
    struct Sample: Decodable {
        let index: Int, spec: Spec, before: String, after: String, localBefore: String, localAfter: String, globalWritten: String, localWritten: String, actions: [Action], events: [Event], result: UInt32?, world: String?, endPC: UInt32?
    }
    struct Corpus: Decodable { let exeSHA256: String, crtSHA256: String, limited: Bool, cases: [Sample], clientParents: [Sample], blobs: [String:Blob] }
    func corpus() throws -> Corpus {
        let url: URL
        if let path = ProcessInfo.processInfo.environment["NTSD_NETWORK_EXIT_CORPUS"] { url = URL(fileURLWithPath: path) }
        else { url = try XCTUnwrap(Bundle.module.url(forResource: "original-network-exit.json",withExtension: nil,subdirectory: "Fixtures")) }
        let c = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(Data(contentsOf: url),maximumCount: 10_000_000))
        XCTAssertEqual(c.cases.count,56);XCTAssertEqual(c.clientParents.count,1);XCTAssertFalse(c.limited)
        XCTAssertEqual(c.exeSHA256,"3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c");XCTAssertEqual(c.crtSHA256,"c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d")
        return c
    }
    func testWholeExitsAndOwnClientContinuation() throws {
        let d = try corpus(),r = Resources(d.blobs);var retained: OriginalStateRecord?,requests = 0,stores = 0
        func run(_ c: Sample,_ globals: inout OriginalStateRecord,client: Bool = false) throws {
            XCTAssertEqual(globals,try r.record(c.before));var local = try r.record(c.localBefore),cursor = 0,gm = [UInt8](repeating: 0,count: globals.bytes.count),lm = [UInt8](repeating: 0,count: local.bytes.count)
            func event(_ kind: String,_ arguments: [UInt32],_ bytes: [UInt8]) throws -> OriginalNetworkClientTests.Response {
                guard cursor < c.actions.count,let e = c.actions[cursor].event else { throw OriginalStateError.invalidStorage("Unexpected exit request \(kind) case\(c.index) action\(cursor)") }
                XCTAssertEqual(c.actions[cursor].kind,"request");XCTAssertEqual(kind,e.kind);XCTAssertEqual(arguments,e.arguments);XCTAssertEqual(bytes,e.bytes);cursor += 1;requests += 1;return e.response
            }
            func store(_ region: String,_ o: Int,_ bytes: [UInt8]) throws {
                guard cursor < c.actions.count else { throw OriginalStateError.invalidStorage("Extra exit store") }
                let a = c.actions[cursor];XCTAssertEqual(a.kind,"store");XCTAssertEqual(a.region,region);XCTAssertEqual(a.offset,o);XCTAssertEqual(a.bytes,bytes);cursor += 1;stores += 1
                for i in o..<o+bytes.count { if region == "globals" { gm[i] = 1 } else { lm[i] = 1 } }
            }
            if client {
                let exit = try OriginalNetworkClient.attempt(globals: &globals,local: &local,world: r.record(XCTUnwrap(c.world)),request: { q in try event(q.kind.rawValue,q.arguments,q.bytes).client },store: { region,o,b in try store(region.rawValue,o,b) })
                XCTAssertEqual(exit.rawValue,c.endPC == 0x42873e ? "present" : "returnWithoutPresentation")
            } else {
                let result = try OriginalNetworkExit.run(globals: &globals,local: &local,request: { q in try event(q.kind.rawValue,q.arguments,q.bytes).result },store: { region,o,b in try store(region.rawValue,o,b) })
                XCTAssertEqual(UInt32(bitPattern: result),c.result)
            }
            XCTAssertEqual(cursor,c.actions.count);XCTAssertEqual(globals,try r.record(c.after));XCTAssertEqual(local,try r.record(c.localAfter));XCTAssertEqual(gm,try r.blob(c.globalWritten));XCTAssertEqual(lm,try r.blob(c.localWritten))
        }
        for c in d.cases {
            if let index = c.spec.parentClient {
                let parent = d.clientParents[index];var own = try r.record(parent.before);try run(parent,&own,client: true);retained = own
            }
            var globals = try c.spec.retain == true ? XCTUnwrap(retained) : r.record(c.before)
            try run(c,&globals);retained = globals
        }
        print("NETWORK EXIT 56 whole returns 1 own client producer \(requests) requests \(stores) semantic stores")
    }
    func testRequiredUnknownBackingRejectsWithRollback() throws {
        let d = try corpus(),r = Resources(d.blobs),c = d.cases[0],base = OriginalMatchPreparation.globalBase
        for address in [0x44f1b4,0x44f1b0,0x44f208,0x44f20b,0x44f58c,0x44f59b] {
            let bytes = try r.blob(c.before);var defined = [Bool](repeating: true,count: bytes.count);defined[address-base] = false
            var globals = try OriginalStateRecord(bytes: bytes,defined: defined),local = try r.record(c.localBefore);let g = globals,l = local
            XCTAssertThrowsError(try OriginalNetworkExit.run(globals: &globals,local: &local,request: { _ in XCTFail("No platform request should precede this missing input");return 0 }))
            XCTAssertEqual(globals,g);XCTAssertEqual(local,l)
        }
    }
    func testUnknownLocalsAreClearedOnlyWhenSendGateRuns() throws {
        let d = try corpus(),r = Resources(d.blobs)
        for index in [0,1] {
            let c = d.cases[index];var globals = try r.record(c.before),local = try OriginalStateRecord(bytes: r.blob(c.localBefore),defined: [Bool](repeating: false,count: 256));let old = local;var cursor = 0
            _ = try OriginalNetworkExit.run(globals: &globals,local: &local,request: { q in let e = c.events[cursor];cursor += 1;XCTAssertEqual(q.kind.rawValue,e.kind);return e.response.result })
            if index == 0 { XCTAssertTrue(local.defined.allSatisfy { $0 });XCTAssertEqual(local,try r.record(c.localAfter)) } else { XCTAssertEqual(local,old) }
            XCTAssertEqual(cursor,c.events.count)
        }
    }
    func testZeroListenerDoesNotRequireActiveAddressOrSockaddr() throws {
        let d = try corpus(),r = Resources(d.blobs),c = d.cases[1],base = OriginalMatchPreparation.globalBase
        let bytes = try r.blob(c.before);var defined = [Bool](repeating: true,count: bytes.count)
        for a in [0x44f1b0,0x44f208,0x44f58c] { defined[a-base] = false }
        var globals = try OriginalStateRecord(bytes: bytes,defined: defined),local = try r.record(c.localBefore);var kinds: [String] = []
        XCTAssertEqual(try OriginalNetworkExit.run(globals: &globals,local: &local,request: { q in kinds.append(q.kind.rawValue);return -123 }),-123)
        XCTAssertEqual(kinds,["closeSocket","cleanup"]);XCTAssertTrue(globals.defined[0x44f1b0-base]);XCTAssertFalse(globals.defined[0x44f208-base]);XCTAssertFalse(globals.defined[0x44f58c-base])
    }
    func testLateCleanupErrorCloseAndFinalStoreRollBack() throws {
        enum Stop: Error { case late }
        let d = try corpus(),r = Resources(d.blobs),base = OriginalMatchPreparation.globalBase
        for trial in 0..<3 {
            let c = d.cases[trial == 1 ? 10 : 0];var globals = try r.record(c.before),local = try r.record(c.localBefore);let g = globals,l = local;var cursor = 0
            XCTAssertThrowsError(try OriginalNetworkExit.run(globals: &globals,local: &local,request: { q in
                let e = c.events[cursor];cursor += 1;XCTAssertEqual(q.kind.rawValue,e.kind)
                if trial == 0 && q.kind == .cleanup || trial == 1 && q.kind == .closeSocket { throw Stop.late };return e.response.result
            },store: { region,o,_ in if trial == 2 && region == .globals && o == 0x44f1b0-base { throw Stop.late } }))
            XCTAssertEqual(globals,g);XCTAssertEqual(local,l);XCTAssertEqual(cursor,trial == 2 ? 2 : 3)
        }
    }
}
