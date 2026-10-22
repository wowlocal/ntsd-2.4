import Foundation
import XCTest
@testable import RandoriCore

/// MEMORY_LOADING L13: the loading packages are read on a thread of their own
/// and taken where they were read, in the same order: the values are the ones
/// read in sequence, and the first failing package in that order decides.
/// ENGINE_SPLIT E4c-2: the synthetic half of native's OriginalLoadingReadAheadTests; the content-reading tests stay there.
final class OriginalLoadingReadAheadTests: XCTestCase {
    struct Failed: Error, Equatable { let name: String }
    override func tearDown() { OriginalConcurrentInputs.backgroundStart = nil }

    func testABackgroundValueRunsOnItsOwnThreadAfterTheHostStart() throws {
        final class Seen: @unchecked Sendable { let lock = NSLock(); var events: [String] = [] }
        let seen = Seen(), caller = Thread.current
        OriginalConcurrentInputs.backgroundStart = { seen.lock.lock(); seen.events.append("start"); seen.lock.unlock() }
        let value = OriginalConcurrentInputs.Background<Int> {
            seen.lock.lock(); seen.events.append(Thread.current == caller ? "caller" : "own"); seen.lock.unlock()
            return 42
        }
        XCTAssertEqual(try value.get(), 42)
        XCTAssertEqual(try value.get(), 42)
        XCTAssertTrue(value.isReady)
        seen.lock.lock(); XCTAssertEqual(seen.events, ["start", "own"]); seen.lock.unlock()
    }

    func testABackgroundErrorIsThrownByEveryGet() {
        let value = OriginalConcurrentInputs.Background<Int> { throw Failed(name: "x") }
        for _ in 0..<2 { XCTAssertThrowsError(try value.get()) { XCTAssertEqual($0 as? Failed, Failed(name: "x")) } }
    }

    func testAWaitingGetReturnsWhenTheValueArrives() throws {
        let gate = DispatchSemaphore(value: 0)
        let value = OriginalConcurrentInputs.Background<[Int]> { gate.wait(); return Array(0..<1000) }
        XCTAssertFalse(value.isReady)
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) { gate.signal() }
        XCTAssertEqual(try value.get(), Array(0..<1000))
    }
}
