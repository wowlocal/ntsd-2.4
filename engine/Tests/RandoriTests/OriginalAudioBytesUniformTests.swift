import Foundation
import XCTest
@testable import RandoriCore

/// MEMORY_LOADING M5b: audio bytes that are one value repeated, all defined
/// or all undefined, are kept as that value; contents, equality and coding
/// are those of the arrays.
final class OriginalAudioBytesUniformTests: XCTestCase {
    /// The previous stored form, with synthesized coding.
    struct Arrays: Codable, Equatable { let bytes: [UInt8], defined: [Bool] }

    func testUniformBuffersKeepTheirContents() throws {
        for count in [1, 2, 7, 8, 9, 15, 16, 17, 1000] {
            for defined in [false, true] {
                let record = try OriginalStateRecord(bytes: Array(repeating: 0xa5, count: count), defined: Array(repeating: defined, count: count))
                XCTAssertNotNil(record.uniformContents()); XCTAssertEqual(record.uniformContents()?.1, defined)
                let audio = OriginalAudioBytes(record)
                XCTAssertEqual(audio.count, count); XCTAssertEqual(audio.bytes, record.bytes); XCTAssertEqual(audio.defined, record.defined)
                XCTAssertTrue(try audio.record() == record)
                XCTAssertEqual(audio, OriginalAudioBytes(bytes: record.bytes, defined: record.defined))
                // One different byte or one different bit: kept as arrays, same contents.
                for position in Set([0, count / 2, count - 1]) {
                    var bytes = record.bytes, mask = record.defined
                    bytes[position] = 0x5a
                    let byteChanged = try OriginalStateRecord(bytes: bytes, defined: mask)
                    // One byte alone is still one value repeated.
                    if count > 1 { XCTAssertNil(byteChanged.uniformContents()) }
                    XCTAssertEqual(OriginalAudioBytes(byteChanged).bytes, bytes)
                    bytes[position] = 0xa5; mask[position].toggle()
                    let bitChanged = try OriginalStateRecord(bytes: bytes, defined: mask)
                    if count > 1 { XCTAssertNil(bitChanged.uniformContents()) }
                    XCTAssertEqual(OriginalAudioBytes(bitChanged).defined, mask)
                    XCTAssertNotEqual(OriginalAudioBytes(bitChanged), audio)
                }
            }
        }
        let empty = try OriginalStateRecord(bytes: [], defined: [])
        XCTAssertNil(empty.uniformContents())
        XCTAssertEqual(OriginalAudioBytes(empty), OriginalAudioBytes(bytes: [], defined: []))
    }

    func testEqualityAndCodingAreTheArrays() throws {
        let uniform = OriginalAudioBytes(try OriginalStateRecord(bytes: Array(repeating: 7, count: 33), defined: Array(repeating: true, count: 33)))
        let arrays = OriginalAudioBytes(bytes: Array(repeating: 7, count: 33), defined: Array(repeating: true, count: 33))
        XCTAssertEqual(uniform, arrays); XCTAssertEqual(arrays, uniform)
        XCTAssertNotEqual(uniform, OriginalAudioBytes(bytes: Array(repeating: 7, count: 32), defined: Array(repeating: true, count: 32)))
        // Sorted keys: JSONEncoder writes keys in its internal dictionary's hash
        // order, which varies between encodings (ENGINE_SPLIT E4c-1a); the claim
        // is the same JSON as the arrays.
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        let legacy = try encoder.encode(Arrays(bytes: Array(repeating: 7, count: 33), defined: Array(repeating: true, count: 33)))
        XCTAssertEqual(try encoder.encode(uniform), legacy); XCTAssertEqual(try encoder.encode(arrays), legacy)
        let decoded = try JSONDecoder().decode(OriginalAudioBytes.self, from: legacy)
        XCTAssertEqual(decoded, uniform); XCTAssertEqual(decoded.bytes, arrays.bytes)
    }
}
