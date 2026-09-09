/// Whole421a2d..421cdc after HUD. EDI is0 on entry. Strings retain their
/// actual caller backing; external output must wait for the whole tick commit.
/// No global/Actor writes occur. The92 untouched fill-effect bytes require
/// the helper's actual entry backing, separately from the caller string region.
public enum OriginalPostHUDNotices {
    public static let localOffset = 0x46c, localSize = 0x154
    static let formats = ["%2.3f %2.4f %d", "%d %d %d %d %d %d %d %d", "%c %d",
        "Function Keys Used:    F6: %d time(s)    F7: %d time(s)    F8: %d time(s)    F9: %d time(s)", "Function Keys Locked"]

    public static func apply(state: OriginalMatchPreparation, local: inout OriginalStateRecord,
        dcResult: Int32, dc: UInt32, fillBacking: () throws -> [UInt8],
        resourceBitmap: (UInt32) throws -> (OriginalStateRecord, UInt32),
        performFill: (OriginalSurfaceFillRequest) throws -> Int32,
        performBlit: (OriginalBitmapBlit) throws -> Int32,
        observe: (OriginalFrontScreenEvent) throws -> Void = { _ in }) throws {
        try draw(world: state.world, actors: state.actors, globals: state.globals, local: &local,
            dcResult: dcResult, dc: dc, fillBacking: fillBacking, resourceBitmap: resourceBitmap,
            performFill: performFill, performBlit: performBlit, observe: observe)
    }

    /// A retained caller may not yet own this stack backing. Keep nil while
    /// the original does not access it; require provenance at the first write.
    /// Never import an expected snapshot or manufacture a backing fill pattern.
    public static func apply(state: OriginalMatchPreparation, local: inout OriginalStateRecord?,
        dcResult: Int32, dc: UInt32, fillBacking: () throws -> [UInt8],
        resourceBitmap: (UInt32) throws -> (OriginalStateRecord, UInt32),
        performFill: (OriginalSurfaceFillRequest) throws -> Int32,
        performBlit: (OriginalBitmapBlit) throws -> Int32,
        observe: (OriginalFrontScreenEvent) throws -> Void = { _ in }) throws {
        try advance(world: state.world, actors: state.actors, globals: state.globals, local: &local,
            dcResult: dcResult, dc: dc, fillBacking: fillBacking, resourceBitmap: resourceBitmap,
            performFill: performFill, performBlit: performBlit, observe: observe)
    }

    static func draw(world: OriginalStateRecord, actors: [OriginalStateRecord], globals: OriginalStateRecord,
        local: inout OriginalStateRecord, dcResult: Int32, dc: UInt32, fillBacking: () throws -> [UInt8],
        resourceBitmap: (UInt32) throws -> (OriginalStateRecord, UInt32),
        performFill: (OriginalSurfaceFillRequest) throws -> Int32,
        performBlit: (OriginalBitmapBlit) throws -> Int32,
        observe: (OriginalFrontScreenEvent) throws -> Void = { _ in },
        observeFormatStorage: (OriginalStateRecord) throws -> Void = { _ in }) throws {
        var candidate: OriginalStateRecord? = local
        try advance(world: world, actors: actors, globals: globals, local: &candidate,
            dcResult: dcResult, dc: dc, fillBacking: fillBacking, resourceBitmap: resourceBitmap,
            performFill: performFill, performBlit: performBlit, observe: observe, observeFormatStorage: observeFormatStorage)
        guard let candidate else { throw error("Lost caller storage") }; local = candidate
    }

