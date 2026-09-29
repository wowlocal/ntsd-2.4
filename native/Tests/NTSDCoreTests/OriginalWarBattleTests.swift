import Foundation
import XCTest
import NTSDReferenceChecks

/// Both accepted 43a860 corpora (startup precision and 64-bit control
/// loading) replayed against OriginalWarBattle with exact masks.
final class OriginalWarBattleTests: XCTestCase {
    private func compare(_ suffix: String) throws {
        func fixture(_ name: String) throws -> Data {
            let url = try XCTUnwrap(Bundle.module.url(forResource: name+suffix,withExtension: "json",subdirectory: "Fixtures"))
            return try Data(contentsOf: url)
        }
        let r = try WarBattleReference.compare(input: fixture("original-war-battle"),loading: fixture("original-initial-loading"),
            catalog: fixture("original-initial-loading-catalog"),sounds: fixture("original-initial-loading-sounds"))
        XCTAssertEqual(r.cases,1410)
        XCTAssertEqual(r.initial.catalog.catalog.objects,137)
        XCTAssertGreaterThan(r.random,0); XCTAssertGreaterThan(r.calls,0); XCTAssertGreaterThan(r.constructors,0)
        XCTAssertEqual(Set(r.families.keys),["spawn","count","kinds","full","over","labels"])
    }
    func testWarBattleAtStartupPrecision() throws { try compare("") }
    func testWarBattleAt64BitPrecision() throws { try compare("-control") }
}
