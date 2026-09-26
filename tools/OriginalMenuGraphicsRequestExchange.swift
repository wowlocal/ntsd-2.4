/// Ordered, typed requests from one whole menu iteration. Reply-family checks
/// are pure; observed numeric failures remain replies, not Native exceptions.
public enum OriginalMenuGraphicsRequest: OriginalExchangeRequest {
    public typealias Stage = OriginalApplicationBootstrap.Stage
    public enum Reply: Equatable {
        case window(OriginalWindowInitialization.Response)
        case bitmap(OriginalBitmapSurfaceLoading.Response)
        case front(OriginalLibSurfaceText.Response)
    }
    case window(OriginalWindowInitialization.Request)
    case bitmap(Stage, OriginalBitmapSurfaceLoading.Request)
    case front(Stage, OriginalFrontScreenEvent)
    public func accepts(_ response: Reply) -> Bool {
        switch (self,response) {
        case (.window,.window),(.bitmap,.bitmap):return true
        case let (.front(_,q),.front(r)):
            switch q.kind {
            case "getDC":return r.result < 0 || r.output != nil
            case "blit","fill","method","setBackgroundMode","setTextColor","textOut","releaseDC":return true
            default:return false
            }
        default:return false
        }
    }
}
public typealias OriginalMenuGraphicsRequestExchange = OriginalRequestExchange<OriginalMenuGraphicsRequest, any OriginalApplicationStartupResource>

/// One staged value cursor and retained earlier nonempty iterations. Receipt
/// resources remain alive through copied platform/delivery contexts.
public struct OriginalMenuGraphicsDelivery {
    public private(set) var cursor: OriginalMenuGraphicsRequestExchange.Cursor?
    private var earlier: [OriginalMenuGraphicsRequestExchange.Cursor] = []
    public var retainedIterationCount: Int { earlier.count }
    public init() {}
    public mutating func begin(_ cursor: OriginalMenuGraphicsRequestExchange.Cursor) {
        if let old = self.cursor,old.position > 0 { earlier.append(old) }
        self.cursor = cursor
    }
    public mutating func response(for request: OriginalMenuGraphicsRequest) throws -> OriginalMenuGraphicsRequest.Reply {
        guard var cursor else { throw OriginalApplicationObservedGraphicsBoundary.missingCursor }
        defer { self.cursor = cursor };return try cursor.response(for:request)
    }
}
public enum OriginalApplicationObservedGraphicsBoundary: Error, Equatable {
    case missingCursor, invalidResponse, reentrantAttempt
}
public protocol OriginalApplicationObservedGraphicsPlatform: OriginalApplicationStartupPlatform {
    var graphicsDelivery: OriginalMenuGraphicsDelivery { get set }
}
