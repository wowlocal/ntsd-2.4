import NTSDCore

/// Runtime logical allocator for Core-visible addresses. This is a declared Mac
/// runtime policy, not the Windows heap: addresses are 16-byte aligned inside a
/// fixed arena, never overlap and are never reused; backing is zero-filled.
/// Callers use it only while servicing an external permit, outside Core attempts.
@MainActor public final class OriginalMacRuntimeHeap {
    public enum Boundary: Error, Equatable { case invalidCount(Int), exhausted(Int) }
    public static let arena: Range<UInt32> = 0x30000000..<0x70000000
    public static let alignment: UInt32 = 16
    public struct Block: Equatable { public let address: UInt32, count: Int }
    private var next = OriginalMacRuntimeHeap.arena.lowerBound
    public private(set) var blocks: [Block] = []
    public init() {}
    /// Zero-count requests still receive a distinct nonzero address, as a
    /// successful allocator must. Counts over 256MiB are rejected explicitly.
    public func allocate(_ count: Int) throws -> OriginalInterfaceAllocation {
        guard count >= 0,count <= 0x10000000 else { throw Boundary.invalidCount(count) }
        let size = UInt64(max(count,1)),align = UInt64(Self.alignment)
        let start = UInt64(next),end = start+size
        guard end <= UInt64(Self.arena.upperBound) else { throw Boundary.exhausted(count) }
        next = UInt32((end+align-1)/align*align)
        blocks.append(.init(address:UInt32(start),count:count))
        return .init(address:UInt32(start),backing:[UInt8](repeating:0,count:count))
    }
}
