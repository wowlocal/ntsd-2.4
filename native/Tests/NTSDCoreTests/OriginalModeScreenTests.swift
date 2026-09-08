import Foundation
import XCTest
import NTSDReferenceChecks

final class OriginalModeScreenTests: XCTestCase {
    private func compare(_ control: Bool) throws {
        let suffix = control ? "-control" : ""
        func fixture(_ name: String) throws -> Data {
            let url = try XCTUnwrap(Bundle.module.url(forResource: "original-"+name+suffix,withExtension: "json",subdirectory: "Fixtures"))
            return try Data(contentsOf: url)
        }
        let result = try ModeScreenReference.compare(screen: fixture("mode-screen"),startup: fixture("menu-startup"),menu: fixture("menu-loading"),
            loading: fixture("menu-loading-state"),catalog: fixture("menu-loading-catalog"),sounds: fixture("menu-loading-sounds"))
        XCTAssertEqual(result.parent.parent.menu.cases,119)
        XCTAssertEqual(result.parent.constructors,11)
        XCTAssertEqual(result.cases,632)
        XCTAssertGreaterThan(result.keys,256)
        XCTAssertGreaterThan(result.backgrounds,13)
        XCTAssertGreaterThan(result.playback,0)
    }
    func testOwnStartupContinuesThroughFullModeScreenAndSharedHelpers() throws { try compare(false) }
    func testModeScreenWithRampBackingAndReverseOriginalAddresses() throws { try compare(true) }
}
