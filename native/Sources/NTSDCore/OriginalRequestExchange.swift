import Foundation

/// A value request and its response-family check. Implementations must be pure;
/// validation runs under the receipt owner's lock, without device IO or callbacks.
public protocol OriginalExchangeRequest: Equatable {
    associatedtype Reply
    func accepts(_ response: Reply) -> Bool
}

/// Prepared responses for a typed external request consumer. Pure
/// value cursors run inside a Core attempt; claim/answer/fail run outside it,
/// except for an inline cursor's server, which runs them inside the attempt.
/// Retrying Native calculation reuses values, not already performed host IO.
public final class OriginalRequestExchange<Input: OriginalExchangeRequest, Resource> {
    public typealias Request = Input
    public typealias Response = Input.Reply
    public enum Status: Equatable { case open, cancelled, finished, indeterminate }
    public enum Boundary: Error, Equatable {
        case foreignOwner, staleRevision, requestInFlight, invalidPermit, responseMismatch, serviceAlreadyStarted
        case requestMismatch(Int), suspendedCursor, unconsumedReplies, closed(Status)
    }
    fileprivate final class Identity: @unchecked Sendable {}

    public struct Receipt {
        public let request: Request, response: Response
        public let resources: [Resource]
    }
    public struct Failure {
        public let request: Request, diagnostic: String, afterCancellation: Bool
        public let resources: [Resource]
    }
    /// This ticket can only be made by a cursor exhausting its prepared prefix.
    public struct RequestNeeded: Error {
        public let request: Request, ordinal: Int
        fileprivate let owner: Identity, revision: Int
    }
    public struct Permit {
        public let request: Request, ordinal: Int
        fileprivate let owner: Identity, identity: Identity
    }
    public struct Snapshot {
        public let receipts: [Receipt], status: Status
        public let outstandingRequest: Request?, failure: Failure?
        public let serviceStarted: Bool
        fileprivate let owner: Identity
        public func cursor() throws -> Cursor {
            guard status == .open else { throw Boundary.closed(status) }
            guard outstandingRequest == nil else { throw Boundary.requestInFlight }
            return Cursor(owner: owner, receipts: receipts)
        }
    }
    /// Copies have independent positions. No mutable exchange/backend is held.
    public struct Cursor {
        fileprivate let owner: Identity
        fileprivate var receipts: [Receipt]
        public private(set) var position = 0
        fileprivate var pending: RequestNeeded?
        /// Inline service: answers a missing request synchronously and records
        /// its receipt instead of suspending the attempt; nil from it suspends
        /// as a permit cursor does. Nil for permit cursors.
        fileprivate var inline: ((RequestNeeded) throws -> Receipt?)?
        public var isSuspended: Bool { pending != nil }
        /// Whether any receipt keeps a resource alive.
        public var retainsResources: Bool { receipts.contains { !$0.resources.isEmpty } }
        fileprivate init(owner: Identity, receipts: [Receipt]) {
            self.owner = owner; self.receipts = receipts
        }
        public mutating func response(for request: Request) throws -> Response {
            guard pending == nil else { throw Boundary.suspendedCursor }
            if position < receipts.count {
                let receipt = receipts[position]
                guard request == receipt.request else { throw Boundary.requestMismatch(position) }
                position += 1; return receipt.response
            }
            let ticket = RequestNeeded(request: request, ordinal: position, owner: owner, revision: receipts.count)
            if let inline, let receipt = try inline(ticket) {
                receipts.append(receipt); position += 1; return receipt.response
            }
            pending = ticket; throw ticket
        }
    }

    private let owner = Identity(), mutex = NSLock()
    private var receipts: [Receipt] = []
    private var status = Status.open
    private var active: Permit?
    private var serviceStarted = false
    private var failure: Failure?
    public init() {}
    private func locked<T>(_ body: () throws -> T) rethrows -> T {
        mutex.lock(); defer { mutex.unlock() }; return try body()
    }
    private func view() -> Snapshot {
        .init(receipts: receipts, status: status, outstandingRequest: active?.request, failure: failure, serviceStarted: serviceStarted, owner: owner)
    }
    public var snapshot: Snapshot { locked { view() } }

