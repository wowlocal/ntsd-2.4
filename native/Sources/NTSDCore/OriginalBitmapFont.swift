/// Whole423940 and its four-pass423a70 caller. The original truncates the
/// supplied byte string in place. Later passes see the preceding pass's NUL.
/// Resource records and viewport globals are declared independent backing;
/// arbitrary aliases between the text storage and those resources are outside
/// this interface. Buffer external effects until the enclosing tick commits.
public enum OriginalBitmapFont {
    public enum Entry: UInt32, Codable, Sendable { case single = 0x423940, fourPass = 0x423a70 }

    public static func draw(_ entry: Entry, text: inout OriginalStateRecord, offset: Int = 0,
        x: Int32, y: Int32, columns: Int32, lines: Int32, style: Int32, cursor: UInt32,
        globals: OriginalStateRecord,
        resourceBitmap: (UInt32) throws -> (OriginalStateRecord, UInt32),
        performBlit: (OriginalBitmapBlit) throws -> Int32,
        observe: (OriginalFrontScreenEvent) throws -> Void = { _ in }) throws {
        var storage = text
        func word(_ address: Int) throws -> UInt32 { try globals.integer(at: address-0x44d000, as: UInt32.self) }
        func string() throws -> [UInt8] {
            var bytes: [UInt8] = [], index = offset
            while true {
                let value = try storage.integer(at: index, as: UInt8.self)
                if value == 0 { return bytes }
                bytes.append(value); index += 1
            }
        }
        func picture(_ style: Int32, _ character: Int32, _ px: Int32, _ py: Int32) throws {
            let address: Int
            switch style {
            case 0: address = 0x44faf4
            case 1: address = 0x44f888
            case 2: address = 0x44fcbc
            default: return
            }
            let bitmap = try word(address), target = try word(0x455608)
            try observe(.init("draw", [bitmap, UInt32(bitPattern: px), UInt32(bitPattern: py),
                UInt32(bitPattern: character), 1, 0, target]))
            guard bitmap != 0 else { throw OriginalStateError.invalidStorage("Bitmap font: Null resource") }
            let (record, surface) = try resourceBitmap(bitmap)
            let input = try OriginalBitmapDrawInput(x: px, y: py, frame: character, colorKey: 1, mirrored: 0,
                sourceSurface: surface, targetSurface: target,
                viewportWidth: Int32(bitPattern: word(0x44d78c)), viewportHeight: Int32(bitPattern: word(0x44d790)))
            try OriginalBitmapDrawing.draw(input, bitmap: record, observeRead: { value in
                var event = OriginalFrontScreenEvent("read"); event.read = value; try observe(event)
            }, observeClip: { value in
                var event = OriginalFrontScreenEvent("clip"); event.clip = value; try observe(event)
            }, perform: { value in
                var event = OriginalFrontScreenEvent("blit"); event.blit = value; try observe(event)
                return try performBlit(value)
            })
        }
        func pass(_ initialX: Int32, _ initialY: Int32) throws {
            let bytes = try string()
            guard bytes.count <= Int(Int32.max) else { throw OriginalStateError.invalidStorage("Bitmap font: Signed string extent") }
            try observe(.init("fontPass", [UInt32(bitPattern: initialX), UInt32(bitPattern: initialY),
                UInt32(bitPattern: columns), UInt32(bitPattern: lines), UInt32(bitPattern: style), cursor], [bytes]))
            var px = initialX, py = initialY, row: Int32 = 0, column: Int32 = 0, consumed = 0
            // The source repeats strlen. No writer touches this independent
            // text storage until the terminating store below, so its length
            // remains stable within one pass (but not between four passes).
            while consumed < bytes.count && row < lines {
                let character = bytes[consumed]
                if character == 10 {
                    if row >= lines &- 1 { break }
                    py = py &+ 16; column = 0; row = row &+ 1; px = initialX
                } else {
                    column = column &+ 1
                    try picture(style, Int32(Int8(bitPattern: character)), px, py)
                    px = px &+ 8
                    if column >= columns {
                        if row >= lines &- 1 { consumed += 1; break }
                        column = 0; row = row &+ 1; py = py &+ 16; px = initialX
                    }
                }
                consumed += 1
            }
            try storage.write(UInt8(0), at: offset+consumed)
            try observe(.init("stringWrite", [UInt32(consumed), 0]))
            if cursor != 0 { try picture(0, 0x5f, px, py) }
        }
        if entry == .fourPass {
            try pass(x &- 1, y &+ 1)
            try pass(x &- 1, y)
            try pass(x, y &+ 1)
        }
        try pass(x, y)
        text = storage
    }
}
