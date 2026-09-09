import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalGameplayOutputTests: XCTestCase {
    private struct Blob: Decodable { let count: Int, deflate: String }
    private struct Storage: Decodable { let bytes: String, defined: String }
    private struct Spec: Decodable { let label: String, results: [Int32]? }
    private struct Case: Decodable {
        let spec: Spec, input: OriginalMenuPresentationInput, globals: String, globalsAfter: String
        let bitmaps: [Storage], events: [OriginalFrontScreenEvent], blits: Int
    }
    private struct Corpus: Decodable {
        let exeSHA256: String, crtSHA256: String, fpcw: Int, bitmapBase: UInt32, cases: [Case], blobs: [String:Blob]
    }

    func testWholeOriginalGameplayOutputAndControlledReturn() throws {
        let url: URL
        if let path = ProcessInfo.processInfo.environment["NTSD_GAMEPLAY_OUTPUT_CORPUS"] { url = URL(fileURLWithPath: path) }
        else { url = try XCTUnwrap(Bundle.module.url(forResource: "original-gameplay-output-controlled", withExtension: "json", subdirectory: "Fixtures")) }
        let corpus = try JSONDecoder().decode(Corpus.self, from: MatchPreparationReference.unpack(Data(contentsOf: url), maximumCount: 192_000_000))
        XCTAssertEqual(corpus.exeSHA256, "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        XCTAssertEqual(corpus.crtSHA256, "c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d")
        XCTAssertEqual(corpus.fpcw, 0x23f); XCTAssertFalse(corpus.cases.isEmpty)
        var cache: [String:[UInt8]] = [:], totalEvents = 0, totalBlits = 0, rollbackTrials = 0
        func blob(_ key: String) throws -> [UInt8] {
            if let value = cache[key] { return value }
            let item = try XCTUnwrap(corpus.blobs[key]), packed = try XCTUnwrap(Data(base64Encoded: item.deflate))
            guard packed.count >= 6, packed[0] == 0x78, packed[1] == 0xda else { throw OriginalStateError.invalidStorage("Output fixture zlib framing") }
            let value = try MatchPreparationReference.inflate(Data(packed.dropFirst(2).dropLast(4)).base64EncodedString(), count: item.count)
            guard MatchPreparationReference.digest(Data(value)) == key else { throw OriginalStateError.invalidStorage("Output fixture SHA") }
            cache[key] = value; return value
        }
        func record(_ key: String) throws -> OriginalStateRecord {
            let bytes = try blob(key); return try .init(bytes: bytes, defined: .init(repeating: true, count: bytes.count))
        }
        for c in corpus.cases {
            let initial = try record(c.globals)
            var globals = initial
            var world = try OriginalStateRecord(bytes: .init(repeating: 0xa5, count: OriginalStateRecord.worldPrefixSize),
                defined: .init(repeating: false, count: OriginalStateRecord.worldPrefixSize))
            let beforeWorld = world
            let pointers = try OriginalStateRecord(bytes: .init(repeating: 0x96, count: 8), defined: .init(repeating: false, count: 8))
            var memory = OriginalMenuPresentationMemory(replayPointers: pointers)
            var bitmaps: [OriginalStateRecord] = [], surfaces: [UInt32] = []
            for b in c.bitmaps {
                let raw = try blob(b.bytes), flags = try blob(b.defined)
                XCTAssertEqual(raw.count, 0x1f50); XCTAssertEqual(flags.count, raw.count)
                let surface = (0..<4).reduce(UInt32(0)) { $0 | UInt32(raw[$1]) << ($1*8) }
                var normalized = raw
                for i in 0..<4 { normalized[i] = i == 0 && surface != 0 ? 1 : 0 }
                bitmaps.append(try .init(bytes: normalized, defined: flags.map { $0 != 0 })); surfaces.append(surface)
            }
            func resource(_ pointer: UInt32) throws -> (OriginalStateRecord, UInt32) {
                guard pointer >= corpus.bitmapBase, (pointer-corpus.bitmapBase)%0x2000 == 0 else { throw OriginalStateError.invalidStorage("Output fixture bitmap binding") }
                let index = Int((pointer-corpus.bitmapBase)/0x2000)
                guard bitmaps.indices.contains(index) else { throw OriginalStateError.invalidStorage("Output fixture bitmap extent") }
                return (bitmaps[index], surfaces[index])
            }
            let results = c.spec.results ?? [-2147467259, 0, -1, 1]
            var events: [OriginalFrontScreenEvent] = [], blits = 0
            try OriginalGameplayOutput.apply(world: &world, globals: &globals, memory: &memory, input: c.input,
                resourceBitmap: resource, performBlit: { _ in
                    defer { blits += 1 }; return results[blits%results.count]
                }, soundRequest: { _ in c.input.methodResult }, observe: { events.append($0) })
            XCTAssertEqual(globals, try record(c.globalsAfter), c.spec.label)
            XCTAssertEqual(world, beforeWorld); XCTAssertEqual(memory.replayPointers, pointers); XCTAssertTrue(memory.allocations.isEmpty)
            XCTAssertEqual(blits, c.blits, c.spec.label)
            guard events == c.events else {
                let index = zip(events,c.events).enumerated().first(where: { $0.element.0 != $0.element.1 })?.offset
                throw OriginalStateError.invalidStorage("Output events differ in \(c.spec.label), index \(index.map(String.init) ?? "count"), native \(events.count), source \(c.events.count): \(index.map { String(describing: events[$0])+" / "+String(describing: c.events[$0]) } ?? "")")
            }
            totalEvents += events.count; totalBlits += blits
            if c.spec.label == "volume-before-sound" {
                var trial = initial, writes = 0, stages: [UInt32] = [], soundMethods = 0
                XCTAssertThrowsError(try OriginalGameplayOutput.apply(world: &world, globals: &trial, memory: &memory,
                    input: c.input, resourceBitmap: resource, performBlit: { _ in 0 }, soundRequest: { event in
                        if event.kind == .method {
                            soundMethods += 1
                            if soundMethods == 8 { throw OriginalStateError.invalidStorage("Late output sound request") }
                        }
                        return 0
                    }, observe: { event in
                        if event.kind == "stage" { stages.append(event.arguments[0]) }
                        if event.kind == "queueWrite" { writes += 1 }
                    })) { error in
                        guard case OriginalStateError.invalidStorage("Late output sound request") = error else { return XCTFail("Unexpected output error: \(error)") }
                    }
                XCTAssertEqual(soundMethods, 8); XCTAssertEqual(writes, 2)
                XCTAssertEqual(stages, [0x41b130,0x4028a0,0x43e940,0x419e60]); XCTAssertEqual(trial, initial)
                XCTAssertEqual(world, beforeWorld); XCTAssertEqual(memory.replayPointers, pointers); XCTAssertTrue(memory.allocations.isEmpty)
                rollbackTrials += 1
            }
        }
        if corpus.cases.count >= 3 { XCTAssertEqual(rollbackTrials, 1) }
        print("GAMEPLAY OUTPUT \(corpus.cases.count) whole controlled returns, \(totalEvents) events, \(totalBlits) Blts, \(rollbackTrials) late rollback trials")
    }
}
