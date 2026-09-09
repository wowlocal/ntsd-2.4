import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalLibStageCommandsTests: XCTestCase {
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
    private struct Event: Decodable, Equatable { let kind: String, arguments: [UInt32] }
    private struct Case: Decodable {
        let label: String, fill: String, poolSHA256: String, maskSHA256: String, globalsSHA256: String
        let actors: [Actor]?, active: [[Int]]?, aliases: [[Int]]?, frames: [Frame]?, headers: [Header]?, globals: [Patch]?
        let requestedID: Int32
        let count: Int32?, sse2: Int?, backgrounds: [[Int32]]?, events: [Event], endPC: UInt32, retainedBefore: UInt32, retainedAfter: UInt32
    }
    private struct Corpus: Decodable {
        let libSHA256: String
        let exeSHA256: String, header: [Patch], headerPatches: [Header], states: [String: Int32], ids: [Int32]
        let backgrounds: [[Int32]], cases: [Case], fpcw: UInt16, instructions: [UInt32]
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
    func testEntireCommandsRecoveryAndCleanupAgainstOriginalInstructions() throws {
        let url: URL
        if let directory = ProcessInfo.processInfo.environment["NTSD_LIB_STAGE_COMMANDS_DIRECTORY"] {
            url = URL(fileURLWithPath: directory).appendingPathComponent("lib-stage-commands.json")
        } else {
            url = try XCTUnwrap(Bundle.module.url(forResource: "original-lib-stage-commands", withExtension: "json", subdirectory: "Fixtures"))
        }
        let c = try JSONDecoder().decode(Corpus.self, from: MatchPreparationReference.unpack(Data(contentsOf: url)))
        XCTAssertEqual(c.exeSHA256, "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        XCTAssertEqual(c.fpcw, 0x27f); XCTAssertEqual(c.ids, [100, 122, 123, 300])
        XCTAssertEqual(c.libSHA256, "28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba")
        XCTAssertEqual(c.cases.count, 4330)
        XCTAssertEqual(c.instructions.count, 573)
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
            let backgrounds = try Dictionary(uniqueKeysWithValues: (item.backgrounds ?? c.backgrounds).map { words in
                var bg = try zero(12)
                for n in 0..<3 { try bg.write(words[n+1], at: 4*n) }
                return (words[0], bg)
            })
            var retained: Int32? = Int32(bitPattern: item.retainedBefore)
            do {
                try OriginalPostDrawCommands.apply(world: &world, actors: &actors, globals: &globals, retainedSpawnSlot: &retained,
                    sse2: item.sse2 == 1, objectCount: item.count ?? 4, library: .init(requestedObjectID: item.requestedID), header: { ownHeaders[$0] },
                    frame: { ownFrames[$0][Int($1)] }, background: { try XCTUnwrap(backgrounds[$0]) }, observe: { event in
                        switch event {
                        case let .random(stream, range, result):
                            events.append(.init(kind: "random", arguments: [stream, range, result].map(UInt32.init(bitPattern:))))
                        case let .reconstruct(slot):
                            events.append(.init(kind: "reconstruct", arguments: [UInt32(slot)]))
                        case let .resumeMusic(slot, control):
                            events.append(.init(kind: "resumeMusic", arguments: [UInt32(slot), control]))
                        }
                    })
                XCTAssertEqual(item.endPC, 0x421a15, item.label + " exit")
            } catch { XCTFail("\(item.label): \(error)"); return }
            let afterWord = retained.map(UInt32.init(bitPattern:))
            let records = [world]+actors
            let pool = MatchPreparationReference.digest(Data(records.flatMap(\.bytes)))
            let masks = MatchPreparationReference.digest(Data(records.flatMap { $0.defined.map { $0 ? UInt8(1) : UInt8(0) } }))
            let globalSHA = MatchPreparationReference.digest(Data(globals.bytes))
            guard pool == item.poolSHA256, masks == item.maskSHA256, globalSHA == item.globalsSHA256,
                  globals.defined.allSatisfy({ $0 }), events == item.events, afterWord == item.retainedAfter else {
                XCTFail("\(item.label): pool=\(pool == item.poolSHA256) masks=\(masks == item.maskSHA256) globals=\(globalSHA == item.globalsSHA256) events=\(events == item.events) retained=\(String(describing: afterWord)) expected=\(item.retainedAfter)")
                if let directory = ProcessInfo.processInfo.environment["NTSD_LIB_STAGE_COMMANDS_DIRECTORY"] {
                    try Data(records.flatMap(\.bytes)).write(to: URL(fileURLWithPath: directory).appendingPathComponent("lib-stage-commands-native-mismatch.bin"))
                    try Data(item.label.utf8).write(to: URL(fileURLWithPath: directory).appendingPathComponent("lib-stage-commands-native-mismatch-label.txt"))
                }
                return
            }
            totalEvents += events.count
        }
        XCTAssertEqual(totalEvents, 6361)
        print("LIB STAGE COMMANDS", c.cases.count, "full pools and", totalEvents, "ordered events compared")
    }

    private func prepared() throws -> (OriginalStateRecord, [OriginalStateRecord], OriginalStateRecord, OriginalStateRecord, OriginalStateRecord, OriginalStateRecord) {
        let bootstrap = try OriginalWorldBootstrap(worldBacking: [UInt8](repeating: 0xa5, count: 0x7d8),
            actorBacking: [[UInt8]](repeating: [UInt8](repeating: 0xa5, count: 0x420), count: 400), selector: 2)
        var world = bootstrap.world, globals = try zero(0xb440), header = try zero(0x7a4), frame = try zero(0x178), bg = try zero(12)
        for slot in 0..<400 { try world.write(UInt8(slot < 2 ? 1 : 0), at: 4+slot) }
        try header.write(Int32(100), at: 0x6f4); try header.write(Int32(20), at: 0x90)
        try frame.write(Int32(3), at: 8)
        for (i, value) in [Int32(800), 200, 700].enumerated() { try bg.write(value, at: 4*i) }
        for i in 0..<3000 { try globals.write(UInt8(1), at: 0x44ff90-0x44d000+i) }
        return (world, bootstrap.actors, globals, header, frame, bg)
    }

    func testFullPoolRequiresRetainedSlotOnlyAfterCoordinateDraws() throws {
        var (world, actors, globals, header, frame, bg) = try prepared()
        for slot in 50..<400 { try world.write(UInt8(1), at: 4+slot) }
        try globals.write(Int32(3), at: 0x450bb8-0x44d000)
        let beforeWorld = world, beforeActors = actors, beforeGlobals = globals
        var retained: Int32?, events: [OriginalPostDrawCommandEvent] = []
        XCTAssertThrowsError(try OriginalPostDrawCommands.apply(world: &world, actors: &actors, globals: &globals,
            retainedSpawnSlot: &retained, sse2: false, objectCount: 1, library: .init(requestedObjectID: 100), header: { _ in header }, frame: { _, _ in frame },
            background: { _ in bg }, observe: { events.append($0) })) { error in
                guard case let OriginalStateError.invalidStorage(message) = error else { return XCTFail("Unexpected error: \(error)") }
                XCTAssertEqual(message, "Post-draw commands: Retained caller slot provenance")
            }
        XCTAssertEqual(events.count, 4)
        for (event, stream) in zip(events, 209...212) {
            guard case let .random(actualStream, range, _) = event else { return XCTFail("Expected coordinate RNG") }
            XCTAssertEqual(actualStream, Int32(stream)); XCTAssertEqual(range, 30)
        }
        XCTAssertEqual(world, beforeWorld); XCTAssertEqual(actors, beforeActors); XCTAssertEqual(globals, beforeGlobals)
        XCTAssertNil(retained)
        // A catalog with no candidates does not consume the unknown caller word.
        try header.write(Int32(200), at: 0x6f4); events.removeAll()
        try OriginalPostDrawCommands.apply(world: &world, actors: &actors, globals: &globals,
            retainedSpawnSlot: &retained, sse2: false, objectCount: 1, library: .init(requestedObjectID: 100), header: { _ in header }, frame: { _, _ in frame },
            background: { _ in bg }, observe: { events.append($0) })
        XCTAssertTrue(events.isEmpty); XCTAssertNil(retained)
    }

    func testSecondConstructionFailureRollsBackPoolRandomAndRetainedSlot() throws {
        var (world, actors, globals, header, frame, bg) = try prepared()
        try globals.write(Int32(3), at: 0x450bb8-0x44d000)
        let beforeWorld = world, beforeActors = actors, beforeGlobals = globals
        var retained: Int32? = 77, events: [OriginalPostDrawCommandEvent] = []
        XCTAssertThrowsError(try OriginalPostDrawCommands.apply(world: &world, actors: &actors, globals: &globals,
            retainedSpawnSlot: &retained, sse2: false, objectCount: 2, library: .init(requestedObjectID: 100), header: { _ in header }, frame: { _, _ in frame },
            background: { _ in bg }, observe: { event in
                events.append(event)
                if event == .reconstruct(slot: 51) { throw OriginalStateError.invalidStorage("Second construction") }
            }))
        XCTAssertEqual(events.filter { if case .reconstruct = $0 { return true }; return false },
                       [.reconstruct(slot: 50), .reconstruct(slot: 51)])
        XCTAssertEqual(events.filter { if case .random = $0 { return true }; return false }.count, 8)
        XCTAssertEqual(world, beforeWorld); XCTAssertEqual(actors, beforeActors); XCTAssertEqual(globals, beforeGlobals)
        XCTAssertEqual(retained, 77)
    }

    func testMusicObserverFailureRollsBackEarlierRecoveryAndCleanup() throws {
        var (world, actors, globals, header, frame, bg) = try prepared()
        try globals.write(Int32(1), at: 0x450bc0-0x44d000)
        try globals.write(UInt32(0x35000100), at: 0x44f044-0x44d000)
        try actors[0].write(Int32(-1), at: 0x2fc); try actors[0].write(Int32(9), at: 0x2e8)
        let beforeWorld = world, beforeActors = actors, beforeGlobals = globals
        var retained: Int32? = -1, events: [OriginalPostDrawCommandEvent] = []
        XCTAssertThrowsError(try OriginalPostDrawCommands.apply(world: &world, actors: &actors, globals: &globals,
            retainedSpawnSlot: &retained, sse2: false, objectCount: 1, library: .init(requestedObjectID: 100), header: { _ in header }, frame: { _, _ in frame },
            background: { _ in bg }, observe: { event in
                events.append(event)
                if events.count == 2 { throw OriginalStateError.invalidStorage("Second music observer") }
            }))
        XCTAssertEqual(events, [.resumeMusic(slot: 0, control: 0x35000100), .resumeMusic(slot: 1, control: 0x35000100)])
        XCTAssertEqual(world, beforeWorld); XCTAssertEqual(actors, beforeActors); XCTAssertEqual(globals, beforeGlobals)
        XCTAssertEqual(retained, -1)
    }

    func testZeroIDReadsFirstHeaderOnlyWhenCatalogCountIsPositive() throws {
        var (world, actors, globals, _, frame, bg) = try prepared()
        try globals.write(Int32(3), at: 0x450bb8-0x44d000)
        for slot in 0..<400 { try world.write(UInt8(0), at: 4+slot) }
        let beforeWorld = world, beforeActors = actors, beforeGlobals = globals
        var retained: Int32?, reads = 0
        for count: Int32 in [0, 1] {
            do {
                try OriginalPostDrawCommands.apply(world: &world, actors: &actors, globals: &globals,
                    retainedSpawnSlot: &retained, sse2: false, objectCount: count,
                    library: .init(requestedObjectID: 0), header: { _ in
                        reads += 1; throw OriginalStateError.invalidStorage("Unavailable first header")
                    }, frame: { _, _ in frame }, background: { _ in bg })
                XCTAssertEqual(count, 0)
            } catch { XCTAssertEqual(count, 1) }
            XCTAssertEqual(world, beforeWorld); XCTAssertEqual(actors, beforeActors); XCTAssertEqual(globals, beforeGlobals)
            XCTAssertNil(retained)
        }
        XCTAssertEqual(reads, 1)
    }
}
