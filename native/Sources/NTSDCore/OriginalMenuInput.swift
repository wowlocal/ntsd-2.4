import Foundation

/// Entire 431b70. Actor references use the shared non-null ordinal convention.
/// This helper reads eight seats regardless of activity, controller or Object ID.
public enum OriginalMenuInput {
    public static func advance(world: OriginalStateRecord, actors: [OriginalStateRecord],
                               globals: inout OriginalStateRecord) throws {
        var state = globals
        let base = OriginalMatchPreparation.globalBase
        for address in stride(from: 0x4513bc, through: 0x4513a4, by: -4) {
            try state.write(Int32(0), at: address-base)
        }
        // Right precedes left, unlike the physical order of the Actor bytes.
        let priority = [(0xcd,0x4513a4), (0xce,0x4513a8), (0xd0,0x4513b0),
                        (0xcf,0x4513ac), (0xd1,0x4513b4), (0xd2,0x4513b8), (0xd3,0x4513bc)]
        for seat in 0..<8 {
            let reference = try world.integer(at: 0x194+seat*4, as: UInt32.self)
            guard reference < actors.count else {
                throw OriginalStateError.invalidStorage("Menu input Actor binding")
            }
            let actor = actors[Int(reference)], latch = 0x451320+seat*4-base
            var pressed = false
            for (offset,flag) in priority where try actor.integer(at: offset, as: UInt8.self) != 0 {
                if try state.integer(at: latch, as: Int32.self) == 0 {
                    try state.write(Int32(1), at: flag-base)
                }
                try state.write(Int32(1), at: latch)
                pressed = true
                break
            }
            if !pressed { try state.write(Int32(0), at: latch) }
        }
        globals = state
    }
}

extension OriginalMatchPreparation {
    public mutating func advanceMenuInput() throws {
        try OriginalMenuInput.advance(world: world, actors: actors, globals: &globals)
    }
}
