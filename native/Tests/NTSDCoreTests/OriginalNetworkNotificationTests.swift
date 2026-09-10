import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalNetworkNotificationTests: XCTestCase {
    struct Blob: Decodable { let count: Int, base64: String }
    struct Response: Decodable {
        let result: Int32, bytes: [UInt8]?
        var native: OriginalNetworkNotification.Response { .init(result: result,bytes: bytes ?? []) }
    }
    struct Event: Decodable { let kind: String, arguments: [UInt32], bytes: [UInt8], response: Response }
    struct Action: Decodable { let kind: String, region: String?, offset: Int?, bytes: [UInt8]?, event: Event? }
    struct Spec: Decodable { let label: String, retain: Bool?, window: UInt32?, wParam: UInt32?, lParam: UInt32? }
    struct Sample: Decodable {
        let index: Int, spec: Spec, before: String, after: String, globalWritten: String, localBefore: String, localAfter: String, localWritten: String, actions: [Action], events: [Event], result: UInt32
    }
    struct Corpus: Decodable { let exeSHA256: String, crtSHA256: String, limited: Bool, cases: [Sample], blobs: [String:Blob] }
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
        if let path = ProcessInfo.processInfo.environment["NTSD_NETWORK_NOTIFICATION_CORPUS"] { url = URL(fileURLWithPath: path) }
        else { url = try XCTUnwrap(Bundle.module.url(forResource: "original-network-notification.json",withExtension: nil,subdirectory: "Fixtures")) }
        let c = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(Data(contentsOf: url),maximumCount: 64_000_000))
        XCTAssertFalse(c.limited);XCTAssertEqual(c.cases.count,415)
        XCTAssertEqual(c.exeSHA256,"3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        XCTAssertEqual(c.crtSHA256,"c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d")
        return Resources(c)
    }
    private func input(_ c: Sample) -> OriginalWindowInput.Message {
        .init(window: c.spec.window ?? 0x73000001,message: 0x401,wParam: c.spec.wParam ?? 0xabcdef12,lParam: c.spec.lParam ?? 8)
    }
    func testWholeNotificationsPacketsMasksAndRetainedState() throws {
        let r = try resources();var globals = try r.record(r.corpus.cases[0].before),retained = 0,requests = 0,stores = 0
        for c in r.corpus.cases {
            if c.spec.retain == true { retained += 1 } else { globals = try r.record(c.before) }
            XCTAssertEqual(globals,try r.record(c.before),"Case\(c.index) own before")
            var local = try r.record(c.localBefore),cursor = 0,gm = [UInt8](repeating: 0,count: OriginalMatchPreparation.globalSize),lm = [UInt8](repeating: 0,count: 160)
            let result = try OriginalNetworkNotification.receive(input(c),globals: &globals,local: &local,request: { q in
                guard cursor < c.actions.count,let e = c.actions[cursor].event else { throw OriginalStateError.invalidStorage("Unexpected network request case\(c.index) action\(cursor) \(q.kind)") }
                XCTAssertEqual(c.actions[cursor].kind,"request");XCTAssertEqual(q.kind.rawValue,e.kind);XCTAssertEqual(q.arguments,e.arguments);XCTAssertEqual(q.bytes,e.bytes)
                cursor += 1;requests += 1;return e.response.native
            },store: { region,offset,bytes in
                guard cursor < c.actions.count else { throw OriginalStateError.invalidStorage("Extra network store") }
                let a = c.actions[cursor];XCTAssertEqual(a.kind,"store");XCTAssertEqual(a.region,region.rawValue);XCTAssertEqual(a.offset,offset);XCTAssertEqual(a.bytes,bytes,"Case\(c.index) action\(cursor)")
                cursor += 1;stores += 1
                for i in offset..<offset+bytes.count { if region == .globals { gm[i] = 1 } else { lm[i] = 1 } }
            })
            XCTAssertEqual(UInt32(bitPattern: result),c.result);XCTAssertEqual(cursor,c.actions.count)
            XCTAssertEqual(globals,try r.record(c.after),"Case\(c.index) globals");XCTAssertEqual(local,try r.record(c.localAfter),"Case\(c.index) local")
            XCTAssertEqual(gm,try r.blob(c.globalWritten));XCTAssertEqual(lm,try r.blob(c.localWritten))
        }
        XCTAssertEqual(retained,4)
        print("NETWORK NOTIFICATION \(r.corpus.cases.count) whole callbacks \(retained) retained calls \(requests) requests \(stores) ordered semantic stores")
    }
    func testLateDefaultAndUnavailableReceiveRollBackWholeCallback() throws {
        enum Stop: Error { case late }
        let r = try resources(),c = r.corpus.cases[0]
        for stop in ["receive","windowDefault"] {
            var globals = try r.record(c.before),local = try r.record(c.localBefore);let g = globals,l = local;var cursor = 0,sends = 0
            XCTAssertThrowsError(try OriginalNetworkNotification.receive(input(c),globals: &globals,local: &local,request: { q in
                let e = c.events[cursor];cursor += 1;XCTAssertEqual(q.kind.rawValue,e.kind);XCTAssertEqual(q.arguments,e.arguments);XCTAssertEqual(q.bytes,e.bytes)
                if q.kind == .send { sends += 1 }
                if q.kind.rawValue == stop { throw Stop.late }
                return e.response.native
            }))
            XCTAssertEqual(sends,stop == "receive" ? 1 : 3);XCTAssertEqual(globals,g);XCTAssertEqual(local,l)
        }
    }
    func testRequiredUnknownStorageAndExcessOutputRejectWithRollback() throws {
        let r = try resources(),c = r.corpus.cases[0],base = OriginalMatchPreparation.globalBase
        for trial in 0..<4 {
            var raw = try r.blob(c.before),defined = [Bool](repeating: true,count: raw.count)
            if trial < 2 { defined[(trial == 0 ? 0x44fcc0 : 0x44ff90)-base] = false }
            // An ordinary settings name can be unbounded. Native-only boundary
            // trial: never execute a source copy into its cookie/control words.
            if trial == 2 { for i in 0..<50 { raw[0x44fcc0-base+i] = 65 };raw[0x44fcc0-base+50] = 0 }
            var globals = try OriginalStateRecord(bytes: raw,defined: defined),local = try r.record(c.localBefore);let g = globals,l = local;var cursor = 0
            XCTAssertThrowsError(try OriginalNetworkNotification.receive(input(c),globals: &globals,local: &local,request: { q in
                let e = c.events[cursor];cursor += 1;XCTAssertEqual(q.kind.rawValue,e.kind)
                if trial == 3 && q.kind == .receive { return .init(result: 77,bytes: [UInt8](repeating: 0,count: 78)) }
                return e.response.native
            }))
            XCTAssertEqual(globals,g);XCTAssertEqual(local,l)
        }
    }
    func testUnknownUntouchedLocalsAndNonacceptInputsRemainUnknown() throws {
        let r = try resources(),c = r.corpus.cases[0]
        var globals = try r.record(c.before),local = try OriginalStateRecord(bytes: r.blob(c.localBefore),defined: [Bool](repeating: false,count: 160)),cursor = 0
        _ = try OriginalNetworkNotification.receive(input(c),globals: &globals,local: &local,request: { _ in
            let e = c.events[cursor];cursor += 1;return e.response.native
        })
        XCTAssertEqual(local.bytes,try r.blob(c.localAfter));XCTAssertEqual(local.defined,try r.blob(c.localWritten).map { $0 != 0 })
        let notice = try XCTUnwrap(r.corpus.cases.first { $0.spec.lParam == 1 })
        globals = try .init(bytes: r.blob(notice.before),defined: [Bool](repeating: false,count: OriginalMatchPreparation.globalSize))
        local = try .init(bytes: r.blob(notice.localBefore),defined: [Bool](repeating: false,count: 160));let g = globals,l = local;cursor = 0
        _ = try OriginalNetworkNotification.receive(input(notice),globals: &globals,local: &local,request: { _ in
            let e = notice.events[cursor];cursor += 1;return e.response.native
        })
        XCTAssertEqual(globals,g);XCTAssertEqual(local,l)
    }
}
