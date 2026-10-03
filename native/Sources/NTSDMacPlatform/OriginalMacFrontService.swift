import NTSDCore

/// Window/front requests use the same display owner as the bitmap service.
/// Text and other unsupported requests stop before physical service begins.
@MainActor public final class OriginalMacFrontService {
    public typealias E = OriginalMenuGraphicsRequestExchange
    public typealias Diagnostic = (OriginalWindowInitialization.Request) throws -> OriginalWindowInitialization.Response
    public let backend: OriginalMacDisplayBackend
    private let diagnostic: Diagnostic?
    public init(backend: OriginalMacDisplayBackend,diagnostic: Diagnostic? = nil) {
        self.backend = backend;self.diagnostic = diagnostic
    }
    private enum Prepared {
        case display(OriginalMacDisplayBackend.Prepared)
        case window(OriginalMacWindowBackend.Prepared)
        case front(OriginalMacDisplayBackend.FrontPrepared)
        case diagnostic(OriginalWindowInitialization.Request,Diagnostic)
    }
    public func serve<P>(_ permit: E.Permit,on driver: OriginalApplicationObservedGraphicsIteration<P>) throws {
        try serve(permit.request,begin:{ try driver.beginService(permit) },
            answer:{ try driver.answer(permit,response:$0,retaining:$1) },
            fail:{ try driver.fail(permit,diagnostic:$0,retaining:$1) })
    }
    /// Whole-iteration permits: only the menu-graphics window/front family.
    public func serve<P>(_ permit: OriginalApplicationIterationExchange.Permit,on driver: OriginalApplicationObservedIteration<P>) throws {
        guard case .graphics(let q) = permit.request else { throw OriginalMacDisplayBackend.Boundary.unsupported("iteration non-graphics family") }
        try serve(q,begin:{ try driver.beginService(permit) },
            answer:{ try driver.answer(permit,response:.graphics($0),retaining:$1) },
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
            if q.kind == "debug" {
                guard let diagnostic else { throw OriginalMacDisplayBackend.Boundary.unsupported("window debug consumer") }
                guard q.words.isEmpty,q.bytes == nil,q.defined == nil,q.strings.count == 1 else {
                    throw OriginalMacDisplayBackend.Boundary.arguments("window debug")
                }
                prepared = .diagnostic(q,diagnostic)
            } else if OriginalMacDisplayBackend.handles(q) { prepared = .display(try backend.prepare(q)) }
            else { prepared = .window(try backend.macWindows.prepare(q)) }
        case .front(_,let q):prepared = .front(try backend.prepareFront(q))
        case .bitmap:throw OriginalMacDisplayBackend.Boundary.unsupported("bitmap uses its existing service")
        }
        try begin()
        do {
            switch prepared {
            case .display(let q):let r = try backend.perform(q);try answer(.window(r.response),r.resources)
            case .window(let q):let r = try backend.macWindows.perform(q);try answer(.window(r.response),r.resources)
            case .front(let q):let r = try backend.performFront(q);try answer(.front(r.response),r.resources)
            case .diagnostic(let q,let consume):
                let response = try consume(q)
                try answer(.window(response),backend.retainedResources+backend.macWindows.retainedResources)
            }
        } catch {
            try fail(String(reflecting:error),backend.retainedResources+backend.macWindows.retainedResources);throw error
        }
    }
}
