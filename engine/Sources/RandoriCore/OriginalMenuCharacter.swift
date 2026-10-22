/// Whole422f60 menu-key conversion. The hostname caller consumes signed AL,
/// not the API-dependent high bytes of EAX. No host keyboard mapping is used.
public enum OriginalMenuCharacter {
    /// readShift supplies the live byte455388 at each original read. keyState
    /// receives VK_CAPITAL20 and returns a declared GetKeyState result; only
    /// signed low16 bits affect the original decisions. This helper mutates no
    /// state. Its enclosing text/menu operation must stage its own changes.
    public static func decode(_ key: UInt32,readShift: () throws -> UInt8,
        keyState: (UInt32) throws -> Int32) throws -> UInt8 {
        if key == 0x20 { return 0x20 }
        if key &- 0x41 <= 0x19 {
            if try readShift() == 0x64,Int16(truncatingIfNeeded: try keyState(20)) == 0 { return UInt8(key) }
            let caps = Int16(truncatingIfNeeded: try keyState(20))
            if caps <= 0 { return UInt8(key)+0x20 }
            return try readShift() == 0x64 ? UInt8(key)+0x20 : UInt8(key)
        }
        if key &- 0x60 <= 9 { return UInt8(key-0x30) }
        switch key {
        case 0x6b:return 0x2b
        case 0x6d:return 0x2d
        case 0x6a:return 0x2a
        case 0x6f:return 0x2f
        case 0x6e:return 0x2e
        default:break
        }
        let shifted = try readShift() == 0x64
        if shifted {
            if let b = shiftedSymbols[key] { return b }
        } else {
            if key &- 0x30 <= 9 { return UInt8(key) }
            if let b = symbols[key] { return b }
        }
        return navigation[key] ?? 0
    }
    private static let symbols: [UInt32:UInt8] = [0xbd:0x2d,0xbb:0x3d,0xdb:0x5b,0xdd:0x5d,0xba:0x3b,0xde:0x27,0xdc:0x5c,0xbc:0x2c,0xbe:0x2e,0xbf:0x2f,0xc0:0x60]
    private static let shiftedSymbols: [UInt32:UInt8] = [0xbd:0x5f,0xbb:0x2b,0xdb:0x7b,0xdd:0x7d,0xba:0x3a,0xde:0x22,0xdc:0x7c,0xbc:0x3c,0xbe:0x3e,0xbf:0x3f,0xc0:0x7e,0x31:0x21,0x32:0x40,0x33:0x23,0x34:0x24,0x35:0x25,0x36:0x5e,0x37:0x26,0x38:0x2a,0x39:0x28,0x30:0x29]
    private static let navigation: [UInt32:UInt8] = [0x21:0x39,0x22:0x33,0x23:0x31,0x24:0x37,0x25:0x34,0x26:0x38,0x27:0x36,0x28:0x32,0xc:0x35,0x2d:0x30]
}
