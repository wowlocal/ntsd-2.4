import Foundation
import XCTest
import NTSDReferenceChecks
@testable import NTSDCore

final class OriginalCatalogTests: XCTestCase {
    func testCatalogParentAgainstOriginalInstructions() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "original-catalog-registry", withExtension: "json", subdirectory: "Fixtures"))
        let result = try CatalogReference.compare(Data(contentsOf: url))
        XCTAssertEqual(result.cases, 12)
        XCTAssertEqual(result.records, 48)
        XCTAssertEqual(result.bytes, 83232)
        XCTAssertEqual(result.requests, 3446)
    }

    func testUnsupportedRegistryInputsCannotBecomeLoadedState() throws {
        let backing = try OriginalCatalogRegistry.regionSizes.mapValues {
            try OriginalStateRecord(bytes: Array(repeating: 0xa5, count: $0), defined: Array(repeating: false, count: $0))
        }
        let inputs = ["", "   ", "<object> id: 1 type: 0 file: x.dat", // missing end marker
                      "<object> id: 2147483648 type: 0 file: x.dat <object_end>",
                      "<object> id: nope type: 0 file: x.dat <object_end>",
                      "<background> id: 1 file: " + String(repeating: "a", count: 180) + " <background_end>",
                      "<object> id: 1 type: 0 file: " + String(repeating: "b", count: 200) + " <object_end>",
                      "<object>\0<object_end>", "<object>\u{1a}<object_end>"]
        for source in inputs {
            XCTAssertThrowsError(try OriginalCatalogRegistry(source: Array(source.utf8), fileName: Array("data\\data.txt".utf8),
                                                             initialChecksum: 0, backing: backing))
        }
        XCTAssertThrowsError(try OriginalCatalogRegistry(source: Array("<object> <object_end>".utf8), fileName: Array(repeating: 97, count: 32),
                                                         initialChecksum: 0, backing: backing))
        XCTAssertTrue(backing.values.allSatisfy { $0.bytes.allSatisfy { $0 == 0xa5 } && $0.defined.allSatisfy { !$0 } })
    }
}
