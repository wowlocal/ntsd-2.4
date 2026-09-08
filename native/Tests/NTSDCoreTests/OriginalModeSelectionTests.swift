import Foundation
import XCTest
import NTSDReferenceChecks

final class OriginalModeSelectionTests: XCTestCase {
    private func compare(_ control: Bool) throws {
        let name = "original-mode-selection"+(control ? "-control" : "")
        let url = try XCTUnwrap(Bundle.module.url(forResource: name,withExtension: "json",subdirectory: "Fixtures"))
        let result = try ModeSelectionReference.compare(Data(contentsOf: url))
        XCTAssertEqual(result.cases,1345)
        XCTAssertEqual(result.input,616)
        XCTAssertEqual(result.selections,729)
        XCTAssertEqual(result.playback,23)
        XCTAssertEqual(result.events,1813)
        XCTAssertEqual(result.helpers,2159)
        XCTAssertEqual(result.records,20175)
        XCTAssertEqual(result.bytes,88_382_640)
    }
    func testOriginalMenuPriorityHoldAliasesAndModeTransitions() throws { try compare(false) }
    func testSameMechanismsWithRampBackingAndReverseActorAddresses() throws { try compare(true) }
}
