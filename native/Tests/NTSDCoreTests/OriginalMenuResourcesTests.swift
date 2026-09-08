import Foundation
import XCTest
import NTSDReferenceChecks

final class OriginalMenuResourcesTests: XCTestCase {
    private func compare(_ suffix: String) throws {
        func fixture(_ name: String) throws -> Data {
            let url = try XCTUnwrap(Bundle.module.url(forResource: name+suffix,withExtension: "json",subdirectory: "Fixtures"))
            return try Data(contentsOf: url)
        }
        let r = try MenuResourcesReference.compare(resources: fixture("original-menu-resources"),music: fixture("original-music-playback"),
            round: fixture("original-match-round"),replay: fixture("original-replay-tick"),control: fixture("original-input-control"),
            local: fixture("original-local-input"),loading: fixture("original-initial-loading"),catalog: fixture("original-initial-loading-catalog"),sounds: fixture("original-initial-loading-sounds"))
        XCTAssertEqual(r.cases,187)
        XCTAssertEqual(r.constructors,1049)
        XCTAssertEqual(r.allocations,1122)
        XCTAssertEqual(r.nullAllocations,73)
        XCTAssertEqual(r.checkpoints,1688)
        XCTAssertEqual(r.events,4468)
        XCTAssertEqual(r.messages,97)
        XCTAssertEqual(r.releases,51)
        XCTAssertEqual(r.nullSpark,6)
        XCTAssertEqual(r.parent.cases,374)
        XCTAssertEqual(r.parent.parent.cases,2074)
        XCTAssertEqual(r.parent.parent.parent.cases,1134)
    }
    func testMenuResourcesAfterNaturalLoadingAndMusic() throws { try compare("") }
    func testMenuResourcesWithReversePoolAndRampStorage() throws { try compare("-control") }
}
