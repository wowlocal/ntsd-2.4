import Foundation
import XCTest
@testable import NTSDCore

/// `byte(at:)` and `isDefined(at:)` (CORE_REALTIME tier 3 S2a) equal
/// indexing the whole `bytes` and `defined` for flat, paged and parted records.
final class OriginalStateRecordNarrowReadTests: XCTestCase {
    private func contents(_ count: Int, seed: UInt64) -> ([UInt8], [Bool]) {
        var x = seed, bytes = [UInt8](repeating: 0, count: count), defined = [Bool](repeating: false, count: count)
        for i in 0..<count {
            x = x &* 6364136223846793005 &+ 1442695040888963407
            bytes[i] = UInt8(truncatingIfNeeded: x >> 33)
            defined[i] = (x >> 61) != 0
        }
        return (bytes, defined)
    }

    func testNarrowReadsMatchWholeArrays() throws {
        var records: [(String, OriginalStateRecord)] = []
        for count in [1, 0x178, 0x420, 0xc3a8, OriginalReplayRecording.byteCount] {
            let (bytes, defined) = contents(count, seed: UInt64(count))
            records.append(("\(count)", try OriginalStateRecord(bytes: bytes, defined: defined)))
        }
        let (bytes, defined) = contents(0xc3a8, seed: 9)
        records.append(("parted", try OriginalStateRecord(bytes: bytes, defined: defined).partitioned(at: [0, 0xb440, 0xb580])))
        for (name, record) in records {
            let all = record.bytes, mask = record.defined
            let n = record.byteCount
            var indices = Array(Set([0, n - 1, n / 2, 0x3fff, 0x4000, 0x3ffff, 0x40000, 0xb43f, 0xb440, 0xb57f, 0xb580].filter { $0 >= 0 && $0 < n }))
            indices += stride(from: 0, to: n, by: max(1, n / 997)).map { $0 }
            for i in indices {
                XCTAssertEqual(record.byte(at: i), all[i], "\(name) byte \(i)")
                XCTAssertEqual(record.isDefined(at: i), mask[i], "\(name) defined \(i)")
            }
        }
    }
}
