/// Whole 437220, the Stage ENDING screen: menu 300 after the last stage group
/// (caller 429e7a..429e91, tail 42e0d2; STAGE_ENDING.md).
///
/// 451b28 is the shown page of the ENDING sheet (global 451190), 451b24 and
/// 451b20 count the 13-band opening and closing wipes, and 451b2c is a blink
/// counter modulo 10 for frame 5 at the page's lower-right corner. A seat whose
/// key byte +0xd1 is set while +0xca is clear starts the closing wipe. After
/// page 4 the menu returns to 10 through 431c70's input reset.
public enum OriginalStageEnding {
    public enum Event: Equatable, Sendable {
        /// 43f010 on the ENDING bitmap with color key 0 and no mirroring.
        case draw(x: Int32, y: Int32, frame: Int32, target: UInt32)
        /// 415160 on the back buffer (455608).
        case fill(x: Int32, y: Int32, width: Int32, height: Int32, color: UInt32)
        /// 431c70 (OriginalMatchPreparation's input reset), before 457580 = 0.
        case resetInput
    }

    /// The ENDING wrapper's frame arrays as 424b45..424c98 write them at startup
    /// from static PE constants (OriginalFrontMenuRectangles). No other writer of
    /// these fields is known.
    public static func endingSheet() throws -> OriginalStateRecord {
        guard let sheet = OriginalFrontMenuRectangles.sheets.first(where: { $0.slot == 0x451190 }) else {
            throw OriginalStateError.invalidStorage("Stage ending: ENDING sheet")
        }
        var record = try OriginalStateRecord(bytes: [UInt8](repeating: 0, count: 0x1f50), defined: [Bool](repeating: false, count: 0x1f50))
        for (frame, rectangle) in sheet.frames.enumerated() {
            for (field, offset) in [0x10, 0x7e0, 0xfb0, 0x1780].enumerated() { try record.write(rectangle[field], at: offset+frame*4) }
        }
        try record.write(Int32(sheet.frames.count), at: 0x0c)
        return record
    }

    /// `ending` is the ENDING bitmap wrapper; its frame widths are at +0xfb0 and
    /// heights at +0x1780. The menu word is 44d020, the caller's argument.
    public static func advance(state: inout OriginalMatchPreparation, target: UInt32, ending: OriginalStateRecord,
                               observe: (Event) throws -> Void = { _ in }) throws {
        var next = state
        let base = OriginalMatchPreparation.globalBase
        func g(_ address: Int) throws -> Int32 { try next.globals.integer(at: address-base, as: Int32.self) }
        func set(_ address: Int, _ value: Int32) throws { try next.globals.write(value, at: address-base) }
        func key(_ seat: Int) throws -> Bool {
            let index = Int(try next.world.integer(at: 0x194+seat*4, as: UInt32.self))
            guard next.actors.indices.contains(index) else { throw OriginalStateError.invalidStorage("Stage ending: seat Actor binding") }
            let actor = next.actors[index]
            return try actor.integer(at: 0xd1, as: UInt8.self) != 0 && actor.integer(at: 0xca, as: UInt8.self) == 0
        }
        // 437223..437242: idiv keeps the dividend's sign.
        try set(0x451b2c, (g(0x451b2c) &+ 1) % 10)
        var page = try g(0x451b28)
        if try [1, 2].contains(g(0x450c30)) {
            if page == 1 { page = 2; try set(0x451b28, page) }
        } else if page == 0 { page = 1; try set(0x451b28, page) }
        guard (0..<500).contains(page) else { throw OriginalStateError.invalidStorage("Stage ending: page outside the ENDING frame arrays") }
        let width = try ending.integer(at: 0xfb0+Int(page)*4, as: Int32.self)
        let height = try ending.integer(at: 0x1780+Int(page)*4, as: Int32.self)
        // cdq/sub/sar: halves rounded toward zero.
        let x = (800 &- width)/2, y = (520 &- height)/2
        let right = width &+ x, bottom = height &+ y
        try observe(.draw(x: x, y: y, frame: page, target: target))
        var closing: Int32
        if try g(0x451b24) < 13 {
            try set(0x451b24, g(0x451b24) &+ 1)
            var band = y
            for _ in 0..<13 { try observe(.fill(x: 0, y: band, width: 794, height: 13 &- g(0x451b24), color: 0)); band &+= 13 }
            closing = try g(0x451b20)
        } else {
            closing = try g(0x451b20)
            if closing == 0 {
                for seat in 0..<8 where try key(seat) { closing = 1; try set(0x451b20, closing); break }
            } else if closing > 0 {
                var band = y
                for _ in 0..<13 { try observe(.fill(x: 0, y: band, width: 794, height: g(0x451b20), color: 0)); band &+= 13 }
                closing = try g(0x451b20) &+ 1
                try set(0x451b20, closing)
                if closing >= 13 {
                    try set(0x451b28, g(0x451b28) &+ 1); try set(0x451b24, 0)
                    closing = 0; try set(0x451b20, closing)
                }
            }
        }
        if try g(0x451b2c) < 5 && g(0x451b24) == 13 && closing == 0 {
            try observe(.draw(x: right, y: bottom, frame: 5, target: target))
        }
        if try g(0x451b28) == 5 {
            try set(0x44d020, 10); try set(0x451b28, 0); try set(0x451b24, 0)
            try observe(.resetInput); try next.resetOriginalInput()
            try set(0x457580, 0)
        }
        state = next
    }
}
