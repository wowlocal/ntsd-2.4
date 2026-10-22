import Foundation
import XCTest
@testable import RandoriCore

/// MEMORY_LOADING L18: the catalog attempt's overlap test by binary search
/// answers what the scan over every range answered, base ranges empty or
/// overlapping included.
final class OriginalAllocationRangesTests: XCTestCase {
    struct SplitMix { var state: UInt64; mutating func next(_ n: UInt64) -> UInt64 {
        state &+= 0x9e3779b97f4a7c15; var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9; z = (z ^ (z >> 27)) &* 0x94d049bb133111eb; return (z ^ (z >> 31)) % n
    } }

    func testOverlapMatchesTheScan() {
        var rng = SplitMix(state: 18)
        for round in 0..<300 {
            let span = UInt64([64, 1000, 1 << 20][round % 3])
            var base: [(UInt64, UInt64)] = []
            for _ in 0..<rng.next(12) {
                let lo = 1 + rng.next(span), count = rng.next(4) == 0 ? 0 : 1 + rng.next(span / 8)
                base.append((lo, lo + count))
            }
            var ranges = OriginalAllocationRanges(base: base), all = base
            for _ in 0..<400 {
                let lo = 1 + rng.next(span), hi = lo + 1 + rng.next(span / 16)
                let expected = all.contains { lo < $0.1 && $0.0 < hi }
                XCTAssertEqual(ranges.overlaps(lo, hi), expected, "round \(round) \(lo)..<\(hi)")
                if !expected { ranges.insert(lo, hi); all.append((lo, hi)) }
            }
        }
    }

    func testAnEmptyBaseRangeInsideCounts() {
        let ranges = OriginalAllocationRanges(base: [(100, 100), (300, 400), (350, 360)])
        XCTAssertTrue(ranges.overlaps(50, 150)); XCTAssertFalse(ranges.overlaps(100, 150)); XCTAssertFalse(ranges.overlaps(50, 100))
        XCTAssertTrue(ranges.overlaps(399, 401)); XCTAssertFalse(ranges.overlaps(200, 300)); XCTAssertFalse(ranges.overlaps(400, 500))
        XCTAssertTrue(ranges.overlaps(361, 362))
    }
}
