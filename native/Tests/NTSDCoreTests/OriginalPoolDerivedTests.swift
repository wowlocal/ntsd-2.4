import XCTest
@testable import NTSDCore

/// CORE_REALTIME phase 4i: the loaded session's bitmap owner check and sound
/// token set give exactly the uncached results.
final class OriginalPoolDerivedTests: XCTestCase {
    typealias Derived = OriginalApplicationPoolSession.PendingInput.Derived

    func record(_ fill: UInt8, undefinedAt: Int? = nil) throws -> OriginalStateRecord {
        var defined = [Bool](repeating: true, count: 0x1f50)
        if let undefinedAt { defined[undefinedAt] = false }
        return try OriginalStateRecord(bytes: [UInt8](repeating: fill, count: 0x1f50), defined: defined)
    }

    func testBitmapMatchesGivesTheComparison() throws {
        let derived = Derived()
        let a = try record(1), b = try record(1), c = try record(2)
        XCTAssertFalse(a.sharesStorage(with: b), "equal contents in different buffers")
        XCTAssertTrue(derived.bitmapMatches(7, a, b))
        XCTAssertTrue(derived.bitmapMatches(7, a, b), "the kept pair")
        XCTAssertFalse(derived.bitmapMatches(7, a, c))
        XCTAssertTrue(derived.bitmapMatches(7, a, b), "an unequal check keeps the earlier pair")
        // A written copy of a kept buffer no longer shares it.
        var changed = b
        try changed.write(UInt8(9), at: 100)
        XCTAssertFalse(derived.bitmapMatches(7, a, changed))
        // Definedness counts, as in ==.
        XCTAssertFalse(derived.bitmapMatches(7, a, try record(1, undefinedAt: 5)))
        // Another token's check is its own.
        XCTAssertFalse(derived.bitmapMatches(8, a, c))
        XCTAssertTrue(derived.bitmapMatches(8, b, a))

        // Seeded: shared copies, equal records in other buffers and different
        // records under a few tokens; every answer equals ==.
        var pool = [try record(1), try record(1), try record(2), try record(1, undefinedAt: 0x1f4f)]
        pool += pool.map { $0 }
        var state: UInt64 = 21
        func next(_ n: Int) -> Int { state = state &* 6364136223846793005 &+ 1442695040888963407; return Int((state >> 33) % UInt64(n)) }
        for step in 0..<2000 {
            let token = UInt32(next(3)), i = next(pool.count), j = next(pool.count)
            XCTAssertEqual(derived.bitmapMatches(token, pool[i], pool[j]), pool[i] == pool[j], "step \(step)")
            if next(50) == 0 { try pool[next(pool.count)].write(UInt8(next(3)), at: next(0x1f50)) }
        }
    }

    func testSoundTokensAreBuiltOnce() {
        let derived = Derived()
        var calls = 0
        XCTAssertEqual(derived.soundTokens { calls += 1; return [1, 2] }, [1, 2])
        XCTAssertEqual(derived.soundTokens { calls += 1; return [3] }, [1, 2])
        XCTAssertEqual(calls, 1)
    }
}
