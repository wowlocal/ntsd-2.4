import Foundation
import CryptoKit
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalActorSchedulerTests: XCTestCase {
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
        let actor: [Patch], header: [Patch], frames: [FramePatch], globals: [Patch]?, events: [Event]
        let mode: Int32?, slot: Int32?
    }
    private struct Corpus: Decodable {
        let exeSHA256: String, fpcw: UInt16, header: [Patch], cases: [Case], instructions: [UInt32]
    }
    private func hex(_ text: String) throws -> [UInt8] {
        let bytes = Array(text.utf8)
        guard bytes.count % 2 == 0 else { throw OriginalStateError.invalidStorage("Odd hex length") }
        return try stride(from: 0, to: bytes.count, by: 2).map {
            try XCTUnwrap(UInt8(String(decoding: bytes[$0..<$0+2], as: UTF8.self), radix: 16))
        }
    }
    private func patch(_ record: inout OriginalStateRecord, _ offset: Int, _ bytes: String) throws {
        for (i, byte) in try hex(bytes).enumerated() { try record.write(byte, at: offset+i) }
    }
    private func zero(_ count: Int) throws -> OriginalStateRecord {
        try .init(bytes: [UInt8](repeating: 0, count: count), defined: [Bool](repeating: true, count: count))
    }

    func testWholeSchedulerAndRealSoundAgainstOriginalInstructions() throws {
        let url: URL
        if let directory = ProcessInfo.processInfo.environment["NTSD_SCHEDULER_DIRECTORY"] {
            url = URL(fileURLWithPath: directory).appendingPathComponent("actor-scheduler.json")
        } else {
            url = try XCTUnwrap(Bundle.module.url(forResource: "original-actor-scheduler", withExtension: "json", subdirectory: "Fixtures"))
        }
        let corpus = try JSONDecoder().decode(Corpus.self, from: MatchPreparationReference.unpack(Data(contentsOf: url)))
        XCTAssertEqual(corpus.exeSHA256, "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        XCTAssertEqual(corpus.fpcw, 0x27f)
        XCTAssertEqual(corpus.cases.count, 6084)
        XCTAssertEqual(Set(corpus.instructions).count, 374)
        XCTAssertEqual(corpus.instructions.filter { (0x40d960...0x40de20).contains($0) }.count, 316)
        XCTAssertEqual(corpus.instructions.filter { (0x416fb0...0x417082).contains($0) }.count, 58)
        let templates = try ["a5", "ramp"].reduce(into: [String: OriginalStateRecord]()) { result, fill in
            result[fill] = try .actor(over: (0..<OriginalStateRecord.actorSize).map { fill == "a5" ? 0xa5 : UInt8(truncatingIfNeeded: $0) })
        }
        var headerBase = try zero(0x7a4), frameBase = try zero(0x178)
        for p in corpus.header { try patch(&headerBase, p.offset, p.bytes) }
        try frameBase.write(UInt8(1), at: 0)
        try frameBase.write(Int32(3), at: 8)
        try frameBase.write(Int32(-1), at: 0x174)
        let base = OriginalMatchPreparation.globalBase
        var globalBase = try zero(OriginalMatchPreparation.globalSize)
        try globalBase.write(Int32(1), at: 0x44d034-base)
        for index in 0..<3000 { try globalBase.write(UInt8(1+index%255), at: 0x44ff90-base+index) }
        var eventCount = 0
        for item in corpus.cases {
            var actor = try XCTUnwrap(templates[item.fill]), header = headerBase, globals = globalBase
            var frames: [Int32: OriginalStateRecord] = [:]
            for p in item.actor { try patch(&actor, p.offset, p.bytes) }
            for p in item.header { try patch(&header, p.offset, p.bytes) }
            for p in item.globals ?? [] { try patch(&globals, p.offset-base, p.bytes) }
            for p in item.frames {
                var frame = frames[p.index] ?? frameBase; try patch(&frame, p.offset, p.bytes); frames[p.index] = frame
            }
            var events: [Event] = []
            do {
                try OriginalActorScheduler.apply(actor: &actor, header: header, globals: &globals,
                    mode: item.mode ?? 0, slot: item.slot ?? 0, frame: { number in
                        guard (0..<400).contains(number) else { throw OriginalStateError.invalidStorage("Probe frame outside Object") }
                        return frames[number] ?? frameBase
                    }, observe: { event in
                        switch event {
                        case let .catalogSound(x, index):
                            events.append(.init(kind: "catalogSound", arguments: [x, index].map(UInt32.init(bitPattern:))))
                        }
                    })
            } catch { XCTFail("\(item.label): \(error)"); return }
            let expected = try hex(item.after), mask = try hex(item.defined).map { $0 != 0 }
            if let offset = actor.bytes.indices.first(where: { actor.bytes[$0] != expected[$0] || actor.defined[$0] != mask[$0] }) {
                XCTFail("\(item.label): +\(String(offset, radix:16)) got \(actor.bytes[offset])/\(actor.defined[offset]), expected \(expected[offset])/\(mask[offset])")
                return
            }
            let sha = MatchPreparationReference.digest(Data(globals.bytes))
            guard sha == item.globalsSHA256 && globals.defined.allSatisfy({ $0 }) && events == item.events else {
                XCTFail("\(item.label): global SHA or ordered sound requests differ"); return
            }
            eventCount += events.count
        }
        XCTAssertEqual(eventCount, 756)
        print("ACTOR SCHEDULER", corpus.cases.count, "whole calls and", eventCount, "ordered sound requests compared")
    }

    func testLateFrameFailureRollsBackEarlierSoundAndCounters() throws {
        var actor = try OriginalStateRecord.actor(over: [UInt8](repeating: 0xa5, count: OriginalStateRecord.actorSize))
        var header = try zero(0x7a4), globals = try zero(OriginalMatchPreparation.globalSize)
        try actor.write(Int32(2), at: 0x74)
        try actor.write(Int32(10), at: 0xec)
        try actor.write(Int32(200), at: 0x10)
        try header.write(Int32(0), at: 0x6f8)
        var first = try zero(0x178)
        try first.write(Int32(3), at: 8)
        try first.write(Int32(3), at: 0x10)
        try first.write(Int32(7), at: 0x174)
        let beforeActor = actor, beforeGlobals = globals
        var sounds = 0
        XCTAssertThrowsError(try OriginalActorScheduler.apply(actor: &actor, header: header, globals: &globals,
            mode: 0, slot: 0, frame: { number in
                guard number == 0 else { throw OriginalStateError.invalidStorage("Unavailable next/previous frame") }
                return first
            }, observe: { _ in sounds += 1 }))
        XCTAssertEqual(sounds, 1)
        XCTAssertEqual(actor, beforeActor)
        XCTAssertEqual(globals, beforeGlobals)
    }

    func testPublicSchedulerRollsBackWhenSecondSoundObserverFails() throws {
        var actor = try OriginalStateRecord.actor(over: [UInt8](repeating: 0xa5, count: OriginalStateRecord.actorSize))
        var globals = try zero(OriginalMatchPreparation.globalSize)
        try actor.write(Int32(2), at: 0x74)
        try actor.write(Int32(10), at: 0xec)
        try actor.write(Int32(200), at: 0x10)
        var first = try zero(0x178), second = try zero(0x178), previous = try zero(0x178)
        for offset in [8, 0x174] { try first.write(Int32(offset == 8 ? 3 : 7), at: offset) }
        try first.write(Int32(1), at: 0x10)
        try second.write(Int32(3), at: 8)
        try second.write(Int32(7), at: 0x174)
        try previous.write(Int32(3), at: 8)
        let object = try OriginalLoadedObject(header: zero(0x7a4), nameTail: zero(0x3c), frames: [],
                                             frameStorage: [first, second, previous], weaponSoundPaths: [:])
        let beforeActor = actor, beforeGlobals = globals
        var sounds: [OriginalActorScheduleEvent] = []
        XCTAssertThrowsError(try OriginalActorScheduler.apply(actor: &actor, object: object, globals: &globals,
            mode: 0, slot: 0, observe: { event in
                sounds.append(event)
                if sounds.count == 2 { throw OriginalStateError.invalidStorage("Late observer failure") }
            }))
        XCTAssertEqual(sounds, [.catalogSound(x: 200, index: 7), .catalogSound(x: 200, index: 7)])
        XCTAssertEqual(actor, beforeActor)
        XCTAssertEqual(globals, beforeGlobals)
    }
}
