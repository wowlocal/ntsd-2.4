import Foundation
import XCTest
import NTSDReferenceChecks

final class OriginalMenuCycleTests: XCTestCase {
    private func compare(_ control: Bool) throws {
        let suffix = control ? "-control" : ""
        func fixture(_ name: String) throws -> Data {
            let url = try XCTUnwrap(Bundle.module.url(forResource: "original-"+name+suffix,withExtension: "json",subdirectory: "Fixtures"))
            return try Data(contentsOf: url)
        }
        let r = try MenuCycleReference.compare(cycle: fixture("menu-cycle"),returning: fixture("menu-return"),screen: fixture("mode-screen"),
            startup: fixture("menu-startup"),menu: fixture("menu-loading"),loading: fixture("menu-loading-state"),catalog: fixture("menu-loading-catalog"),sounds: fixture("menu-loading-sounds"))
        XCTAssertEqual(r.parent.cases,95)
        XCTAssertEqual(r.parent.parent.cases,632)
        XCTAssertEqual(r.cases,4)
        XCTAssertEqual(r.returns,3)
    }
    func testOwnOuterCallsAcquireKeyboardOnOriginalPhaseAndConfirmVS() throws { try compare(false) }
    func testSameSequenceWithRampBackingAndReverseActorAddresses() throws { try compare(true) }
}
