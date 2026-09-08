import Foundation
import XCTest
import NTSDReferenceChecks

final class OriginalMusicPlaybackTests: XCTestCase {
    private func compare(_ suffix: String) throws {
        func fixture(_ name: String) throws -> Data {
            let url = try XCTUnwrap(Bundle.module.url(forResource: name+suffix,withExtension: "json",subdirectory: "Fixtures"))
            return try Data(contentsOf: url)
        }
        let r = try MusicPlaybackReference.compare(music: fixture("original-music-playback"),round: fixture("original-match-round"),
            replay: fixture("original-replay-tick"),control: fixture("original-input-control"),local: fixture("original-local-input"),
            loading: fixture("original-initial-loading"),catalog: fixture("original-initial-loading-catalog"),sounds: fixture("original-initial-loading-sounds"))
        XCTAssertEqual(r.cases,374)
        XCTAssertEqual(r.calls,1225)
        XCTAssertEqual(r.events,5956)
        XCTAssertEqual(r.allocations,219)
        XCTAssertEqual(r.messages,12)
        XCTAssertEqual(r.formats,219)
        XCTAssertEqual(r.records,32575)
        XCTAssertEqual(r.bytes,18_155_382)
        XCTAssertEqual(r.parent.cases,2074)
        XCTAssertEqual(r.parent.parent.cases,1134)
        XCTAssertEqual(r.parent.parent.parent.cases,2993)
        XCTAssertEqual(r.parent.parent.parent.local.cases,303)
    }
    func testEnabledMusicFromNaturalFirstMenu() throws { try compare("") }
    func testMusicWithReversePoolAndRampStorage() throws { try compare("-control") }
}
