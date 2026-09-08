import Foundation

public enum OriginalReplayAllocationEvent: Equatable {
    case allocate(generation: UInt32, bytes: Int)
    case release(generation: UInt32)
}

/// Recording buffer initialization 43d2c0..43db38 and free/reset 43d280.
/// This is not replay playback, compression, file IO or per-tick recording.
public struct OriginalReplayRecording {
    public static let byteCount = 0x630e18
    public private(set) var buffer: OriginalStateRecord?
    /// Logical non-null allocation identity. No Windows/host pointer is stored
    /// in the runtime; clear retains the generation but removes the buffer.
    public private(set) var generation: UInt32 = 0

    public init() {}

    public mutating func clear(observe: (OriginalReplayAllocationEvent) throws -> Void = { _ in }) throws {
        if buffer != nil {
            try observe(.release(generation: generation))
            buffer = nil
        }
    }

    public mutating func begin(mode: Int32, world: OriginalStateRecord, actors: [OriginalStateRecord],
                               catalog: OriginalLoadedCatalog, globals: inout OriginalStateRecord,
                               observe: (OriginalReplayAllocationEvent) throws -> Void = { _ in }) throws {
        var candidate = self, state = globals
        try candidate.initialize(mode: mode, world: world, actors: actors, catalog: catalog, globals: &state, observe: observe)
        self = candidate; globals = state
    }

    private mutating func initialize(mode: Int32, world: OriginalStateRecord, actors: [OriginalStateRecord],
                                     catalog: OriginalLoadedCatalog, globals: inout OriginalStateRecord,
                                     observe: (OriginalReplayAllocationEvent) throws -> Void) throws {
        guard world.bytes.count == OriginalStateRecord.worldPrefixSize, actors.count == 400,
              globals.bytes.count == OriginalMatchPreparation.globalSize else { throw Self.error("Input storage sizes") }
        try clear(observe: observe)
        guard generation != UInt32.max else { throw Self.error("Logical allocation identity exhausted") }
        generation += 1
        try observe(.allocate(generation: generation, bytes: Self.byteCount))
        // Original calloc(1, 0x630e18) defines every byte, including unused data.
        var record = try OriginalStateRecord(bytes: [UInt8](repeating: 0, count: Self.byteCount),
                                             defined: [Bool](repeating: true, count: Self.byteCount))
        func global(_ address: Int) throws -> UInt32 {
            try globals.integer(at: address-OriginalMatchPreparation.globalBase, as: UInt32.self)
        }
        func copyString(_ source: Int, _ destination: Int) throws {
            var offset = 0
            while true {
                let byte = try globals.integer(at: source+offset-OriginalMatchPreparation.globalBase, as: UInt8.self)
                try record.write(byte, at: destination+offset)
                offset += 1
                if byte == 0 { return }
            }
        }
        try globals.write(UInt32(0), at: 0x450b8c-OriginalMatchPreparation.globalBase)
        try globals.write(UInt32(1), at: 0x450b80-OriginalMatchPreparation.globalBase)
        for (destination, source) in [(0, 0x450c30), (8, 0x458428), (12, 0x45842c), (4, 0x450b94)] {
            try record.write(global(source), at: destination)
        }
        try record.write(mode, at: 0x148)
        for seat in 0..<8 { try copyString(0x44fcc0+seat*11, 0x14c+seat*11) }
        for (source, destination) in [(0x44fd18, 0x630bc0), (0x44f900, 0x630c24), (0x44f890, 0x630db4)] {
            try copyString(source, destination)
        }
        try record.write(global(0x44d024), at: 0x1a4)
        // Thirteen arrays of 18 dwords. Inactive slots are copied too. Only
        // Object +6f4 (source ID) is exported, never its registry ordinal.
        for slot in 0..<18 {
            guard try world.integer(at: 0x194+slot*4, as: UInt32.self) == slot else { throw Self.error("Actor table binding") }
            let actor = actors[slot], object = Int(try actor.integer(at: 0x368, as: UInt32.self))
            guard catalog.objects.indices.contains(object) else { throw Self.error("Object binding") }
            try record.write(actor.integer(at: 0x364, as: UInt32.self), at: 0x1a8+slot*4)
            try record.write(catalog.objects[object].header.integer(at: 0x6f4, as: UInt32.self), at: 0x1f0+slot*4)
            try record.write(Int32(world.integer(at: 4+slot, as: Int8.self)), at: 0x238+slot*4)
            for (array, offset) in [0x8, 0x10, 0x14, 0x18, 0x308, 0x354, 0x304, 0x33c, 0x344, 0x340].enumerated() {
                try record.write(actor.integer(at: offset, as: UInt32.self), at: 0x280+array*0x48+slot*4)
            }
        }
        try copyString(0x44eed0, 0x550)
        try record.write(global(0x44f620), at: 0x744)
        try record.write(global(0x44d03c), at: 0x748)
        for word in 0..<22 {
            for block in 0..<4 { try record.write(global(0x44d5f8+block*0x58+word*4), at: 0x74c+block*0x58+word*4) }
        }
        try record.write(global(0x450bcc), at: 0x8c4)
        // Fixed 3001-byte copy, including the byte after the 3000-entry table.
        // It is not strlen, and the RNG counter is not saved here.
        for offset in 0..<3001 {
            try record.write(globals.integer(at: 0x44ff90+offset-OriginalMatchPreparation.globalBase, as: UInt8.self), at: 0x8c8+offset)
        }
        for word in 0..<11 { try record.write(global(0x44d324+word*4), at: 0x1488+word*4) }
        try record.write(global(0x450b90), at: 0x14b4)
        for address in [0x450c34, 0x450bd0, 0x450bd4, 0x450bd8] {
            try globals.write(UInt32(0), at: address-OriginalMatchPreparation.globalBase)
        }
        buffer = record
    }

    private static func error(_ message: String) -> OriginalLoaderError { .outsideVerifiedDomain("Replay initialization: \(message)") }
}
