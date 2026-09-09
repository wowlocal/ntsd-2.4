/// Entire421a15..421a2d caller and41ae60..41b12d HUD. The original stack
/// argument is unused; the target is global455608. Device requests must be
/// buffered until the enclosing tick commits. HRESULTs do not stop this pass.
public enum OriginalWorldHUD {
    public static func apply(state: inout OriginalMatchPreparation,
        surface: (Int) throws -> UInt32,
        resourceBitmap: (UInt32) throws -> (OriginalStateRecord, UInt32),
        performBlit: (OriginalBitmapBlit) throws -> Int32,
        observe: (OriginalFrontScreenEvent) throws -> Void = { _ in }) throws {
        let catalog = state.catalog, bitmaps = state.bitmaps, released = state.releasedBitmaps
        guard try state.world.integer(at: 0x7d4, as: UInt32.self) == 0 else { throw error("Catalog binding") }
        try draw(world: state.world, actors: state.actors, globals: &state.globals,
            header: { n in
                guard catalog.objects.indices.contains(n) else { throw error("Object binding") }
                return catalog.objects[n].header
            }, catalogBitmap: { token in
                guard token != 0, Int(token)-1 < bitmaps.count, !released.contains(Int(token)-1) else { throw error("Bitmap binding") }
                return try (bitmaps[Int(token)-1].storage, surface(Int(token)-1))
            }, resourceBitmap: resourceBitmap, performBlit: performBlit, observe: observe)
    }
    private static func error(_ detail: String) -> OriginalStateError { .invalidStorage("World HUD: "+detail) }

    static func draw(world: OriginalStateRecord, actors: [OriginalStateRecord], globals: inout OriginalStateRecord,
        header: (Int) throws -> OriginalStateRecord,
        catalogBitmap: (UInt32) throws -> (OriginalStateRecord, UInt32),
        resourceBitmap: (UInt32) throws -> (OriginalStateRecord, UInt32),
        performBlit: (OriginalBitmapBlit) throws -> Int32,
        observe: (OriginalFrontScreenEvent) throws -> Void = { _ in }) throws {
        var next = globals
        // Original EDI is0 at this caller after the resource loop. Keep these
        // writes before all HUD resource resolution and drawing callbacks.
        try next.write(Int32(0), at: 0x450bc0-0x44d000)
        try next.write(Int32(0), at: 0x450bb8-0x44d000)
        func g(_ address: Int) throws -> Int32 { try next.integer(at: address-0x44d000, as: Int32.self) }
        func token(_ address: Int) throws -> UInt32 { UInt32(bitPattern: try g(address)) }
        func active(_ slot: Int) throws -> Bool { try world.integer(at: 4+slot, as: UInt8.self) != 0 }
        func actor(_ slot: Int) throws -> OriginalStateRecord {
            let n = Int(try world.integer(at: 0x194+4*slot, as: UInt32.self))
            guard actors.indices.contains(n) else { throw error("Actor binding") }; return actors[n]
        }
        func i(_ slot: Int, _ offset: Int) throws -> Int32 { try actor(slot).integer(at: offset, as: Int32.self) }
        func read(_ value: OriginalBitmapDrawRead) throws {
            var event = OriginalFrontScreenEvent("read"); event.read = value; try observe(event)
        }
        func blit(_ value: OriginalBitmapBlit) throws -> Int32 {
            var event = OriginalFrontScreenEvent("blit"); event.blit = value; try observe(event)
            return try performBlit(value)
        }
        func picture(_ bitmap: UInt32, catalog: Bool, x: Int32, y: Int32, frame: Int32, key: UInt32) throws {
            let destination = try token(0x455608)
            try observe(.init("draw", [bitmap, UInt32(bitPattern: x), UInt32(bitPattern: y), UInt32(bitPattern: frame), key, 0, destination]))
            guard bitmap != 0 else { throw error("Null bitmap") }
            let (record, surface) = try catalog ? catalogBitmap(bitmap) : resourceBitmap(bitmap)
            let input = try OriginalBitmapDrawInput(x: x, y: y, frame: frame, colorKey: key, mirrored: 0,
                sourceSurface: surface, targetSurface: destination, viewportWidth: g(0x44d78c), viewportHeight: g(0x44d790))
            try OriginalBitmapDrawing.draw(input, bitmap: record, observeRead: read, observeClip: { value in
                var event = OriginalFrontScreenEvent("clip"); event.clip = value; try observe(event)
            }, perform: blit)
        }
        func bar(_ width: Int32, row: Int32, x: Int32, y: Int32) throws {
            let destination = try token(0x455608), bitmap = try token(0x44fd7c)
            try observe(.init("rectangle", [bitmap, 0, UInt32(bitPattern: row), UInt32(bitPattern: width), 10,
                                            UInt32(bitPattern: x), UInt32(bitPattern: y), destination]))
            let (record, surface) = try resourceBitmap(bitmap)
            try OriginalRectangleDrawing.draw(bitmap: record, surface: surface, target: destination,
                sourceX: 0, sourceY: row, width: width, height: 10, x: x, y: y, observeRead: read, perform: blit)
        }
        func width(_ value: Int32) -> Int32 { (value &* 31)/125 }
        for cell in 0..<8 {
            let x = Int32(cell & 3)*198, y = Int32(cell >> 2)*54
            try picture(token(0x4511a8), catalog: false, x: x, y: y, frame: -1, key: 0)
            let slot: Int
            if try active(cell) { slot = cell }
            else if try active(cell+10) { slot = cell+10 }
            else { continue }
            let object = Int(try actor(slot).integer(at: 0x368, as: UInt32.self))
            try picture(header(object).integer(at: 0x728, as: UInt32.self), catalog: true, x: x+9, y: y+7, frame: -1, key: 0)
            if try i(slot, 0x2fc) > 0 {
                try bar(width(i(slot, 0x300)), row: 30, x: x+57, y: y+16)
                try bar(width(i(slot, 0x2fc)), row: 20, x: x+57, y: y+16)
                if try (i(slot, 0xe0)/1000 == 1 || i(slot, 0xe4) > 0) && g(0x450bd0)%2 == 0 {
                    try bar(width(i(slot, 0x2fc)), row: 40, x: x+57, y: y+16)
                }
                try bar(124, row: 10, x: x+57, y: y+36)
                try bar(width(i(slot, 0x308)), row: 0, x: x+57, y: y+36)
            }
            let team = try i(slot, 0x364)
            let address = [Int32(1): 0x44f888, 2: 0x44fcbc, 3: 0x44fb68, 4: 0x44faf8][team] ?? 0x44faf4
            try picture(token(address), catalog: false, x: x+5, y: y, frame: 254, key: 1)
        }
        globals = next
    }
}
