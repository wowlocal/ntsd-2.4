import NTSDCore

/// Physical resource work is served outside Core, once per validated permit.
@MainActor public final class OriginalMacDisplayStartupService<Platform: OriginalApplicationObservedStartupPlatform> {
    public typealias Driver = OriginalApplicationObservedStartup<Platform>
    public enum Boundary: Error { case notWindowRequest }
    public let backend: OriginalMacDisplayBackend
    private let driver: Driver
    public init(driver: Driver,backend: OriginalMacDisplayBackend) { self.driver = driver;self.backend = backend }
    public func serve(_ permit: Driver.Exchange.Permit) throws {
        guard case .window(let q) = permit.request else { throw Boundary.notWindowRequest }
        let prepared = try backend.prepare(q)
        try driver.beginService(permit)
        do {
            let value = try backend.perform(prepared)
            try driver.answer(permit,response:.window(value.response),retaining:value.resources)
        } catch {
            try driver.fail(permit,diagnostic:String(reflecting:error),retaining:backend.retainedResources)
            throw error
        }
    }
}
