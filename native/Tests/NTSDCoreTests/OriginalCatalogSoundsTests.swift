import Foundation
import XCTest
import NTSDReferenceChecks

final class OriginalCatalogSoundsTests: XCTestCase {
    private func compare(_ suffix: String) throws -> CatalogSoundsReference.Result {
        func fixture(_ name: String) throws -> Data {
            let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
            return try Data(contentsOf: url)
        }
        return try CatalogSoundsReference.compare(catalog: fixture("original-loaded-catalog-audio"+suffix), sounds: fixture("original-catalog-sounds"+suffix))
    }
    func testCompleteSourceCatalogWithEnabledWaveLoading() throws {
        let r = try compare("")
        XCTAssertEqual(r.catalog.objects, 137)
        XCTAssertEqual(r.catalog.frames, 15388)
        XCTAssertEqual(r.catalog.bytes, 112_063_739)
        XCTAssertEqual(r.catalog.checksum, 31_475_378)
        XCTAssertEqual(r.calls, 400)
        XCTAssertEqual(r.sources, 365)
        XCTAssertEqual(r.weaponCalls, 14)
        XCTAssertEqual(r.frameCalls, 386)
        XCTAssertEqual(r.bytes, 66_210_142)
        XCTAssertEqual(r.events, 6426)
        XCTAssertEqual(r.restores, 80)
    }
    func testRepeatedObjectsUseTheLiveOriginalSoundCache() throws {
        let r = try compare("-interleaved")
        XCTAssertEqual(r.catalog.objects, 3)
        XCTAssertEqual(r.catalog.frames, 720)
        XCTAssertEqual(r.catalog.bytes, 82_089_953)
        XCTAssertEqual(r.catalog.checksum, 1_496_213)
        XCTAssertEqual(r.calls, 29)
        XCTAssertEqual(r.sources, 28)
        XCTAssertEqual(r.weaponCalls, 0)
        XCTAssertEqual(r.frameCalls, 29)
        XCTAssertEqual(r.bytes, 4_157_380)
        XCTAssertEqual(r.events, 466)
        XCTAssertEqual(r.restores, 6)
    }
}
