import Foundation
import XCTest
import NTSDReferenceChecks

/// Both accepted 437860 corpora (startup precision and 64-bit control
/// loading) replayed against OriginalMissionStage with exact masks.
final class OriginalMissionStageTests: XCTestCase {
    private func compare(_ suffix: String) throws {
        func fixture(_ name: String) throws -> Data {
            let url = try XCTUnwrap(Bundle.module.url(forResource: name+suffix,withExtension: "json",subdirectory: "Fixtures"))
            return try Data(contentsOf: url)
        }
        let r = try MissionStageReference.compare(input: fixture("original-mission-stage"),loading: fixture("original-initial-loading"),
            catalog: fixture("original-initial-loading-catalog"),sounds: fixture("original-initial-loading-sounds"))
        XCTAssertTrue(r.strict)
        XCTAssertEqual(r.initial.catalog.catalog.objects,137)
        XCTAssertGreaterThan(r.random,0); XCTAssertGreaterThan(r.calls,0); XCTAssertGreaterThan(r.constructors,0)
        XCTAssertEqual(Set(r.families.keys),["start","phase","banner","end","bound","set","pressure","survival","refill"])
    }
    func testMissionStageAtStartupPrecision() throws { try compare("") }
    func testMissionStageAt64BitPrecision() throws { try compare("-control") }
}
