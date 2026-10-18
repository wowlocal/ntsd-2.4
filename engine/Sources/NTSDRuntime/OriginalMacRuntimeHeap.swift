import NTSDCore

/// Runtime logical allocator for Core-visible addresses. This is a declared Mac
/// runtime policy, not the Windows heap: addresses are 16-byte aligned inside a
/// fixed arena and never overlap; backing is zero-filled. Addresses are never
/// reused, except replay blocks (the per-match recording, a playback buffer and
/// the result writer's buffer): one that the current Core memory marks freed is
/// handed out again for a replay request of the same size.
/// Callers use it only while servicing an external permit, outside Core attempts.
@MainActor public final class OriginalMacRuntimeHeap {
    public enum Boundary: Error, Equatable { case invalidCount(Int), exhausted(Int) }
    public static let arena: Range<UInt32> = 0x30000000..<0x70000000
    public static let alignment: UInt32 = 16
    public struct Block: Equatable { public let address: UInt32, count: Int }
    private var next = OriginalMacRuntimeHeap.arena.lowerBound
    public private(set) var blocks: [Block] = []
    /// Replay block start → size, and those the last `collect` found freed.
    private var replayBlocks: [UInt32:Int] = [:],freed: Set<UInt32> = []
    /// Arena bytes handed out so far.
    public var used: UInt32 { next - Self.arena.lowerBound }
    public init() {}
    /// Zero-count requests still receive a distinct nonzero address, as a
    /// successful allocator must. Counts over 256MiB are rejected explicitly.
    public func allocate(_ count: Int) throws -> OriginalInterfaceAllocation {
        .init(address:try reserve(count),backing:[UInt8](repeating:0,count:count))
    }
    /// Address only, for callers whose Core owner materializes its own backing.
    public func reserve(_ count: Int) throws -> UInt32 {
        guard count >= 0,count <= 0x10000000 else { throw Boundary.invalidCount(count) }
        let size = UInt64(max(count,1)),align = UInt64(Self.alignment)
        let start = UInt64(next),end = start+size
        guard end <= UInt64(Self.arena.upperBound) else { throw Boundary.exhausted(count) }
        next = UInt32((end+align-1)/align*align)
        blocks.append(.init(address:UInt32(start),count:count))
        return UInt32(start)
    }
    /// Address only, for a replay block: the lowest freed one of this size,
    /// otherwise a new one.
    public func reserveReplay(_ count: Int) throws -> UInt32 {
        if let address = freed.filter({ replayBlocks[$0] == count }).min() { freed.remove(address); return address }
        let address = try reserve(count); replayBlocks[address] = count; return address
    }
    /// Takes the replay blocks that `memory` (the owner the next Core call
    /// starts from) holds as freed allocations; live and unknown ones stay out.
    public func collect(_ memory: OriginalMenuPresentationMemory) {
        freed = Set(replayBlocks.keys.filter { memory.allocations[$0].map { !$0.live } ?? false })
    }
}
