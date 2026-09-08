import Foundation
import XCTest
import NTSDReferenceChecks

final class OriginalMenuReturnTests: XCTestCase {
    private func compare(_ control: Bool) throws {
        let suffix = control ? "-control" : ""
        func fixture(_ name: String) throws -> Data {
            let url = try XCTUnwrap(Bundle.module.url(forResource: "original-"+name+suffix,withExtension: "json",subdirectory: "Fixtures"))
            return try Data(contentsOf: url)
        }
        let r = try MenuReturnReference.compare(returning: fixture("menu-return"),screen: fixture("mode-screen"),startup: fixture("menu-startup"),
            menu: fixture("menu-loading"),loading: fixture("menu-loading-state"),catalog: fixture("menu-loading-catalog"),sounds: fixture("menu-loading-sounds"))
        XCTAssertEqual(r.parent.cases,632)
        XCTAssertEqual(r.parent.parent.parent.menu.cases,119)
        XCTAssertEqual(r.cases,95)
        XCTAssertEqual(r.checkpoints,193)
        XCTAssertGreaterThan(r.draws,0)
    }
    func testOwnModeScreenReturnsThroughMenuMatchAndEarlyDispatcher() throws { try compare(false) }
    func testSameReturnsWithRampBackingAndOriginalReverseAddresses() throws { try compare(true) }
}
