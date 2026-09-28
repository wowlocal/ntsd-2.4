import Foundation

/// Every external request of one whole menu iteration: menu graphics (window,
/// bitmap, front), message-loop queue and WndProc window requests, in original
/// order on one journal. Reply-family checks are pure.
public enum OriginalApplicationIterationRequest: OriginalExchangeRequest {
    public typealias Loop = OriginalApplicationMessageLoop
    public enum Reply: Equatable {
        case graphics(OriginalMenuGraphicsRequest.Reply)
        case queue(Loop.Response)
        case windowDefault(Int32)
        case graph(OriginalGraphEvents.Response)
    }
    case graphics(OriginalMenuGraphicsRequest)
    case queue(Loop.Request)
    case windowDefault(OriginalWindowInput.Request)
    /// GetEvent/FreeEventParams/seek of the WndProc graph callback.
    case graph(OriginalGraphEvents.Request)
    public func accepts(_ response: Reply) -> Bool {
        switch (self,response) {
        case let (.graphics(q),.graphics(r)):return q.accepts(r)
        case let (.queue(q),.queue(r)):
            // Only message retrieval owns MSG output writes.
            return r.writes.isEmpty || q.kind == .peek || q.kind == .get
        case (.windowDefault,.windowDefault),(.graph,.graph):return true
        default:return false
        }
    }
}
public typealias OriginalApplicationIterationExchange = OriginalRequestExchange<OriginalApplicationIterationRequest, any OriginalApplicationStartupResource>

/// One staged value cursor plus earlier nonempty iterations, whose receipt
/// resources stay alive through copied platform/delivery contexts.
public struct OriginalApplicationIterationDelivery {
    public private(set) var cursor: OriginalApplicationIterationExchange.Cursor?
    private var earlier = OriginalRetainedHistory<OriginalApplicationIterationExchange.Cursor>()
    public var retainedIterationCount: Int { earlier.count }
    public init() {}
    public mutating func begin(_ cursor: OriginalApplicationIterationExchange.Cursor) {
        if let old = self.cursor,old.position > 0 { earlier.append(old) }
        self.cursor = cursor
    }
    public mutating func response(for request: OriginalApplicationIterationRequest) throws -> OriginalApplicationIterationRequest.Reply {
        guard var cursor else { throw OriginalApplicationObservedIterationBoundary.missingCursor }
        defer { self.cursor = cursor };return try cursor.response(for:request)
    }
}
public enum OriginalApplicationObservedIterationBoundary: Error, Equatable {
    case missingCursor, invalidResponse, reentrantAttempt
}
public protocol OriginalApplicationObservedIterationPlatform: OriginalApplicationStartupPlatform {
    var iterationDelivery: OriginalApplicationIterationDelivery { get set }
}

/// One whole Host iteration on its existing owner, with every external request
/// suspended as a permit. Prepared `Inputs` must leave queue/window/surface/
/// lifecycle arrays empty; menu initialization values remain explicit inputs.
public final class OriginalApplicationObservedIteration<Platform: OriginalApplicationObservedIterationPlatform> {
    public typealias Host = OriginalApplicationHostSession<Platform>
    public typealias Exchange = OriginalApplicationIterationExchange
    public typealias Boundary = OriginalApplicationObservedIterationBoundary
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
            func graphics(_ q: OriginalMenuGraphicsRequest,_ p: Platform) throws -> OriginalMenuGraphicsRequest.Reply {
                guard case .graphics(let r) = try p.iterationDelivery.response(for:.graphics(q)) else { throw Boundary.invalidResponse }
                return r
            }
            do {
                let result = try host.step(prepare:{ p,state in
                    p.iterationDelivery.begin(cursor);return try prepare(p,state)
                },observe:observe,menuObserve:menuObserve,graphicsObserve:graphicsObserve,
                checkpoint:checkpoint,bodyProduced:bodyProduced,beforeCommit:beforeCommit,
                bitmap:{ stage,q,p in
                    guard case .bitmap(let r) = try graphics(.bitmap(stage,q),p) else { throw Boundary.invalidResponse }
                    return r
                },lifecycle:{ q,p in
                    guard case .window(let r) = try graphics(.window(q),p) else { throw Boundary.invalidResponse }
                    return r
                },surface:{ q,p in
                    guard case .window(let r) = try graphics(.window(q),p) else { throw Boundary.invalidResponse }
                    return r
                },front:{ stage,q,p in
                    guard case .front(let r) = try graphics(.front(stage,q),p) else { throw Boundary.invalidResponse }
                    return r
                },queue:{ q,p in
                    guard case .queue(let r) = try p.iterationDelivery.response(for:.queue(q)) else { throw Boundary.invalidResponse }
                    return r
                },windowDefault:{ q,p in
                    guard case .windowDefault(let r) = try p.iterationDelivery.response(for:.windowDefault(q)) else { throw Boundary.invalidResponse }
                    return r
                },graph:{ q,p in
                    guard case .graph(let r) = try p.iterationDelivery.response(for:.graph(q)) else { throw Boundary.invalidResponse }
                    return r
                },beforePublication:{ p in
                    try beforePublication(p)
                    guard let consumed = p.iterationDelivery.cursor else { throw Boundary.missingCursor }
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
