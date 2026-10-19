import Foundation
import XCTest
@testable import NTSDCore

/// MEMORY_LOADING L15: definedness masks are packed and expanded eight bytes
/// at a time; the results equal the per-bit definitions for every length,
/// offset and pattern.
final class OriginalDefinedBitsTests: XCTestCase {
    struct SplitMix { var state: UInt64; mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15; var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9; z = (z ^ (z >> 27)) &* 0x94d049bb133111eb; return z ^ (z >> 31)
    } }

    func testPackAndSpreadMatchTheBitDefinitions() {
        for v in 0...255 {
            let bits = UInt8(v), bools = (0..<8).map { bits & (1 << UInt8($0)) != 0 }
            let word = bools.withUnsafeBytes { $0.loadUnaligned(as: UInt64.self) }
            XCTAssertEqual(OriginalStateRecord.packDefined(word), bits)
            var spread = OriginalStateRecord.spreadDefined(bits)
            XCTAssertEqual(withUnsafeBytes(of: &spread) { Array($0) }, bools.map { $0 ? 1 : 0 })
        }
    }

    func testRecordsKeepEveryDefinednessPattern() throws {
        var rng = SplitMix(state: 15)
        for n in Array(0...70) + [255, 256, 257, 4099] {
            for density in [0, 1, 2, 3] {
                let defined = (0..<n).map { _ -> Bool in
                    switch density { case 0: return false; case 3: return true; default: return rng.next() % UInt64(density + 1) == 0 }
                }
                let bytes = (0..<n).map { _ in UInt8(truncatingIfNeeded: rng.next()) }
                let record = try OriginalStateRecord(bytes: bytes, defined: defined)
                XCTAssertEqual(record.defined, defined, "n \(n) density \(density)")
                XCTAssertEqual(record.bytes, bytes)
                for i in 0..<n where i % 7 == 0 || i == n - 1 { XCTAssertEqual(record.isDefined(at: i), defined[i]) }
                guard n > 0 else { continue }
                for _ in 0..<12 {
                    let a = Int(rng.next() % UInt64(n + 1)), b = Int(rng.next() % UInt64(n + 1))
                    let range = min(a, b)..<max(a, b)
                    XCTAssertEqual(record.extract(range).defined, Array(defined[range]), "n \(n) range \(range)")
                    // Equal to a record made from the slices: the same bytes, bits and zero padding bits.
                    XCTAssertEqual(record.extract(range), try OriginalStateRecord(bytes: Array(bytes[range]), defined: Array(defined[range])))
                    XCTAssertEqual(record.allDefined(in: range), !defined[range].contains(false))
                    // A parted record reads its parts' ranges from mid-byte offsets.
                    if n >= 4 && n < 4099 {
                        let parted = record.partitioned(at: [0, 3, max(4, n / 2)].filter { $0 < n }.reduce(into: [Int]()) { if $1 > ($0.last ?? -1) { $0.append($1) } })
                        XCTAssertEqual(parted.readOnce().defined, defined, "n \(n) parted")
                        XCTAssertEqual(parted.extract(range).defined, Array(defined[range]), "n \(n) parted range \(range)")
                    }
                }
            }
        }
    }
}
