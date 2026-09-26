import NTSDCore

/// Window/front requests use the same display owner as the bitmap service.
/// Text and other unsupported requests stop before physical service begins.
@MainActor public final class OriginalMacFrontService {
    public typealias E = OriginalMenuGraphicsRequestExchange
    public let backend: OriginalMacDisplayBackend
    public init(backend: OriginalMacDisplayBackend) { self.backend = backend }
    private enum Prepared {
        case display(OriginalMacDisplayBackend.Prepared)
        case window(OriginalMacWindowBackend.Prepared)
        case front(OriginalMacDisplayBackend.FrontPrepared)
    }
    public func serve<P>(_ permit: E.Permit,on driver: OriginalApplicationObservedGraphicsIteration<P>) throws {
        try serve(permit.request,begin:{ try driver.beginService(permit) },
            answer:{ try driver.answer(permit,response:$0,retaining:$1) },
            fail:{ try driver.fail(permit,diagnostic:$0,retaining:$1) })
    }
    public func serve(_ permit: E.Permit,on exchange: E) throws {
        try serve(permit.request,begin:{ try exchange.beginService(permit) },
            answer:{ try exchange.answer(permit,response:$0,retaining:$1) },
            fail:{ try exchange.fail(permit,diagnostic:$0,retaining:$1) })
    }
    private func serve(_ request: E.Request,begin: () throws -> Void,
        answer: (E.Response,[any OriginalApplicationStartupResource]) throws -> Void,
        fail: (String,[any OriginalApplicationStartupResource]) throws -> Void) throws {
        let prepared: Prepared
        switch request {
        case .window(let q):
            if OriginalMacDisplayBackend.handles(q) { prepared = .display(try backend.prepare(q)) }
            else { prepared = .window(try backend.windows.prepare(q)) }
        case .front(_,let q):prepared = .front(try backend.prepareFront(q))
        case .bitmap:throw OriginalMacDisplayBackend.Boundary.unsupported("bitmap uses its existing service")
        }
        try begin()
        do {
            switch prepared {
            case .display(let q):let r = try backend.perform(q);try answer(.window(r.response),r.resources)
            case .window(let q):let r = try backend.windows.perform(q);try answer(.window(r.response),r.resources)
            case .front(let q):let r = try backend.performFront(q);try answer(.front(r.response),r.resources)
            }
        } catch {
            try fail(String(reflecting:error),backend.retainedResources+backend.windows.retainedResources);throw error
        }
    }
}
