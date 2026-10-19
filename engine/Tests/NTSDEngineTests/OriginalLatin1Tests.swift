import XCTest
@testable import NTSDCore

/// MEMORY_LOADING L7: Latin-1 text converts to the same Strings and bytes as
/// building them scalar by scalar.
final class OriginalLatin1Tests: XCTestCase {
    func scalarString(_ bytes: [UInt8]) -> String { String(String.UnicodeScalarView(bytes.map { UnicodeScalar($0) })) }

    func testEveryByteAndMixedTextConvertAsScalars() {
        var cases: [[UInt8]] = [[], Array("<frame> 0 standing".utf8), (0...255).map { UInt8($0) }, [0], [0x7f, 0x80, 0xff, 0x41],
                                Array("name: deep\r\n\t<frame> 1 punch\r\n   pic: 3\n\0end\r\r\n".utf8)]
        var state: UInt64 = 0x9e3779b97f4a7c15
        for length in 0..<300 {
            cases.append((0..<length).map { _ in state = state &* 0x5851f42d4c957f2d &+ 1; return UInt8(truncatingIfNeeded: state >> 56) })
            cases.append((0..<length).map { _ in state = state &* 0x5851f42d4c957f2d &+ 1; return UInt8(truncatingIfNeeded: state >> 58) + 0x20 })
        }
        for bytes in cases {
            let expected = scalarString(bytes), text = OriginalLatin1.string(bytes)
            XCTAssertEqual(text, expected); XCTAssertEqual(Array(text.unicodeScalars), Array(expected.unicodeScalars))
            XCTAssertEqual(OriginalLatin1.string(bytes[...]), expected)
            XCTAssertEqual(OriginalLatin1.bytes(text), bytes); XCTAssertEqual(OriginalLatin1.bytes(expected), bytes)
        }
        XCTAssertNil(OriginalLatin1.bytes("a\u{100}")); XCTAssertNil(OriginalLatin1.bytes("\u{1F600}"))
        XCTAssertEqual(OriginalLatin1.bytes("e\u{301}"), nil)   // a combining scalar above 255 stays outside the domain
    }
}
