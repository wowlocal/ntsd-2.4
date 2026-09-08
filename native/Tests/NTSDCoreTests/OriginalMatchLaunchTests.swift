import Foundation
import XCTest
import NTSDReferenceChecks

final class OriginalMatchLaunchTests: XCTestCase {
    private func compare(_ control: Bool) throws {
        let suffix = control ? "-control" : ""
        func fixture(_ name: String) throws -> Data {
            let url = try XCTUnwrap(Bundle.module.url(forResource:"original-"+name+suffix,withExtension:"json",subdirectory:"Fixtures"))
            return try Data(contentsOf:url)
        }
        let r = try MatchLaunchReference.compare(launch:fixture("match-launch"),selection:fixture("match-selection"),character:fixture("character-screen"),cycle:fixture("menu-cycle"),
            returning:fixture("menu-return"),screen:fixture("mode-screen"),startup:fixture("menu-startup"),menu:fixture("menu-loading"),loading:fixture("menu-loading-state"),
            catalog:fixture("menu-loading-catalog"),sounds:fixture("menu-loading-sounds"))
        XCTAssertEqual(r.cases,8)
        XCTAssertEqual(r.parent.cases,50)
        XCTAssertEqual(r.parent.returns,49)
        XCTAssertEqual(r.parent.parent.cases,34)
        XCTAssertEqual(r.parent.parent.parent.cases,4)
        XCTAssertEqual(r.parent.parent.parent.parent.cases,95)
        XCTAssertEqual(r.parent.parent.parent.parent.parent.cases,632)
    }
    func testOwnStartThroughEnabledMusicAndRecordingToFirstGameplayEntry() throws { try compare(false) }
    func testSameWholeLaunchWithRampAndReverseActorAddresses() throws { try compare(true) }
}
