import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalNetworkClientTests: XCTestCase {
    struct Blob: Decodable { let count: Int, base64: String }
    struct Response: Decodable {
        let result: Int32, bytes: [UInt8]?, hostAddress: UInt32?
        var client: OriginalNetworkClient.Response { .init(result: result,bytes: bytes ?? [],hostAddress: hostAddress) }
        var server: OriginalNetworkNotification.Response { .init(result: result,bytes: bytes ?? []) }
    }
    struct Event: Decodable { let kind: String, arguments: [UInt32], bytes: [UInt8], response: Response }
    struct Action: Decodable { let kind: String, region: String?, offset: Int?, bytes: [UInt8]?, event: Event? }
    struct Spec: Decodable { let label: String }
    struct Sample: Decodable {
        let index: Int, spec: Spec, before: String, after: String, globalWritten: String, localBefore: String, localAfter: String, localWritten: String, world: String?, actions: [Action], events: [Event], endPC: UInt32?, result: UInt32?
    }
    struct Delivery: Decodable { let sender: String, bytes: [UInt8] }
    struct Pair: Decodable { let client: Sample, server: Sample, clientBlobs: [String:Blob], serverBlobs: [String:Blob], deliveries: [Delivery] }
    struct Corpus: Decodable { let exeSHA256: String, crtSHA256: String, limited: Bool, cases: [Sample], pairs: [Pair], blobs: [String:Blob] }
    final class Resources {
        let blobs: [String:Blob]
        var cache: [String:[UInt8]] = [:]
        init(_ blobs: [String:Blob]) { self.blobs = blobs }
        func blob(_ key: String) throws -> [UInt8] {
            if let b = cache[key] { return b }
            let b = try XCTUnwrap(blobs[key]),d = try XCTUnwrap(Data(base64Encoded: b.base64))
            XCTAssertEqual(d.count,b.count);XCTAssertEqual(MatchPreparationReference.digest(d),key)
            let value = [UInt8](d);cache[key] = value;return value
        }
        func record(_ key: String) throws -> OriginalStateRecord {
            let b = try blob(key);return try .init(bytes: b,defined: [Bool](repeating: true,count: b.count))
        }
    }
    private func corpus() throws -> Corpus {
        let url: URL
        if let path = ProcessInfo.processInfo.environment["NTSD_NETWORK_CLIENT_CORPUS"] { url = URL(fileURLWithPath: path) }
        else { url = try XCTUnwrap(Bundle.module.url(forResource: "original-network-client.json",withExtension: nil,subdirectory: "Fixtures")) }
        let c = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(Data(contentsOf: url),maximumCount: 90_000_000))
        XCTAssertFalse(c.limited);XCTAssertEqual(c.cases.count,392);XCTAssertEqual(c.pairs.count,1)
        XCTAssertEqual(c.exeSHA256,"3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        XCTAssertEqual(c.crtSHA256,"c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d")
        return c
    }
    final class Peer: @unchecked Sendable {
        let condition = NSCondition()
        var queues: [String:[[UInt8]]] = ["server":[],"client":[]]
        var sent: [String:[[UInt8]]] = ["server":[],"client":[]]
        func send(_ role: String,_ bytes: [UInt8]) {
            condition.lock();defer { condition.unlock() }
            sent[role,default:[]].append(bytes);queues[role == "server" ? "client" : "server",default:[]].append(bytes);condition.broadcast()
        }
        func receive(_ role: String,_ count: Int) throws -> [UInt8] {
            condition.lock();defer { condition.unlock() };let limit = Date().addingTimeInterval(30)
            while queues[role,default:[]].isEmpty {
                guard condition.wait(until: limit) else { throw OriginalStateError.invalidStorage("Controlled peer queue exhausted") }
            }
            let value = queues[role]!.removeFirst();guard value.count <= count else { throw OriginalStateError.invalidStorage("Peer packet exceeds request") };return value
        }
    }
    final class Trial: @unchecked Sendable {
        let resources: Resources, sample: Sample, peer: Peer?, role: String
        var failure: Error?, requests = 0, stores = 0
        init(_ r: Resources,_ c: Sample,_ role: String = "client",_ peer: Peer? = nil) { resources = r;sample = c;self.role = role;self.peer = peer }
        func run() throws {
            let r = resources,c = sample;var globals = try r.record(c.before),local = try r.record(c.localBefore),cursor = 0
            var gm = [UInt8](repeating: 0,count: globals.bytes.count),lm = [UInt8](repeating: 0,count: local.bytes.count)
            func event(_ kind: String,_ arguments: [UInt32],_ bytes: [UInt8]) throws -> Response {
                guard cursor < c.actions.count,let e = c.actions[cursor].event else { throw OriginalStateError.invalidStorage("Unexpected client/peer request case\(c.index) action\(cursor) \(kind)") }
                XCTAssertEqual(c.actions[cursor].kind,"request");XCTAssertEqual(kind,e.kind);XCTAssertEqual(arguments,e.arguments);XCTAssertEqual(bytes,e.bytes)
                cursor += 1;requests += 1
                if let peer {
                    if kind == "send" { peer.send(role,bytes) }
                    if kind == "receive" {
                        let own = try peer.receive(role,Int(arguments[1]));XCTAssertEqual(own,e.response.bytes);XCTAssertEqual(Int32(own.count),e.response.result)
                        return Response(result: Int32(own.count),bytes: own,hostAddress: nil)
                    }
                }
                return e.response
            }
            func store(_ region: String,_ offset: Int,_ bytes: [UInt8]) throws {
                guard cursor < c.actions.count else { throw OriginalStateError.invalidStorage("Extra client/peer store") }
                let a = c.actions[cursor];XCTAssertEqual(a.kind,"store");XCTAssertEqual(a.region,region);XCTAssertEqual(a.offset,offset);XCTAssertEqual(a.bytes,bytes,"Case\(c.index) action\(cursor)")
                cursor += 1;stores += 1
                for i in offset..<offset+bytes.count { if region == "globals" { gm[i] = 1 } else { lm[i] = 1 } }
            }
            if role == "client" {
                let world = try r.record(XCTUnwrap(c.world))
                let exit = try OriginalNetworkClient.attempt(globals: &globals,local: &local,world: world,request: { q in try event(q.kind.rawValue,q.arguments,q.bytes).client },store: { region,o,b in try store(region.rawValue,o,b) })
                XCTAssertEqual(exit.rawValue,c.endPC == 0x42873e ? "present" : "returnWithoutPresentation")
            } else {
                let returned = try OriginalNetworkNotification.receive(.init(window: 0x73000001,message: 0x401,wParam: 0xabcdef12,lParam: 8),globals: &globals,local: &local,request: { q in try event(q.kind.rawValue,q.arguments,q.bytes).server },store: { region,o,b in try store(region.rawValue,o,b) })
                XCTAssertEqual(UInt32(bitPattern: returned),c.result)
            }
            XCTAssertEqual(cursor,c.actions.count);XCTAssertEqual(globals,try r.record(c.after));XCTAssertEqual(local,try r.record(c.localAfter));XCTAssertEqual(gm,try r.blob(c.globalWritten));XCTAssertEqual(lm,try r.blob(c.localWritten))
        }
    }
    func testWholeDeferredActionsAndExactPackets() throws {
        let d = try corpus(),r = Resources(d.blobs);var requests = 0,stores = 0
        for c in d.cases { let t = Trial(r,c);try t.run();requests += t.requests;stores += t.stores }
        print("NETWORK CLIENT \(d.cases.count) actions \(requests) requests \(stores) semantic stores")
    }
    func testBothNativePeersConsumeOwnGeneratedPackets() throws {
        let d = try corpus(),p = try XCTUnwrap(d.pairs.first),peer = Peer()
        let trials = [Trial(Resources(p.serverBlobs),p.server,"server",peer),Trial(Resources(p.clientBlobs),p.client,"client",peer)]
        DispatchQueue.concurrentPerform(iterations: trials.count) { i in
            do { try trials[i].run() } catch { trials[i].failure = error }
        }
        for trial in trials { if let error = trial.failure { throw error } }
        XCTAssertTrue(peer.queues.values.allSatisfy { $0.isEmpty })
        for role in ["server","client"] { XCTAssertEqual(peer.sent[role],p.deliveries.filter { $0.sender == role }.map(\.bytes)) }
        print("NETWORK PEERS 2 original/native calls 4 own packet deliveries 3169 bytes")
    }
    func testLateReceiveAndFinalStoreRollBackWholeAction() throws {
        enum Stop: Error { case late }
        let d = try corpus(),r = Resources(d.blobs),c = d.cases[0],world = try r.record(XCTUnwrap(c.world))
        for lateStore in [false,true] {
            var globals = try r.record(c.before),local = try r.record(c.localBefore);let g = globals,l = local;var cursor = 0
            XCTAssertThrowsError(try OriginalNetworkClient.attempt(globals: &globals,local: &local,world: world,request: { q in
                let e = c.events[cursor];cursor += 1;XCTAssertEqual(q.kind.rawValue,e.kind)
                if !lateStore && q.kind == .receive && q.arguments[1] == 3001 { throw Stop.late }
                return e.response.client
            },store: { region,o,_ in if lateStore && region == .globals && o == 0x44d064-OriginalMatchPreparation.globalBase { throw Stop.late } }))
            XCTAssertEqual(cursor,c.events.count);XCTAssertEqual(globals,g);XCTAssertEqual(local,l)
        }
    }
    func testRequiredUnknownBackingAndOutputLimitReject() throws {
        let d = try corpus(),r = Resources(d.blobs),c = d.cases[0],base = OriginalMatchPreparation.globalBase
        for trial in 0..<6 {
            let gb = try r.blob(c.before),lb = try r.blob(c.localBefore),wb = try r.blob(XCTUnwrap(c.world))
            var gd = [Bool](repeating: true,count: gb.count),ld = [Bool](repeating: true,count: lb.count),wd = [Bool](repeating: true,count: wb.count)
            if trial == 0 { wd[0x7d8] = false };if trial == 1 { gd[0x44fcc0-base] = false }
            if trial == 2 { ld[0x270] = false };if trial == 3 { ld[0xf4] = false }
            var globals = try OriginalStateRecord(bytes: gb,defined: gd),local = try OriginalStateRecord(bytes: lb,defined: ld);let g = globals,l = local,world = try OriginalStateRecord(bytes: wb,defined: wd);var cursor = 0
            XCTAssertThrowsError(try OriginalNetworkClient.attempt(globals: &globals,local: &local,world: world,request: { q in
                let e = c.events[cursor];cursor += 1;XCTAssertEqual(q.kind.rawValue,e.kind)
                if trial == 4 && q.kind == .hostLookup { return .init(result: e.response.result) }
                if q.kind == .receive {
                    if trial == 2 && q.arguments[1] == 100 || trial == 3 && q.arguments[1] == 77 { return .init(result: 0) }
                    if trial == 5 && q.arguments[1] == 3001 { return .init(result: 3001,bytes: [UInt8](repeating: 0,count: 3002)) }
                }
                return e.response.client
            }))
            XCTAssertEqual(globals,g);XCTAssertEqual(local,l)
        }
    }
    func testGreetingMismatchDoesNotReadUnknownSuffix() throws {
        let d = try corpus(),r = Resources(d.blobs),c = d.cases[0],world = try r.record(XCTUnwrap(c.world))
        var globals = try r.record(c.before),local = try OriginalStateRecord(bytes: r.blob(c.localBefore),defined: [Bool](repeating: false,count: 0x400)),cursor = 0
        let exit = try OriginalNetworkClient.attempt(globals: &globals,local: &local,world: world,request: { q in
            let e = c.events[cursor];cursor += 1;XCTAssertEqual(q.kind.rawValue,e.kind)
            if q.kind == .receive { return .init(result: 1,bytes: [0]) };return e.response.client
        })
        XCTAssertEqual(exit.rawValue,"present");XCTAssertEqual(cursor,6)
        XCTAssertEqual(local.defined.enumerated().filter { $0.element }.map(\.offset),[0x270])
    }
}
