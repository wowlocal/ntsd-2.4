import Foundation
import XCTest
import NTSDCore
import NTSDReferenceChecks

final class OriginalGameplayBodyTests: XCTestCase {
    private func compare(_ control: Bool) throws {
        let suffix = control ? "-control" : ""
        func fixture(_ name: String) throws -> Data {
            try Data(contentsOf: XCTUnwrap(Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures")))
        }
        func own(_ name: String) throws -> Data { try fixture("original-"+name+suffix+".json") }
        let result = try InitializedGameplayReference.compare(own("initialized-gameplay"), fixture: fixture,
            postDraw: own("gameplay-lifecycle"), commands: own("gameplay-commands"), hud: own("gameplay-hud"),
            notices: own("gameplay-notices"), resultRecording: own("gameplay-result-recording"),
            resultLayout: own("gameplay-result-layout"), returned: own("gameplay-return"), compareGameplayBody: true)
        XCTAssertEqual(result.gameplay.bodyPasses, 1)
        XCTAssertEqual(result.gameplay.bodyCheckpoints, OriginalGameplayBody.Stage.allCases.count)
        XCTAssertGreaterThan(result.gameplay.bodyEvents, 0)
        XCTAssertEqual(result.gameplay.gameplayReturns, 1)
        XCTAssertEqual(result.fpuCheckpoints, 1614)
    }
    func testWholeBodyOnOwnInitializedMatch() throws { try compare(false) }
    func testWholeBodyOnOwnInitializedMatchWithControlBacking() throws { try compare(true) }
}
