import Foundation
import XCTest
@testable import RandoriCore

/// MEMORY_LOADING L12: the package loads can run on a host's parallel loop;
/// `threadLoop` calls every index exactly once whatever the thread count, and
/// results keep their order and their own errors.
final class OriginalConcurrentLoopTests: XCTestCase {
    override func tearDown() { OriginalConcurrentInputs.parallelLoop = nil }

    func testThreadLoopCallsEveryIndexOnce() {
        final class Seen: @unchecked Sendable { let lock = NSLock(); var counts: [Int] = []; var threads = Set<String>() }
        for count in [0, 1, 2, 7, 1000] {
            for workers in [0, 1, 2, 3, 8, 64] {
                let seen = Seen(); seen.counts = [Int](repeating: 0, count: count)
                final class Started: @unchecked Sendable { let lock = NSLock(); var n = 0 }
                let started = Started()
                OriginalConcurrentInputs.threadLoop(count, workers: workers, threadStart: { started.lock.lock(); started.n += 1; started.lock.unlock() }) { i in
                    seen.lock.lock(); seen.counts[i] += 1; seen.lock.unlock()
                }
                XCTAssertEqual(seen.counts, [Int](repeating: 1, count: count), "count \(count) workers \(workers)")
                started.lock.lock(); XCTAssertLessThanOrEqual(started.n, max(0, min(workers, count) - 1)); started.lock.unlock()
            }
        }
    }

    func testMapThroughAHostLoopKeepsTheOrderAndEachError() {
        struct Odd: Error, Equatable { let value: Int }
        OriginalConcurrentInputs.parallelLoop = { count, body in
            OriginalConcurrentInputs.threadLoop(count, workers: 6, threadStart: {}, body)
        }
        for size in [0, 1, 999] {
            let results = OriginalConcurrentInputs.map(Array(0..<size)) { value -> Int in
                if value % 5 == 1 { throw Odd(value: value) }
                return value * 3
            }
            XCTAssertEqual(results.count, size)
            for (value, result) in results.enumerated() {
                switch result {
                case .success(let tripled): XCTAssertEqual(tripled, value * 3)
                case .failure(let error): XCTAssertEqual(error as? Odd, Odd(value: value))
                }
            }
        }
    }
}
