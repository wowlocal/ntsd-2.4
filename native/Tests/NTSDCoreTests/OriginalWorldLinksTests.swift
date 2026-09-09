import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalWorldLinksTests: XCTestCase {
    private struct Patch: Decodable {
        let offset: Int,bytes: String
        init(from decoder: Decoder) throws { var c = try decoder.unkeyedContainer();offset = try c.decode(Int.self);bytes = try c.decode(String.self) }
    }
    private struct Actor: Decodable {
        let index: Int,patches: [Patch]
        init(from decoder: Decoder) throws { var c = try decoder.unkeyedContainer();index = try c.decode(Int.self);patches = try c.decode([Patch].self) }
    }
    private struct Frame: Decodable {
        let object: Int,index: Int,offset: Int,bytes: String
        init(from decoder: Decoder) throws { var c = try decoder.unkeyedContainer();object = try c.decode(Int.self);index = try c.decode(Int.self);offset = try c.decode(Int.self);bytes = try c.decode(String.self) }
    }
    private struct Header: Decodable {
        let object: Int,offset: Int,bytes: String
        init(from decoder: Decoder) throws { var c = try decoder.unkeyedContainer();object = try c.decode(Int.self);offset = try c.decode(Int.self);bytes = try c.decode(String.self) }
    }
    private struct Event: Decodable,Equatable { let slot: Int,kind: String,arguments: [UInt32] }
    private struct Case: Decodable {
        let label: String,fill: String,poolSHA256: String,maskSHA256: String,globalsSHA256: String
        let actors: [Actor]?,active: [[Int]]?,aliases: [[Int]]?,frames: [Frame]?,headers: [Header]?,globals: [Patch]?,events: [Event],bounds: [Int32]?,sse2: Int?
    }
    private struct Corpus: Decodable { let exeSHA256: String,header: [Patch],baseActor: [Patch],states: [String:Int32],ids: [Int32],cases: [Case],fpcw: Int }
    private func patch(_ record: inout OriginalStateRecord,_ offset: Int,_ hex: String) throws {
        let bytes = Array(hex.utf8);XCTAssertEqual(bytes.count%2,0)
        for i in stride(from: 0,to: bytes.count,by: 2) { try record.write(XCTUnwrap(UInt8(String(decoding: bytes[i..<i+2],as: UTF8.self),radix: 16)),at: offset+i/2) }
    }
    func testWholeDepthPlacementUseAndThrow() throws {
        let url: URL
        if let path = ProcessInfo.processInfo.environment["NTSD_WORLD_LINKS_CORPUS"] { url = URL(fileURLWithPath: path) }
        else { url = try XCTUnwrap(Bundle.module.url(forResource: "original-world-links",withExtension: "json",subdirectory: "Fixtures")) }
        let c = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(Data(contentsOf: url),maximumCount: 32_000_000))
        XCTAssertEqual(c.fpcw,0x37f)
        try compare(c)
    }
    func testWholePassAtStartupPrecision() throws {
        let url: URL
        if let directory = ProcessInfo.processInfo.environment["NTSD_PRECISION_DIRECTORY"] {
            url = URL(fileURLWithPath: directory).appendingPathComponent("world-links53.json")
        } else { url = try XCTUnwrap(Bundle.module.url(forResource: "original-world-links53",withExtension: "json",subdirectory: "Fixtures")) }
        let c = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(Data(contentsOf: url),maximumCount: 64_000_000))
        XCTAssertEqual(c.fpcw,0x27f)
        try compare(c)
    }
    private func compare(_ c: Corpus) throws {
        XCTAssertEqual(c.exeSHA256,"3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        XCTAssertEqual(c.ids,[2,122,123,10]);XCTAssertEqual(c.cases.count,3018)
        func defined(_ size: Int) throws -> OriginalStateRecord { try .init(bytes: [UInt8](repeating: 0,count: size),defined: [Bool](repeating: true,count: size)) }
        var headers: [OriginalStateRecord] = [],frames: [[OriginalStateRecord]] = []
        for (i,id) in c.ids.enumerated() {
            var h = try defined(0x7a4)
            for p in c.header { try patch(&h,p.offset,p.bytes) }
            try h.write(id,at: 0x6f4);try h.write(Int32(i == 0 ? 0 : 1),at: 0x6f8);headers.append(h)
            frames.append(try (0..<400).map { n in
                var f = try defined(0x178);try f.write(UInt8(1),at: 0);try f.write(c.states[String(n)] ?? 3,at: 8)
                if [60,65,80,85,90].contains(n) { try f.write(Int32(100),at: 0x4c) };return f
            })
        }
        var globalsBase = try defined(OriginalMatchPreparation.globalSize)
        try globalsBase.write(Int32(1),at: 0x44d034-0x44d000)
        for i in 0..<3000 { try globalsBase.write(UInt8(1+i%255),at: 0x44ff90-0x44d000+i) }
        for item in c.cases {
            var template = try OriginalStateRecord.actor(over: (0..<0x420).map { item.fill == "a5" ? 0xa5 : UInt8(truncatingIfNeeded: $0) })
            for p in c.baseActor { try patch(&template,p.offset,p.bytes) }
            var actors = [OriginalStateRecord](repeating: template,count: 400)
            var world = try OriginalStateRecord.worldPrefix(over: (0..<0x7d8).map { item.fill == "a5" ? 0xa5 : UInt8(truncatingIfNeeded: $0) })
            let aliases = Dictionary(uniqueKeysWithValues: (item.aliases ?? []).map { ($0[0],$0[1]) })
            let active = Dictionary(uniqueKeysWithValues: (item.active ?? []).map { ($0[0],$0[1]) })
            for i in 0..<400 {
                try world.write(UInt32(aliases[i] ?? i),at: 0x194+i*4);try world.write(UInt8(active[i] ?? 0),at: 4+i);try actors[i].write(UInt32(0),at: 0x368)
            };try world.write(UInt32(0),at: 0x7d4)
            for a in item.actors ?? [] { for p in a.patches { try patch(&actors[a.index],p.offset,p.bytes) } }
            var ownFrames = frames,ownHeaders = headers,globals = globalsBase,events: [Event] = [],bg = try defined(0x990)
            let bounds = item.bounds ?? [0,600];try bg.write(bounds[0],at: 4);try bg.write(bounds[1],at: 8)
            for p in item.frames ?? [] { try patch(&ownFrames[p.object][p.index],p.offset,p.bytes) }
            for p in item.headers ?? [] { try patch(&ownHeaders[p.object],p.offset,p.bytes) }
            for p in item.globals ?? [] { try patch(&globals,p.offset-0x44d000,p.bytes) }
            try OriginalWorldLinks.apply(world: world,actors: &actors,globals: &globals,sse2Conversion: item.sse2 == 1,precision: OriginalArithmeticPrecision(controlWord: UInt16(c.fpcw)),
                header: { ownHeaders[$0] },frame: { ownFrames[$0][Int($1)] },background: { _ in bg },observe: { event in
                    if case let .random(slot,stream,range,result) = event { events.append(.init(slot: slot,kind: "random",arguments: [stream,range,result].map(UInt32.init(bitPattern:)))) }
                })
            let records = [world]+actors
            XCTAssertEqual(MatchPreparationReference.digest(Data(records.flatMap(\.bytes))),item.poolSHA256,item.label+" pool")
            XCTAssertEqual(MatchPreparationReference.digest(Data(records.flatMap { $0.defined.map { $0 ? UInt8(1) : UInt8(0) } })),item.maskSHA256,item.label+" masks")
            XCTAssertEqual(MatchPreparationReference.digest(Data(globals.bytes)),item.globalsSHA256,item.label+" globals")
            XCTAssertTrue(globals.defined.allSatisfy { $0 });XCTAssertEqual(events,item.events,item.label+" events")
        }
        print("WORLD LINKS",c.cases.count,"whole pools compared")
    }
    func testFailureAfterDepthPlacementAndRandomRollsBackWholePool() throws {
        let bootstrap = try OriginalWorldBootstrap(worldBacking: [UInt8](repeating: 0xa5,count: 0x7d8),actorBacking: [[UInt8]](repeating: [UInt8](repeating: 0xa5,count: 0x420),count: 400),selector: 2)
        var world = bootstrap.world,actors = bootstrap.actors
        for slot in [0,1] { try world.write(UInt8(1),at: 4+slot) }
        for (a,o,v): (Int,Int,Int32) in [(0,0x9c,1),(1,0x98,-1),(1,0xa0,0),(1,0x368,1)] { try actors[a].write(v,at: o) }
        try actors[0].writeBinary64(700,at: 0x68)
        func defined(_ size: Int) throws -> OriginalStateRecord { try .init(bytes: [UInt8](repeating: 0,count: size),defined: [Bool](repeating: true,count: size)) }
        var globals = try defined(0xb440),header = try defined(0x7a4),frame = try defined(0x178),bg = try defined(0x990)
        for i in 0..<3000 { try globals.write(UInt8(1),at: 0x44ff90-0x44d000+i) }
        try frame.write(Int32(12),at: 8);try bg.write(Int32(600),at: 8)
        var weapon = header;try weapon.write(Int32(1),at: 0x6f8)
        let beforeActors = actors,beforeGlobals = globals
        var depths: [Int] = [],draws: [OriginalWorldLinksEvent] = []
        XCTAssertThrowsError(try OriginalWorldLinks.apply(world: world,actors: &actors,globals: &globals,header: { $0 == 0 ? header : weapon },frame: { _,_ in frame },background: { _ in bg },observe: { event in
            draws.append(event);throw OriginalStateError.invalidStorage("Stop after original RNG")
        },afterDepth: { slot,actor in depths.append(slot);XCTAssertEqual(try actor.integer(at: 0x18,as: Int32.self),600) }))
        XCTAssertEqual(depths,[0]);XCTAssertEqual(draws,[.random(slot: 1,stream: 138,range: 16,result: 2)])
        XCTAssertEqual(actors,beforeActors);XCTAssertEqual(globals,beforeGlobals)
    }
}
