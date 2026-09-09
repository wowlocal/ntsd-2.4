/// Entire41b5d0 through ret8, including the actual background drawing child.
/// The caller supplies device bindings; simulation never executes Windows code.
public enum OriginalWorldCamera {
    public static func apply(state: inout OriginalMatchPreparation,mode: Int32,target: UInt32,
        sse2Conversion: Bool = false,surface: (Int) throws -> UInt32,
        fillBacking: () throws -> [UInt8],
        performFill: (OriginalSurfaceFillRequest) throws -> Int32,
        performBlit: (OriginalBitmapBlit) throws -> Int32,
        observe: (OriginalFrontScreenEvent) throws -> Void = { _ in }) throws {
        var next = state
        let catalog = next.catalog,bitmaps = next.bitmaps,released = next.releasedBitmaps,backgrounds = next.backgrounds
        guard try next.world.integer(at: 0x7d4,as: UInt32.self) == 0 else { throw error("Catalog binding") }
        try bounds(world: &next.world,actors: &next.actors,globals: &next.globals,mode: mode,sse2Conversion: sse2Conversion,
            header: { n in
                guard catalog.objects.indices.contains(n) else { throw error("Object binding") };return catalog.objects[n].header
            },frame: { n,f in
                guard catalog.objects.indices.contains(n) else { throw error("Frame binding") }
                if catalog.objects[n].frameStorage.indices.contains(Int(f)) { return catalog.objects[n].frameStorage[Int(f)] }
                return try OriginalCPointPass.headerFrame(f,header: catalog.objects[n].header)
            },background: { n in
                guard backgrounds.indices.contains(Int(n)) else { throw error("Background binding") };return backgrounds[Int(n)]
            })
        try OriginalBackgroundDrawing.draw(backgrounds: &next.backgrounds,globals: next.globals,target: target,bitmap: { token in
            guard token != 0,Int(token)-1 < bitmaps.count,!released.contains(Int(token)-1) else { throw error("Bitmap binding") }
            return try (bitmaps[Int(token)-1].storage,surface(Int(token)-1))
        },fillBacking: fillBacking,performFill: performFill,performBlit: performBlit,observe: observe)
        state = next
    }
    private static func error(_ detail: String) -> OriginalStateError { .invalidStorage("World camera: "+detail) }
    /// Bounds and camera calculations are a child of apply, not a complete tick.
    static func bounds(world: inout OriginalStateRecord,actors: inout [OriginalStateRecord],globals: inout OriginalStateRecord,
        mode: Int32,sse2Conversion: Bool = false,header: (Int) throws -> OriginalStateRecord,
        frame: (Int,Int32) throws -> OriginalStateRecord,background: (Int32) throws -> OriginalStateRecord) throws {
        func g(_ address: Int) throws -> Int32 { try globals.integer(at: address-0x44d000,as: Int32.self) }
        func active(_ slot: Int) throws -> Bool { try world.integer(at: 4+slot,as: UInt8.self) != 0 }
        func index(_ slot: Int) throws -> Int {
            let n = Int(try world.integer(at: 0x194+4*slot,as: UInt32.self))
            guard actors.indices.contains(n) else { throw error("Actor binding") };return n
        }
        func i(_ a: Int,_ offset: Int) throws -> Int32 { try actors[a].integer(at: offset,as: Int32.self) }
        func obj(_ a: Int) throws -> Int { Int(try actors[a].integer(at: 0x368,as: UInt32.self)) }
        let bg = try background(g(0x44d024)),width = try bg.integer(at: 0,as: Int32.self)
        for slot in 0..<400 where try active(slot) {
            let a = try index(slot),h = try header(obj(a)),type = try h.integer(at: 0x6f8,as: Int32.self)
            var z = try actors[a].binary64(at: 0x68),x = try actors[a].binary64(at: 0x58)
            guard z.isFinite,x.isFinite else { throw error("Nonfinite coordinates") }
            let low = Double(try bg.integer(at: 4,as: Int32.self)) - (type == 0 ? 0 : 1)
            let high = Double(try bg.integer(at: 8,as: Int32.self)) + (type == 0 ? 0 : 1)
            // Comparisons precede each store. Preserve untouched masks and -0.
            if z < low { z = low;try actors[a].writeBinary64(z,at: 0x68) }
            if z > high { z = high;try actors[a].writeBinary64(z,at: 0x68) }
            try actors[a].write(OriginalCoordinateConversion.integer(z,sse2: sse2Conversion),at: 0x18)
            func lower(_ v: Double) throws { if x < v { x = v;try actors[a].writeBinary64(x,at: 0x58) } }
            func upper(_ v: Double) throws { if x > v { x = v;try actors[a].writeBinary64(x,at: 0x58) } }
            if type == 3 {
                if x < -300 { try world.write(UInt8(0),at: 4+slot) }
                if x > Double(width)+300 { try world.write(UInt8(0),at: 4+slot) }
            } else if type == 0 {
                if slot >= 20 { try lower(-100);try upper(Double(width)+100) }
                else { try lower(i(a,0x364) == 5 ? -300 : 0);try upper(Double(width)) }
                if try g(0x450bb4) > 0 && x > Double(g(0x450bb4)) && i(a,0x364) != 5 && i(a,8) == 0 { try upper(Double(g(0x450bb4))) }
            } else {
                let id = try h.integer(at: 0x6f4,as: Int32.self)
                // The mode/Stage exception is ALSO behind the ID122/123 gate.
                if try (id == 122 || id == 123) && (i(a,0x344) > 0 || (mode == 1 && g(0x450b94)/10 == 5)) {
                    try lower(10);try upper(Double(width)-10)
                } else {
                    if x < 0,try i(a,0x14) == 0 { try world.write(UInt8(0),at: 4+slot) }
                    if x > Double(width),try i(a,0x14) == 0 { try world.write(UInt8(0),at: 4+slot) }
                }
            }
            // Deactivated slots still receive this conversion before advancing.
            try actors[a].write(OriginalCoordinateConversion.integer(x,sse2: sse2Conversion),at: 0x10)
        }
        var sum: Int32 = 0,count: Int32 = 0
        for slot in 0..<8 where try active(slot) && g(0x450b4c+slot*4) > 0 {
            let a = try index(slot)
            if try i(a,0x2fc) > 0 {
                let f = try frame(obj(a),i(a,0x70))
                if try f.integer(at: 8,as: Int32.self) == 14 { sum = try sum &+ i(a,0x10) }
                else {
                    let face = Int32(try actors[a].integer(at: 0x80,as: Int8.self))
                    sum = try sum &+ (i(a,0x10) &- (face &* 260)) &+ 130
                };count &+= 1
            }
        }
        if count == 0 {
            for slot in 0..<400 where try active(slot) {
                let a = try index(slot)
                if try header(obj(a)).integer(at: 0x6f8,as: Int32.self) == 0 && i(a,0x2fc) > 0 { sum = try sum &+ i(a,0x10);count &+= 1 }
            }
        }
        if count == 0 { sum = 800;count = 1 }
        let limit = width &- 794
        var target = max(0,(sum/count) &- 397)
        target = min(target,limit)
        if try g(0x450bb0) != 0 { target = try min(target,g(0x450bb0)) }
        var current = try g(0x450bc4)
        var velocity = try ((g(0x450bc8) &* 6) &+ ((target &- current)/14))/7
        if velocity == 0 { if target > current { velocity = 1 } else if target < current { velocity = -1 } }
        try globals.write(velocity,at: 0x450bc8-0x44d000)
        current &+= velocity
        let replay = try g(0x450b74) != 0 && g(0x450b84) != 0
        if replay { current = try g(0x450b7c) }
        current = min(max(current,0),limit)
        try globals.write(current,at: 0x450bc4-0x44d000)
        if replay { try globals.write(current,at: 0x450b7c-0x44d000) }
    }
}
