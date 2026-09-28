import Foundation

public typealias OriginalLifecycleRequestExchange = OriginalRequestExchange<OriginalWindowInitialization.Request, any OriginalApplicationStartupResource>

/// Value-owned receipt lifetimes on a staged platform. Earlier nonempty cursors
/// retain their actual owners after a later iteration replaces the active cursor.
public struct OriginalLifecycleDelivery {
    public private(set) var cursor: OriginalLifecycleRequestExchange.Cursor?
    private var earlier: [OriginalLifecycleRequestExchange.Cursor] = []
    public var retainedIterationCount: Int { earlier.count }
    public init() {}
    public mutating func begin(_ cursor: OriginalLifecycleRequestExchange.Cursor) {
        if let old = self.cursor,old.position > 0 { earlier.append(old) }
        self.cursor = cursor
    }
    public mutating func response(for request: OriginalWindowInitialization.Request) throws -> OriginalWindowInitialization.Response {
        guard var cursor else { throw OriginalApplicationObservedLifecycleBoundary.missingCursor }
        defer { self.cursor = cursor };return try cursor.response(for:request)
    }
}
public enum OriginalApplicationObservedLifecycleBoundary: Error, Equatable {
    case missingCursor, reentrantAttempt
}
public protocol OriginalApplicationObservedLifecyclePlatform: OriginalApplicationStartupPlatform {
    var lifecycleDelivery: OriginalLifecycleDelivery { get set }
}
