/// Whole422218..422994, or the recorder's alternate422944 indicator entry.
/// Caller formatting storage remains optional until its first actual write.
/// RootSP64 and SP68 are semantic caller inputs, never expected stack bytes.
public enum OriginalResultLayout {
    public static let localOffset = 0x44c, localSize = 0x174

    public static func apply(state: inout OriginalMatchPreparation,
        context: OriginalInputControlContext, continuation: OriginalResultRecording.Continuation,
        stageDefeated: UInt32?, indicatorTarget: UInt32?, local: inout OriginalStateRecord?,
        dcResult: Int32, dc: UInt32, surface: (Int) throws -> UInt32,
        resourceBitmap: (UInt32) throws -> (OriginalStateRecord, UInt32),
        performBlit: (OriginalBitmapBlit) throws -> Int32,
        observe: (OriginalFrontScreenEvent) throws -> Void = { _ in }) throws {
        let catalog = state.catalog, bitmaps = state.bitmaps, released = state.releasedBitmaps
        try draw(world: state.world, actors: state.actors, globals: &state.globals,
            continuation: continuation, stageDefeated: stageDefeated, indicatorTarget: indicatorTarget,
            local: &local, dcResult: dcResult, dc: dc, header: { n in
                guard catalog.objects.indices.contains(n) else { throw error("Object binding") }
                return catalog.objects[n].header
            }, catalogBitmap: { token in
                guard token != 0, Int(token)-1 < bitmaps.count, !released.contains(Int(token)-1) else { throw error("Bitmap binding") }
                return try (bitmaps[Int(token)-1].storage, surface(Int(token)-1))
            }, playbackTicks: {
                let pointer = try context.memory.replayPointers.integer(at: 4, as: UInt32.self)
                guard pointer != 0, let allocation = context.memory.allocations[pointer], allocation.live else { throw error("Playback ownership") }
                return try allocation.storage.integer(at: 0x144, as: Int32.self)
            }, resourceBitmap: resourceBitmap, performBlit: performBlit, observe: observe)
    }

    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Result layout: "+text) }

