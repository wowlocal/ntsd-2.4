import Foundation
import CryptoKit
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalLibActorControlTests: XCTestCase {
    private struct Patch: Decodable {
        let offset: Int, bytes: String
        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer();offset = try c.decode(Int.self);bytes = try c.decode(String.self)
        }
    }
    private struct FramePatch: Decodable {
        let index: Int, offset: Int, bytes: String
        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer();index = try c.decode(Int.self);offset = try c.decode(Int.self);bytes = try c.decode(String.self)
        }
    }
    private struct Event: Decodable, Equatable { let kind: String, arguments: [UInt32] }
    private struct Case: Decodable {
        let label: String,fill: String,after: String,defined: String,globalsSHA256: String
        let actor: [Patch],header: [Patch]?,frames: [FramePatch]?,globals: [Patch]?,events: [Event]
        let fpcw: UInt16
    }
    private struct Corpus: Decodable {
        let exeSHA256: String,libSHA256: String,header: [Patch],states: [String:Int32],cases: [Case]
    }
    private func bytes(_ text: String) throws -> [UInt8] {
        let utf8 = Array(text.utf8)
        guard utf8.count%2 == 0 else { throw OriginalStateError.invalidStorage("Odd hexadecimal") }
        return try stride(from: 0,to: utf8.count,by: 2).map {
            try XCTUnwrap(UInt8(String(decoding: utf8[$0..<$0+2],as: UTF8.self),radix: 16))
        }
    }
    private func zero(_ size: Int) throws -> OriginalStateRecord {
        try .init(bytes: Array(repeating: 0,count: size),defined: Array(repeating: true,count: size))
    }
    private func patch(_ record: inout OriginalStateRecord,_ offset: Int,_ value: String) throws {
        for (n,byte) in try bytes(value).enumerated() { try record.write(byte,at: offset+n) }
    }
    private func globals() throws -> OriginalStateRecord {
        var result = try zero(OriginalMatchPreparation.globalSize)
        let base = OriginalMatchPreparation.globalBase
        try result.write(Int32(1),at: 0x44d034-base)
        for i in 0..<3000 { try result.write(UInt8(1+i%255),at: 0x44ff90-base+i) }
        return result
    }

    func testWholeControlWithInstalledLibrary() throws {
        let url: URL
        if let path = ProcessInfo.processInfo.environment["NTSD_LIB_ACTOR_CONTROL_CORPUS"] { url = URL(fileURLWithPath: path) }
        else { url = try XCTUnwrap(Bundle.module.url(forResource: "original-lib-actor-control",withExtension: "json",subdirectory: "Fixtures")) }
        let c = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(Data(contentsOf: url),maximumCount: 256_000_000))
        XCTAssertEqual(c.exeSHA256,"3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        XCTAssertEqual(c.libSHA256,"28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba")
        XCTAssertEqual(c.cases.count,7168)
        var header = try zero(0x7a4)
        for p in c.header { try patch(&header,p.offset,p.bytes) }
        let frames = try (0..<400).map { n -> OriginalStateRecord in
            var r = try zero(0x178);try r.write(UInt8(1),at: 0);try r.write(c.states[String(n)] ?? Int32(3),at: 8)
            if [60,65,80,85,90].contains(n) { try r.write(Int32(100),at: 0x4c) }
            return r
        }
        let initialGlobals = try globals(),tail = try zero(0x3c)
        var templates: [String:OriginalStateRecord] = [:]
        for fill in ["a5","ramp"] {
            templates[fill] = try .actor(over: (0..<OriginalStateRecord.actorSize).map { fill == "a5" ? 0xa5 : UInt8(truncatingIfNeeded: $0) })
        }
        var eventsCompared = 0
        for item in c.cases {
            var actor = try XCTUnwrap(templates[item.fill]),owned = initialGlobals,ownHeader = header,ownFrames = frames
            for p in item.actor { try patch(&actor,p.offset,p.bytes) }
            for p in item.header ?? [] { try patch(&ownHeader,p.offset,p.bytes) }
            for p in item.globals ?? [] { try patch(&owned,p.offset-OriginalMatchPreparation.globalBase,p.bytes) }
            for p in item.frames ?? [] { try patch(&ownFrames[p.index],p.offset,p.bytes) }
            let object = OriginalLoadedObject(header: ownHeader,nameTail: tail,frames: [],frameStorage: ownFrames,weaponSoundPaths: [:])
            var events: [Event] = []
            do {
                try OriginalLibActorControl.apply(actor: &actor,object: object,globals: &owned,phase: 1,mode: 0,
                    precision: OriginalArithmeticPrecision(controlWord: item.fpcw),observe: { event in
                        switch event {
                        case let .random(stream,range,result):events.append(.init(kind: "random",arguments: [stream,range,result].map(UInt32.init(bitPattern:))))
                        case let .sound(x,index):events.append(.init(kind: "sound",arguments: [x,index].map(UInt32.init(bitPattern:))))
                        }
                    })
                let expected = try bytes(item.after),mask = try bytes(item.defined).map { $0 != 0 }
                guard actor.bytes == expected && actor.defined == mask else {
                    let offset = try XCTUnwrap(actor.bytes.indices.first { actor.bytes[$0] != expected[$0] || actor.defined[$0] != mask[$0] })
                    XCTFail("\(item.label): Actor byte/mask +\(String(offset,radix: 16))");return
                }
                let sha = SHA256.hash(data: Data(owned.bytes)).map { String(format: "%02x",$0) }.joined()
                guard sha == item.globalsSHA256 && owned.defined.allSatisfy({ $0 }) && events == item.events else {
                    XCTFail("\(item.label): globals or ordered events");return
                }
            } catch { XCTFail("\(item.label): \(error)");return }
            eventsCompared += events.count
        }
        print("LIB ACTOR CONTROL",c.cases.count,"whole calls;",eventsCompared,"ordered events; full Actor bytes/masks and globals matched")
    }

    func testMissingFrameAfterLibraryTransitionRollsBackWholeCall() throws {
        var actor = try OriginalStateRecord.actor(over: Array(repeating: 0xa5,count: OriginalStateRecord.actorSize))
        try actor.write(Int32(41),at: 0x70);try actor.write(UInt8(1),at: 0x80)
        try actor.write(UInt8(1),at: 0xd0);try actor.write(UInt8(0),at: 0xcf);try actor.writeBinary64(1,at: 0x40)
        var owned = try globals(),frames = Array(repeating: try zero(0x178),count: 42)
        try frames[41].write(Int32(85),at: 8)
        let object = try OriginalLoadedObject(header: zero(0x7a4),nameTail: zero(0x3c),frames: [],frameStorage: frames,weaponSoundPaths: [:])
        let before = actor,globalsBefore = owned
        XCTAssertThrowsError(try OriginalLibActorControl.apply(actor: &actor,object: object,globals: &owned,phase: 1,mode: 0)) { error in
            guard case let OriginalStateError.invalidStorage(message) = error else { return XCTFail("Unexpected \(error)") }
            XCTAssertEqual(message,"Library Actor control frame outside Object: 42")
        }
        XCTAssertEqual(actor,before);XCTAssertEqual(owned,globalsBefore)
    }
}
