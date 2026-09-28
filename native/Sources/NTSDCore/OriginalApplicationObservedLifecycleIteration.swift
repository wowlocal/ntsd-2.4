import Foundation

/// One whole Host iteration on its existing owner. Only lifecycle requests are
/// suspended here; all other inputs remain explicitly prepared observations.
public final class OriginalApplicationObservedLifecycleIteration<Platform: OriginalApplicationObservedLifecyclePlatform> {
    public typealias Host = OriginalApplicationHostSession<Platform>
    public typealias Exchange = OriginalLifecycleRequestExchange
    public typealias Boundary = OriginalApplicationObservedLifecycleBoundary
    public enum Outcome {
        case request(Exchange.Permit)
        case advanced(Host.Outcome)
    }
    private let host: Host, sequence: UInt64, exchange = Exchange(), lock = NSRecursiveLock()
    private var inFlight = false
    public init(host: Host) { self.host = host;sequence = host.committedSequence }
    private func locked<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock();defer { lock.unlock() };return try body()
    }
    private func attempt<T>(_ body: () throws -> T) throws -> T {
        try locked {
            guard !inFlight else { throw Boundary.reentrantAttempt }
            inFlight = true;defer { inFlight = false };return try body()
        }
    }
    public var exchangeSnapshot: Exchange.Snapshot { locked { exchange.snapshot } }
    public func resume(prepare: (Platform, Host.Session.State) throws -> Host.Inputs,
        observe: @escaping (Host.Application.Observation) throws -> Void = { _ in },
        menuObserve: @escaping (OriginalFrontScreenEvent) throws -> Void = { _ in },
        graphicsObserve: @escaping (OriginalApplicationGraphics.Command) throws -> Void = { _ in },
        checkpoint: (Host.Session.Checkpoint, OriginalStateRecord, Int32?) throws -> Void = { _,_,_ in },
        bodyProduced: (OriginalFrontScreenBody.StartupResult) throws -> Void = { _ in },
        beforeCommit: (Host.Session.Loop, Host.Session.State) throws -> Void = { _,_ in },
        beforePublication: (Platform) throws -> Void = { _ in }) throws -> Outcome {
        try attempt {
            let cursor = try exchange.snapshot.cursor()
            do {
                let result = try host.step(prepare:{ p,state in
                    p.lifecycleDelivery.begin(cursor);return try prepare(p,state)
                },observe:observe,menuObserve:menuObserve,graphicsObserve:graphicsObserve,
                checkpoint:checkpoint,bodyProduced:bodyProduced,beforeCommit:beforeCommit,
                lifecycle:{ q,p in try p.lifecycleDelivery.response(for:q) },
                beforePublication:{ p in
                    try beforePublication(p)
                    guard let consumed = p.lifecycleDelivery.cursor else { throw Boundary.missingCursor }
                    _ = try self.exchange.finish(consumed)
                },expectedSequence:sequence)
                return .advanced(result)
            } catch let needed as Exchange.RequestNeeded {
                // The entire Host/Core attempt has unwound before claim/service.
                return .request(try exchange.claim(needed))
            }
        }
    }
    public func beginService(_ permit: Exchange.Permit) throws { try attempt { try exchange.beginService(permit) } }
    public func answer(_ permit: Exchange.Permit,response: Exchange.Response,
        retaining resources: [any OriginalApplicationStartupResource] = []) throws {
        try attempt { try exchange.answer(permit,response:response,retaining:resources) }
    }
    public func fail(_ permit: Exchange.Permit,diagnostic: String,
        retaining resources: [any OriginalApplicationStartupResource] = []) throws {
        try attempt { try exchange.fail(permit,diagnostic:diagnostic,retaining:resources) }
    }
    public func cancel() throws { try attempt { exchange.cancel() } }
}
