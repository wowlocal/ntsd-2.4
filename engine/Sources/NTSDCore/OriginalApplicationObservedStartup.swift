import Foundation

/// Whole startup consumes this single ordered value cursor. stagedCopy must copy
/// its position independently. Neither provider nor Core may perform host IO
/// inside an attempted transaction. Prepared nonthrowing inputs remain fixed.
public protocol OriginalApplicationObservedStartupPlatform: OriginalApplicationStartupPlatform {
    var startupExchange: OriginalStartupRequestExchange.Cursor? { get set }
}

/// Owns one Host from declared initial state through startup suspension and commit.
/// Returned requests must be served outside resume; an answer records the actual
/// outcome, not a promise that a later Core rollback can undo physical work.
public final class OriginalApplicationObservedStartup<Platform: OriginalApplicationObservedStartupPlatform> {
    public typealias Host = OriginalApplicationHostSession<Platform>
    public typealias Exchange = OriginalStartupRequestExchange
    public enum Boundary: Error, Equatable { case reentrantAttempt, missingCursor }
    public enum Outcome {
        case request(Exchange.Permit)
        /// The same retained Host is now available for its normal menu/input API.
        case started(sequence: UInt64, host: Host)
    }
    private let host: Host, exchange = Exchange(), lock = NSRecursiveLock()
    private let initial: OriginalStateRecord, instance: UInt32, show: Int32
    private var inFlight = false

    public init(platform: Platform, instance: UInt32, show: Int32, initial: OriginalStateRecord) throws {
        host = try Host(platform: platform)
        self.instance = instance; self.show = show; self.initial = initial
    }
    private func locked<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock(); defer { lock.unlock() }; return try body()
    }
    private func attempt<T>(_ body: () throws -> T) throws -> T {
        try locked {
            guard !inFlight else { throw Boundary.reentrantAttempt }
            inFlight = true; defer { inFlight = false }; return try body()
        }
    }
    // The returned Host may be running a callback that reads the exchange.
    // Never hold our lock while waiting for these committed Host value reads.
    public var snapshot: Host.Application { host.snapshot }
    public var exchangeSnapshot: Exchange.Snapshot { locked { exchange.snapshot } }
    public var pendingBatchCount: Int { host.pendingBatchCount }
    /// Before handoff, inspect an independent copy of our private Host platform.
    /// After completion use the returned Host, avoiding coordinator -> Host lock
    /// nesting while external Host callbacks may inspect the exchange.
    public func platformSnapshot() throws -> Platform {
        try attempt {
            guard exchange.snapshot.status != .finished else { throw Exchange.Boundary.closed(.finished) }
            return try host.platformSnapshot()
        }
    }

    /// Preparation/observers mutate only attempted state; they must retain the
    /// same prepared constants and file inputs across retries. No callback is a device consumer.
    public func resume(prepare: (Platform) throws -> Void = { _ in },
        store: (Platform, Int, [UInt8]) throws -> Void = { _,_,_ in },
        beforeCommit: (OriginalWinMainStartup, Host.Session, Platform) throws -> Void = { _,_,_ in },
        failedAttempt: (Platform, Error) -> Void = { _,_ in }) throws -> Outcome {
        try attempt {
            let cursor = try exchange.snapshot.cursor()
            do {
                let sequence = try host.start(instance: instance, show: show, initial: initial,
                    prepare: { candidate in candidate.startupExchange = cursor; try prepare(candidate) },
                    store: store, beforeCommit: beforeCommit,
                    beforePublication: { candidate in
                        guard let consumed = candidate.startupExchange else { throw Boundary.missingCursor }
                        // This is after the last fallible context copy. The private
                        // exchange cannot change concurrently/reentrantly; only
                        // nonthrowing Host publication follows a successful finish.
                        _ = try self.exchange.finish(consumed)
                    }, failedAttempt: failedAttempt)
                return .started(sequence: sequence, host: host)
            } catch let needed as Exchange.RequestNeeded {
                // The Core/Host stack has fully unwound before issuing a permit.
                return .request(try exchange.claim(needed))
            }
        }
    }
    /// External services call this before IO, after validating supported inputs.
    /// It never calls host code while the coordinator or exchange lock is held.
    public func beginService(_ permit: Exchange.Permit) throws {
        try attempt { try exchange.beginService(permit) }
    }
    public func answer(_ permit: Exchange.Permit, response: Exchange.Response,
        retaining resources: [any OriginalApplicationStartupResource] = []) throws {
        try attempt { try exchange.answer(permit, response: response, retaining: resources) }
    }
    public func fail(_ permit: Exchange.Permit, diagnostic: String,
        retaining resources: [any OriginalApplicationStartupResource] = []) throws {
        try attempt { try exchange.fail(permit, diagnostic: diagnostic, retaining: resources) }
    }
    public func cancel() throws { try attempt { exchange.cancel() } }
}
