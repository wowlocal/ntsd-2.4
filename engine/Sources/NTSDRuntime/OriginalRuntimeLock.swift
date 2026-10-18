import Foundation
#if canImport(Darwin)
import os

/// The runtime's state lock. Apple platforms keep `OSAllocatedUnfairLock`.
public typealias OriginalRuntimeLock<State> = OSAllocatedUnfairLock<State>
#else
/// The runtime's state lock: the subset of `OSAllocatedUnfairLock` the runtime
/// uses, over NSLock, for hosts without the os module's unfair lock.
public final class OriginalRuntimeLock<State>: @unchecked Sendable {
    private let mutex = NSLock()
    private var state: State
    public init(initialState: State) { state = initialState }
    public func withLock<Result>(_ body: (inout State) throws -> Result) rethrows -> Result {
        mutex.lock(); defer { mutex.unlock() }
        return try body(&state)
    }
    public func withLockUnchecked<Result>(_ body: (inout State) throws -> Result) rethrows -> Result { try withLock(body) }
}
#endif
