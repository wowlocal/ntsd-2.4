import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalApplicationRecoveryTests: XCTestCase {
    typealias Legacy = OriginalWindowLifecycleTests
    struct Extra: Decodable { let completed: Bool, error: String? }
    struct Metadata: Decodable { let initialGlobals: String, cases: [Extra] }
    struct Context: Equatable { var objects: [Legacy.Object]; var requests: [String] = [] }
    struct Resources {
        let legacy: Legacy.Resources, metadata: Metadata
        init() throws {
            let url: URL
            if let p = ProcessInfo.processInfo.environment["NTSD_APPLICATION_RECOVERY"] { url = URL(fileURLWithPath: p) }
            else { url = try XCTUnwrap(Bundle.module.url(forResource: "original-application-recovery.json",withExtension: nil,subdirectory: "Fixtures")) }
            let data = try MatchPreparationReference.unpack(Data(contentsOf: url),maximumCount: 32_000_000)
            legacy = Legacy.Resources(try JSONDecoder().decode(Legacy.Corpus.self,from: data))
            metadata = try JSONDecoder().decode(Metadata.self,from: data)
            XCTAssertEqual(legacy.corpus.exeSHA256,"3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
            XCTAssertEqual(legacy.corpus.libSHA256,"28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba")
            XCTAssertFalse(legacy.corpus.limited);XCTAssertEqual(legacy.corpus.cases.count,322)
        }
        func initial(_ c: Legacy.Sample) throws -> (OriginalStateRecord,Context) {
            var globals = try legacy.record(metadata.initialGlobals), objects: [Legacy.Object] = []
            // Independently verified PE loader template plus declared controls.
            for (a,v): (Int,UInt32) in [(0x458430,UInt32(bitPattern: c.spec.mode ?? 0)),(0x458434,0),(0x44d794,1),(0x4554c0,0x400000),(0x44d78c,794),(0x44d790,550),(0x4546f4,0x73000011),(0x455634,0),(0x455608,0),(0x457578,0)] {
                try globals.write(v,at: a-0x44d000)
            }
            let resources = c.spec.resources ?? (c.spec.initialize == true ? 0 : 7)
            for (bit,address,family) in [(1,0x457578,"draw"),(2,0x455608,"surface"),(4,0x455634,"surface")] where resources & bit != 0 {
                let pointer = UInt32(0x31000000+0x1000*(objects.count+1))
                objects.append(.init(address: pointer,family: family,releases: []));try globals.write(pointer,at: address-0x44d000)
            }
            return (globals,.init(objects: objects))
        }
    }
    func apply(_ e: Legacy.Event,_ request: OriginalWindowInitialization.Request,_ context: inout Context) throws -> OriginalWindowInitialization.Response {
        XCTAssertEqual(request,e.request);context.requests.append(e.key)
        if let output = e.response.output {
            XCTAssertFalse(context.objects.contains { $0.address == output })
            context.objects.append(.init(address: output,family: request.kind == "directDrawCreate" ? "draw" : request.kind == "createClipper" ? "clipper" : "surface",releases: []))
        }
        if request.kind == "release" {
            let i = try XCTUnwrap(context.objects.firstIndex { $0.address == request.words[0] })
            context.objects[i].releases.append(.init(key: e.key,result: UInt32(bitPattern: e.response.result)))
        }
        return e.response
    }
    func testWholeRecoveryAndOwnRecreatedSurfaces() throws {
        let r = try Resources(), legacy = r.legacy
        var globals = try legacy.record(r.metadata.initialGlobals),context = Context(objects: [])
        var recovered = 0, initialized = 0, rejected = 0, requests = 0
        for (i,c) in legacy.corpus.cases.enumerated() {
            if c.spec.retain != true { (globals,context) = try r.initial(c) }
            XCTAssertEqual(globals,try legacy.record(c.before.globals));XCTAssertEqual(context.objects,c.before.objects)
            let previous = globals, oldContext = context
            var cursor = 0,frame = 0,mask = [UInt8](repeating: 0,count: 0xb440)
            let store: OriginalWindowInput.Store = { address,bytes in
                let a = c.actions[cursor];cursor += 1;XCTAssertEqual(a.kind,"store");XCTAssertEqual(a.address,address);XCTAssertEqual(a.bytes,bytes)
                for j in address-0x44d000..<address-0x44d000+bytes.count { mask[j] = 1 }
            }
            let backing: (String,Int) throws -> [UInt8] = { kind,count in
                let b = c.backings[frame];frame += 1;XCTAssertEqual(kind,b.kind);XCTAssertEqual(count,b.bytes.count);return b.bytes
            }
            let perform: (OriginalWindowInitialization.Request,inout Context) throws -> OriginalWindowInitialization.Response = { request,owned in
                let a = c.actions[cursor];cursor += 1;XCTAssertEqual(a.kind,"request");requests += 1
                return try self.apply(XCTUnwrap(a.event),request,&owned)
            }
            let value: Int32
            if c.spec.initialize == true {
                initialized += 1
                value = try OriginalWindowInitialization.initialize(instance: 0x400000,show: 10,globals: &globals,backing: backing,
                    perform: { try perform($0,&context) },store: store).returnCode
            } else if r.metadata.cases[i].completed {
                recovered += 1
                value = try OriginalApplicationRecovery.recover(globals: &globals,context: &context,backing: backing,perform: perform,store: store)
            } else {
                rejected += 1;XCTAssertNotNil(r.metadata.cases[i].error)
                XCTAssertThrowsError(try OriginalApplicationRecovery.recover(globals: &globals,context: &context,backing: backing,perform: perform,store: store)) { error in
                    guard case OriginalStateError.invalidStorage(let detail) = error else { return XCTFail("Unexpected error \(error)") }
                    XCTAssertEqual(detail,"Application recovery has no back surface at43e876")
                }
                XCTAssertEqual(globals,previous);XCTAssertEqual(context,oldContext);XCTAssertEqual(cursor,c.actions.count);continue
            }
            XCTAssertEqual(UInt32(bitPattern: value),c.result,"case\(i)")
            XCTAssertEqual(cursor,c.actions.count);XCTAssertEqual(frame,c.backings.count)
            XCTAssertEqual(mask,try legacy.blob(c.writeMasks[0]));XCTAssertEqual(try legacy.blob(c.writeMasks[1]),[UInt8](repeating: 0,count: 8))
            XCTAssertEqual(globals,try legacy.record(c.after.globals));XCTAssertEqual(context.objects,c.after.objects)
            XCTAssertEqual(c.before.pointers,c.after.pointers);XCTAssertTrue(c.before.allocations.isEmpty);XCTAssertTrue(c.after.allocations.isEmpty)
        }
        XCTAssertEqual(recovered,318);XCTAssertEqual(initialized,3);XCTAssertEqual(rejected,1)
        print("APPLICATION RECOVERY \(recovered) whole returns,\(initialized) own initializers,\(rejected) explicit source-fault rejection,\(requests) requests")
    }
    enum Trial: Error { case late }
    func testLateFailureRollsBackGlobalsAndOwnedDisplayObjects() throws {
        let r = try Resources(),c = try XCTUnwrap(r.legacy.corpus.cases.first { $0.spec.label == "recreation-api-errors" && $0.spec.mode == 0 })
        let events = c.actions.compactMap { $0.event },lastShow = try XCTUnwrap(events.last { $0.request.kind == "showWindow" }).key
        for stage in 0..<6 {
            var (globals,context) = try r.initial(c);let before = globals,old = context
            var n = 0,frame = 0
            XCTAssertThrowsError(try OriginalApplicationRecovery.recover(globals: &globals,context: &context,backing: { kind,_ in
                if stage == 4 && kind == "surfaceDescription" { return [] }
                defer { frame += 1 };return c.backings[frame].bytes
            },perform: { request,owned in
                let e = events[n];n += 1;let response = try self.apply(e,request,&owned)
                if stage == 0 && e.key == "release#2" || stage == 1 && e.key == "createSurface#2" || stage == 2 && e.key == lastShow { throw Trial.late }
                return response
            },store: { address,bytes in
                if stage == 3 && address == 0x458434 && bytes == [0,0,0,0] { throw Trial.late }
            },beforeCommit: { _,_,_ in if stage == 5 { throw Trial.late } }))
            XCTAssertEqual(globals,before);XCTAssertEqual(context,old)
        }
    }
}
