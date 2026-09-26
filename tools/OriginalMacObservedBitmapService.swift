import NTSDCore

/// Source-compatible alias; the shared typed request now belongs to Core.
public typealias OriginalMacBitmapRequest = OriginalBitmapRequest
@MainActor public final class OriginalMacBitmapService {
    public typealias Exchange = OriginalBitmapRequestExchange
    public typealias Diagnostic = (OriginalBitmapSurfaceLoading.Request) throws -> OriginalBitmapSurfaceLoading.Response
    public let backend: OriginalMacDisplayBackend,inputs: OriginalMacDisplayBackend.BitmapInputs
    private let diagnostic: Diagnostic?
    public init(backend: OriginalMacDisplayBackend,inputs: OriginalMacDisplayBackend.BitmapInputs,
        diagnostic: Diagnostic? = nil) {
        self.backend = backend;self.inputs = inputs;self.diagnostic = diagnostic
    }
    public func serve(_ permit: Exchange.Permit,on exchange: Exchange) throws {
        try serve(permit,begin:{ try exchange.beginService(permit) },
            answer:{ try exchange.answer(permit,response:$0,retaining:$1) },
            fail:{ try exchange.fail(permit,diagnostic:$0,retaining:$1) })
    }
    public func serve<P>(_ permit: Exchange.Permit,on driver: OriginalApplicationObservedBitmapIteration<P>) throws {
        try serve(permit,begin:{ try driver.beginService(permit) },
            answer:{ try driver.answer(permit,response:$0,retaining:$1) },
            fail:{ try driver.fail(permit,diagnostic:$0,retaining:$1) })
    }
    private func serve(_ permit: Exchange.Permit,begin: () throws -> Void,
        answer: (Exchange.Response,[any OriginalApplicationStartupResource]) throws -> Void,
        fail: (String,[any OriginalApplicationStartupResource]) throws -> Void) throws {
        let q = permit.request.value
        let prepared: OriginalMacDisplayBackend.BitmapPrepared?
        if q.kind == "message" || q.kind == "debug" {
            guard diagnostic != nil,q.bytes == nil,q.defined == nil,
                (q.kind == "message" && q.words == [0,0] && q.strings.count == 2) ||
                (q.kind == "debug" && q.words.isEmpty && q.strings.count == 1) else {
                throw OriginalMacDisplayBackend.Boundary.unsupported("bitmap diagnostic consumer")
            }
            prepared = nil
        } else { prepared = try backend.prepareBitmap(q,inputs:inputs) }
        try begin()
        do {
            if let prepared {
                let result = try backend.performBitmap(prepared);try answer(result.response,result.resources)
            } else { try answer(diagnostic!(q),[]) }
        } catch {
            try fail(String(reflecting:error),backend.retainedResources);throw error
        }
    }
}
