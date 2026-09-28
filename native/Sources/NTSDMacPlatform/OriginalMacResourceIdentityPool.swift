/// One identity space for all resources of a native platform instance. Tokens
/// are never recycled and do not encode pointers or source address ranges.
@MainActor public final class OriginalMacResourceIdentityPool {
    public enum Boundary: Error { case exhausted }
    private var next: UInt32 = 1
    public init() {}
    func take() throws -> UInt32 {
        guard next != 0 else { throw Boundary.exhausted }
        let result = next; next &+= 1; return result
    }
}
