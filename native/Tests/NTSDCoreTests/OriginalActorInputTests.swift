import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalActorInputTests: XCTestCase {
    private struct Patch: Decodable {
        let offset: Int, bytes: String
        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            offset = try c.decode(Int.self); bytes = try c.decode(String.self)
        }
    }
    private struct FramePatch: Decodable {
        let index: Int32, offset: Int, bytes: String
        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            index = try c.decode(Int32.self); offset = try c.decode(Int.self); bytes = try c.decode(String.self)
        }
    }
    private struct Case: Decodable {
        let label: String, operation: String, fill: String, after: String, defined: String
        let actor: [Patch], frames: [FramePatch]?, globals: [[Int32]]
        let sourceID: Int32?, target: Int32?, key: UInt8?, advanced: Int32?, result: UInt32?
    }
    private struct Corpus: Decodable { let exeSHA256: String, cases: [Case] }

    private func hex(_ text: String) throws -> [UInt8] {
        let bytes = Array(text.utf8)
        guard bytes.count%2 == 0 else { throw OriginalStateError.invalidStorage("Odd hex length") }
        return try stride(from: 0, to: bytes.count, by: 2).map {
            try XCTUnwrap(UInt8(String(decoding: bytes[$0..<$0+2], as: UTF8.self), radix: 16))
        }
    }
    private func patch(_ record: inout OriginalStateRecord, _ offset: Int, _ text: String) throws {
        for (index, byte) in try hex(text).enumerated() { try record.write(byte, at: offset+index) }
    }

    func testOriginalGenericInputBuffersCombosAndFrameTransfers() throws {
        let url: URL
        if let path = ProcessInfo.processInfo.environment["NTSD_ACTOR_INPUT_CORPUS"] { url = URL(fileURLWithPath: path) }
        else { url = try XCTUnwrap(Bundle.module.url(forResource: "original-actor-input", withExtension: "json", subdirectory: "Fixtures")) }
        let raw = try MatchPreparationReference.unpack(Data(contentsOf: url), maximumCount: 128_000_000)
        let corpus = try JSONDecoder().decode(Corpus.self, from: raw)
        XCTAssertEqual(corpus.exeSHA256, "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        XCTAssertEqual(corpus.cases.count, 14624)
        let emptyFrame = try OriginalStateRecord(bytes: [UInt8](repeating: 0, count: 0x178), defined: [Bool](repeating: true, count: 0x178))
        for item in corpus.cases {
            var actor = try OriginalStateRecord.actor(over: (0..<OriginalStateRecord.actorSize).map { item.fill == "a5" ? 0xa5 : UInt8(truncatingIfNeeded: $0) })
            for p in item.actor { try patch(&actor, p.offset, p.bytes) }
            var frames: [Int32:OriginalStateRecord] = [:]
            for index: Int32 in [0,2,3,300] {
                var record = emptyFrame
                try record.write(UInt8(1), at: 0)
                if index == 2 { try record.write(Int32(100), at: 0x4c) }
                if index == 3 { try record.write(Int32(20), at: 0x4c) }
                frames[index] = record
            }
            for p in item.frames ?? [] {
                var record = frames[p.index] ?? emptyFrame
                try patch(&record, p.offset, p.bytes); frames[p.index] = record
            }
            func frame(_ index: Int32) throws -> OriginalStateRecord {
                guard (0..<400).contains(index) else { throw OriginalStateError.invalidStorage("Probe frame index") }
                return frames[index] ?? emptyFrame
            }
            var globals = try OriginalStateRecord(bytes: [UInt8](repeating: 0, count: OriginalMatchPreparation.globalSize),
                defined: [Bool](repeating: true, count: OriginalMatchPreparation.globalSize))
            for p in item.globals { try globals.write(p[1], at: Int(p[0])-OriginalMatchPreparation.globalBase) }
            switch item.operation {
            case "edges": try OriginalActorInput.captureEdges(actor: &actor)
            case "combos": try OriginalActorInput.recognizeCombos(actor: &actor, sourceID: item.sourceID ?? 2, globals: globals, frame: frame)
            case "actions": try OriginalActorInput.applyFrameInput(actor: &actor, globals: globals, frame: frame)
            case "prefix": try OriginalActorInput.apply(actor: &actor, sourceID: item.sourceID ?? 2, globals: globals, frame: frame)
            case "transfer": try OriginalActorInput.transfer(actor: &actor, target: XCTUnwrap(item.target), globals: globals, frame: frame)
            case "invalidates":
                let result = try OriginalActorInput.invalidates(actor: actor, key: XCTUnwrap(item.key), advanced: XCTUnwrap(item.advanced))
                XCTAssertEqual(result ? UInt32(1) : 0, item.result, item.label)
            default: XCTFail("Unknown operation: \(item.operation)"); return
            }
            let expected = try hex(item.after), mask = try hex(item.defined).map { $0 != 0 }
            guard actor.bytes == expected && actor.defined == mask else {
                let offset = try XCTUnwrap(actor.bytes.indices.first { actor.bytes[$0] != expected[$0] || actor.defined[$0] != mask[$0] })
                XCTFail("\(item.label): byte/mask at +\(String(offset, radix: 16)): \(actor.bytes[offset])/\(actor.defined[offset]) != \(expected[offset])/\(mask[offset])")
                return
            }
        }
    }

    func testUnsupportedTransferRollsBackEarlierEdgesAndHistory() throws {
        var actor = try OriginalStateRecord.actor(over: [UInt8](repeating: 0xa5, count: OriginalStateRecord.actorSize))
        try actor.write(UInt8(1), at: 0xd1)
        let before = actor
        let globals = try OriginalStateRecord(bytes: [UInt8](repeating: 0, count: OriginalMatchPreparation.globalSize),
            defined: [Bool](repeating: true, count: OriginalMatchPreparation.globalSize))
        var current = try OriginalStateRecord(bytes: [UInt8](repeating: 0, count: 0x178), defined: [Bool](repeating: true, count: 0x178))
        try current.write(Int32(400), at: 0x24)
        XCTAssertThrowsError(try OriginalActorInput.apply(actor: &actor, sourceID: 2, globals: globals, frame: { index in
            guard index == 0 else { throw OriginalStateError.invalidStorage("Unresolved frame") }
            return current
        }))
        XCTAssertEqual(actor, before)
    }
}
