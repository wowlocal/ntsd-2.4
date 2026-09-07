import Foundation
import XCTest
@testable import NTSDCore

final class OriginalStateTests: XCTestCase {
    private struct Corpus: Decodable { let exeSHA256: String; let cases: [Case] }
    private struct Case: Decodable {
        let kind: String, label: String, initial: String, bytes: String
        let defined: [Bool]
    }

    private func hex(_ text: String) throws -> [UInt8] {
        let chars = Array(text.utf8)
        guard chars.count % 2 == 0 else { throw OriginalStateError.invalidStorage("Odd hexadecimal length") }
        return try stride(from: 0, to: chars.count, by: 2).map {
            try XCTUnwrap(UInt8(String(decoding: chars[$0..<($0 + 2)], as: UTF8.self), radix: 16))
        }
    }

    func testOriginalConstructorBytesAndWriteMasks() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "original-state-constructors", withExtension: "json", subdirectory: "Fixtures"))
        let corpus = try JSONDecoder().decode(Corpus.self, from: Data(contentsOf: url))
        XCTAssertEqual(corpus.exeSHA256, "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        XCTAssertEqual(corpus.cases.count, 16)
        for item in corpus.cases {
            let initial = try hex(item.initial)
            let actual: OriginalStateRecord
            switch item.kind {
            case "actor": actual = try .actor(over: initial)
            case "world": actual = try .worldPrefix(over: initial)
            default: throw OriginalStateError.invalidStorage("Unknown constructor")
            }
            let expected = try hex(item.bytes)
            XCTAssertEqual(actual.bytes.count, expected.count, item.label)
            XCTAssertEqual(actual.defined.count, item.defined.count, item.label)
            if let offset = actual.bytes.indices.first(where: {
                actual.bytes[$0] != expected[$0] || actual.defined[$0] != item.defined[$0]
            }) {
                XCTFail("\(item.label): first byte or initialization mismatch at +0x\(String(offset, radix: 16))")
            }
        }
    }

    func testUntouchedBytesNeedExplicitInitializationBeforeTypedReads() throws {
        // A zero backing byte is not evidence that the constructor initialized Object*.
        var actor = try OriginalStateRecord.actor(over: Array(repeating: 0, count: OriginalStateRecord.actorSize))
        XCTAssertThrowsError(try actor.integer(at: 0x368, as: UInt32.self))
        XCTAssertThrowsError(try actor.integer(at: 0x80, as: UInt32.self)) // facing byte + padding
        XCTAssertEqual(try actor.integer(at: 0x80, as: UInt8.self), 0)
        try actor.write(UInt32(0x81234567), at: 0x368)
        XCTAssertEqual(try actor.integer(at: 0x368, as: UInt32.self), 0x81234567)
        XCTAssertThrowsError(try actor.integer(at: 0x370, as: UInt32.self))
        let world = try OriginalStateRecord.worldPrefix(over: Array(repeating: 0, count: OriginalStateRecord.worldPrefixSize))
        XCTAssertThrowsError(try world.integer(at: 0x194, as: UInt32.self))
        XCTAssertThrowsError(try world.integer(at: 0x7d4, as: UInt32.self))
    }

    func testNumericViewsPreserveBitsAndRejectOutOfBoundsAtomically() throws {
        var record = try OriginalStateRecord(bytes: Array(repeating: 0, count: 8), defined: Array(repeating: false, count: 8))
        // Signed zero, subnormal, infinity, a NaN payload, and constructor 0.1.
        for bits: UInt64 in [0x8000000000000000, 1, 0x7ff0000000000000, 0x7ff8123456789abc, 0x3fb999999999999a] {
            try record.write(bits, at: 0)
            XCTAssertEqual(try record.binary64(at: 0).bitPattern, bits)
            try record.writeBinary64(Double(bitPattern: bits), at: 0)
            XCTAssertEqual(try record.integer(at: 0, as: UInt64.self), bits)
        }
        try record.write(UInt64(0x89abcdef8012ff80), at: 0)
        XCTAssertEqual(try record.integer(at: 0, as: Int8.self), -128)
        XCTAssertEqual(try record.integer(at: 1, as: Int8.self), -1)
        XCTAssertEqual(try record.integer(at: 0, as: UInt16.self), 0xff80)
        XCTAssertEqual(try record.integer(at: 2, as: Int16.self), Int16(bitPattern: 0x8012))
        XCTAssertEqual(try record.integer(at: 4, as: Int32.self), Int32(bitPattern: 0x89abcdef))
        let prior = record
        for offset in [-1, 5, Int.max] {
            XCTAssertThrowsError(try record.write(UInt32(0), at: offset))
            XCTAssertEqual(record, prior)
            XCTAssertThrowsError(try record.integer(at: offset, as: UInt32.self))
        }
        XCTAssertThrowsError(try OriginalStateRecord.actor(over: Array(repeating: 0, count: 0x500)))
        XCTAssertThrowsError(try OriginalStateRecord(bytes: [0], defined: []))
    }
}
