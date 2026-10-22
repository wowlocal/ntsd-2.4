import Foundation
import XCTest
@testable import RandoriCore

/// MEMORY_LOADING M6: the stage table's slots share one paged backing; a slot
/// the loader fills becomes flat with the same contents. Representation never
/// changes contents, errors or equality.
final class OriginalPagedStageTests: XCTestCase {
    func record(_ count: Int, seed: UInt64) throws -> OriginalStateRecord {
        var state = seed, bytes = [UInt8](), defined = [Bool]()
        for _ in 0..<count {
            state &+= 0x9e3779b97f4a7c15; var z = state
            z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9; z = (z ^ (z >> 27)) &* 0x94d049bb133111eb; z ^= z >> 31
            bytes.append(UInt8(truncatingIfNeeded: z)); defined.append(z & 0x100 != 0)
        }
        return try OriginalStateRecord(bytes: bytes, defined: defined)
    }

    func testPagedAndUnpagedKeepContentsAndEquality() throws {
        for count in [1, 100, 16_384, 16_385, 300_000] {
            let flat = try record(count, seed: UInt64(count))
            let paged = flat.paged(), back = paged.unpaged()
            XCTAssertNil(paged.storageIdentity); XCTAssertNotNil(back.storageIdentity)
            XCTAssertEqual(paged, flat); XCTAssertEqual(back, flat); XCTAssertEqual(paged.bytes, flat.bytes); XCTAssertEqual(paged.defined, flat.defined)
            XCTAssertEqual(paged.byteCount, count)
            for offset in [0, count / 2, count - 1] {
                XCTAssertEqual(paged.byte(at: offset), flat.byte(at: offset)); XCTAssertEqual(paged.isDefined(at: offset), flat.isDefined(at: offset))
            }
            // Typed reads give the same values and the same errors (undefined
            // bytes included), and a write to a copy changes that copy only, as
            // on the flat record, across page (16 KiB) and group (256 KiB) edges.
            for offset in [0, count / 2, 16_382, 262_142, count - 4] where offset >= 0 && offset + 4 <= count {
                let pagedValue = Result { try paged.integer(at: offset, as: UInt32.self) }
                let flatValue = Result { try flat.integer(at: offset, as: UInt32.self) }
                switch (pagedValue, flatValue) {
                case (.success(let x), .success(let y)): XCTAssertEqual(x, y)
                case (.failure(let x), .failure(let y)): XCTAssertEqual("\(x)", "\(y)")
                default: XCTFail("count \(count) offset \(offset): \(pagedValue) against \(flatValue)")
                }
                var a = paged, b = flat
                try a.write(UInt32(0xdeadbeef), at: offset); try b.write(UInt32(0xdeadbeef), at: offset)
                XCTAssertTrue(a.unpaged() == b, "count \(count) offset \(offset)"); XCTAssertEqual(try a.integer(at: offset, as: UInt32.self), 0xdeadbeef)
                XCTAssertTrue(paged.unpaged() == flat); XCTAssertFalse(a.unpaged() == flat)
            }
            var a = paged, b = flat
            // An out-of-range write fails alike on both.
            let pagedWrite = Result { try a.write(UInt32(1), at: count - 3) }, flatWrite = Result { try b.write(UInt32(1), at: count - 3) }
            guard case .failure(let pagedError) = pagedWrite, case .failure(let flatError) = flatWrite else { XCTFail("count \(count)"); continue }
            XCTAssertEqual("\(pagedError)", "\(flatError)")
        }
        let empty = try OriginalStateRecord(bytes: [], defined: [])
        XCTAssertEqual(empty.paged(), empty); XCTAssertEqual(empty.unpaged(), empty)
    }

    func testAPagedStageTableLoadsLikeAFlatOne() throws {
        let size = OriginalStageLoader.stageSize
        let backing = try OriginalStateRecord(bytes: (0..<size).map { UInt8(truncatingIfNeeded: $0 &* 7) }, defined: Array(repeating: false, count: size))
        let text = "<stage> id: 3 <phase> bound: 10 id: 5 hp: 10 ratio: 0.5 <boss> <phase_end> <phase> music: bgm\\stage.wma id: 6 <soldier> when_clear_goto_phase: 0 <phase_end> <stage_end> <stage> id: 41 <stage_end>"
        var flat = try OriginalStageLoader(backing: Array(repeating: backing, count: 60))
        var paged = try OriginalStageLoader(backing: Array(repeating: backing.paged(), count: 60))
        var flatCheckpoints: [String] = [], pagedCheckpoints: [String] = []
        try flat.load(decoded: text) { kind, stage, phase, record in flatCheckpoints.append("\(kind) \(stage) \(phase ?? -1) \(record.bytes.hashValue)") }
        try paged.load(decoded: text) { kind, stage, phase, record in pagedCheckpoints.append("\(kind) \(stage) \(phase ?? -1) \(record.bytes.hashValue)") }
        XCTAssertEqual(pagedCheckpoints, flatCheckpoints)
        // Compared flat (memcmp; a paged and a flat record compare through
        // whole arrays, which the records would keep).
        for slot in 0..<60 { XCTAssertTrue(paged.records[slot].unpaged() == flat.records[slot], "slot \(slot)") }
        for slot in 0..<60 {
            // Filled slots are flat; the others still page their shared backing.
            XCTAssertEqual(paged.records[slot].storageIdentity != nil, slot == 3 || slot == 41, "slot \(slot)")
        }
        // An unsupported stream fails the same way and commits nothing.
        let bad = "<stage> id: 2 <stage_end> <stage> id: 60 <stage_end>"
        var flatBad = flat, pagedBad = paged
        let flatLoad = Result { try flatBad.load(decoded: bad) }, pagedLoad = Result { try pagedBad.load(decoded: bad) }
        guard case .failure(let flatError) = flatLoad, case .failure(let pagedError) = pagedLoad else { return XCTFail("both loads must fail") }
        XCTAssertEqual("\(pagedError)", "\(flatError)")
        for slot in 0..<60 { XCTAssertTrue(pagedBad.records[slot].unpaged() == paged.records[slot].unpaged(), "slot \(slot)") }
    }
}
