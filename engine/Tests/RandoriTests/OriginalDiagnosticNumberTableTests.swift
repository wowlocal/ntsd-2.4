import Foundation
import XCTest
@testable import RandoriCore

/// ENGINE_SPLIT E7e-1: the VC80 scaling tables are computed, not copied. Their
/// 42 twelve-byte entries hash to the digest of the pinned DLL's tables (its
/// bytes are not in this repository's engine); the game's diagnostic-number
/// corpus compares the entries themselves with the DLL's.
final class OriginalDiagnosticNumberTableTests: XCTestCase {
    func testComputedTablesMatchThePinnedDLLsDigest() {
        let tables = OriginalDiagnosticNumber.tableHex
        XCTAssertEqual(tables.map(\.count), [21, 21])
        XCTAssertEqual(OriginalDiagnosticNumber.powers, [1, 2, 3, 4, 5, 6, 7, 8, 16, 24, 32, 40, 48, 56, 64, 128, 192, 256, 320, 384, 448])
        let bytes = tables.flatMap { $0 }.flatMap { hex -> [UInt8] in
            let chars = Array(hex.utf8)
            return stride(from: 0, to: chars.count, by: 2).map { UInt8(String(decoding: chars[$0..<$0+2], as: UTF8.self), radix: 16)! }
        }
        XCTAssertEqual(bytes.count, 42*12)
        XCTAssertEqual(PortableSHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined(),
                       "13175ac4fec5e3602495c2164b80050d181c3d0f9b948e48dd524f367b8d5508")
        // Exact powers keep a zero tail: 10 = 0xa / 2^3 × 2^3 and 10^4 = 0x2710 / 2^13
        // × 2^13, their significands 0xa000… and 0x9c40… with exponents 3 and 13.
        func hex(top: UInt16, exponent: Int) -> String {
            let words = [0, 0, 0, 0, top, UInt16(exponent + 0x3fff)]
            return words.map { String(format: "%02x%02x", $0 & 0xff, $0 >> 8) }.joined()
        }
        XCTAssertEqual(tables[0][0], hex(top: 10 << 12, exponent: 3))
        XCTAssertEqual(tables[0][3], hex(top: 10_000 << 2, exponent: 13))
    }
}
