import Foundation
import XCTest
import NTSDReferenceChecks

final class OriginalObjectInputTests: XCTestCase {
    private func compare(_ suffix: String) throws {
        func fixture(_ name: String) throws -> Data {
            let url = try XCTUnwrap(Bundle.module.url(forResource: name+suffix,withExtension: "json",subdirectory: "Fixtures"))
            return try Data(contentsOf: url)
        }
        // Both forms against the same recorded cases (CORE_REALTIME B2).
        for inPlace in [false,true] {
            let r = try ObjectInputReference.compare(input: fixture("original-object-input"),loading: fixture("original-initial-loading"),
                catalog: fixture("original-initial-loading-catalog"),sounds: fixture("original-initial-loading-sounds"),inPlace: inPlace)
            XCTAssertEqual(r.initial.catalog.catalog.objects,137)
            XCTAssertEqual(Set(r.hitFa.keys),[1,3,4,5,7,8,10,12,14])
            XCTAssertGreaterThan(r.random,0)
            XCTAssertGreaterThan(r.constructors,0)
            XCTAssertGreaterThan(r.rollbacks,0)
        }
    }
    func testObjectInputAtStartupPrecision() throws { try compare("") }
    func testObjectInputAt64BitPrecisionOverReversedActorStorage() throws { try compare("-control") }
}
