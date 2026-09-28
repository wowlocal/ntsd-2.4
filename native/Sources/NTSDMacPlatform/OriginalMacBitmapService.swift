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
        try serve(permit.request.value,begin:{ try exchange.beginService(permit) },
            answer:{ try exchange.answer(permit,response:$0,retaining:$1) },
            fail:{ try exchange.fail(permit,diagnostic:$0,retaining:$1) })
    }
    public func serve<P>(_ permit: Exchange.Permit,on driver: OriginalApplicationObservedBitmapIteration<P>) throws {
        try serve(permit.request.value,begin:{ try driver.beginService(permit) },
            answer:{ try driver.answer(permit,response:$0,retaining:$1) },
            fail:{ try driver.fail(permit,diagnostic:$0,retaining:$1) })
    }
    public func serve<P>(_ permit: OriginalMenuGraphicsRequestExchange.Permit,
        on driver: OriginalApplicationObservedGraphicsIteration<P>) throws {
        guard case .bitmap(_,let q) = permit.request else {
            throw OriginalMacDisplayBackend.Boundary.unsupported("menu graphics bitmap family")
        }
        try serve(q,begin:{ try driver.beginService(permit) },
            answer:{ try driver.answer(permit,response:.bitmap($0),retaining:$1) },
            fail:{ try driver.fail(permit,diagnostic:$0,retaining:$1) })
    }
    public func serve<P>(_ permit: OriginalApplicationIterationExchange.Permit,
        on driver: OriginalApplicationObservedIteration<P>) throws {
        guard case .graphics(.bitmap(_,let q)) = permit.request else {
            throw OriginalMacDisplayBackend.Boundary.unsupported("iteration bitmap family")
        }
        try serve(q,begin:{ try driver.beginService(permit) },
            answer:{ try driver.answer(permit,response:.graphics(.bitmap($0)),retaining:$1) },
            fail:{ try driver.fail(permit,diagnostic:$0,retaining:$1) })
    }
    private func serve(_ q: OriginalBitmapSurfaceLoading.Request,begin: () throws -> Void,
        answer: (Exchange.Response,[any OriginalApplicationStartupResource]) throws -> Void,
        fail: (String,[any OriginalApplicationStartupResource]) throws -> Void) throws {
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
