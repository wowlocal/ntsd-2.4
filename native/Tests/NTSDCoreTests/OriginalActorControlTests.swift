import Foundation
import CryptoKit
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalActorControlTests: XCTestCase {
    private struct Patch: Decodable {
        let offset: Int, bytes: String
        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer(); offset = try c.decode(Int.self); bytes = try c.decode(String.self)
        }
    }
    private struct FramePatch: Decodable {
        let index: Int32, offset: Int, bytes: String
        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            index = try c.decode(Int32.self); offset = try c.decode(Int.self); bytes = try c.decode(String.self)
        }
    }
    private struct Event: Decodable, Equatable { let kind: String, arguments: [UInt32] }
    private struct Case: Decodable {
        let label: String, fill: String, after: String, defined: String, globalsSHA256: String
        let actor: [Patch], header: [Patch]?, frames: [FramePatch]?, globals: [Patch]?, events: [Event]
        let objectIndex: Int?
    }
    private struct Parent: Decodable { let fixture: String, sha256: String }
    private struct Binding: Decodable { let index: Int, id: Int32 }
    private struct Corpus: Decodable {
        let exeSHA256: String, header: [Patch], states: [String:Int32], cases: [Case]
        let parent: Parent?, bindings: [Binding]?
    }
    private func hex(_ text: String) throws -> [UInt8] {
        let bytes = Array(text.utf8)
        guard bytes.count%2 == 0 else { throw OriginalStateError.invalidStorage("Odd hex length") }
        return try stride(from: 0, to: bytes.count, by: 2).map {
            try XCTUnwrap(UInt8(String(decoding: bytes[$0..<$0+2], as: UTF8.self), radix: 16))
        }
    }
    private func patch(_ record: inout OriginalStateRecord,_ offset: Int,_ text: String) throws {
        for (i,byte) in try hex(text).enumerated() { try record.write(byte, at: offset+i) }
    }

    func testWholeOriginalControlOnRawActorAndGlobals() throws {
        let url: URL
        if let path = ProcessInfo.processInfo.environment["NTSD_ACTOR_CONTROL_CORPUS"] { url = URL(fileURLWithPath: path) }
        else { url = try XCTUnwrap(Bundle.module.url(forResource: "original-actor-control", withExtension: "json", subdirectory: "Fixtures")) }
        let raw = try MatchPreparationReference.unpack(Data(contentsOf: url), maximumCount: 256_000_000)
        let corpus = try JSONDecoder().decode(Corpus.self, from: raw)
        XCTAssertEqual(corpus.exeSHA256, "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        XCTAssertEqual(corpus.cases.count,25795)
        try compare(corpus)
    }

    func testControlWithAllOriginalTypeZeroObjects() throws {
        let url: URL
        if let path = ProcessInfo.processInfo.environment["NTSD_ACTOR_CATALOG_CORPUS"] { url = URL(fileURLWithPath: path) }
        else { url = try XCTUnwrap(Bundle.module.url(forResource: "original-actor-control-catalog", withExtension: "json", subdirectory: "Fixtures")) }
        let corpus = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(Data(contentsOf: url),maximumCount: 128_000_000))
        XCTAssertEqual(corpus.exeSHA256,"3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        XCTAssertEqual(corpus.cases.count,5376)
        let parent = try XCTUnwrap(corpus.parent), bindings = try XCTUnwrap(corpus.bindings)
        XCTAssertEqual(bindings.count,42)
        let fixtureURL = try XCTUnwrap(Bundle.module.url(forResource: parent.fixture,withExtension: nil,subdirectory: "Fixtures"))
        let parentData = try Data(contentsOf: fixtureURL)
        XCTAssertEqual(SHA256.hash(data: parentData).map { String(format:"%02x",$0) }.joined(),parent.sha256)
        let result = try LoadedCatalogReference.compare(parentData,onLoaded: { catalog in
            for binding in bindings {
                let object = catalog.objects[binding.index]
                XCTAssertEqual(try object.header.integer(at: 0x6f4,as: Int32.self),binding.id)
                XCTAssertEqual(try object.header.integer(at: 0x6f8,as: Int32.self),0)
            }
            try self.compare(corpus,objects: catalog.objects)
        })
        XCTAssertEqual(result.objects,137)
    }

    func testFailedAttackAfterRandomDrawRollsBackActorAndGlobals() throws {
        var actor = try OriginalStateRecord.actor(over: [UInt8](repeating: 0xa5,count: OriginalStateRecord.actorSize))
        try actor.write(UInt8(1),at: 0xd1)
        let header = try OriginalStateRecord(bytes: [UInt8](repeating: 0,count: 0x7a4),defined: [Bool](repeating: true,count: 0x7a4))
        var globals = try OriginalStateRecord(bytes: [UInt8](repeating: 0,count: OriginalMatchPreparation.globalSize),defined: [Bool](repeating: true,count: OriginalMatchPreparation.globalSize))
        let base = OriginalMatchPreparation.globalBase
        for i in 0..<3000 { try globals.write(UInt8(1+i%255),at: 0x44ff90-base+i) }
        try globals.write(Int32(1),at: 0x44d034-base)
        let beforeActor = actor,beforeGlobals = globals
        let current = try OriginalStateRecord(bytes: [UInt8](repeating: 0,count: 0x178),defined: [Bool](repeating: true,count: 0x178))
        var drew = false
        XCTAssertThrowsError(try OriginalActorControl.apply(actor: &actor,header: header,globals: &globals,frame: { index in
            guard index == 0 else { throw OriginalStateError.invalidStorage("Missing selected attack frame") }
            return current
        },observe: { event in
            if case .random = event { drew = true }
        }))
        XCTAssertTrue(drew)
        XCTAssertEqual(actor,beforeActor); XCTAssertEqual(globals,beforeGlobals)
    }

    private func compare(_ corpus: Corpus,objects: [OriginalLoadedObject]? = nil) throws {
        let templates = try ["a5","ramp"].reduce(into: [String:OriginalStateRecord]()) { result,fill in
            result[fill] = try .actor(over: (0..<OriginalStateRecord.actorSize).map { fill == "a5" ? 0xa5 : UInt8(truncatingIfNeeded: $0) })
        }
        var headerBase = try OriginalStateRecord(bytes: [UInt8](repeating: 0,count: 0x7a4),defined: [Bool](repeating: true,count: 0x7a4))
        for p in corpus.header { try patch(&headerBase,p.offset,p.bytes) }
        var emptyFrame = try OriginalStateRecord(bytes: [UInt8](repeating: 0,count: 0x178),defined: [Bool](repeating: true,count: 0x178))
        try emptyFrame.write(UInt8(1),at: 0); try emptyFrame.write(Int32(3),at: 8)
        var frameBase: [Int32:OriginalStateRecord] = [:]
        for (key,state) in corpus.states { var record = emptyFrame; try record.write(state,at: 8); frameBase[try XCTUnwrap(Int32(key))] = record }
        for index: Int32 in [60,65,80,85,90] { var record = frameBase[index] ?? emptyFrame; try record.write(Int32(100),at: 0x4c); frameBase[index] = record }
        let base = OriginalMatchPreparation.globalBase
        var globalBase = try OriginalStateRecord(bytes: [UInt8](repeating: 0,count: OriginalMatchPreparation.globalSize),defined: [Bool](repeating: true,count: OriginalMatchPreparation.globalSize))
        try globalBase.write(Int32(1),at: 0x44d034-base)
        for i in 0..<3000 { try globalBase.write(UInt8(1+i%255),at: 0x44ff90-base+i) }
        for item in corpus.cases {
            let object = try item.objectIndex.map { index -> OriginalLoadedObject in
                let loaded = try XCTUnwrap(objects)
                guard loaded.indices.contains(index) else { throw OriginalStateError.invalidStorage("Original Object binding") }
                return loaded[index]
            }
            var actor = try XCTUnwrap(templates[item.fill]), header = object?.header ?? headerBase, globals = globalBase, frames = frameBase
            for p in item.actor { try patch(&actor,p.offset,p.bytes) }
            for p in item.header ?? [] { try patch(&header,p.offset,p.bytes) }
            for p in item.globals ?? [] { try patch(&globals,p.offset-base,p.bytes) }
            for p in item.frames ?? [] {
                var record = frames[p.index] ?? emptyFrame; try patch(&record,p.offset,p.bytes); frames[p.index] = record
            }
            var events: [Event] = []
            do {
                try OriginalActorControl.apply(actor: &actor,header: header,globals: &globals,frame: { index in
                    guard (0..<400).contains(index) else { throw OriginalStateError.invalidStorage("Probe frame index \(index)") }
                    if let object { return object.frameStorage[Int(index)] }
                    return frames[index] ?? emptyFrame
                },observe: { event in
                    switch event {
                    case let .random(stream,range,result): events.append(.init(kind: "random",arguments: [stream,range,result].map(UInt32.init(bitPattern:))))
                    case let .sound(x,index): events.append(.init(kind: "sound",arguments: [x,index].map(UInt32.init(bitPattern:))))
                    }
                })
            } catch { XCTFail("\(item.label): \(error)"); return }
            let expected = try hex(item.after), mask = try hex(item.defined).map { $0 != 0 }
            guard actor.bytes == expected && actor.defined == mask else {
                let offset = try XCTUnwrap(actor.bytes.indices.first { actor.bytes[$0] != expected[$0] || actor.defined[$0] != mask[$0] })
                XCTFail("\(item.label): byte/mask +\(String(offset,radix:16)): \(actor.bytes[offset])/\(actor.defined[offset]) != \(expected[offset])/\(mask[offset])")
                return
            }
            let sha = SHA256.hash(data: Data(globals.bytes)).map { String(format:"%02x",$0) }.joined()
            guard sha == item.globalsSHA256 && globals.defined.allSatisfy({ $0 }) && events == item.events else {
                XCTFail("\(item.label): global SHA \(sha) != \(item.globalsSHA256) or events \(events) != \(item.events)"); return
            }
        }
    }
}
