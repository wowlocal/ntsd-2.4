import Foundation
import XCTest
import NTSDReferenceChecks

final class OriginalLoadedCatalogTests: XCTestCase {
    private func compare(_ suffix: String) throws -> LoadedCatalogReference.Result {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "original-loaded-catalog" + suffix, withExtension: "json", subdirectory: "Fixtures"))
        return try LoadedCatalogReference.compare(Data(contentsOf: url))
    }

    private func checkWholeSource(_ result: LoadedCatalogReference.Result, checksum: UInt32) {
        XCTAssertEqual(result.objects, 137)
        XCTAssertEqual(result.backgrounds, 17)
        XCTAssertEqual(result.stages, 25)
        XCTAssertEqual(result.phases, 138)
        XCTAssertEqual(result.frames, 15388)
        XCTAssertEqual(result.bitmaps, 829)
        XCTAssertEqual(result.allocations, 14586)
        XCTAssertEqual(result.bytes, 112063739)
        XCTAssertEqual(result.checksum, checksum)
    }

    func testCompleteOriginalCatalogWithTextFiles() throws {
        checkWholeSource(try compare(""), checksum: 31475378)
    }

    func testCompleteOriginalCatalogWithRawFilesAndZeroBacking() throws {
        checkWholeSource(try compare("-raw-zero"), checksum: 31461560)
    }

    func testInterleavedChildrenAndDuplicateSourceIDs() throws {
        let result = try compare("-interleaved")
        XCTAssertEqual(result.objects, 3)
        XCTAssertEqual(result.backgrounds, 2)
        XCTAssertEqual(result.stages, 25)
        XCTAssertEqual(result.phases, 138)
        XCTAssertEqual(result.frames, 720)
        XCTAssertEqual(result.bitmaps, 26)
        XCTAssertEqual(result.allocations, 744)
        XCTAssertEqual(result.bytes, 82089953)
        XCTAssertEqual(result.checksum, 1496213)
    }
}
