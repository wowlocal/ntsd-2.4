import XCTest
@testable import NTSDCore

/// CORE_REALTIME tier 3 R0: `validate` finds a zero table byte with memchr;
/// it accepts and rejects exactly what `!table.contains(0)` did, wherever the
/// zero is, alongside the table size, index and counter checks.
final class OriginalRandomValidationTests: XCTestCase {
    func random(_ table: [UInt8],index: Int = 0,counter: Int = 0) -> OriginalRandom {
        OriginalRandom(table:table,index:index,counter:counter,source:"test",sourceSHA256:"")
    }
    func testZeroBytesAnywhereAreRejected() {
        let clean = (0..<3000).map { UInt8($0 % 255 + 1) }
        XCTAssertNoThrow(try random(clean).validate())
        for at in [0,1,7,8,15,16,31,32,63,64,1499,2990,2998,2999] {
            var table = clean;table[at] = 0
            XCTAssertThrowsError(try random(table).validate(),"zero at \(at)")
            XCTAssertTrue(table.contains(0))
        }
        XCTAssertThrowsError(try random(Array(clean.dropLast())).validate(),"2999 bytes")
        XCTAssertThrowsError(try random(clean + [1]).validate(),"3001 bytes")
        XCTAssertThrowsError(try random([]).validate(),"empty")
        XCTAssertThrowsError(try random(clean,index:3000).validate())
        XCTAssertThrowsError(try random(clean,counter:1234).validate())
        XCTAssertNoThrow(try random(clean,index:2999,counter:1233).validate())
    }
}
