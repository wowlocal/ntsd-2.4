import Foundation

/// Win32 SYSTEMTIME values supplied by the platform boundary. Prelude uses six
/// UInt16 fields verbatim; day-of-week and milliseconds are intentionally unused.
public struct OriginalLocalTime: Codable, Equatable {
    public let year: UInt16, month: UInt16, dayOfWeek: UInt16, day: UInt16
    public let hour: UInt16, minute: UInt16, second: UInt16, milliseconds: UInt16
    public init(year: UInt16, month: UInt16, dayOfWeek: UInt16, day: UInt16,
                hour: UInt16, minute: UInt16, second: UInt16, milliseconds: UInt16) {
        self.year = year; self.month = month; self.dayOfWeek = dayOfWeek; self.day = day
        self.hour = hour; self.minute = minute; self.second = second; self.milliseconds = milliseconds
    }
}

public enum OriginalMatchPreludeEvent: Equatable {
    case localTime
    case soundRequest(loop: Bool)
    case soundMethod(resource: UInt32, vtableOffset: Int, arguments: [UInt32])
    case fillRectangle(resource: UInt32, x: Int32, y: Int32, width: Int32, height: Int32, color: UInt32)
}

/// Menu-confirmed prelude 42cf8a..42d1ff, using the actual caller's mode 451160
/// and menu-state 44d020 bindings. This is not menu selection, enabled music,
/// device output or a complete match start. Device words are opaque resource
/// handles supplied by an adapter; this native code never dereferences them.
public enum OriginalMatchPrelude {
    @discardableResult
    public static func apply(globals: inout OriginalStateRecord, localTime: OriginalLocalTime,
                             observe: (OriginalMatchPreludeEvent) throws -> Void = { _ in }) throws -> String {
        guard globals.bytes.count == OriginalMatchPreparation.globalSize else { throw error("Global storage size") }
        var state = globals
        func read(_ address: Int) throws -> Int32 { try state.integer(at: address-OriginalMatchPreparation.globalBase, as: Int32.self) }
        func write(_ address: Int, _ value: Int32) throws { try state.write(value, at: address-OriginalMatchPreparation.globalBase) }
        let mode = try read(0x451160)
        try write(0x450bb0, 0); try write(0x450bb4, 0)
        if mode == 1 {
            let stage = try read(0x450b94)
            try write(0x450b9c, 70)
            for address in [0x450ba8, 0x450bac, 0x450ba4, 0x44d028] { try write(address, 0) }
            if let arena = [Int32(0): Int32(1), 10: 2, 20: 3, 30: 4, 40: 5, 50: 6][stage] {
                try write(0x44d024, arena)
            }
            try write(0x44fb6c, -1); try write(0x450ba0, 0); try write(0x44f880, -1)
            try write(0x450bc8, 0); try write(0x450bc4, 0)
        }
        try write(0x44d020, 0)
        try observe(.localTime)
        // sprintf "%4d%02d%02d_%02d%02d%02d": year is SPACE padded,
        // widths are minima, and these are integers rather than calendar formats.
        func decimal(_ value: UInt16, width: Int, padding: Character) -> String {
            let text = String(value)
            return String(repeating: String(padding), count: max(0, width-text.count))+text
        }
        var name = decimal(localTime.year, width: 4, padding: " ")
            + decimal(localTime.month, width: 2, padding: "0") + decimal(localTime.day, width: 2, padding: "0")
            + "_" + decimal(localTime.hour, width: 2, padding: "0")
            + decimal(localTime.minute, width: 2, padding: "0") + decimal(localTime.second, width: 2, padding: "0")
        if mode == 1 {
            let group = try read(0x450b94)/10 // signed division toward zero
            name += group < 5 ? "_Stage_\(group+1)" : "_Survival"
        }
        if mode == 0 { name += "_VS" }
        name += ".lfr"
        for (offset, byte) in (Array(name.utf8)+[0]).enumerated() {
            try state.write(byte, at: 0x44fd98-OriginalMatchPreparation.globalBase+offset)
        }
        try write(0x450b6c, 0)
        if try read(0x450be4) != 0 { try write(0x450b70, 1) }
        if try read(0x450b98) != 0 {
            let resource = try state.integer(at: 0x455608-OriginalMatchPreparation.globalBase, as: UInt32.self)
            guard resource != 0 else { throw error("Missing display surface") }
            try observe(.fillRectangle(resource: resource, x: 0, y: 0, width: 794, height: 550, color: 0))
            try write(0x450b98, 0)
        } else {
            try confirmationSound(in: state, observe: observe)
        }
        globals = state
        return name
    }

    /// Shared original 401a30 path for the loop=0 requests made by this menu.
    static func confirmationSound(in state: OriginalStateRecord,
                                  observe: (OriginalMatchPreludeEvent) throws -> Void) throws {
        try observe(.soundRequest(loop: false))
        if try state.integer(at: 0x44eecc-OriginalMatchPreparation.globalBase, as: UInt32.self) == 0 { return }
        let resource = try state.integer(at: 0x455610-OriginalMatchPreparation.globalBase, as: UInt32.self)
        if resource == 0 { return }
        // All three methods execute even when an earlier HRESULT fails.
        try observe(.soundMethod(resource: resource, vtableOffset: 0x48, arguments: []))
        try observe(.soundMethod(resource: resource, vtableOffset: 0x34, arguments: [0]))
        try observe(.soundMethod(resource: resource, vtableOffset: 0x30, arguments: [0, 0, 0]))
    }

    private static func error(_ text: String) -> OriginalLoaderError { .outsideVerifiedDomain("Match prelude: \(text)") }
}
