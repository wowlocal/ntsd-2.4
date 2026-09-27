import NTSDCore

/// Serve audio only after the whole Core attempt unwinds. Fulfilled receipts own
/// their resources; retries never repeat these copies or allocations.
@MainActor public final class OriginalMacAudioService {
    public typealias Exchange = OriginalStartupRequestExchange
    public let backend: OriginalMacAudioBackend
    public init(backend: OriginalMacAudioBackend) { self.backend = backend }
    public func serve(_ permit: Exchange.Permit,on exchange: Exchange) throws {
        try serve(permit.request,begin:{ try exchange.beginService(permit) },
            answer:{ try exchange.answer(permit,response:$0,retaining:$1) },
            fail:{ try exchange.fail(permit,diagnostic:$0,retaining:$1) })
    }
    public func serve<P>(_ permit: Exchange.Permit,on driver: OriginalApplicationObservedStartup<P>) throws {
        try serve(permit.request,begin:{ try driver.beginService(permit) },
            answer:{ try driver.answer(permit,response:$0,retaining:$1) },
            fail:{ try driver.fail(permit,diagnostic:$0,retaining:$1) })
    }
    private func serve(_ request: OriginalStartupRequest,begin: () throws -> Void,
        answer: (OriginalStartupResponse,[any OriginalApplicationStartupResource]) throws -> Void,
        fail: (String,[any OriginalApplicationStartupResource]) throws -> Void) throws {
        let prepared = try backend.prepare(request)
        try begin()
        do {
            let result = try backend.perform(prepared);try answer(result.response,result.resources)
        } catch {
            try fail(String(reflecting:error),backend.retainedResources);throw error
        }
    }
    public func serve(_ permit: OriginalLoadingAudioExchange.Permit,on exchange: OriginalLoadingAudioExchange) throws {
        try serveLoading(permit.request,begin:{ try exchange.beginService(permit) },
            answer:{ try exchange.answer(permit,response:$0,retaining:$1) },
            fail:{ try exchange.fail(permit,diagnostic:$0,retaining:$1) })
    }
    public func serve<P>(_ permit: OriginalLoadingAudioExchange.Permit,on driver: OriginalApplicationObservedLoadingAudio<P>) throws {
        try serveLoading(permit.request,begin:{ try driver.beginService(permit) },
            answer:{ try driver.answer(permit,response:$0,retaining:$1) },
            fail:{ try driver.fail(permit,diagnostic:$0,retaining:$1) })
    }
    private func serveLoading(_ request: OriginalLoadingAudioRequest,begin: () throws -> Void,
        answer: (OriginalLoadingAudioRequest.Reply,[any OriginalApplicationStartupResource]) throws -> Void,
        fail: (String,[any OriginalApplicationStartupResource]) throws -> Void) throws {
        let prepared = try backend.prepareLoading(request)
        try begin()
        do {
            let result = try backend.performLoading(prepared);try answer(result.response,result.resources)
        } catch {
            try fail(String(reflecting:error),backend.retainedResources);throw error
        }
    }
}
