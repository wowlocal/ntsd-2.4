import Foundation

/// The per-thread RNG word in the supplied VC80 CRT (PTD+0x14). This state is
/// separate from the game's 417170 table index/counter and survives table rebuilds.
public struct OriginalCRTRandom: Codable, Equatable, Sendable {
    public private(set) var state: UInt32

    /// Actual _initptd 78132d1a establishes 1 before any srand call.
    public init(state: UInt32 = 1) { self.state = state }

    /// VC80 7816d5e3: copy all 32 bits of the unsigned seed.
    public mutating func seed(_ value: UInt32) { state = value }

    /// VC80 7816d5f0: wrapping 32-bit multiplication/addition, logical shift.
    public mutating func next() -> UInt32 {
        state = state &* 0x343fd &+ 0x269ec3
        return (state >> 16) & 0x7fff
    }

    /// Bounded original startup prefix 43cf40..43cf63. The platform supplies
    /// timeGetTime's UInt32 milliseconds; this is not the complete startup path.
    public mutating func seedFromStartup(milliseconds: UInt32, globals: inout OriginalStateRecord) throws {
        try Self.check(globals)
        try globals.write(UInt32(0), at: 0x458420-OriginalMatchPreparation.globalBase)
        seed(milliseconds)
    }

    /// Entire EXE 422ac0, called by 427a2c/427a71. Exactly 3000 CRT draws,
    /// followed by a zero terminator; gameplay RNG index/counter are untouched.
    public mutating func rebuildGameTable(globals: inout OriginalStateRecord) throws {
        try Self.check(globals)
        let start = 0x44ff90-OriginalMatchPreparation.globalBase
        for index in 0..<3000 {
            try globals.write(UInt8(next() % 255 + 1), at: start+index)
        }
        try globals.write(UInt8(0), at: start+3000)
    }

    private static func check(_ globals: OriginalStateRecord) throws {
        guard globals.bytes.count == OriginalMatchPreparation.globalSize else {
            throw OriginalStateError.invalidStorage("CRT RNG global storage size")
        }
    }
}
