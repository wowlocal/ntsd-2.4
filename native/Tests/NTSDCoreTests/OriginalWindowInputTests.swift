import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalWindowInputTests: XCTestCase {
    struct Blob: Decodable { let count: Int, deflate: String }
    struct Allocation: Decodable { let address: UInt32, count: Int, live: Bool, bytes: String }
    struct Snapshot: Decodable { let globals: String, local: String, pointers: String, allocations: [Allocation] }
    struct Spec: Decodable {
        let label: String, message: UInt32?, key: UInt32?, lParam: UInt32?, window: UInt32?
        let retain: Bool?, constructor: Bool?, stimulus: [[Int64]]?, messageResult: Int32?
        let active: UInt32?, length: UInt32?
    }
    struct Event: Decodable, Equatable {
        let kind: OriginalWindowInput.Request.Kind, arguments: [UInt32], strings: [[UInt8]], result: Int32
        var request: OriginalWindowInput.Request { .init(kind,arguments,strings) }
    }
    struct Action: Decodable, Equatable {
        let kind: String, address: Int?, bytes: [UInt8]?, event: Event?
    }
    struct Sample: Decodable {
        let index: Int, spec: Spec, before: Snapshot, after: Snapshot
        let writeMasks: [String], actions: [Action], result: UInt32
    }
    struct Corpus: Decodable {
        let exeSHA256: String, libSHA256: String, cases: [Sample], blobs: [String:Blob], limited: Bool
    }
    final class Resources {
        let corpus: Corpus
        var cache: [String:[UInt8]] = [:]
        init(_ corpus: Corpus) { self.corpus = corpus }
        func blob(_ key: String) throws -> [UInt8] {
            if let raw = cache[key] { return raw }
            let b = try XCTUnwrap(corpus.blobs[key])
            // Inner source blobs retain zlib framing; Apple's shared decoder
            // consumes raw DEFLATE. Preserve and validate the source envelope.
            let packed = [UInt8](try XCTUnwrap(Data(base64Encoded: b.deflate)))
            guard packed.count >= 6, packed[0] == 0x78, packed[1] == 0xda else {
                throw OriginalStateError.invalidStorage("Window input fixture zlib framing")
            }
            let raw = try MatchPreparationReference.inflate(Data(packed.dropFirst(2).dropLast(4)).base64EncodedString(),count: b.count,maximumCount: 1_000_000)
            var a: UInt32 = 1, s: UInt32 = 0
            for byte in raw { a = (a+UInt32(byte))%65521; s = (s+a)%65521 }
            XCTAssertEqual((s << 16)|a,packed.suffix(4).reduce(UInt32(0)) { ($0 << 8)|UInt32($1) })
            XCTAssertEqual(MatchPreparationReference.digest(Data(raw)),key)
            cache[key] = raw;return raw
        }
        func record(_ key: String) throws -> OriginalStateRecord {
            let raw = try blob(key);return try .init(bytes: raw,defined: [Bool](repeating: true,count: raw.count))
        }
        func memory(_ s: Snapshot) throws -> OriginalMenuPresentationMemory {
            var m = OriginalMenuPresentationMemory(replayPointers: try record(s.pointers))
            for a in s.allocations { m.allocations[a.address] = .init(storage: try record(a.bytes),live: a.live) }
            return m
        }
        func check(_ globals: OriginalStateRecord, _ local: OriginalStateRecord,
                   _ memory: OriginalMenuPresentationMemory, _ s: Snapshot, _ label: String) throws {
            XCTAssertEqual(globals,try record(s.globals),label+" globals")
            XCTAssertEqual(local,try record(s.local),label+" local")
            XCTAssertEqual(memory.replayPointers,try record(s.pointers),label+" pointers")
            XCTAssertEqual(memory.allocations.count,s.allocations.count)
            for a in s.allocations {
                let own = try XCTUnwrap(memory.allocations[a.address])
                XCTAssertEqual(own.live,a.live,label+" allocation lifetime")
                XCTAssertEqual(own.storage,try record(a.bytes),label+" allocation bytes/masks")
            }
        }
    }
    private func resources() throws -> Resources {
        let url: URL
        if let p = ProcessInfo.processInfo.environment["NTSD_WINDOW_INPUT_CORPUS"] { url = URL(fileURLWithPath: p) }
        else { url = try XCTUnwrap(Bundle.module.url(forResource: "original-window-input.json",withExtension: nil,subdirectory: "Fixtures")) }
        let c = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(Data(contentsOf: url),maximumCount: 128_000_000))
        XCTAssertEqual(c.exeSHA256,"3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        XCTAssertEqual(c.libSHA256,"28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba")
        XCTAssertFalse(c.limited);XCTAssertEqual(c.cases.count,4372)
        return Resources(c)
    }
    private func input(_ c: Sample) -> OriginalWindowInput.Message {
        .init(window: c.spec.window ?? 0x72000001,message: c.spec.message!,wParam: c.spec.key ?? 0,lParam: c.spec.lParam ?? 0)
    }
    func testWholeCallbacksOwnTextSequencesAndExactStoreOrder() throws {
        let r = try resources()
        var globals = try r.record(r.corpus.cases[0].before.globals)
        var local = try r.record(r.corpus.cases[0].before.local)
        var memory = try r.memory(r.corpus.cases[0].before)
        var requests = 0,stores = 0,callbacks = 0,constructors = 0,retained = 0
        for c in r.corpus.cases {
            if c.spec.retain == true {
                retained += 1
                for write in c.spec.stimulus ?? [] {
                    XCTAssertTrue(write[0] >= OriginalWindowInput.localBase)
                    try local.write(UInt32(truncatingIfNeeded: write[1]),at: Int(write[0])-OriginalWindowInput.localBase)
                }
            } else {
                globals = try r.record(c.before.globals);local = try r.record(c.before.local);memory = try r.memory(c.before)
            }
            try r.check(globals,local,memory,c.before,"\(c.index) own before")
            var cursor = 0
            var masks = [[UInt8](repeating: 0,count: OriginalMatchPreparation.globalSize),[UInt8](repeating: 0,count: OriginalWindowInput.localCount),[UInt8](repeating: 0,count: 8)]
            let store: OriginalWindowInput.Store = { address,bytes in
                guard cursor < c.actions.count else { throw OriginalStateError.invalidStorage("Extra input store case\(c.index)") }
                XCTAssertEqual(c.actions[cursor],.init(kind: "store",address: address,bytes: bytes,event: nil),"Case\(c.index) action\(cursor)")
                cursor += 1;stores += 1
                let region = address >= 0x4588a8 ? 2 : address >= OriginalWindowInput.localBase ? 1 : 0
                let offset = address-[OriginalMatchPreparation.globalBase,OriginalWindowInput.localBase,0x4588a8][region]
                guard offset >= 0 && offset+bytes.count <= masks[region].count else { throw OriginalStateError.invalidStorage("Native store outside source extent") }
                for i in 0..<bytes.count { masks[region][offset+i] = 1 }
            }
            if c.spec.constructor == true {
                constructors += 1;try OriginalWindowInput.initializeText(&local,store: store)
            } else {
                callbacks += 1
                let result = try OriginalWindowInput.receive(input(c),globals: &globals,local: &local,memory: &memory,request: { request in
                    guard cursor < c.actions.count,let event = c.actions[cursor].event else { throw OriginalStateError.invalidStorage("Unexpected input request case\(c.index) action\(cursor) \(request.kind)") }
                    XCTAssertEqual(c.actions[cursor].kind,"request");XCTAssertEqual(request,event.request,"Case\(c.index) action\(cursor)")
                    cursor += 1;requests += 1;return event.result
                },store: store)
                XCTAssertEqual(UInt32(bitPattern: result),c.result,"Case\(c.index) result")
            }
            XCTAssertEqual(cursor,c.actions.count,"Case\(c.index) action count")
            for i in 0..<3 { XCTAssertEqual(masks[i],try r.blob(c.writeMasks[i]),"Case\(c.index) region\(i) write mask") }
            try r.check(globals,local,memory,c.after,"\(c.index) after")
        }
        XCTAssertEqual(callbacks,4369);XCTAssertEqual(constructors,3);XCTAssertEqual(retained,385)
        XCTAssertEqual(requests,5908);XCTAssertEqual(stores,23835)
        print("WINDOW INPUT \(callbacks) whole callbacks \(constructors) constructors \(retained) own retained calls \(requests) requests \(stores) ordered stores")
    }
    func testLateCloseAndMissingReplayOwnershipRollBackWholeCallback() throws {
        enum Stop: Error { case close }
        let r = try resources()
        let c = try XCTUnwrap(r.corpus.cases.first { $0.spec.label == "escape-cleanup" && $0.spec.messageResult == 6 && $0.before.allocations.count == 2 })
        for missing in [false,true] {
            var globals = try r.record(c.before.globals),local = try r.record(c.before.local),memory = try r.memory(c.before)
            if missing { memory.allocations.removeValue(forKey: c.before.allocations[1].address) }
            let oldGlobals = globals,oldLocal = local,oldMemory = memory
            var frees = 0,posts = 0
            XCTAssertThrowsError(try OriginalWindowInput.receive(input(c),globals: &globals,local: &local,memory: &memory,request: { request in
                if request.kind == .message { return 6 }
                if request.kind == .free { frees += 1 }
                if request.kind == .postMessage { posts += 1;throw Stop.close }
                return -1
            }))
            XCTAssertEqual(frees,missing ? 1 : 2);XCTAssertEqual(posts,missing ? 0 : 1)
            XCTAssertEqual(globals,oldGlobals);XCTAssertEqual(local,oldLocal)
            XCTAssertEqual(memory.replayPointers,oldMemory.replayPointers);XCTAssertEqual(memory.allocations,oldMemory.allocations)
        }
    }
    func testTextIndexAliasLateFailureAndUnknownStorageRollBack() throws {
        enum Stop: Error { case alias }
        let r = try resources()
        let c = try XCTUnwrap(r.corpus.cases.first { $0.spec.active == 1 && $0.spec.length == 299 && $0.spec.key == 0x42 })
        for unknown in [false,true] {
            var globals = try r.record(c.before.globals),local = try r.record(c.before.local),memory = try r.memory(c.before)
            if unknown {
                var mask = local.defined;mask[0x130] = false
                local = try .init(bytes: local.bytes,defined: mask)
            }
            let oldGlobals = globals,oldLocal = local,oldMemory = memory
            var stores = 0
            XCTAssertThrowsError(try OriginalWindowInput.receive(input(c),globals: &globals,local: &local,memory: &memory,request: { _ in
                XCTFail("Failure must precede platform requests");return 0
            },store: { address,bytes in
                stores += 1
                if address == OriginalWindowInput.localBase+0x130 && bytes == [0] { throw Stop.alias }
            }))
            XCTAssertEqual(stores,unknown ? 0 : 4)
            XCTAssertEqual(globals,oldGlobals);XCTAssertEqual(local,oldLocal)
            XCTAssertEqual(memory.replayPointers,oldMemory.replayPointers);XCTAssertEqual(memory.allocations,oldMemory.allocations)
        }
    }
}
