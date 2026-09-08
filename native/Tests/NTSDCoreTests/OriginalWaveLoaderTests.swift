import Foundation
import XCTest
import NTSDReferenceChecks

final class OriginalWaveLoaderTests: XCTestCase {
    func testEveryOriginalWaveAndInitialSoundLoadingAgainstEXE() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "original-wave-loader", withExtension: "json", subdirectory: "Fixtures"))
        let result = try WaveLoaderReference.compare(Data(contentsOf: url))
        XCTAssertEqual(result.sources, 409)
        XCTAssertEqual(result.cases, 431)
        XCTAssertEqual(result.startupPasses, 3)
        XCTAssertEqual(result.startupLoads, 54)
        XCTAssertEqual(result.bytes, 75_829_038)
        XCTAssertEqual(result.events, 6982)
        XCTAssertEqual(result.restores, 93)
        XCTAssertEqual(result.messages, 13)
        XCTAssertEqual(result.leaks, 2)
        XCTAssertEqual(result.invalidContinuations, 2)
    }
}
