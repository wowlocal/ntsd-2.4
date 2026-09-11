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
        var world = try OriginalStateRecord.worldPrefix(over: worldBacking)
        try world.write(selector, at: 0)
        try self.init(world: world, actorBacking: actorBacking)
    }

    /// Continue an already constructed World, retaining all earlier bytes/masks.
    public init(world initialWorld: OriginalStateRecord, actorBacking: [[UInt8]]) throws {
        guard actorBacking.count == Self.slotCount else {
            throw OriginalStateError.invalidStorage("Bootstrap requires World and400 Actor backing allocations")
        }
        try self.init(world: initialWorld, allocateActor: { slot, _ in actorBacking[slot] })
    }

    /// Deliver each allocation at41c075, then construct it before requesting the
    /// next slot. The observer sees the completed4061d0 bytes before caller fields.
    /// Allocator/observer effects must be staged by the enclosing operation.
    public init(world initialWorld: OriginalStateRecord,
                allocateActor: (Int, Int) throws -> [UInt8],
                afterConstructor: (Int, OriginalStateRecord) throws -> Void = { _, _ in }) throws {
        guard initialWorld.bytes.count == OriginalStateRecord.worldPrefixSize else {
            throw OriginalStateError.invalidStorage("Bootstrap requires World and400 Actor backing allocations")
        }
        self.world = initialWorld
        try world.write(UInt32(0), at: 0x7d4) // bound catalog, not null
        actors = []
        actors.reserveCapacity(Self.slotCount)
        for slot in 0..<Self.slotCount {
            let backing = try allocateActor(slot, OriginalStateRecord.actorSize)
            var record = try OriginalStateRecord.actor(over: backing)
            try afterConstructor(slot, record)
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
    public mutating func activateStagingActors(firstObjectWord90: Int32,
                afterConstructor: (Int, OriginalStateRecord) throws -> Void = { _, _ in }) throws {
        try activateStagingActors(firstObjectWord90: { firstObjectWord90 }, afterConstructor: afterConstructor)
    }

    /// Read Object+90 at each original consumer, after that Actor constructor.
    /// A missing value must not prevent the preceding allocations/constructions.
    public mutating func activateStagingActors(firstObjectWord90: () throws -> Int32,
                afterConstructor: (Int, OriginalStateRecord) throws -> Void = { _, _ in }) throws {
        var candidate = self
        let positions: [(Double, Double)] = [(200, 0), (210, 0), (210, 0), (210, 0),
                                             (580, -200), (570, 0), (580, -200), (570, 0)]
        for (slot, position) in positions.enumerated() {
            try candidate.actors[slot].reconstructActor()
            try afterConstructor(slot, candidate.actors[slot])
            try candidate.actors[slot].write(UInt32(0), at: 0x368)
            try candidate.actors[slot].write(firstObjectWord90(), at: 0x31c)
            try candidate.actors[slot].writeBinary64(position.0, at: 0x58)
            try candidate.actors[slot].writeBinary64(position.1, at: 0x60)
            try candidate.actors[slot].writeBinary64(300, at: 0x68)
            try candidate.world.write(UInt8(1), at: 4 + slot)
        }
        self = candidate
    }
}
