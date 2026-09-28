import Foundation
import XCTest
import NTSDReferenceChecks

final class OriginalCharacterAITests: XCTestCase {
    private func compare(_ suffix: String) throws {
        func fixture(_ name: String) throws -> Data {
            let url = try XCTUnwrap(Bundle.module.url(forResource: name+suffix,withExtension: "json",subdirectory: "Fixtures"))
            return try Data(contentsOf: url)
        }
        let r = try CharacterAIReference.compare(input: fixture("original-character-ai"),loading: fixture("original-initial-loading"),
            catalog: fixture("original-initial-loading-catalog"),sounds: fixture("original-initial-loading-sounds"))
        XCTAssertEqual(r.initial.catalog.catalog.objects,137)
        XCTAssertGreaterThan(r.owners[33] ?? 0,0)
        XCTAssertGreaterThan(r.random,0)
    }
    func testCharacterAIAtStartupPrecision() throws { try compare("") }
    func testCharacterAIAt64BitPrecisionWithSSE2Conversion() throws { try compare("-control") }
}
