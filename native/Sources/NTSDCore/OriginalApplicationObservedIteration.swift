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
        case network(OriginalMenuNetworkReply)
        case socket(OriginalNetworkNotification.Response)
        case client(OriginalNetworkClient.Response)
        case networkExit(Int32)
    }
    case graphics(OriginalMenuGraphicsRequest)
    case queue(Loop.Request)
    case windowDefault(OriginalWindowInput.Request)
    /// GetEvent/FreeEventParams/seek of the WndProc graph callback.
    case graph(OriginalGraphEvents.Request)
    /// 402b60's Winsock requests and row 2's bind/listen (NETWORK_PLAY_PLAN.md N2).
    case network(OriginalMainMenuEvent)
    /// Socket IO and ordered sleeps inside the WndProc 0x401 callback.
    case socket(OriginalNetworkNotification.Request)
    /// The deferred client lookup/connect/handshake, including its sleeps.
    case client(OriginalNetworkClient.Request)
    /// 402d70's exit notice, close and cleanup; messages use the window channel.
    case networkExit(OriginalNetworkExit.Request)
    public func accepts(_ response: Reply) -> Bool {
        switch (self,response) {
        case let (.graphics(q),.graphics(r)):return q.accepts(r)
        case let (.queue(q),.queue(r)):
            // Only message retrieval owns MSG output writes.
            return r.writes.isEmpty || q.kind == .peek || q.kind == .get
        case (.windowDefault,.windowDefault),(.graph,.graph),(.network,.network),(.socket,.socket),(.client,.client),(.networkExit,.networkExit):return true
        default:return false
        }
    }
}
public typealias OriginalApplicationIterationExchange = OriginalRequestExchange<OriginalApplicationIterationRequest, any OriginalApplicationStartupResource>

/// One staged value cursor plus earlier nonempty iterations whose receipts
/// hold resources, which stay alive through copied platform/delivery contexts.
/// An iteration whose receipts hold none (the message loop's queue and
/// DefWindowProc requests, every gameplay tick) is not kept: it has nothing to
/// keep alive, and keeping it grew the app by ≈12 MB per match.
public struct OriginalApplicationIterationDelivery {
    public private(set) var cursor: OriginalApplicationIterationExchange.Cursor?
    private var earlier = OriginalRetainedHistory<OriginalApplicationIterationExchange.Cursor>()
    public var retainedIterationCount: Int { earlier.count }
    public init() {}
    public mutating func begin(_ cursor: OriginalApplicationIterationExchange.Cursor) {
        if let old = self.cursor,old.position > 0,old.retainsResources { earlier.append(old) }
        self.cursor = cursor
    }
    public mutating func response(for request: OriginalApplicationIterationRequest) throws -> OriginalApplicationIterationRequest.Reply {
        // In place (CORE_REALTIME A2): copying the cursor out copied its
        // receipts for every reply; on a throw it keeps what it recorded, as
        // the copy written back by the old `defer` did.
        guard cursor != nil else { throw OriginalApplicationObservedIterationBoundary.missingCursor }
        return try cursor!.response(for:request)
    }
}
public enum OriginalApplicationObservedIterationBoundary: Error, Equatable {
    case missingCursor, invalidResponse, reentrantAttempt
}
public protocol OriginalApplicationObservedIterationPlatform: OriginalApplicationStartupPlatform {
    var iterationDelivery: OriginalApplicationIterationDelivery { get set }
}

