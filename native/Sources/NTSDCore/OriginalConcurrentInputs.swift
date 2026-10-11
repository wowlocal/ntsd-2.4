import Foundation
#if canImport(Dispatch)
import Dispatch
#endif

/// Package entries are independent files. Reading, verifying and decoding them
/// on every core computes the same values as one after another (MEMORY_LOADING
/// L3); callers take the results in manifest order, so the first failing entry
/// in that order still fails first, with its own error. Later entries are read
/// meanwhile, which costs only time.
public enum OriginalConcurrentInputs {
    /// A host's parallel loop: calls the body once for every index below the
    /// count, on any threads, and returns when all calls have returned. Nil
    /// uses Dispatch's concurrentPerform. The Android host passes `threadLoop`
    /// with threads allowed on every core: Dispatch's workers inherit the game
    /// thread's fast-cluster mask there (MEMORY_LOADING L12). Set before loading.
    nonisolated(unsafe) public static var parallelLoop: ((Int, (Int) -> Void) -> Void)?

    static func map<Element, Value>(_ elements: [Element], _ transform: (Element) throws -> Value) -> [Result<Value, Error>] {
        var results = [Result<Value, Error>?](repeating: nil, count: elements.count)
        results.withUnsafeMutableBufferPointer { slots in
            withoutActuallyEscaping(transform) { transform in
                let body: (Int) -> Void = { i in slots[i] = Result { try transform(elements[i]) } }
                if let loop = parallelLoop { loop(elements.count, body) }
                else { DispatchQueue.concurrentPerform(iterations: elements.count, execute: body) }
            }
        }
        return results.map { $0! }
    }

    /// Calls `body` for every index below `count` on the calling thread and up
    /// to `workers - 1` new threads, each running `threadStart` first, taking
    /// indices in turn; returns when every call has returned. The calling thread
    /// works too, so the loop finishes even if no thread starts. A thread drops
    /// its reference to the body before counting its call finished, and the
    /// shared box is emptied before returning: none keeps it past this call.
    public static func threadLoop(_ count: Int, workers: Int, threadStart: @escaping @Sendable () -> Void, _ body: (Int) -> Void) {
        guard count > 1, workers > 1 else { for i in 0..<count { body(i) }; return }
        final class Work: @unchecked Sendable {
            let condition = NSCondition(); var next = 0, finished = 0; var body: ((Int) -> Void)?
            func run(_ count: Int) {
                while true {
                    condition.lock(); let i = next; next += 1; var call = i < count ? body : nil; condition.unlock()
                    if call == nil { return }
                    // The only reference, dropped before the call counts as finished.
                    call!(i); call = nil
                    condition.lock(); finished += 1; if finished == count { condition.broadcast() }; condition.unlock()
                }
            }
        }
        withoutActuallyEscaping(body) { body in
            let work = Work()
            work.body = body
            for _ in 1..<min(workers, count) {
                let thread = Thread { threadStart(); work.run(count) }
                thread.name = "NTSD.load"; thread.stackSize = 1 << 20; thread.start()
            }
            work.run(count)
            work.condition.lock()
            while work.finished < count { work.condition.wait() }
            work.body = nil
            work.condition.unlock()
        }
    }

    /// Lowercase hexadecimal, as `String(format: "%02x")` per byte.
    static func hex<Bytes: Sequence>(_ bytes: Bytes) -> String where Bytes.Element == UInt8 {
        let digits = Array("0123456789abcdef".utf8)
        var text: [UInt8] = []
        for byte in bytes { text.append(digits[Int(byte >> 4)]); text.append(digits[Int(byte & 15)]) }
        return String(decoding: text, as: UTF8.self)
    }
}
