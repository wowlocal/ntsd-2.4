import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalWindowLifecycleTests: XCTestCase {
    struct Blob: Decodable { let count: Int, base64: String }
    struct Release: Codable, Equatable { let key: String, result: UInt32 }
    struct Object: Codable, Equatable { let address: UInt32, family: String; var releases: [Release] }
    struct Allocation: Decodable { let address: UInt32, count: Int, live: Bool, bytes: String }
    struct Snapshot: Decodable { let globals: String, pointers: String, objects: [Object], allocations: [Allocation] }
    struct Spec: Decodable {
        let label: String, message: UInt32?, wParam: UInt32?, lParam: UInt32?, window: UInt32?
        let initialize: Bool?, retain: Bool?, stimulus: [[Int64]]?, mode: Int32?, resources: Int?, audio: Bool?
    }
    struct Backing: Decodable { let kind: String, bytes: [UInt8] }
    struct Event: Decodable {
        let key: String, request: OriginalWindowInitialization.Request, response: OriginalWindowInitialization.Response
    }
    struct Action: Decodable { let kind: String, address: Int?, bytes: [UInt8]?, event: Event? }
    struct Sample: Decodable {
        let index: Int, spec: Spec, before: Snapshot, after: Snapshot, writeMasks: [String], actions: [Action], backings: [Backing], result: UInt32
    }
    struct Corpus: Decodable { let exeSHA256: String, libSHA256: String, cases: [Sample], blobs: [String:Blob], limited: Bool }
    final class Resources {
        let corpus: Corpus
        var cache: [String:[UInt8]] = [:]
        init(_ corpus: Corpus) { self.corpus = corpus }
        func blob(_ key: String) throws -> [UInt8] {
            if let b = cache[key] { return b }
            let input = try XCTUnwrap(corpus.blobs[key]), data = try XCTUnwrap(Data(base64Encoded: input.base64))
            XCTAssertEqual(data.count,input.count);XCTAssertEqual(MatchPreparationReference.digest(data),key)
            let b = [UInt8](data);cache[key] = b;return b
        }
        func record(_ key: String) throws -> OriginalStateRecord {
            let b = try blob(key);return try .init(bytes: b,defined: [Bool](repeating: true,count: b.count))
        }
        func memory(_ s: Snapshot) throws -> OriginalMenuPresentationMemory {
            var m = OriginalMenuPresentationMemory(replayPointers: try record(s.pointers))
            for a in s.allocations { m.allocations[a.address] = .init(storage: try record(a.bytes),live: a.live) }
            return m
        }
        func check(_ state: OriginalStateRecord,_ memory: OriginalMenuPresentationMemory,_ objects: [Object],_ snapshot: Snapshot,_ label: String) throws {
            XCTAssertEqual(state,try record(snapshot.globals),label+" globals")
            XCTAssertEqual(memory.replayPointers,try record(snapshot.pointers),label+" replay pointers")
            XCTAssertEqual(objects,snapshot.objects,label+" display lifetime")
            XCTAssertEqual(memory.allocations,try self.memory(snapshot).allocations,label+" allocation bytes/masks/lifetime")
        }
    }
    private func resources() throws -> Resources {
        let url: URL
        if let path = ProcessInfo.processInfo.environment["NTSD_WINDOW_LIFECYCLE_CORPUS"] { url = URL(fileURLWithPath: path) }
        else { url = try XCTUnwrap(Bundle.module.url(forResource: "original-window-lifecycle.json",withExtension: nil,subdirectory: "Fixtures")) }
        let c = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(Data(contentsOf: url),maximumCount: 128_000_000))
        XCTAssertEqual(c.exeSHA256,"3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        XCTAssertEqual(c.libSHA256,"28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba")
        XCTAssertFalse(c.limited);XCTAssertEqual(c.cases.count,320);return Resources(c)
    }
    private func input(_ c: Sample) -> OriginalWindowInput.Message {
        .init(window: c.spec.window ?? 0x73000011,message: c.spec.message!,wParam: c.spec.wParam ?? 0,lParam: c.spec.lParam ?? 0)
    }
    func testWholeLifecycleOwnWindowsAndExactRequestStoreOrder() throws {
        let r = try resources(), first = r.corpus.cases[0]
        var globals = try r.record(first.before.globals), memory = try r.memory(first.before), objects = first.before.objects
        var callbacks = 0,initializations = 0,retained = 0,requests = 0,stores = 0
        for c in r.corpus.cases {
            if c.spec.retain == true {
                retained += 1
                for w in c.spec.stimulus ?? [] { try globals.write(UInt32(truncatingIfNeeded: w[1]),at: Int(w[0])-OriginalMatchPreparation.globalBase) }
            } else { globals = try r.record(c.before.globals);memory = try r.memory(c.before);objects = c.before.objects }
            try r.check(globals,memory,objects,c.before,"Case\(c.index) own before")
            var cursor = 0,frame = 0,counts: [String:Int] = [:]
            var masks = [[UInt8](repeating: 0,count: OriginalMatchPreparation.globalSize),[UInt8](repeating: 0,count: 8)]
            let store: OriginalWindowInput.Store = { address,bytes in
                guard cursor < c.actions.count else { throw OriginalStateError.invalidStorage("Extra lifecycle store") }
                let a = c.actions[cursor];XCTAssertEqual(a.kind,"store");XCTAssertEqual(address,a.address,"Case\(c.index) action\(cursor)");XCTAssertEqual(bytes,a.bytes,"Case\(c.index) action\(cursor)")
                cursor += 1;stores += 1
                let region = address >= 0x4588a8 ? 1 : 0, offset = address-(address >= 0x4588a8 ? 0x4588a8 : OriginalMatchPreparation.globalBase)
                guard offset >= 0,offset+bytes.count <= masks[region].count else { throw OriginalStateError.invalidStorage("Lifecycle store extent") }
                for i in offset..<offset+bytes.count { masks[region][i] = 1 }
            }
            let backing: (String,Int) throws -> [UInt8] = { kind,count in
                guard frame < c.backings.count else { throw OriginalStateError.invalidStorage("Extra lifecycle backing") }
                let b = c.backings[frame];frame += 1;XCTAssertEqual(kind,b.kind);XCTAssertEqual(count,b.bytes.count);return b.bytes
            }
            let perform: (OriginalWindowInitialization.Request) throws -> OriginalWindowInitialization.Response = { request in
                guard cursor < c.actions.count,let event = c.actions[cursor].event else { throw OriginalStateError.invalidStorage("Unexpected lifecycle request case\(c.index) action\(cursor) \(request.kind)") }
                XCTAssertEqual(c.actions[cursor].kind,"request");XCTAssertEqual(request,event.request,"Case\(c.index) action\(cursor)")
                cursor += 1;requests += 1;counts[request.kind,default: 0] += 1
                let key = request.kind+"#"+String(counts[request.kind]!);XCTAssertEqual(key,event.key)
                if let output = event.response.output {
                    XCTAssertFalse(objects.contains { $0.address == output })
                    objects.append(.init(address: output,family: request.kind == "directDrawCreate" ? "draw" : request.kind == "createClipper" ? "clipper" : "surface",releases: []))
                }
                if request.kind == "release" {
                    let index = try XCTUnwrap(objects.firstIndex { $0.address == request.words[0] })
                    objects[index].releases.append(.init(key: key,result: UInt32(bitPattern: event.response.result)))
                }
                return event.response
            }
            let result: Int32
            if c.spec.initialize == true {
                initializations += 1
                result = try OriginalWindowInitialization.initialize(instance: 0x400000,show: 10,globals: &globals,backing: backing,perform: perform,store: store).returnCode
            } else {
                callbacks += 1
                result = try OriginalWindowLifecycle.receive(input(c),globals: &globals,memory: &memory,backing: backing,perform: perform,store: store)
            }
            XCTAssertEqual(UInt32(bitPattern: result),c.result,"Case\(c.index) result")
            XCTAssertEqual(cursor,c.actions.count);XCTAssertEqual(frame,c.backings.count)
            for i in 0..<2 { XCTAssertEqual(masks[i],try r.blob(c.writeMasks[i]),"Case\(c.index) write mask\(i)") }
            try r.check(globals,memory,objects,c.after,"Case\(c.index) after")
        }
        XCTAssertEqual(callbacks,318);XCTAssertEqual(initializations,2);XCTAssertEqual(retained,18)
        print("WINDOW LIFECYCLE \(callbacks) whole callbacks \(initializations) initializations \(retained) own retained calls \(requests) requests \(stores) ordered stores")
    }
    func testLateRecreationAndMissingBackingRollBackWholeCallback() throws {
        enum Stop: Error { case late }
        let r = try resources(), c = try XCTUnwrap(r.corpus.cases.first { $0.spec.label == "recreate-ownership" && $0.spec.mode == 0 && $0.spec.resources == 7 })
        for missing in [false,true] {
            var globals = try r.record(c.before.globals),memory = try r.memory(c.before)
            let before = globals,oldMemory = memory
            var event = 0,frame = 0,releases = 0,shows = 0
            let events = c.actions.compactMap { $0.event }
            XCTAssertThrowsError(try OriginalWindowLifecycle.receive(input(c),globals: &globals,memory: &memory,backing: { kind,_ in
                if missing && kind == "surfaceDescription" { return [] }
                defer { frame += 1 };return c.backings[frame].bytes
            },perform: { request in
                let e = events[event];event += 1;XCTAssertEqual(request,e.request)
                if request.kind == "release" { releases += 1 }
                if request.kind == "showWindow" { shows += 1 }
                if request.kind == "windowDefault" { throw Stop.late }
                return e.response
            }))
            XCTAssertEqual(releases,3);XCTAssertEqual(shows,missing ? 0 : 1)
            XCTAssertEqual(globals,before);XCTAssertEqual(memory.replayPointers,oldMemory.replayPointers);XCTAssertEqual(memory.allocations,oldMemory.allocations)
        }
    }
    func testDestroyOwnershipAndLateQuitRollBack() throws {
        enum Stop: Error { case late }
        let r = try resources(), c = try XCTUnwrap(r.corpus.cases.first { $0.spec.label == "destroy-resources" && $0.spec.audio == true && $0.before.allocations.count == 2 })
        for missing in [false,true] {
            var globals = try r.record(c.before.globals),memory = try r.memory(c.before)
            if missing { memory.allocations.removeValue(forKey: c.before.allocations[1].address) }
            let before = globals,oldMemory = memory;var frees = 0,quit = 0
            XCTAssertThrowsError(try OriginalWindowLifecycle.receive(input(c),globals: &globals,memory: &memory,backing: { _,_ in XCTFail("Unexpected frame");return [] },perform: { request in
                if request.kind == "free" { frees += 1 }
                if request.kind == "postQuit" { quit += 1;throw Stop.late }
                return .init(result: -1)
            }))
            XCTAssertEqual(frees,missing ? 1 : 2);XCTAssertEqual(quit,missing ? 0 : 1)
            XCTAssertEqual(globals,before);XCTAssertEqual(memory.replayPointers,oldMemory.replayPointers);XCTAssertEqual(memory.allocations,oldMemory.allocations)
        }
    }
}
