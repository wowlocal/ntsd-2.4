import XCTest
@testable import RandoriCore

/// ENGINE_SPLIT E5c-2a: an ID range answers as the original's `id < lower || id >= upper`
/// does (negated) for every Int32. Synthetic ranges.
final class OriginalIDRangeTests: XCTestCase {
    func testMembershipEqualsTheOriginalComparisons() {
        for (lower,upper) in [(Int32(100),Int32(200)),(Int32.min,Int32(30)),(Int32(30),Int32(50)),(Int32(5),Int32(5)),(Int32(0),Int32.max)] {
            let range = OriginalIDRange(lower..<upper)
            var probes: [Int32] = [Int32.min,Int32.min+1,-1,0,1,Int32.max-1,Int32.max]
            for edge in [lower,upper] { for d: Int32 in [-1,0,1] { let (v,o) = edge.addingReportingOverflow(d);if !o { probes.append(v) } } }
            for id in probes { XCTAssertEqual(range.contains(id),!(id < lower || id >= upper),"\(lower)..<\(upper) \(id)") }
            XCTAssertEqual(range.lowerBound,lower);XCTAssertEqual(range.upperBound,upper)
        }
    }
    func testEqualityFollowsTheBounds() {
        XCTAssertEqual(OriginalIDRange(100..<200),OriginalIDRange(100..<200))
        XCTAssertNotEqual(OriginalIDRange(5..<5),OriginalIDRange(7..<7))
    }
}
