import XCTest
@testable import RandoriCore

/// MEMORY_LOADING L10: text-mode translation gives the same bytes as the
/// per-byte definitions it replaced.
final class OriginalFileTranslationTests: XCTestCase {
    func modelRead(_ bytes: [UInt8]) -> [UInt8] {
        var output: [UInt8] = [], index = 0
        while index < bytes.count, bytes[index] != 0x1a {
            if bytes[index] == 13, index + 1 < bytes.count, bytes[index + 1] == 10 { index += 1 }
            output.append(bytes[index]); index += 1
        }
        return output
    }
    func modelWrite(_ bytes: [UInt8]) -> [UInt8] { bytes.flatMap { $0 == 10 ? [13, 10] : [$0] } }

    func testTextTranslationMatchesThePerByteDefinitions() {
        var state: UInt64 = 1
        var cases: [[UInt8]] = [[], [10], [13], [13, 10], [10, 13], [0x1a], [65, 0x1a, 66], [13, 13, 10, 10], [13, 0x1a, 10]]
        for length in 0..<400 {
            cases.append((0..<length).map { _ in
                state = state &* 6364136223846793005 &+ 1442695040888963407
                return [10, 13, 0x1a, 65, 0, 255][Int(state >> 61) % 6]
            })
        }
        for bytes in cases {
            XCTAssertEqual(OriginalFileTranslation.text.read(bytes), modelRead(bytes), "\(bytes)")
            XCTAssertEqual(OriginalFileTranslation.text.write(bytes), modelWrite(bytes), "\(bytes)")
            XCTAssertEqual(OriginalFileTranslation.raw.read(bytes), bytes); XCTAssertEqual(OriginalFileTranslation.raw.write(bytes), bytes)
        }
    }
}
