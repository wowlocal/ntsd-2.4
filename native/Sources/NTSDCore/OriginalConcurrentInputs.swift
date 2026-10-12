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
    /// Runs first on a `Background` value's thread (the Android host allows it
    /// every core below the game thread's priority). Set before the first one.
    nonisolated(unsafe) public static var backgroundStart: (@Sendable () -> Void)?

    /// A value computed on a thread of its own from creation. `get` waits for
    /// it, then returns it or throws its error, every time it is called: a
    /// caller that takes it where it used to compute it keeps that point and,
    /// taking several in their old order, which error comes first (MEMORY_LOADING
    /// L13). The thread takes the computation out of the box before running it,
    /// so only the result stays.
    public final class Background<Value>: @unchecked Sendable {
        private let condition = NSCondition()
        private var compute: (@Sendable () throws -> Value)?
        private var result: Result<Value, Error>?
        public init(_ compute: @escaping @Sendable () throws -> Value) {
            #if os(WASI)
            // A host without threads (TVOS_WEB W0): computed here, at creation;
            // `get` returns it or throws its error as it would after waiting.
            result = Result { try compute() }
            #else
            self.compute = compute
            let thread = Thread { [self] in
                OriginalConcurrentInputs.backgroundStart?()
                condition.lock(); let body = self.compute!; self.compute = nil; condition.unlock()
                let value = Result { try body() }
                condition.lock(); result = value; condition.broadcast(); condition.unlock()
            }
            // The main thread's stack size: the loads ran there before.
            thread.name = "NTSD.readahead"; thread.stackSize = 8 << 20; thread.start()
            #endif
        }
        /// Whether the value is ready (`get` would not wait).
        public var isReady: Bool { condition.lock(); defer { condition.unlock() }; return result != nil }
        public func get() throws -> Value {
            condition.lock()
            while result == nil { condition.wait() }
            let value = result!
            condition.unlock()
            return try value.get()
        }
    }

    static func map<Element, Value>(_ elements: [Element], _ transform: (Element) throws -> Value) -> [Result<Value, Error>] {
        var results = [Result<Value, Error>?](repeating: nil, count: elements.count)
        results.withUnsafeMutableBufferPointer { buffer in
            let slots = buffer   // the same buffer, captured by value
            withoutActuallyEscaping(transform) { transform in
                let body: (Int) -> Void = { i in slots[i] = Result { try transform(elements[i]) } }
                if let loop = parallelLoop { loop(elements.count, body) }
                else {
                    #if canImport(Dispatch)
                    DispatchQueue.concurrentPerform(iterations: elements.count, execute: body)
                    #else
                    // A host without threads (WASI, TVOS_WEB W0): the same calls,
                    // one after another; each result lands in its own slot.
                    for i in 0..<elements.count { body(i) }
                    #endif
                }
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
