import NTSDCore

/// A typed use of the shared request exchange, not another execution engine.
/// The enclosing caller stages a cursor, unwinds on RequestNeeded, then claims
/// and serves the request here. Finish only after the entire caller can commit.
public struct OriginalMacBitmapRequest: OriginalExchangeRequest {
    public typealias Reply = OriginalBitmapSurfaceLoading.Response
    public let value: OriginalBitmapSurfaceLoading.Request
    public init(_ value: OriginalBitmapSurfaceLoading.Request) { self.value = value }
    public func accepts(_ response: Reply) -> Bool { true }
}
@MainActor public final class OriginalMacBitmapService {
    public typealias Exchange = OriginalRequestExchange<OriginalMacBitmapRequest, any OriginalApplicationStartupResource>
    public let backend: OriginalMacDisplayBackend,inputs: OriginalMacDisplayBackend.BitmapInputs
    public init(backend: OriginalMacDisplayBackend,inputs: OriginalMacDisplayBackend.BitmapInputs) {
        self.backend = backend;self.inputs = inputs
    }
    /// Validation precedes beginService; actual allocation/copy follows it once.
    /// Receipts retain retired owners as well as live ones across late rollback.
    public func serve(_ permit: Exchange.Permit,on exchange: Exchange) throws {
        let prepared = try backend.prepareBitmap(permit.request.value,inputs:inputs)
        try exchange.beginService(permit)
        do {
            let result = try backend.performBitmap(prepared)
            try exchange.answer(permit,response:result.response,retaining:result.resources)
        } catch {
            try exchange.fail(permit,diagnostic:String(reflecting:error),retaining:backend.retainedResources)
            throw error
        }
    }
}
