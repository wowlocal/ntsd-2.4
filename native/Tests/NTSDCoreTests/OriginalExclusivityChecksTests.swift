import XCTest

/// Shipping builds may drop Swift's dynamic exclusivity checks (CORE_REALTIME
/// 4aa); a test bundle must keep them, so an overlapping access traps here
/// instead of passing silently.
final class OriginalExclusivityChecksTests: XCTestCase {
    func testBundleKeepsExclusivityChecks() {
        #if NTSD_UNCHECKED_EXCLUSIVITY
        XCTFail("This test bundle was built with NTSD_UNCHECKED_EXCLUSIVITY=1; build tests without it")
        #endif
    }
}
