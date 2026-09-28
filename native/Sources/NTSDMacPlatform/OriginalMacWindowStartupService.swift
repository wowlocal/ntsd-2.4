import NTSDCore

/// Bound to one startup owner; IO starts only after its unforgeable permit is
/// validated atomically. Core rollback never repeats or undoes this physical work.
@MainActor public final class OriginalMacWindowStartupService<Platform: OriginalApplicationObservedStartupPlatform> {
    public typealias Driver = OriginalApplicationObservedStartup<Platform>
    public enum Boundary: Error { case notWindowRequest }
    public let backend: OriginalMacWindowBackend
    private let driver: Driver
    public init(driver: Driver,backend: OriginalMacWindowBackend) {
        self.driver = driver; self.backend = backend
    }
    public func serve(_ permit: Driver.Exchange.Permit) throws {
        guard case .window(let q) = permit.request else { throw Boundary.notWindowRequest }
        // Unsupported DirectDraw/surface requests stay available to a separately
        // declared provider. They do not turn into numeric success or failure.
        let prepared = try backend.prepare(q)
        try driver.beginService(permit)
        do {
            let served = try backend.perform(prepared)
            try driver.answer(permit,response:.window(served.response),retaining:served.resources)
        } catch {
            // The operation began; preserve a diagnostic and all remaining owners.
            // If a reentrant caller already ended the permit, do not hide its error.
            try driver.fail(permit,diagnostic:String(reflecting:error),retaining:backend.retainedResources)
            throw error
        }
    }
}