    /// Inline cursor over all current receipts. A missing request is claimed and
    /// `serve` runs synchronously inside the Core attempt; it must begin service
    /// and answer (or fail) on this exchange through the permit, as a permit
    /// service would. The recorded receipt is reused by any later retry, so no
    /// operation repeats; a failure ends the attempt and leaves the exchange
    /// indeterminate. This trades suspension for per-request reruns of an attempt.
    public func inlineCursor(_ serve: @escaping (Permit) throws -> Void) throws -> Cursor {
        var cursor = try snapshot.cursor()
        cursor.inline = { [unowned self] ticket in
            let permit = try self.claim(ticket)
            try serve(permit)
            return try self.locked {
                guard self.status == .open || self.status == .finished,self.active == nil,
                      self.receipts.count == ticket.ordinal+1 else { throw Boundary.unconsumedReplies }
                return self.receipts[ticket.ordinal]
            }
        }
        return cursor
    }
    /// Inline cursor that serves only the missing requests `accepts` takes; any
    /// other suspends the attempt as a permit cursor does. `accepts` runs before
    /// the claim (a claim cannot be undone); `serve` gets this exchange and must
    /// begin service and answer (or fail) through the permit, as a permit
    /// service would (CORE_REALTIME M2). The cursor holds the exchange weakly.
    public func inlineCursor(accepting accepts: @escaping (Request) -> Bool,
                             _ serve: @escaping (Permit, OriginalRequestExchange) throws -> Void) throws -> Cursor {
        var cursor = try snapshot.cursor()
        cursor.inline = { [weak self] ticket in
            guard let self, accepts(ticket.request) else { return nil }
            let permit = try self.claim(ticket)
            try serve(permit, self)
            return try self.locked {
                guard self.status == .open || self.status == .finished,self.active == nil,
                      self.receipts.count == ticket.ordinal+1 else { throw Boundary.unconsumedReplies }
                return self.receipts[ticket.ordinal]
            }
        }
        return cursor
    }
    /// Cursor over all current receipts whose missing requests `serve` answers
    /// directly, without a claim, permit or service record (CORE_REALTIME A3
    /// L4a); nil from `serve` suspends the cursor as a permit cursor does. Its
    /// replies stay in the cursor until `record` adds them here.
    public func directCursor(_ serve: @escaping (Request) throws -> Response?) throws -> Cursor {
        var cursor = try snapshot.cursor()
        cursor.inline = { ticket in
            guard let response = try serve(ticket.request) else { return nil }
            return Receipt(request: ticket.request, response: response, resources: [])
        }
        return cursor
    }
    /// Adds replies a direct cursor served, in order, as their claims and
    /// answers would have (CORE_REALTIME A3 L4a).
    public func record(_ replies: [Receipt]) throws {
        try locked {
            guard status == .open else { throw Boundary.closed(status) }
            guard active == nil else { throw Boundary.requestInFlight }
            receipts.append(contentsOf: replies)
        }
    }
    /// A direct server's failure, as `fail` records it after a claim
    /// (CORE_REALTIME A3 L4a).
    public func recordFailure(_ request: Request, diagnostic: String) throws {
        try locked {
            guard status == .open else { throw Boundary.closed(status) }
            guard active == nil else { throw Boundary.requestInFlight }
            failure = .init(request: request, diagnostic: diagnostic, afterCancellation: false, resources: [])
            serviceStarted = false; status = .indeterminate
        }
    }
    /// Call after the Core attempt has unwound, before performing the operation.
    /// A claim is not success and supplies no numeric response to Core.
    public func claim(_ ticket: RequestNeeded) throws -> Permit {
        try locked {
            guard ticket.owner === owner else { throw Boundary.foreignOwner }
            guard status == .open else { throw Boundary.closed(status) }
            guard ticket.revision == receipts.count, ticket.ordinal == receipts.count else { throw Boundary.staleRevision }
            guard active == nil else { throw Boundary.requestInFlight }
            let permit = Permit(request: ticket.request, ordinal: ticket.ordinal, owner: owner, identity: Identity())
            active = permit; serviceStarted = false; return permit
        }
    }
    private func validate(_ permit: Permit) throws {
        guard permit.owner === owner else { throw Boundary.foreignOwner }
        guard let active, permit.identity === active.identity else { throw Boundary.invalidPermit }
    }
    /// Claim physical service once, before any external effect. Existing prepared
    /// callers may still answer without IO. Cancellation prevents new service;
    /// an operation already begun may record its actual late answer or failure.
    public func beginService(_ permit: Permit) throws {
        try locked {
            try validate(permit)
            guard status == .open else { throw Boundary.closed(status) }
            guard !serviceStarted else { throw Boundary.serviceAlreadyStarted }
            serviceStarted = true
        }
    }
    /// An issued operation may finish after cancellation. Keep its actual reply
    /// and owners once, while leaving further service cancelled.
    public func answer(_ permit: Permit, response: Response,
        retaining resources: [Resource] = []) throws {
        try locked {
            try validate(permit)
            guard permit.request.accepts(response) else { throw Boundary.responseMismatch }
            receipts.append(.init(request: permit.request, response: response, resources: resources))
            active = nil; serviceStarted = false
        }
    }
    /// Unknown physical outcome is terminal and is never translated into an
    /// invented HRESULT. The caller must resolve the external failure separately.
    public func fail(_ permit: Permit, diagnostic: String,
        retaining resources: [Resource] = []) throws {
        try locked {
            try validate(permit)
            failure = .init(request: permit.request, diagnostic: diagnostic,
                afterCancellation: status == .cancelled, resources: resources)
            active = nil; serviceStarted = false; status = .indeterminate
        }
    }
    public func cancel() {
        locked { if status == .open { status = .cancelled } }
    }
    /// Call only after the actual encompassing caller returns. This validates
    /// receipt consumption, not whether a window/game/device operation succeeded.
    /// Existing snapshots remain immutable; no resource receipt is discarded.
    @discardableResult public func finish(_ cursor: Cursor) throws -> Snapshot {
        try locked {
            guard cursor.owner === owner else { throw Boundary.foreignOwner }
            guard status == .open else { throw Boundary.closed(status) }
            guard active == nil else { throw Boundary.requestInFlight }
            guard cursor.receipts.count == receipts.count else { throw Boundary.staleRevision }
            guard cursor.pending == nil else { throw Boundary.suspendedCursor }
            guard cursor.position == receipts.count else { throw Boundary.unconsumedReplies }
            status = .finished; return view()
        }
    }
}
