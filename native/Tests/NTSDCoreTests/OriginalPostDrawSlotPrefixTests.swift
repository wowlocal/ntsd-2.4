import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalPostDrawSlotPrefixTests: XCTestCase {
    private struct Patch: Decodable {
        let offset: Int, bytes: String
        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer(); offset = try c.decode(Int.self); bytes = try c.decode(String.self)
        }
    }
    private struct Actor: Decodable {
        let index: Int, patches: [Patch]
        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer(); index = try c.decode(Int.self); patches = try c.decode([Patch].self)
        }
    }
    private struct Header: Decodable {
        let object: Int, offset: Int, bytes: String
        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            object = try c.decode(Int.self); offset = try c.decode(Int.self); bytes = try c.decode(String.self)
        }
    }
    private struct Frame: Decodable {
        let object: Int, index: Int, offset: Int, bytes: String
        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            object = try c.decode(Int.self); index = try c.decode(Int.self)
            offset = try c.decode(Int.self); bytes = try c.decode(String.self)
        }
    }
    private struct Event: Decodable, Equatable { let slot: Int, kind: String, arguments: [UInt32] }
    private struct Case: Decodable {
        let label: String, fill: String, poolSHA256: String, maskSHA256: String, globalsSHA256: String
        let actors: [Actor]?, active: [[Int]]?, aliases: [[Int]]?, frames: [Frame]?, headers: [Header]?, globals: [Patch]?
        let count: Int32?, slot: Int, events: [Event], endPC: UInt32, retainedBefore: UInt32, retainedAfter: UInt32
    }
    private struct Corpus: Decodable {
        let exeSHA256: String, header: [Patch], headerPatches: [Header], states: [String: Int32], ids: [Int32]
        let cases: [Case], fpcw: UInt16, instructions: [UInt32]
    }
    private func zero(_ count: Int) throws -> OriginalStateRecord {
        try .init(bytes: [UInt8](repeating: 0, count: count), defined: [Bool](repeating: true, count: count))
    }
    private func patch(_ record: inout OriginalStateRecord, _ offset: Int, _ hex: String) throws {
        let bytes = Array(hex.utf8); XCTAssertEqual(bytes.count % 2, 0)
        for i in stride(from: 0, to: bytes.count, by: 2) {
            try record.write(XCTUnwrap(UInt8(String(decoding: bytes[i..<i+2], as: UTF8.self), radix: 16)), at: offset+i/2)
        }
    }
    func testWholeSlotPrefixAgainstOriginalInstructions() throws {
        let url: URL
        if let directory = ProcessInfo.processInfo.environment["NTSD_POSTDRAW_PREFIX_DIRECTORY"] {
            url = URL(fileURLWithPath: directory).appendingPathComponent("postdraw-slot-prefix.json")
        } else {
            url = try XCTUnwrap(Bundle.module.url(forResource: "original-postdraw-slot-prefix", withExtension: "json", subdirectory: "Fixtures"))
        }
        let c = try JSONDecoder().decode(Corpus.self, from: MatchPreparationReference.unpack(Data(contentsOf: url)))
        XCTAssertEqual(c.exeSHA256, "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        XCTAssertEqual(c.fpcw, 0x27f); XCTAssertEqual(c.ids, [2, 50, 217, 218])
        XCTAssertEqual(c.cases.count, 897)
        XCTAssertEqual(Set(c.instructions).count, 714)
        XCTAssertEqual(c.instructions.filter { (0x41f550...0x41fb06).contains($0) }.count, 329)
        var headers: [OriginalStateRecord] = [], frames: [[OriginalStateRecord]] = []
        for (i, id) in c.ids.enumerated() {
            var h = try zero(0x7a4)
            for p in c.header { try patch(&h, p.offset, p.bytes) }
            try h.write(id, at: 0x6f4); try h.write(Int32(i == 3 ? 3 : 0), at: 0x6f8)
            for p in c.headerPatches where p.object == i { try patch(&h, p.offset, p.bytes) }
            headers.append(h)
            frames.append(try (0..<400).map { n in
                var f = try zero(0x178); try f.write(UInt8(1), at: 0)
                try f.write(c.states[String(n)] ?? 3, at: 8)
                if [60, 65, 80, 85, 90].contains(n) { try f.write(Int32(100), at: 0x4c) }
                return f
            })
        }
        var globalsBase = try zero(OriginalMatchPreparation.globalSize)
        try globalsBase.write(Int32(1), at: 0x44d034-0x44d000)
        for i in 0..<3000 { try globalsBase.write(UInt8(1+i%255), at: 0x44ff90-0x44d000+i) }
        var totalEvents = 0
        for item in c.cases {
            let template = try OriginalStateRecord.actor(over: (0..<0x420).map { item.fill == "a5" ? 0xa5 : UInt8(truncatingIfNeeded: $0) })
            var actors = [OriginalStateRecord](repeating: template, count: 400)
            var world = try OriginalStateRecord.worldPrefix(over: (0..<0x7d8).map { item.fill == "a5" ? 0xa5 : UInt8(truncatingIfNeeded: $0) })
            let aliases = Dictionary(uniqueKeysWithValues: (item.aliases ?? []).map { ($0[0], $0[1]) })
            let active = Dictionary(uniqueKeysWithValues: (item.active ?? []).map { ($0[0], $0[1]) })
            for i in 0..<400 {
                try world.write(UInt32(aliases[i] ?? i), at: 0x194+i*4); try world.write(UInt8(active[i] ?? 0), at: 4+i)
                try actors[i].write(UInt32(0), at: 0x368)
            }
            try world.write(UInt32(0), at: 0x7d4)
            for a in item.actors ?? [] { for p in a.patches { try patch(&actors[a.index], p.offset, p.bytes) } }
            var ownHeaders = headers, ownFrames = frames, globals = globalsBase, events: [Event] = []
            for p in item.headers ?? [] { try patch(&ownHeaders[p.object], p.offset, p.bytes) }
            for p in item.frames ?? [] { try patch(&ownFrames[p.object][p.index], p.offset, p.bytes) }
            for p in item.globals ?? [] { try patch(&globals, p.offset-0x44d000, p.bytes) }
            var retained: Int32? = Int32(bitPattern: item.retainedBefore)
            do {
                let scheduled = try OriginalPostDrawSlotPrefix.apply(world: &world, actors: &actors, globals: &globals,
                    slot: item.slot, retainedObjectIndex: &retained, objectCount: item.count ?? 4,
                    header: { ownHeaders[$0] }, frame: { ownFrames[$0][Int($1)] }, observe: { event in
                        switch event {
                        case let .random(slot, stream, range, result):
                            events.append(.init(slot: slot, kind: "random", arguments: [stream, range, result].map(UInt32.init(bitPattern:))))
                        case let .reconstruct(slot, created):
                            events.append(.init(slot: slot, kind: "reconstruct", arguments: [UInt32(created)]))
                        case let .catalogSound(slot, x, index):
                            events.append(.init(slot: slot, kind: "catalogSound", arguments: [x, index].map(UInt32.init(bitPattern:))))
                        }
                    })
                XCTAssertEqual(scheduled ? 0x41fb0b : 0x4214c6, item.endPC, item.label + " exit")
            } catch { XCTFail("\(item.label): \(error)"); return }
            let records = [world]+actors
            let pool = MatchPreparationReference.digest(Data(records.flatMap(\.bytes)))
            let masks = MatchPreparationReference.digest(Data(records.flatMap { $0.defined.map { $0 ? UInt8(1) : UInt8(0) } }))
            let globalSHA = MatchPreparationReference.digest(Data(globals.bytes))
            guard pool == item.poolSHA256, masks == item.maskSHA256, globalSHA == item.globalsSHA256,
                  globals.defined.allSatisfy({ $0 }), events == item.events,
                  retained.map(UInt32.init(bitPattern:)) == item.retainedAfter else {
                XCTFail("\(item.label): pool=\(pool == item.poolSHA256) masks=\(masks == item.maskSHA256) globals=\(globalSHA == item.globalsSHA256) events=\(events == item.events) retained=\(String(describing: retained)) expected=\(item.retainedAfter)")
                return
            }
            totalEvents += events.count
        }
        XCTAssertEqual(totalEvents, 2334)
        print("POSTDRAW SLOT PREFIX", c.cases.count, "full pools and", totalEvents, "ordered events compared")
    }

    private func particleState() throws -> (OriginalStateRecord, [OriginalStateRecord], OriginalStateRecord, OriginalStateRecord, OriginalStateRecord) {
        let bootstrap = try OriginalWorldBootstrap(worldBacking: [UInt8](repeating: 0xa5, count: 0x7d8),
            actorBacking: [[UInt8]](repeating: [UInt8](repeating: 0xa5, count: 0x420), count: 400), selector: 2)
        var world = bootstrap.world, actors = bootstrap.actors, globals = try zero(0xb440)
        for i in 0..<400 { try world.write(UInt8(i == 0 ? 1 : 0), at: 4+i) }
        try world.write(UInt32(0), at: 0x194+4*50)
        try actors[0].write(Int32(1), at: 0x88)
        var header = try zero(0x7a4), frame = try zero(0x178)
        try header.write(Int32(217), at: 0x6f4); try frame.write(Int32(9996), at: 8)
        for i in 0..<3000 { try globals.write(UInt8(1), at: 0x44ff90-0x44d000+i) }
        return (world, actors, globals, header, frame)
    }
    func testLateParticleFailureRollsBackAliasedParentPoolGlobalsAndRetainedIndex() throws {
        var (world, actors, globals, header, frame) = try particleState()
        let beforeWorld = world, beforeActors = actors, beforeGlobals = globals
        var retained: Int32? = 3, seen: [OriginalPostDrawSlotEvent] = []
        XCTAssertThrowsError(try OriginalPostDrawSlotPrefix.apply(world: &world, actors: &actors, globals: &globals,
            slot: 0, retainedObjectIndex: &retained, objectCount: 1, header: { _ in header }, frame: { _, _ in frame }, observe: { event in
                seen.append(event)
                if case .random(_, 156, _, _) = event { throw OriginalStateError.invalidStorage("Late particle observer") }
            }))
        XCTAssertEqual(seen, [.reconstruct(slot: 0, created: 50), .random(slot: 0, stream: 155, range: 7, result: 2),
                             .random(slot: 0, stream: 156, range: 7, result: 3)])
        XCTAssertEqual(world, beforeWorld); XCTAssertEqual(actors, beforeActors); XCTAssertEqual(globals, beforeGlobals)
        XCTAssertEqual(retained, 3)
    }
    func testMissingRetainedIndexIsRequiredOnlyWhenOriginalDereferencesIt() throws {
        var (world, actors, globals, header, frame) = try particleState()
        var retained: Int32?, seen: [OriginalPostDrawSlotEvent] = []
        let beforeWorld = world, beforeActors = actors, beforeGlobals = globals
        XCTAssertThrowsError(try OriginalPostDrawSlotPrefix.apply(world: &world, actors: &actors, globals: &globals,
            slot: 0, retainedObjectIndex: &retained, objectCount: 0, header: { _ in header }, frame: { _, _ in frame }, observe: { seen.append($0) }))
        XCTAssertEqual(world, beforeWorld); XCTAssertEqual(actors, beforeActors); XCTAssertEqual(globals, beforeGlobals)
        XCTAssertNil(retained); XCTAssertTrue(seen.isEmpty)
        for i in 50..<400 { try world.write(UInt8(1), at: 4+i) }
        XCTAssertTrue(try OriginalPostDrawSlotPrefix.apply(world: &world, actors: &actors, globals: &globals,
            slot: 0, retainedObjectIndex: &retained, objectCount: 0, header: { _ in header }, frame: { _, _ in frame }, observe: { seen.append($0) }))
        XCTAssertNil(retained)
        XCTAssertFalse(seen.contains { if case .reconstruct = $0 { return true }; return false })
    }
}
