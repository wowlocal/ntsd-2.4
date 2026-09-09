/// Whole41b390/ret12. Author/info strings are live mutable game globals;
/// sentinel comparison includes all ten bytes, including the terminating NUL.
public enum OriginalPlaybackInformation {
    public static func draw(mode: Int32, recordedTicks: Int32, currentTicks: Int32,
        globals: inout OriginalStateRecord,
        resourceBitmap: (UInt32) throws -> (OriginalStateRecord, UInt32),
        performBlit: (OriginalBitmapBlit) throws -> Int32,
        observe: (OriginalFrontScreenEvent) throws -> Void = { _ in }) throws {
        var staged = globals
        func byte(_ address: Int) throws -> UInt8 { try staged.integer(at: address-0x44d000, as: UInt8.self) }
        func string(_ address: Int) throws -> [UInt8] {
            var bytes: [UInt8] = []
            while true {
                let value = try byte(address+bytes.count)
                if value == 0 { return bytes }; bytes.append(value)
            }
        }
        func store(_ address: Int, _ bytes: [UInt8]) throws {
            guard [1,4].contains(bytes.count) else { preconditionFailure("Playback information store width") }
            let value = bytes.enumerated().reduce(UInt32(0)) { $0 | UInt32($1.element) << ($1.offset*8) }
            if bytes.count == 4 { try staged.write(value, at: address-0x44d000) }
            else { try staged.write(bytes[0], at: address-0x44d000) }
            try observe(.init("infoWrite", [UInt32(address), UInt32(bytes.count), value]))
        }
        func label(_ literal: String) throws {
            let bytes = Array(literal.utf8)+[0]
            try store(0x450f60, Array(bytes[0..<4])); try store(0x450f64, Array(bytes[4..<8]))
        }
        func font(_ address: Int, _ x: Int32, _ y: Int32, _ lines: Int32) throws {
            // At most256 consumed bytes keep all these strings separate from
            // the font binding words and the455608 destination during a pass.
            try observe(.init("infoText", [UInt32(address)]))
            let fontGlobals = staged
            try OriginalBitmapFont.draw(.fourPass, text: &staged, offset: address-0x44d000,
                x: x, y: y, columns: 64, lines: lines, style: 0, cursor: 0,
                globals: fontGlobals, resourceBitmap: resourceBitmap, performBlit: performBlit, observe: observe)
        }
        func equalsSentinel(_ address: Int, _ literal: String) throws -> Bool {
            // REP CMPSB stops on its first differing byte. Do not require
            // unavailable bytes after a mismatch merely to compare a slice.
            for (offset, expected) in (Array(literal.utf8)+[0]).enumerated() {
                if try byte(address+offset) != expected { return false }
            }
            return true
        }
        var y: Int32 = mode == 4 ? 155 : 133
        if try !equalsSentinel(0x44fd18, "<No name>") {
            try label("Author:"); try font(0x450f60, 10, y, 1)
            try font(0x44fd18, 75, y, 1); y = y &+ 22
        }
        if try !equalsSentinel(0x44f900, "<No info>") {
            try label("  Info:"); try font(0x450f60, 10, y, 4)
            try font(0x44f900, 75, y, 4)
        }
        func twoDigits(_ value: Int32) -> String {
            let text = String(value)
            return text.count >= 2 ? text : "0"+text
        }
        func format(_ ticks: Int32, _ destination: Int, _ prefix: String) throws {
            let seconds = (ticks &+ 15)/30
            let values: [Int32], pattern: String
            if seconds < 3600 {
                values = [seconds/60, seconds%60]; pattern = "%02d:%02d"
            } else {
                let remainder = seconds%3600
                values = [seconds/3600, remainder/60, remainder%60]; pattern = "%02d:%02d:%02d"
            }
            let result = Array((prefix+values.map(twoDigits).joined(separator: ":")).utf8)
            for (offset, value) in (result+[0]).enumerated() { try store(destination+offset, [value]) }
            try observe(.init("format", [UInt32(result.count)], [Array((prefix+pattern).utf8), result]))
        }
        try format(currentTicks, 0x450e98, "")
        try format(recordedTicks, 0x450e30, " / ")
        let total = try string(0x450e30)+[0], destination = 0x450e98+(try string(0x450e98).count)
        let whole = total.count/4*4
        for offset in stride(from: 0, to: whole, by: 4) { try store(destination+offset, Array(total[offset..<offset+4])) }
        for offset in whole..<total.count { try store(destination+offset, [total[offset]]) }
        try font(0x450e98, 5, 510, 4)
        globals = staged
    }
}
