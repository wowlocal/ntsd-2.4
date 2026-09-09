public struct OriginalWorldImpulseWrite: Equatable {
    public let slot: Int,actor: Int,offset: Int,size: Int
    public let value: UInt64
}

/// Whole4196f0..419798. No Object, frame, type, ID or RNG dependency.
/// Arithmetic reproduces CW037f values; process-wide x87 exception flags are
/// not native game state. Observers must be buffered by the enclosing tick.
public enum OriginalWorldImpulses {
    public static func apply(state: inout OriginalMatchPreparation,
                             observe: (OriginalWorldImpulseWrite) throws -> Void = { _ in }) throws {
        try apply(world: state.world,actors: &state.actors,observe: observe)
    }
    static func apply(world: OriginalStateRecord,actors: inout [OriginalStateRecord],
                      observe: (OriginalWorldImpulseWrite) throws -> Void = { _ in }) throws {
        var pool = actors
        func index(_ slot: Int) throws -> Int {
            let value = Int(try world.integer(at: 0x194+4*slot,as: UInt32.self))
            guard pool.indices.contains(value) else { throw OriginalStateError.invalidStorage("World impulses: Actor binding") }
            return value
        }
        func put(_ slot: Int,_ offset: Int,_ value: UInt64,_ size: Int = 8) throws {
            let a = try index(slot)
            if size == 4 { try pool[a].write(UInt32(truncatingIfNeeded: value),at: offset) }
            else { try pool[a].write(value,at: offset) }
            try observe(.init(slot: slot,actor: a,offset: offset,size: size,value: value))
        }
        for slot in 0..<400 where try world.integer(at: 4+slot,as: UInt8.self) != 0 {
            let a = try index(slot)
            if try pool[a].integer(at: 0xb4,as: Int32.self) != 0 { continue }
            if try pool[a].integer(at: 0x20,as: Int32.self) != 0 {
                for offset in [0x28,0x30,0x38] {
                    let a = try index(slot),count = try pool[a].integer(at: 0x20,as: Int32.self)
                    let bits = try pool[a].integer(at: offset,as: UInt64.self)
                    try put(slot,offset+0x18,scaled(bits,divisor: count &+ 1))
                }
                try put(slot,0x20,0,4)
            }
            for offset in [0x28,0x30,0x38] { try put(slot,offset,0) }
        }
        actors = pool
    }
    private static func scaled(_ bits: UInt64,divisor: Int32) throws -> UInt64 {
        let magnitude = bits & 0x7fffffffffffffff
        // FLD quiets signaling NaNs; their sign/payload survives positive2 and
        // integer division, including a negative or zero divisor.
        if magnitude > 0x7ff0000000000000 { return bits | 0x0008000000000000 }
        if divisor == 0 {
            return magnitude == 0 ? 0xfff8000000000000 : (bits & 0x8000000000000000) | 0x7ff0000000000000
        }
        if magnitude == 0x7ff0000000000000 { return divisor < 0 ? bits ^ 0x8000000000000000 : bits }
        // Do not round/overflow the multiply in binary64 before dividing.
        return try ((OriginalExtended(Double(bitPattern: bits))*OriginalExtended(2))/OriginalExtended(Double(divisor))).double.bitPattern
    }
}
