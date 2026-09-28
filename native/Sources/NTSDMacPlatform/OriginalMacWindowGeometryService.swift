import NTSDCore

/// Actual geometry queries run outside the Core transaction and only once per
/// receipt. Other lifecycle requests require their own explicit provider.
@MainActor public final class OriginalMacWindowGeometryService {
    public let backend: OriginalMacWindowBackend
    public enum Boundary: Error, Equatable { case notGeometry }
    public init(backend: OriginalMacWindowBackend) { self.backend = backend }
    public func serve<P>(_ permit: OriginalLifecycleRequestExchange.Permit,
        on driver: OriginalApplicationObservedLifecycleIteration<P>) throws {
        let q = permit.request
        guard q.kind == "clientRect" || q.kind == "screenPoint" else { throw Boundary.notGeometry }
        let prepared = try backend.prepare(q)
        try driver.beginService(permit)
        do {
            let value = try backend.perform(prepared)
            try driver.answer(permit,response:value.response,retaining:value.resources)
        } catch {
            try driver.fail(permit,diagnostic:String(reflecting:error),retaining:backend.retainedResources)
            throw error
        }
    }
}
