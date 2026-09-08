import Foundation
import XCTest
import NTSDReferenceChecks

final class OriginalReplayTickTests: XCTestCase {
    private func compare(_ suffix: String) throws {
        func fixture(_ name: String) throws -> Data {
            let url = try XCTUnwrap(Bundle.module.url(forResource: name+suffix,withExtension: "json",subdirectory: "Fixtures"))
            return try Data(contentsOf: url)
        }
        let r = try ReplayTickReference.compare(replay: fixture("original-replay-tick"),control: fixture("original-input-control"),
            local: fixture("original-local-input"),loading: fixture("original-initial-loading"),
            catalog: fixture("original-initial-loading-catalog"),sounds: fixture("original-initial-loading-sounds"))
        XCTAssertEqual(r.cases,1134)
        XCTAssertEqual(r.parent.cases,2993)
        XCTAssertEqual(r.parent.local.cases,303)
        XCTAssertEqual(r.chains,307)
        XCTAssertEqual(r.reads,315)
        XCTAssertEqual(r.writes,513)
        XCTAssertEqual(r.checks,612)
        XCTAssertEqual(r.messages,148)
        XCTAssertEqual(r.events,1673)
    }
    func testReplayTicksAfterOriginalLoadingAndControl() throws { try compare("") }
    func testReplayTicksWithReversePoolAndRampBuffers() throws { try compare("-control") }
}