/// One whole Host iteration on its existing owner, with every external request
/// suspended as a permit unless an `Inline` server takes it inside the attempt.
/// Prepared `Inputs` must leave queue/window/surface/
/// lifecycle arrays empty; menu initialization values remain explicit inputs.
public final class OriginalApplicationObservedIteration<Platform: OriginalApplicationObservedIterationPlatform> {
    public typealias Host = OriginalApplicationHostSession<Platform>
    public typealias Exchange = OriginalApplicationIterationExchange
    public typealias Boundary = OriginalApplicationObservedIterationBoundary
    public enum Outcome {
        case request(Exchange.Permit)
        case advanced(Host.Outcome)
    }
    /// Requests served inside the attempt instead of suspending it
    /// (CORE_REALTIME M2): `accepts` picks them and `serve` begins service and
    /// answers or fails through the exchange. It must not call this driver or
    /// the Host (they throw `reentrantAttempt`) or touch the platform. Every
    /// other request suspends as a permit.
    public struct Inline {
        public let accepts: (Exchange.Request) -> Bool
        public let serve: (Exchange.Permit, Exchange) throws -> Void
        public init(accepts: @escaping (Exchange.Request) -> Bool,serve: @escaping (Exchange.Permit, Exchange) throws -> Void) {
            self.accepts = accepts;self.serve = serve
        }
    }
    /// The cursor stays in the committed or pending platform after the attempt;
    /// the attempt disarms this on exit so a stored cursor suspends and does not
    /// keep the server alive.
    private final class Gate { var inline: Inline?; init(_ inline: Inline) { self.inline = inline } }
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
        /// false: `beforeCommit` ignores the state (it gets the step's staged
        /// state without the alias merge); see OriginalApplicationMenuSession.step.
        observesCommit: Bool = true,
        beforePublication: (Platform) throws -> Void = { _ in },
        network: Bool = false,inline: Inline? = nil) throws -> Outcome {
        try attempt {
            let gate = inline.map(Gate.init)
            defer { gate?.inline = nil }
            let cursor = try makeCursor(gate)
            do {
                return .advanced(try fullStep(prepare:{ p,state in
                    p.iterationDelivery.begin(cursor);return try prepare(p,state)
                },observe:observe,menuObserve:menuObserve,graphicsObserve:graphicsObserve,
                checkpoint:checkpoint,bodyProduced:bodyProduced,beforeCommit:beforeCommit,observesCommit:observesCommit,
                beforePublication:beforePublication,network:network))
            } catch let needed as Exchange.RequestNeeded {
                // The entire Host/Core attempt has unwound before claim/service.
                return .request(try exchange.claim(needed))
            }
        }
    }
    /// `resume` without observers that first tries the Host's idle kernel
    /// (`stepIdle`); when the iteration is not idle, the whole step runs over a
    /// fresh cursor that replays the requests the kernel served (none is served
    /// twice) with the same prepared inputs (`prepare` runs once per resume)
    /// (CORE_REALTIME A1). `prepare` must not change the platform it is given:
    /// when the iteration is not idle its inputs are reused with a fresh copy.
    public func resumeIdleFirst(prepare: (Platform, Host.Session.State) throws -> Host.Inputs,
        beforePublication: (Platform) throws -> Void = { _ in },
        network: Bool = false,inline: Inline? = nil) throws -> Outcome {
        try attempt {
            let gate = inline.map(Gate.init)
            defer { gate?.inline = nil }
            let idle = try makeCursor(gate)
            var inputs: Host.Inputs?
            func prepared(_ p: Platform,_ state: Host.Session.State,_ cursor: Exchange.Cursor) throws -> Host.Inputs {
                p.iterationDelivery.begin(cursor)
                if let inputs { return inputs }
                let made = try prepare(p,state);inputs = made;return made
            }
            do {
                if let outcome = try host.stepIdle(prepare:{ p,state in try prepared(p,state,idle) },queue:{ q,p in
                    guard case .queue(let r) = try p.iterationDelivery.response(for:.queue(q)) else { throw Boundary.invalidResponse }
                    return r
                },beforePublication:{ p in try self.finishPublication(p,beforePublication) },expectedSequence:sequence) {
                    return .advanced(outcome)
                }
                let full = try makeCursor(gate)
                return .advanced(try fullStep(prepare:{ p,state in try prepared(p,state,full) },observesCommit:false,
                                              beforePublication:beforePublication,network:network))
            } catch let needed as Exchange.RequestNeeded {
                return .request(try exchange.claim(needed))
            }
        }
    }
    private func makeCursor(_ gate: Gate?) throws -> Exchange.Cursor {
        try gate.map { gate in
            try exchange.inlineCursor(accepting:{ gate.inline?.accepts($0) ?? false }) { permit,exchange in
                try gate.inline!.serve(permit,exchange)
            }
        } ?? exchange.snapshot.cursor()
    }
    private func finishPublication(_ p: Platform,_ beforePublication: (Platform) throws -> Void) throws {
        try beforePublication(p)
        guard let consumed = p.iterationDelivery.cursor else { throw Boundary.missingCursor }
        _ = try exchange.finish(consumed)
    }
    /// One whole Host step with every request through the platform's
    /// iteration delivery (`resume`'s body).
    private func fullStep(prepare: (Platform, Host.Session.State) throws -> Host.Inputs,
        observe: @escaping (Host.Application.Observation) throws -> Void = { _ in },
        menuObserve: @escaping (OriginalFrontScreenEvent) throws -> Void = { _ in },
        graphicsObserve: @escaping (OriginalApplicationGraphics.Command) throws -> Void = { _ in },
        checkpoint: (Host.Session.Checkpoint, OriginalStateRecord, Int32?) throws -> Void = { _,_,_ in },
        bodyProduced: (OriginalFrontScreenBody.StartupResult) throws -> Void = { _ in },
        beforeCommit: (Host.Session.Loop, Host.Session.State) throws -> Void = { _,_ in },
        observesCommit: Bool = true,
        beforePublication: (Platform) throws -> Void,network: Bool) throws -> Host.Outcome {
        func graphics(_ q: OriginalMenuGraphicsRequest,_ p: Platform) throws -> OriginalMenuGraphicsRequest.Reply {
            guard case .graphics(let r) = try p.iterationDelivery.response(for:.graphics(q)) else { throw Boundary.invalidResponse }
            return r
        }
        return try host.step(prepare:prepare,observe:observe,menuObserve:menuObserve,graphicsObserve:graphicsObserve,
            checkpoint:checkpoint,bodyProduced:bodyProduced,beforeCommit:beforeCommit,observesCommit:observesCommit,
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
            },network:network ? { e,p in
                guard case .network(let r) = try p.iterationDelivery.response(for:.network(e)) else { throw Boundary.invalidResponse }
                return r
            } : nil,socket:{ q,p in
                guard case .socket(let r) = try p.iterationDelivery.response(for:.socket(q)) else { throw Boundary.invalidResponse }
                return r
            },client:network ? { q,p in
                guard case .client(let r) = try p.iterationDelivery.response(for:.client(q)) else { throw Boundary.invalidResponse }
                return r
            } : nil,networkExit:network ? { q,p in
                guard case .networkExit(let r) = try p.iterationDelivery.response(for:.networkExit(q)) else { throw Boundary.invalidResponse }
                return r
            } : nil,beforePublication:{ p in try self.finishPublication(p,beforePublication) },expectedSequence:sequence)
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
