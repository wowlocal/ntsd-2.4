/// Whole41b130/ret8, including global label storage and actual four-pass font
/// mutation. Unknown modes retain the existing label before suffix selection.
public enum OriginalModeLabel {
    public static func draw(mode: Int32, alternateLine: UInt32, globals: inout OriginalStateRecord,
        resourceBitmap: (UInt32) throws -> (OriginalStateRecord, UInt32),
        performBlit: (OriginalBitmapBlit) throws -> Int32,
        observe: (OriginalFrontScreenEvent) throws -> Void = { _ in }) throws {
        var staged = globals
        let base = 0x450c38-0x44d000
        func length() throws -> Int {
            var count = 0
            while try staged.integer(at: base+count, as: UInt8.self) != 0 { count += 1 }
            return count
        }
        func copy(_ literal: String, _ stores: [(Int, Int)], destination: Int = 0) throws {
            let bytes = Array(literal.utf8)+[0]
            for (offset, size) in stores {
                let value = (0..<size).reduce(UInt32(0)) { $0 | UInt32(bytes[offset+$1]) << ($1*8) }
                switch size {
                case 1: try staged.write(UInt8(truncatingIfNeeded: value), at: base+destination+offset)
                case 2: try staged.write(UInt16(truncatingIfNeeded: value), at: base+destination+offset)
                case 4: try staged.write(value, at: base+destination+offset)
                default: preconditionFailure("Mode label literal store width")
                }
                try observe(.init("labelWrite", [UInt32(0x450c38+destination+offset), UInt32(size), value]))
            }
        }
        switch mode {
        case 0: try copy("VS mode ", [(0,4),(4,4),(8,1)])
        case 1:
            try copy("Stage mode ", [(0,4),(4,4),(8,4)])
            if try staged.integer(at: 0x450b94-0x44d000, as: Int32.self)/10 == 5 {
                try copy("Survival Stage ", [(0,4),(12,4),(8,4),(4,4)])
            }
        case 2: try copy("1 on 1 ", [(0,4),(4,4)])
        case 3: try copy("2 on 2 ", [(0,4),(4,4)])
        case 4: try copy("Battle mode ", [(0,4),(12,1),(8,4),(4,4)])
        default: break
        }
        switch try staged.integer(at: 0x450c30-0x44d000, as: Int32.self) {
        case 0: try copy("(Difficult)", [(0,4),(4,4),(8,4)], destination: length())
        case 1: try copy("(Normal)", [(0,4),(4,4),(8,1)], destination: length())
        case 2: try copy("(Easy)", [(0,4),(4,2),(6,1)], destination: length())
        case -1: try copy("(CRAZY!)", [(0,4),(4,4),(8,1)], destination: length())
        default: break
        }
        let x = 790 &- (Int32(try length()) &* 8), y: Int32 = alternateLine == 0 ? 531 : 510
        // The font's at-most256-byte consumption cannot touch its earlier
        // resource bindings or the later455608 destination. Both are read
        // after the caller has finished any suffix writes above.
        let fontGlobals = staged
        try OriginalBitmapFont.draw(.fourPass, text: &staged, offset: base, x: x, y: y,
            columns: 64, lines: 4, style: 0, cursor: 0, globals: fontGlobals,
            resourceBitmap: resourceBitmap, performBlit: performBlit, observe: observe)
        globals = staged
    }
}