    static func draw(world: OriginalStateRecord, actors: [OriginalStateRecord], globals: inout OriginalStateRecord,
        continuation: OriginalResultRecording.Continuation, stageDefeated: UInt32?, indicatorTarget: UInt32?,
        local: inout OriginalStateRecord?, dcResult: Int32, dc: UInt32,
        header: (Int) throws -> OriginalStateRecord,
        catalogBitmap: (UInt32) throws -> (OriginalStateRecord, UInt32), playbackTicks: () throws -> Int32,
        resourceBitmap: (UInt32) throws -> (OriginalStateRecord, UInt32),
        performBlit: (OriginalBitmapBlit) throws -> Int32,
        observe: (OriginalFrontScreenEvent) throws -> Void = { _ in }) throws {
        guard local == nil || local?.bytes.count == localSize else { throw error("Caller string extent") }
        var next = globals, scratch = local
        func g(_ address: Int) throws -> Int32 { try next.integer(at: address-0x44d000, as: Int32.self) }
        func token(_ address: Int) throws -> UInt32 { UInt32(bitPattern: try g(address)) }
        func active(_ slot: Int) throws -> Bool { try world.integer(at: 4+slot, as: UInt8.self) != 0 }
        func actor(_ slot: Int) throws -> OriginalStateRecord {
            let n = Int(try world.integer(at: 0x194+4*slot, as: UInt32.self))
            guard actors.indices.contains(n) else { throw error("Actor binding") }; return actors[n]
        }
        func i(_ slot: Int, _ offset: Int) throws -> Int32 { try actor(slot).integer(at: offset, as: Int32.self) }
        func localWrite(_ offset: UInt32, _ value: UInt32, size: UInt32 = 4) throws {
            // Root50 is an address adjustment. Its event value is relative to
            // World+4 (10), the only normalized low-local pointer calculation.
            try observe(.init("localWrite", [offset, size, value]))
        }
        func picture(_ bitmap: UInt32, catalog: Bool = false, x: Int32, y: Int32,
                     frame: Int32 = -1, key: UInt32 = 0, destination: UInt32? = nil) throws {
            let target = try destination ?? token(0x455608)
            try observe(.init("draw", [bitmap, UInt32(bitPattern: x), UInt32(bitPattern: y), UInt32(bitPattern: frame), key, 0, target]))
            guard bitmap != 0 else { throw error("Null bitmap") }
            let (record, surface) = try catalog ? catalogBitmap(bitmap) : resourceBitmap(bitmap)
            let input = try OriginalBitmapDrawInput(x: x, y: y, frame: frame, colorKey: key, mirrored: 0,
                sourceSurface: surface, targetSurface: target, viewportWidth: g(0x44d78c), viewportHeight: g(0x44d790))
            try OriginalBitmapDrawing.draw(input, bitmap: record, observeRead: { value in
                var event = OriginalFrontScreenEvent("read"); event.read = value; try observe(event)
            }, observeClip: { value in
                var event = OriginalFrontScreenEvent("clip"); event.clip = value; try observe(event)
            }, perform: { value in
                var event = OriginalFrontScreenEvent("blit"); event.blit = value; try observe(event)
                return try performBlit(value)
            })
        }
        func format(_ pattern: String, _ output: String) throws -> [UInt8] {
            let bytes = Array(output.utf8)
            guard var record = scratch else { throw error("Caller string backing unavailable") }
            guard bytes.count+1 <= localSize else { throw error("String overwrites caller security cookie") }
            for (offset, byte) in (bytes+[0]).enumerated() {
                try record.write(byte, at: offset)
                try observe(.init("formatWrite", [UInt32(offset), 1, UInt32(byte)]))
            }
            scratch = record
            try observe(.init("format", [UInt32(bytes.count)], [Array(pattern.utf8), bytes]))
            return bytes
        }
        func text(_ bytes: [UInt8], x: Int32, y: Int32, color: UInt32) throws {
            let target = try token(0x455608)
            try observe(.init("text", [target, 0, color, UInt32(bitPattern: x), UInt32(bitPattern: y)], [bytes]))
            try OriginalSurfaceText.draw(bytes, target: target, background: 0, color: color,
                x: x, y: y, dcResult: dcResult, dc: dc) {
                try observe(.init($0.kind.rawValue, $0.arguments, $0.strings))
            }
        }
        if continuation == .resultLayout {
            var count: Int32 = 0
            for seat in 0..<8 { if try active(seat) || active(seat+10) { count += 1 } }
            let span = count*45, height = try span+93+(g(0x451160) == 4 ? 45 : 0), top = (530-height)/2
            try localWrite(0x34, UInt32(bitPattern: span)); try localWrite(0x4c, UInt32(bitPattern: top))
            try picture(token(0x44fcb4), x: 150, y: top)
            var row = top+16
            try localWrite(0x3c, 0x006d6f43); try localWrite(0x54, 0)
            try localWrite(0x60, UInt32(bitPattern: row)); try localWrite(0x50, 10)
            for seat in 0..<8 {
                if try active(seat) || active(seat+10) {
                    row += 45; try localWrite(0x60, UInt32(bitPattern: row))
                    try picture(token(0x44fd8c), x: 150, y: row)
                    let slot = try active(seat) ? seat : seat+10
                    try localWrite(0x58, UInt32(slot))
                    let object = Int(try actor(slot).integer(at: 0x368, as: UInt32.self))
                    try picture(header(object).integer(at: 0x728, as: UInt32.self), catalog: true, x: 165, y: row)
                    var label: [UInt8] = [67, 111, 109, 0]
                    for (offset, byte) in label.enumerated() { try localWrite(0x3c+UInt32(offset), UInt32(byte), size: 1) }
                    if slot < 10 {
                        label = [80, UInt8(slot+49), 32, 0]
                        for offset in 0..<3 { try localWrite(0x3c+UInt32(offset), UInt32(label[offset]), size: 1) }
                    }
                    let y = row+15
                    var x: Int32 = 206
                    try localWrite(0x38, UInt32(x)); try localWrite(0x40, 0)
                    for glyph in 0..<3 {
                        let team = try i(slot, 0x364)
                        let address = [Int32(1): 0x44f888, 2: 0x44fcbc, 3: 0x44fb68, 4: 0x44faf8][team] ?? 0x44faf4
                        try picture(token(address), x: x, y: y, frame: Int32(Int8(bitPattern: label[glyph])), key: 1)
                        x += 9; try localWrite(0x38, UInt32(x)); try localWrite(0x40, UInt32(glyph+1))
                    }
                    for (offset, x, color) in [(0x358,271,0xaaaaff),(0x348,326,0xaaaaff),
                                              (0x34c,390,0xaaf0f0),(0x350,454,0xaaf0f0),(0x35c,527,0xaaf5aa)] {
                        try text(format("%d", String(i(slot, offset))), x: Int32(x), y: y, color: UInt32(color))
                    }
                    let mark: Int?
                    if try g(0x451160) == 1 {
                        guard let stageDefeated else { throw error("Retained stage result unavailable") }
                        mark = try stageDefeated == 1 ? 0x44fb64 : (i(slot, 0x2fc) > 0 ? 0x44fd90 : 0x44fd94)
                    } else {
                        let winner = try g(0x450bf8)
                        mark = try winner < 0 ? nil : (winner != i(slot, 0x364) ? 0x44fb64 :
                            (i(slot, 0x2fc) > 0 ? 0x44fd90 : 0x44fd94))
                    }
                    if let mark { try picture(token(mark), x: 571, y: y) }
                }
                try localWrite(0x54, UInt32(seat+1))
            }
            if try g(0x451160) == 4 {
                try picture(token(0x44f87c), x: 150, y: top+span+61)
                try picture(token(0x44f88c), x: 150, y: top+span+106)
                for (address, x, color) in [(0x451b64,243,0xffafaf),(0x451b68,483,0xafafff),
                                           (0x451b6c,323,0xffafaf),(0x451b70,563,0xafafff)] {
                    try text(format("%d", String(g(address))), x: Int32(x), y: top+span+84, color: UInt32(color))
                }
            } else { try picture(token(0x44f88c), x: 150, y: top+span+61) }
            let seconds = try (g(0x450bbc) &+ 15)/30
            let values: [Int32], pattern: String
            if seconds < 3600 { values = [seconds/60, seconds%60]; pattern = "%02d : %02d" }
            else { values = [seconds/3600, (seconds%3600)/60, seconds%60]; pattern = "%02d : %02d : %02d" }
            let output = values.map { value in let text = String(value); return text.count < 2 ? "0"+text : text }.joined(separator: " : ")
            let bytes = try format(pattern, output)
            try text(bytes, x: 580, y: top+span+(g(0x451160) == 4 ? 112 : 67), color: 0xffffff)
        }
        if try g(0x450b84) != 0 {
            guard let indicatorTarget else { throw error("Retained indicator target unavailable") }
            try picture(token(0x45116c), x: 67, y: 534, frame: 24, destination: indicatorTarget)
            if try g(0x44d030) != 0 {
                let current = try g(0x450bbc), recorded = try playbackTicks(), mode = try g(0x451160)
                try OriginalPlaybackInformation.draw(mode: mode, recordedTicks: recorded, currentTicks: current,
                    globals: &next, resourceBitmap: resourceBitmap, performBlit: performBlit, observe: observe)
            }
        }
        globals = next; local = scratch
    }
}
