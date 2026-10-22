/// Opaque lifetime retention only; the backend owns actual operations and release.
public protocol OriginalWindowResponseResource: AnyObject {}

extension OriginalWindowInitialization.Request: OriginalExchangeRequest {
    public typealias Reply = OriginalWindowInitialization.Response
    // Preserve the original window contract: payload validation belongs to the
    // recovered child, not to this generic transport owner.
    public func accepts(_ response: Reply) -> Bool { true }
}

/// Existing window API, now sharing the same owner/cursor/permit implementation.
public typealias OriginalWindowRequestExchange = OriginalRequestExchange<
    OriginalWindowInitialization.Request, any OriginalWindowResponseResource>
