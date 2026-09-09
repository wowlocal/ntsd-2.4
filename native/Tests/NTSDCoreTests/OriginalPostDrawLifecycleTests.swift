import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalPostDrawLifecycleTests: XCTestCase {
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
        let count: Int32?, slot: Int, sse2: Int?, whole: Bool?, events: [Event], endPC: UInt32, scratchBefore: [UInt32], scratchAfter: [UInt32]
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
    func testCompletePostSchedulerAndWholeLiveSlotLoopAgainstOriginalInstructions() throws {
        let url: URL
        if let directory = ProcessInfo.processInfo.environment["NTSD_POSTDRAW_LIFECYCLE_DIRECTORY"] {
            url = URL(fileURLWithPath: directory).appendingPathComponent("postdraw-lifecycle.json")
        } else {
            url = try XCTUnwrap(Bundle.module.url(forResource: "original-postdraw-lifecycle", withExtension: "json", subdirectory: "Fixtures"))
        }
        let c = try JSONDecoder().decode(Corpus.self, from: MatchPreparationReference.unpack(Data(contentsOf: url)))
        XCTAssertEqual(c.exeSHA256, "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        XCTAssertEqual(c.fpcw, 0x27f); XCTAssertEqual(c.ids, [100, 999, 998, 50])
        XCTAssertEqual(c.cases.count, 5432)
        XCTAssertEqual(c.instructions.count, 2370)
        XCTAssertEqual(c.cases.filter { $0.whole == true }.count, 921)
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
            let words = item.scratchBefore.map(Int32.init(bitPattern:))
            var scratch = OriginalPostDrawScratch(fireSlot: words[0], fireObject: words[1], deathSlot: words[2],
                                                  weaponSlot: words[3], weaponObject: words[4], particleObject: words[5])
            do {
                try OriginalPostDrawLifecycle.apply(world: &world, actors: &actors, globals: &globals, scratch: &scratch,
                    wholeLoop: item.whole ?? false, slot: item.slot, precision: .bits53, sse2: item.sse2 == 1, objectCount: item.count ?? 4,
                    header: { ownHeaders[$0] }, frame: { ownFrames[$0][Int($1)] }, observe: { event in
                        switch event {
                        case let .random(slot, stream, range, result):
                            events.append(.init(slot: slot, kind: "random", arguments: [stream, range, result].map(UInt32.init(bitPattern:))))
                        case let .reconstruct(slot, created):
                            events.append(.init(slot: slot, kind: "reconstruct", arguments: [UInt32(created)]))
                        case let .builtinSound(slot, x, index):
                            events.append(.init(slot: slot, kind: "builtinSound", arguments: [x, index].map(UInt32.init(bitPattern:))))
                        case let .catalogSound(slot, x, index):
                            events.append(.init(slot: slot, kind: "catalogSound", arguments: [x, index].map(UInt32.init(bitPattern:))))
                        }
                    })
                XCTAssertEqual(item.whole == true ? 0x4214d5 : 0x4214c6, item.endPC, item.label + " exit")
            } catch { XCTFail("\(item.label): \(error)"); return }
            let afterWords = [scratch.fireSlot, scratch.fireObject, scratch.deathSlot, scratch.weaponSlot, scratch.weaponObject, scratch.particleObject].map { $0.map(UInt32.init(bitPattern:)) }
            let records = [world]+actors
            let pool = MatchPreparationReference.digest(Data(records.flatMap(\.bytes)))
            let masks = MatchPreparationReference.digest(Data(records.flatMap { $0.defined.map { $0 ? UInt8(1) : UInt8(0) } }))
            let globalSHA = MatchPreparationReference.digest(Data(globals.bytes))
            guard pool == item.poolSHA256, masks == item.maskSHA256, globalSHA == item.globalsSHA256,
                  globals.defined.allSatisfy({ $0 }), events == item.events, afterWords == item.scratchAfter.map(Optional.some) else {
                XCTFail("\(item.label): pool=\(pool == item.poolSHA256) masks=\(masks == item.maskSHA256) globals=\(globalSHA == item.globalsSHA256) events=\(events == item.events) scratch=\(afterWords) expected=\(item.scratchAfter)")
                if let directory = ProcessInfo.processInfo.environment["NTSD_POSTDRAW_LIFECYCLE_DIRECTORY"] {
                    try Data(records.flatMap(\.bytes)).write(to: URL(fileURLWithPath: directory).appendingPathComponent("postdraw-lifecycle-native-mismatch.bin"))
                    try Data(item.label.utf8).write(to: URL(fileURLWithPath: directory).appendingPathComponent("postdraw-lifecycle-native-mismatch-label.txt"))
                }
                return
            }
            totalEvents += events.count
        }
        XCTAssertEqual(totalEvents, 25638)
        print("POSTDRAW LIFECYCLE", c.cases.count, "full pools and", totalEvents, "ordered events compared")
    }

    private func prepared() throws -> (OriginalStateRecord, [OriginalStateRecord], OriginalStateRecord, OriginalStateRecord, [OriginalStateRecord]) {
        let bootstrap = try OriginalWorldBootstrap(worldBacking: [UInt8](repeating: 0xa5, count: 0x7d8),
            actorBacking: [[UInt8]](repeating: [UInt8](repeating: 0xa5, count: 0x420), count: 400), selector: 2)
        var world = bootstrap.world, globals = try zero(0xb440), header = try zero(0x7a4), first = try zero(0x178), second = try zero(0x178)
        for slot in 0..<400 { try world.write(UInt8(slot < 2 ? 1 : 0), at: 4+slot) }
        try header.write(Int32(999), at: 0x6f4); try header.write(Int32(20), at: 0x90)
        try first.write(Int32(3), at: 8); try first.write(Int32(-1), at: 0x174)
        try second.write(Int32(13), at: 8); try second.write(Int32(-1), at: 0x174)
        for i in 0..<3000 { try globals.write(UInt8(1), at: 0x44ff90-0x44d000+i) }
        return (world, bootstrap.actors, globals, header, [first, second])
    }
    func testWholeLoopRollsBackEarlierSlotParticlesGlobalsAndScratch() throws {
        var (world, actors, globals, header, frames) = try prepared()
        try actors[1].write(Int32(1), at: 0x78)
        let beforeWorld = world, beforeActors = actors, beforeGlobals = globals
        var scratch = OriginalPostDrawScratch(deathSlot: -1), events: [OriginalPostDrawLifecycleEvent] = []
        let beforeScratch = scratch
        var constructions = 0
        XCTAssertThrowsError(try OriginalPostDrawLifecycle.apply(world: &world, actors: &actors, globals: &globals, scratch: &scratch,
            wholeLoop: true, slot: 0, precision: .bits53, sse2: false, objectCount: 1, header: { _ in header }, frame: { _, number in frames[Int(number)] }, observe: { event in
                events.append(event)
                if case .reconstruct = event { constructions += 1 }
                if constructions == 2 { throw OriginalStateError.invalidStorage("Second effect constructor") }
            }))
        XCTAssertEqual(events.filter { if case .reconstruct = $0 { return true }; return false },
                       [.reconstruct(slot: 1, created: 50), .reconstruct(slot: 1, created: 51)])
        XCTAssertEqual(events.filter { if case .random = $0 { return true }; return false }.count, 4)
        XCTAssertEqual(world, beforeWorld); XCTAssertEqual(actors, beforeActors); XCTAssertEqual(globals, beforeGlobals)
        XCTAssertEqual(scratch, beforeScratch)
    }
    func testUnknownFireObjectFailsOnlyWhenDereferenced() throws {
        var (world, actors, globals, header, frames) = try prepared()
        try header.write(Int32(2), at: 0x6f4); try frames[1].write(Int32(18), at: 8)
        try actors[0].write(Int32(1), at: 0x78)
        let beforeWorld = world, beforeActors = actors, beforeGlobals = globals
        var scratch = OriginalPostDrawScratch(), events: [OriginalPostDrawLifecycleEvent] = []
        XCTAssertThrowsError(try OriginalPostDrawLifecycle.apply(world: &world, actors: &actors, globals: &globals, scratch: &scratch,
            wholeLoop: false, slot: 0, precision: .bits53, sse2: false, objectCount: 1, header: { _ in header }, frame: { _, number in frames[Int(number)] }, observe: { events.append($0) }))
        XCTAssertTrue(events.isEmpty); XCTAssertEqual(scratch, OriginalPostDrawScratch())
        XCTAssertEqual(world, beforeWorld); XCTAssertEqual(actors, beforeActors); XCTAssertEqual(globals, beforeGlobals)
        for slot in 50..<400 { try world.write(UInt8(1), at: 4+slot) }
        try OriginalPostDrawLifecycle.apply(world: &world, actors: &actors, globals: &globals, scratch: &scratch,
            wholeLoop: false, slot: 0, precision: .bits53, sse2: false, objectCount: 1, header: { _ in header }, frame: { _, number in frames[Int(number)] }, observe: { events.append($0) })
        XCTAssertTrue(events.isEmpty); XCTAssertNil(scratch.fireObject)
        XCTAssertEqual(try actors[0].integer(at: 0x78, as: Int32.self), 0)
    }
}
