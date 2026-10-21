import Foundation
import XCTest
@testable import NTSDCore

/// MEMORY_LOADING L3: package entries are read, verified and decoded
/// concurrently and taken in manifest order, so the first failing entry in that
/// order still decides the error, whichever entry fails first in time.
/// ENGINE_SPLIT E4c-2: the synthetic half of native's OriginalConcurrentInputsTests; the content-reading tests stay there.
final class OriginalConcurrentInputsTests: XCTestCase {
    func testMapKeepsTheOrderAndEachEntrysError() {
        struct Odd: Error, Equatable { let value: Int }
        let results = OriginalConcurrentInputs.map(Array(0..<5000)) { value -> Int in
            if value % 7 == 3 { throw Odd(value: value) }
            return value * 2
        }
        XCTAssertEqual(results.count, 5000)
        for (value, result) in results.enumerated() {
            switch result {
            case .success(let doubled): XCTAssertEqual(doubled, value * 2)
            case .failure(let error): XCTAssertEqual(error as? Odd, Odd(value: value)); XCTAssertEqual(value % 7, 3)
            }
        }
    }

    func testHexMatchesTheFormattedDigits() {
        let all = (0...255).map { UInt8($0) }
        XCTAssertEqual(OriginalConcurrentInputs.hex(all), all.map { String(format: "%02x", $0) }.joined())
        XCTAssertEqual(OriginalConcurrentInputs.hex([]), "")
    }
}