    private static func advance(world: OriginalStateRecord, actors: [OriginalStateRecord], globals: OriginalStateRecord,
        local: inout OriginalStateRecord?, dcResult: Int32, dc: UInt32, fillBacking: () throws -> [UInt8],
        resourceBitmap: (UInt32) throws -> (OriginalStateRecord, UInt32),
        performFill: (OriginalSurfaceFillRequest) throws -> Int32,
        performBlit: (OriginalBitmapBlit) throws -> Int32,
        observe: (OriginalFrontScreenEvent) throws -> Void = { _ in },
        observeFormatStorage: (OriginalStateRecord) throws -> Void = { _ in }) throws {
        guard (local == nil || local?.bytes.count == localSize), globals.bytes.count == OriginalMatchPreparation.globalSize else {
            throw error("Caller storage extent")
        }
        var scratch = local
        func g(_ address: Int) throws -> Int32 { try globals.integer(at: address-0x44d000, as: Int32.self) }
        func token(_ address: Int) throws -> UInt32 { UInt32(bitPattern: try g(address)) }
        func byte(_ address: Int) throws -> UInt8 { try globals.integer(at: address-0x44d000, as: UInt8.self) }
        func integer(_ value: Int32) -> [UInt8] { Array(String(value).utf8) }
        func store(_ bytes: [UInt8], at offset: Int) throws {
            // RootSP+5c0 is the cookie: this is the known local storage extent,
            // NOT a recovered C-array capacity. Oversized original sprintf
            // really corrupts that cookie; do not silently truncate its output.
            guard offset >= 0, offset+bytes.count <= localSize else { throw error("String overwrites caller security cookie") }
            guard var record = scratch else { throw error("Caller string backing unavailable") }
            for (i, b) in bytes.enumerated() { try record.write(b, at: offset+i) }
            scratch = record
        }
        func format(_ index: Int, _ bytes: [UInt8]) throws -> [UInt8] {
            try store(bytes+[0], at: 0x20)
            try observe(.init("format", [UInt32(bytes.count)], [Array(formats[index].utf8), bytes]))
            if let scratch { try observeFormatStorage(scratch) }
            return Array(bytes.prefix { $0 != 0 })
        }
        func text(_ bytes: [UInt8], x: Int32 = 0, y: Int32, color: UInt32 = 0xffffff) throws {
            let target = try token(0x455608)
            try observe(.init("text", [target, 0, color, UInt32(bitPattern: x), UInt32(bitPattern: y)], [bytes]))
            try OriginalSurfaceText.draw(bytes, target: target, background: 0, color: color, x: x, y: y, dcResult: dcResult, dc: dc) {
                try observe(.init($0.kind.rawValue, $0.arguments, $0.strings))
            }
        }
        if try g(0x450bec) != 0 {
            // The original follows World slot0 even when its activity is zero.
            let slot = Int(try world.integer(at: 0x194, as: UInt32.self))
            guard actors.indices.contains(slot) else { throw error("Slot0 Actor binding") }
            let actor = actors[slot]
            let height = try actor.integer(at: 0x14, as: Int32.self)
            let second = quietLoad(try actor.integer(at: 0x60, as: UInt64.self))
            let first = quietLoad(try actor.integer(at: 0x48, as: UInt64.self))
            let coordinates = try OriginalDiagnosticNumber.fixed(bits: first, fractionDigits: 3)+[32]
                + OriginalDiagnosticNumber.fixed(bits: second, fractionDigits: 4)+[32]
                + integer(height)
            try text(format(0, coordinates), y: 0)
            let keys = try (0..<8).map { try integer(Int32(Int8(bitPattern: byte(0x44d040+$0)))) }
            try text(format(1, Array(keys.joined(separator: [32]))), y: 30)
            try text(format(2, [byte(0x4553e8), 32]+integer(g(0x450bfc))), y: 60)
        }
        if try g(0x450c2c) == 1 {
            try text(Array("Press F4 or 'Attack' to exit".utf8), x: 610, y: 110, color: 0x7d7d7d)
            let literal = OriginalFrontScreenBody.literals[2].bytes
            guard literal.count == 29 else { throw error("URL literal extent") }
            try store(literal, at: 0)
            // Both source strlen loops are live; preserve termination after
            // each byte change, not an assumed Unicode character count.
            var index = 0
            func byteAt(_ offset: Int) throws -> UInt8 {
                guard let record = scratch else { throw error("Caller string backing unavailable") }
                return try record.integer(at: offset, as: UInt8.self)
            }
            func length() throws -> Int {
                for i in 0..<localSize { if try byteAt(i) == 0 { return i } }
                throw error("URL terminator")
            }
            while try index < length() {
                let value = try byteAt(index)
                try store([value &- UInt8(index%4)], at: index); index += 1
            }
            let decoded = try (0..<length()).map { try byteAt($0) }
            try text(decoded, x: 5, y: 110, color: 0xc8c8c8)
            let bitmap = try token(0x44f8f8), target = try token(0x455608)
            try observe(.init("draw", [bitmap, 360, 288, UInt32.max, 1, 0, target]))
            guard bitmap != 0 else { throw error("Null exit bitmap") }
            let (record, surface) = try resourceBitmap(bitmap)
            let input = try OriginalBitmapDrawInput(x: 360, y: 288, frame: -1, colorKey: 1, mirrored: 0,
                sourceSurface: surface, targetSurface: target, viewportWidth: g(0x44d78c), viewportHeight: g(0x44d790))
            try OriginalBitmapDrawing.draw(input, bitmap: record, observeRead: { value in
                var event = OriginalFrontScreenEvent("read"); event.read = value; try observe(event)
            }, observeClip: { value in
                var event = OriginalFrontScreenEvent("clip"); event.clip = value; try observe(event)
            }, perform: { value in
                var event = OriginalFrontScreenEvent("blit"); event.blit = value; try observe(event)
                return try performBlit(value)
            })
            // Source ESI now equals28, EDI=rootSP+489 (copied URL end).
            // Neither is interchangeable with the entry's sprintf/zero pair.
        } else if try g(0x450c28) == 1 {
            var bytes = Array("Function Keys Used:".utf8)
            for i in 0..<4 { bytes += Array("    F\(i+6): ".utf8)+integer(try g(0x450c18+4*i))+Array(" time(s)".utf8) }
            let message = try format(3, bytes)
            if try g(0x451160) == 1 {
                let fill = try OriginalSurfaceFilling.request(target: token(0x455608), x: 0, y: 128, width: 794, height: 21, color: 0, backing: fillBacking())
                guard fill.target != 0 else { throw error("Null fill surface") }
                var event = OriginalFrontScreenEvent("fill"); event.fill = fill; try observe(event)
                _ = try performFill(fill)
                try text(message, y: 129)
            } else { try text(message, y: 109) }
        } else if try g(0x450c28) == 2 {
            try text(format(4, Array(formats[4].utf8)), y: 109)
        }
        local = scratch
    }

    // FLDQ/FSTPQ preserves finite bits, zeros and infinities, and sets the
    // binary64 quiet bit on NaN. Floating-point exception flags are separate.
    static func quietLoad(_ bits: UInt64) -> UInt64 {
        if bits & 0x7ff0000000000000 == 0x7ff0000000000000 && bits & 0x000fffffffffffff != 0 {
            return bits | 0x0008000000000000
        }
        return bits
    }
    private static func error(_ detail: String) -> OriginalStateError { .invalidStorage("Post-HUD notices: "+detail) }
}
