import Foundation

/// Actual API replies, obtained outside a staged Core call. The reply's writes
/// are validated by the bitmap provenance owner, never used as a saved after-state.
public struct OriginalBitmapRequest: OriginalExchangeRequest {
    public typealias Reply = OriginalBitmapSurfaceLoading.Response
    public let value: OriginalBitmapSurfaceLoading.Request
    public init(_ value: OriginalBitmapSurfaceLoading.Request) { self.value = value }
    public func accepts(_ response: Reply) -> Bool { true }
}
public typealias OriginalBitmapRequestExchange = OriginalRequestExchange<OriginalBitmapRequest, any OriginalApplicationStartupResource>

/// Value-owned receipt lifetimes on a staged platform. Earlier nonempty cursors
/// retain their actual owners after a later iteration replaces the active cursor.
public struct OriginalBitmapDelivery {
    public private(set) var cursor: OriginalBitmapRequestExchange.Cursor?
    private var earlier: [OriginalBitmapRequestExchange.Cursor] = []
    public var retainedIterationCount: Int { earlier.count }
    public init() {}
    public mutating func begin(_ cursor: OriginalBitmapRequestExchange.Cursor) {
        if let old = self.cursor,old.position > 0 { earlier.append(old) }
        self.cursor = cursor
    }
    public mutating func response(for request: OriginalBitmapSurfaceLoading.Request) throws -> OriginalBitmapSurfaceLoading.Response {
        guard var cursor else { throw OriginalApplicationObservedBitmapBoundary.missingCursor }
        defer { self.cursor = cursor };return try cursor.response(for:.init(request))
    }
}
public enum OriginalApplicationObservedBitmapBoundary: Error, Equatable {
    case missingCursor, reentrantAttempt
}
public protocol OriginalApplicationObservedBitmapPlatform: OriginalApplicationStartupPlatform {
    var bitmapDelivery: OriginalBitmapDelivery { get set }
}
