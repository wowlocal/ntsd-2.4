/// Original loading-time pool, EXE 0x41c052..0x41c2f5, before bitmap allocation.
/// This is NOT selected-player/new-round spawning. It constructs all 400 slots,
/// then reconstructs and activates eight staging actors using catalog entry zero.
public struct OriginalWorldBootstrap: Equatable, Sendable {
    public static let slotCount = 400
    public private(set) var world: OriginalStateRecord
    public private(set) var actors: [OriginalStateRecord]

    /// Canonical references in these records are UInt32 ordinals, not host or x86
    /// addresses: World actor table -> slot number; catalog pointer -> catalog 0;
    /// Actor +0x368 -> object entry 0. All allocations are present/non-null.
    /// No other dword, including opaque address-looking data, is normalized.
    public init(worldBacking: [UInt8], actorBacking: [[UInt8]], selector: Int32) throws {
        guard actorBacking.count == Self.slotCount else {
            throw OriginalStateError.invalidStorage("Bootstrap requires all 400 Actor backing allocations")
        }
        world = try .worldPrefix(over: worldBacking)
        try world.write(selector, at: 0)
        try world.write(UInt32(0), at: 0x7d4) // bound catalog, not null
        actors = []
        actors.reserveCapacity(Self.slotCount)
        for (slot, backing) in actorBacking.enumerated() {
            var record = try OriginalStateRecord.actor(over: backing)
            try record.writeBinary64(200, at: 0x58) // 0x449470
            try record.writeBinary64(0, at: 0x60)
            try record.writeBinary64(300, at: 0x68) // 0x447928
            try record.write(UInt32(0), at: 0x368) // bound first object, not null
            actors.append(record)
            try world.write(UInt32(slot), at: 0x194 + slot * 4)
            try world.write(UInt8(0), at: 4 + slot)
        }
    }

    /// Original 0x41c0d8..0x41c2f5. +0x31c copies the first Object's +0x90
    /// word verbatim; its wider semantics belong to the whole-object loader.
    /// The fixed positions and eight slots are actual EXE bootstrap writes,
    /// not per-character rules or assumptions about the final match formation.
    public mutating func activateStagingActors(firstObjectWord90: Int32) throws {
        let positions: [(Double, Double)] = [(200, 0), (210, 0), (210, 0), (210, 0),
                                             (580, -200), (570, 0), (580, -200), (570, 0)]
        for (slot, position) in positions.enumerated() {
            try actors[slot].reconstructActor()
            try actors[slot].write(UInt32(0), at: 0x368)
            try actors[slot].write(firstObjectWord90, at: 0x31c)
            try actors[slot].writeBinary64(position.0, at: 0x58)
            try actors[slot].writeBinary64(position.1, at: 0x60)
            try actors[slot].writeBinary64(300, at: 0x68)
            try world.write(UInt8(1), at: 4 + slot)
        }
    }
}
