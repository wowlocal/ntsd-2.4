import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalActorPhysicsTests: XCTestCase {
    private struct Patch: Decodable {
        let offset: Int,bytes: String
        init(from decoder: Decoder) throws { var c = try decoder.unkeyedContainer();offset = try c.decode(Int.self);bytes = try c.decode(String.self) }
    }
    private struct Frame: Decodable {
        let index: Int,offset: Int,bytes: String
        init(from decoder: Decoder) throws { var c = try decoder.unkeyedContainer();index = try c.decode(Int.self);offset = try c.decode(Int.self);bytes = try c.decode(String.self) }
    }
    private struct Event: Decodable,Equatable { let kind: String,arguments: [UInt32] }
    private struct Case: Decodable {
        let label: String,fill: String,after: String,defined: String,globalsSHA256: String
        let actor: [Patch],header: [Patch]?,frames: [Frame]?,globals: [Patch]?,events: [Event],sse2: Int?,objectIndex: Int?
    }
    private struct Parent: Decodable { let fixture: String,sha256: String }
    private struct Corpus: Decodable { let exeSHA256: String,fpcw: Int,header: [Patch],states: [String:Int32],cases: [Case],parent: Parent? }
    private func hex(_ value: String) throws -> [UInt8] {
        let bytes = Array(value.utf8)
        return try stride(from: 0,to: bytes.count,by: 2).map { try XCTUnwrap(UInt8(String(decoding: bytes[$0..<$0+2],as: UTF8.self),radix: 16)) }
    }
    private func patch(_ record: inout OriginalStateRecord,_ offset: Int,_ value: String) throws {
        for (i,byte) in try hex(value).enumerated() { try record.write(byte,at: offset+i) }
    }
    func testWholePhysics() throws {
        let url: URL
        if let path = ProcessInfo.processInfo.environment["NTSD_ACTOR_PHYSICS_CORPUS"] { url = URL(fileURLWithPath: path) }
        else { url = try XCTUnwrap(Bundle.module.url(forResource: "original-actor-physics",withExtension: "json",subdirectory: "Fixtures")) }
        let c = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(Data(contentsOf: url),maximumCount: 256_000_000))
        XCTAssertEqual(c.exeSHA256,"3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c");XCTAssertEqual(c.fpcw,0x37f)
        XCTAssertEqual(c.cases.count,9344)
        try compare(c)
    }
    func testPhysicsOnCompleteCatalog() throws {
        let url: URL
        if let path = ProcessInfo.processInfo.environment["NTSD_PHYSICS_CATALOG_CORPUS"] { url = URL(fileURLWithPath: path) }
        else { url = try XCTUnwrap(Bundle.module.url(forResource: "original-actor-physics-catalog",withExtension: "json",subdirectory: "Fixtures")) }
        let c = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(Data(contentsOf: url),maximumCount: 256_000_000))
        XCTAssertEqual(c.exeSHA256,"3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c");XCTAssertEqual(c.fpcw,0x37f)
        let parent = try XCTUnwrap(c.parent),p = try XCTUnwrap(Bundle.module.url(forResource: parent.fixture,withExtension: nil,subdirectory: "Fixtures"))
        XCTAssertEqual(c.cases.count,46089);XCTAssertEqual(Set(c.cases.compactMap(\.objectIndex)).count,137)
        let data = try Data(contentsOf: p);XCTAssertEqual(MatchPreparationReference.digest(data),parent.sha256)
        let result = try LoadedCatalogReference.compare(data,onLoaded: { catalog in try self.compare(c,objects: catalog.objects) })
        XCTAssertEqual(result.objects,137)
    }
    private func compare(_ c: Corpus,objects: [OriginalLoadedObject]? = nil) throws {
        func defined(_ size: Int) throws -> OriginalStateRecord { try .init(bytes: [UInt8](repeating: 0,count: size),defined: [Bool](repeating: true,count: size)) }
        var headerBase = try defined(0x7a4)
        for p in c.header { try patch(&headerBase,p.offset,p.bytes) }
        let frames = try (0..<400).map { n -> OriginalStateRecord in
            var f = try defined(0x178);try f.write(UInt8(1),at: 0);try f.write(c.states[String(n)] ?? 3,at: 8)
            if [60,65,80,85,90].contains(n) { try f.write(Int32(100),at: 0x4c) };return f
        }
        var globalBase = try defined(0xb440)
        try globalBase.write(Int32(1),at: 0x44d034-0x44d000)
        for i in 0..<3000 { try globalBase.write(UInt8(1+i%255),at: 0x44ff90-0x44d000+i) }
        let templates = try ["a5","ramp"].reduce(into: [String:OriginalStateRecord]()) { result,fill in
            result[fill] = try .actor(over: (0..<0x420).map { fill == "a5" ? 0xa5 : UInt8(truncatingIfNeeded: $0) })
        }
        for item in c.cases {
            var actor = try XCTUnwrap(templates[item.fill]),header = headerBase,ownFrames = frames,globals = globalBase,events: [Event] = []
            for p in item.actor { try patch(&actor,p.offset,p.bytes) }
            for p in item.header ?? [] { try patch(&header,p.offset,p.bytes) }
            for p in item.frames ?? [] { try patch(&ownFrames[p.index],p.offset,p.bytes) }
            for p in item.globals ?? [] { try patch(&globals,p.offset-0x44d000,p.bytes) }
            func observe(_ event: OriginalActorPhysicsEvent) {
                switch event {
                case let .builtinSound(x,index):events.append(.init(kind: "builtinSound",arguments: [x,index].map(UInt32.init(bitPattern:))))
                case let .catalogSound(x,index):events.append(.init(kind: "catalogSound",arguments: [x,index].map(UInt32.init(bitPattern:))))
                }
            }
            if let index = item.objectIndex {
                let loaded = try XCTUnwrap(objects);XCTAssertTrue(item.header?.isEmpty != false && item.frames?.isEmpty != false)
                try OriginalActorPhysics.apply(actor: &actor,object: loaded[index],globals: &globals,sse2Conversion: item.sse2 == 1,observe: observe)
            } else {
                try OriginalActorPhysics.apply(actor: &actor,header: header,globals: &globals,sse2Conversion: item.sse2 == 1,frame: { ownFrames[Int($0)] },observe: observe)
            }
            let expected = try hex(item.after),mask = try hex(item.defined).map { $0 != 0 }
            if actor.bytes != expected || actor.defined != mask {
                let offsets = actor.bytes.indices.filter { actor.bytes[$0] != expected[$0] || actor.defined[$0] != mask[$0] }
                XCTFail(item.label+" differs at "+offsets.prefix(24).map { String($0,radix: 16)+":\(actor.bytes[$0])/\(expected[$0])" }.joined(separator: ","));return
            }
            XCTAssertEqual(MatchPreparationReference.digest(Data(globals.bytes)),item.globalsSHA256,item.label+" globals")
            XCTAssertTrue(globals.defined.allSatisfy { $0 });XCTAssertEqual(events,item.events,item.label+" events")
        }
        print("ACTOR PHYSICS",c.cases.count,"whole raw Actors compared")
    }
}
