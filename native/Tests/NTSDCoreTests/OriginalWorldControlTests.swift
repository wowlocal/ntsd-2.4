import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalWorldControlTests: XCTestCase {
    func testFailureAfterEarlierActorRollsBackWholePoolAndRNG() throws {
        let bootstrap = try OriginalWorldBootstrap(worldBacking: [UInt8](repeating: 0xa5,count: 0x7d8),
            actorBacking: [[UInt8]](repeating: [UInt8](repeating: 0xa5,count: 0x420),count: 400),selector: 2)
        var world = bootstrap.world,actors = bootstrap.actors
        try world.write(UInt8(1),at: 4);try world.write(UInt8(1),at: 5)
        try actors[0].write(UInt8(1),at: 0xd1);try actors[1].write(UInt32(1),at: 0x368)
        var globals = try OriginalStateRecord(bytes: [UInt8](repeating: 0,count: 0xb440),defined: [Bool](repeating: true,count: 0xb440))
        for i in 0..<3000 { try globals.write(UInt8(1),at: 0x44ff90-0x44d000+i) }
        let header = try OriginalStateRecord(bytes: [UInt8](repeating: 0,count: 0x7a4),defined: [Bool](repeating: true,count: 0x7a4))
        var frame = try OriginalStateRecord(bytes: [UInt8](repeating: 0,count: 0x178),defined: [Bool](repeating: true,count: 0x178))
        try frame.write(UInt8(1),at: 0)
        let beforeActors = actors,beforeGlobals = globals
        var drew = false,firstReturned = false
        XCTAssertThrowsError(try OriginalWorldControl.apply(world: world,actors: &actors,globals: &globals,objectCount: 1,header: { index in
            guard index == 0 else { throw OriginalStateError.invalidStorage("Missing second Actor Object") };return header
        },frame: { _,_ in frame },observe: { slot,event in
            if slot == 0,case .random = event { drew = true }
        },afterActorControl: { slot,_ in if slot == 0 { firstReturned = true } }))
        XCTAssertTrue(drew);XCTAssertTrue(firstReturned)
        XCTAssertEqual(actors,beforeActors);XCTAssertEqual(globals,beforeGlobals)
    }
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
    private struct Event: Decodable,Equatable { let slot: Int,kind: String,arguments: [UInt32] }
    private struct Case: Decodable {
        let label: String,fill: String,poolSHA256: String,maskSHA256: String,globalsSHA256: String
        let actors: [Actor]?,active: [[Int]]?,aliases: [[Int]]?,frames: [Frame]?,globals: [Patch]?,count: Int32?,events: [Event],fpcw: UInt16?
    }
    private struct Corpus: Decodable { let exeSHA256: String,header: [Patch],states: [String:Int32],ids: [Int32],cases: [Case],fpcw: UInt16? }
    private func patch(_ record: inout OriginalStateRecord,_ offset: Int,_ hex: String) throws {
        let bytes = Array(hex.utf8);XCTAssertEqual(bytes.count%2,0)
        for i in stride(from: 0,to: bytes.count,by: 2) {
            try record.write(XCTUnwrap(UInt8(String(decoding: bytes[i..<i+2],as: UTF8.self),radix: 16)),at: offset+i/2)
        }
    }
    func testEntireControlCaller() throws {
        let url: URL
        if let path = ProcessInfo.processInfo.environment["NTSD_WORLD_CONTROL_CORPUS"] { url = URL(fileURLWithPath: path) }
        else { url = try XCTUnwrap(Bundle.module.url(forResource: "original-world-control",withExtension: "json",subdirectory: "Fixtures")) }
        let c = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(Data(contentsOf: url),maximumCount: 32_000_000))
        XCTAssertNil(c.fpcw);XCTAssertEqual(c.cases.count,1491)
        try compare(c)
    }

    func testEntireControlCallerAtStartupPrecision() throws {
        let url: URL
        if let directory = ProcessInfo.processInfo.environment["NTSD_CONTROL_PRECISION_DIRECTORY"] {
            url = URL(fileURLWithPath: directory).appendingPathComponent("world-control53.json")
        } else {
            url = try XCTUnwrap(Bundle.module.url(forResource: "original-world-control53",withExtension: "json",subdirectory: "Fixtures"))
        }
        let c = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(Data(contentsOf: url),maximumCount: 32_000_000))
        XCTAssertEqual(c.fpcw,0x27f);XCTAssertEqual(c.cases.count,1491)
        try compare(c)
    }

    func testLiveAliasedArithmeticAtThreePrecisions() throws {
        let url: URL
        if let directory = ProcessInfo.processInfo.environment["NTSD_CONTROL_PRECISION_DIRECTORY"] {
            url = URL(fileURLWithPath: directory).appendingPathComponent("world-control-precision.json")
        } else {
            url = try XCTUnwrap(Bundle.module.url(forResource: "original-world-control-precision",withExtension: "json",subdirectory: "Fixtures"))
        }
        let c = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(Data(contentsOf: url),maximumCount: 32_000_000))
        XCTAssertNil(c.fpcw);XCTAssertEqual(c.cases.count,36)
        for word: UInt16 in [0x7f,0x27f,0x37f] { XCTAssertEqual(c.cases.filter { $0.fpcw == word }.count,12) }
        try compare(c)
    }

    private func compare(_ c: Corpus) throws {
        XCTAssertEqual(c.exeSHA256,"3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        XCTAssertEqual(c.ids,[10,20,20,30])
        func defined(_ count: Int) throws -> OriginalStateRecord { try .init(bytes: [UInt8](repeating: 0,count: count),defined: [Bool](repeating: true,count: count)) }
        var headers: [OriginalStateRecord] = [],frames: [[OriginalStateRecord]] = []
        for (i,id) in c.ids.enumerated() {
            var h = try defined(0x7a4)
            for p in c.header { try patch(&h,p.offset,p.bytes) }
            try h.write(id,at: 0x6f4);try h.write(Int32(i == 3 ? 3 : 0),at: 0x6f8);headers.append(h)
            frames.append(try (0..<400).map { n in
                var f = try defined(0x178);try f.write(UInt8(1),at: 0)
                try f.write(c.states[String(n)] ?? 3,at: 8)
                if [60,65,80,85,90].contains(n) { try f.write(Int32(100),at: 0x4c) };return f
            })
        }
        var globalsBase = try defined(OriginalMatchPreparation.globalSize)
        try globalsBase.write(Int32(1),at: 0x44d034-0x44d000)
        for i in 0..<3000 { try globalsBase.write(UInt8(1+i%255),at: 0x44ff90-0x44d000+i) }
        for item in c.cases {
            let actorTemplate = try OriginalStateRecord.actor(over: (0..<0x420).map { item.fill == "a5" ? 0xa5 : UInt8(truncatingIfNeeded: $0) })
            var actors = [OriginalStateRecord](repeating: actorTemplate,count: 400)
            var world = try OriginalStateRecord.worldPrefix(over: (0..<0x7d8).map { item.fill == "a5" ? 0xa5 : UInt8(truncatingIfNeeded: $0) })
            let aliases = Dictionary(uniqueKeysWithValues: (item.aliases ?? []).map { ($0[0],$0[1]) })
            let active = Dictionary(uniqueKeysWithValues: (item.active ?? []).map { ($0[0],$0[1]) })
            for i in 0..<400 {
                try world.write(UInt32(aliases[i] ?? i),at: 0x194+i*4);try world.write(UInt8(active[i] ?? 0),at: 4+i)
                try actors[i].write(UInt32(0),at: 0x368)
            };try world.write(UInt32(0),at: 0x7d4)
            for a in item.actors ?? [] { for p in a.patches { try patch(&actors[a.index],p.offset,p.bytes) } }
            var ownFrames = frames,globals = globalsBase,events: [Event] = []
            for p in item.frames ?? [] { try patch(&ownFrames[p.object][p.index],p.offset,p.bytes) }
            for p in item.globals ?? [] { try patch(&globals,p.offset-0x44d000,p.bytes) }
            try OriginalWorldControl.apply(world: world,actors: &actors,globals: &globals,objectCount: item.count ?? 4,
                header: { headers[$0] },frame: { ownFrames[$0][Int($1)] },
                precision: try (item.fpcw ?? c.fpcw).map { try OriginalArithmeticPrecision(controlWord: $0) } ?? .bits64,observe: { slot,event in
                    switch event {
                    case let .random(stream,range,result):events.append(.init(slot: slot,kind: "random",arguments: [stream,range,result].map(UInt32.init(bitPattern:))))
                    case let .sound(x,index):events.append(.init(slot: slot,kind: "sound",arguments: [x,index].map(UInt32.init(bitPattern:))))
                    }
                })
            let records = [world]+actors
            XCTAssertEqual(MatchPreparationReference.digest(Data(records.flatMap(\.bytes))),item.poolSHA256,item.label+" pool")
            XCTAssertEqual(MatchPreparationReference.digest(Data(records.flatMap { $0.defined.map { $0 ? UInt8(1) : UInt8(0) } })),item.maskSHA256,item.label+" masks")
            XCTAssertEqual(MatchPreparationReference.digest(Data(globals.bytes)),item.globalsSHA256,item.label+" globals")
            XCTAssertTrue(globals.defined.allSatisfy { $0 });XCTAssertEqual(events,item.events,item.label+" events")
        }
    }
}
