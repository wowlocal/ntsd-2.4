import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalWorldImpulsesTests: XCTestCase {
    private struct Patch: Decodable {
        let offset: Int,bytes: String
        init(from decoder: Decoder) throws { var c = try decoder.unkeyedContainer();offset = try c.decode(Int.self);bytes = try c.decode(String.self) }
    }
    private struct Actor: Decodable {
        let index: Int,patches: [Patch]
        init(from decoder: Decoder) throws { var c = try decoder.unkeyedContainer();index = try c.decode(Int.self);patches = try c.decode([Patch].self) }
    }
    private struct Write: Decodable,Equatable { let slot: Int,actor: Int,offset: Int,bytes: String }
    private struct Case: Decodable {
        let label: String,fill: String,poolSHA256: String,maskSHA256: String,globalsSHA256: String
        let actors: [Actor]?,active: [[Int]]?,aliases: [[Int]]?,events: [Write]
    }
    private struct Formats: Decodable {
        struct Case: Decodable { let inputs: [UInt8],bytes: [UInt8],result: Int }
        let dllSHA256: String,format: [UInt8],cases: [Case]
    }
    private struct Corpus: Decodable { let exeSHA256: String,cases: [Case],fpcw: Int,instructions: [UInt32],formats: Formats }
    private func patch(_ record: inout OriginalStateRecord,_ p: Patch) throws {
        let bytes = Array(p.bytes.utf8)
        for i in stride(from: 0,to: bytes.count,by: 2) { try record.write(XCTUnwrap(UInt8(String(decoding: bytes[i..<i+2],as: UTF8.self),radix: 16)),at: p.offset+i/2) }
    }
    func testWholePoolAndSignedDiagnosticBytes() throws {
        let url: URL
        if let path = ProcessInfo.processInfo.environment["NTSD_WORLD_IMPULSES_CORPUS"] { url = URL(fileURLWithPath: path) }
        else { url = try XCTUnwrap(Bundle.module.url(forResource: "original-world-impulses",withExtension: "json",subdirectory: "Fixtures")) }
        let c = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(Data(contentsOf: url),maximumCount: 16_000_000))
        XCTAssertEqual(c.exeSHA256,"3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        XCTAssertEqual(c.fpcw,0x37f);XCTAssertEqual(c.cases.count,1030);XCTAssertEqual(c.instructions.count,58)
        var globals = try OriginalStateRecord(bytes: [UInt8](repeating: 0,count: 0xb440),defined: [Bool](repeating: true,count: 0xb440))
        try globals.write(Int32(1),at: 0x44d034-0x44d000)
        for i in 0..<3000 { try globals.write(UInt8(1+i%255),at: 0x44ff90-0x44d000+i) }
        let globalsSHA = MatchPreparationReference.digest(Data(globals.bytes))
        var writes = 0
        for item in c.cases {
            let template = try OriginalStateRecord.actor(over: (0..<0x420).map { item.fill == "a5" ? 0xa5 : UInt8(truncatingIfNeeded: $0) })
            var actors = [OriginalStateRecord](repeating: template,count: 400)
            var world = try OriginalStateRecord.worldPrefix(over: (0..<0x7d8).map { item.fill == "a5" ? 0xa5 : UInt8(truncatingIfNeeded: $0) })
            let aliases = Dictionary(uniqueKeysWithValues: (item.aliases ?? []).map { ($0[0],$0[1]) })
            let active = Dictionary(uniqueKeysWithValues: (item.active ?? []).map { ($0[0],$0[1]) })
            for i in 0..<400 {
                try world.write(UInt32(aliases[i] ?? i),at: 0x194+i*4);try world.write(UInt8(active[i] ?? 0),at: 4+i);try actors[i].write(UInt32(0),at: 0x368)
            };try world.write(UInt32(0),at: 0x7d4)
            for a in item.actors ?? [] { for p in a.patches { try patch(&actors[a.index],p) } }
            var seen: [Write] = []
            try OriginalWorldImpulses.apply(world: world,actors: &actors,observe: { w in
                let bytes = (0..<w.size).map { String(format: "%02x",UInt8(truncatingIfNeeded: w.value >> (8*$0))) }.joined()
                seen.append(.init(slot: w.slot,actor: w.actor,offset: w.offset,bytes: bytes))
            })
            XCTAssertEqual(seen,item.events,item.label+" writes");writes += seen.count
            let records = [world]+actors
            XCTAssertEqual(MatchPreparationReference.digest(Data(records.flatMap(\.bytes))),item.poolSHA256,item.label+" pool")
            XCTAssertEqual(MatchPreparationReference.digest(Data(records.flatMap { $0.defined.map { $0 ? UInt8(1) : UInt8(0) } })),item.maskSHA256,item.label+" masks")
            XCTAssertEqual(globalsSHA,item.globalsSHA256,item.label+" globals")
        }
        XCTAssertEqual(c.formats.dllSHA256,"c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d")
        XCTAssertEqual(c.formats.format,OriginalPostDrawImpulses.format);XCTAssertEqual(c.formats.cases.count,256)
        var world = try OriginalStateRecord.worldPrefix(over: [UInt8](repeating: 0xa5,count: 0x7d8))
        try world.write(UInt32(399),at: 0x1bc) // Inactive, aliased diagnostic slot10.
        var actors = [OriginalStateRecord](repeating: try .actor(over: [UInt8](repeating: 0xa5,count: 0x420)),count: 400)
        for item in c.formats.cases {
            for (offset,value) in zip([0xc4,0xc5,0xc3,0xc2,0xbe,0xc0],item.inputs) { try actors[399].write(value,at: offset) }
            let text = try OriginalPostDrawImpulses.inputText(world: world,actors: actors)
            XCTAssertEqual(text,item.bytes);XCTAssertEqual(text.count,item.result)
        }
        print("WORLD IMPULSES",c.cases.count,"whole pools",writes,"ordered writes",c.formats.cases.count,"CRT formats")
    }
    func testFailureAfterVelocityWritesRollsBackPool() throws {
        let bootstrap = try OriginalWorldBootstrap(worldBacking: [UInt8](repeating: 0xa5,count: 0x7d8),actorBacking: [[UInt8]](repeating: [UInt8](repeating: 0xa5,count: 0x420),count: 400),selector: 2)
        var world = bootstrap.world,actors = bootstrap.actors
        try world.write(UInt8(1),at: 4);try actors[0].write(Int32(2),at: 0x20)
        for offset in [0x28,0x30,0x38] { try actors[0].writeBinary64(12.5,at: offset) }
        let before = actors;var writes: [Int] = []
        XCTAssertThrowsError(try OriginalWorldImpulses.apply(world: world,actors: &actors,observe: { w in
            writes.append(w.offset)
            if w.offset == 0x20 { throw OriginalStateError.invalidStorage("Injected stop after three velocity stores") }
        }))
        XCTAssertEqual(writes,[0x40,0x48,0x50,0x20]);XCTAssertEqual(actors,before)
    }
}
