/// Whole41a5a0..41ae50 with actual Actor/Object/bitmap children. Hit effects
/// advance during this rendering pass, before the original frame scheduler.
public enum OriginalWorldDrawing {
    /// Catalog bitmap references and retained interface resource tokens have
    /// different ownership. Never interpret an opaque resource as an ordinal.
    /// Buffer device events until the enclosing tick successfully commits.
    public static func apply(state: inout OriginalMatchPreparation,target: UInt32,phase: Int32,
        surface: (Int) throws -> UInt32,
        resourceBitmap: (UInt32) throws -> (OriginalStateRecord,UInt32),
        performBlit: (OriginalBitmapBlit) throws -> Int32,
        observe: (OriginalFrontScreenEvent) throws -> Void = { _ in }) throws {
        var next = state
        let catalog = next.catalog,bitmaps = next.bitmaps,released = next.releasedBitmaps
        guard try next.world.integer(at: 0x7d4,as: UInt32.self) == 0 else { throw error("Catalog binding") }
        try draw(world: next.world,actors: &next.actors,globals: next.globals,backgrounds: next.backgrounds,
            target: target,phase: phase,header: { n in
                guard catalog.objects.indices.contains(n) else { throw error("Object binding") };return catalog.objects[n].header
            },frame: { n,f in
                guard catalog.objects.indices.contains(n) else { throw error("Frame binding") }
                if catalog.objects[n].frameStorage.indices.contains(Int(f)) { return catalog.objects[n].frameStorage[Int(f)] }
                return try OriginalCPointPass.headerFrame(f,header: catalog.objects[n].header)
            },catalogBitmap: { token in
                guard token != 0,Int(token)-1 < bitmaps.count,!released.contains(Int(token)-1) else { throw error("Bitmap binding") }
                return try (bitmaps[Int(token)-1].storage,surface(Int(token)-1))
            },resourceBitmap: resourceBitmap,performBlit: performBlit,observe: observe)
        state = next
    }
    private static func error(_ detail: String) -> OriginalStateError { .invalidStorage("World drawing: "+detail) }
    static func draw(world: OriginalStateRecord,actors: inout [OriginalStateRecord],globals: OriginalStateRecord,
        backgrounds: [OriginalStateRecord],target: UInt32,phase: Int32,
        header: (Int) throws -> OriginalStateRecord,frame: (Int,Int32) throws -> OriginalStateRecord,
        catalogBitmap: (UInt32) throws -> (OriginalStateRecord,UInt32),
        resourceBitmap: (UInt32) throws -> (OriginalStateRecord,UInt32),
        performBlit: (OriginalBitmapBlit) throws -> Int32,
        observe: (OriginalFrontScreenEvent) throws -> Void) throws {
        func g(_ address: Int) throws -> Int32 { try globals.integer(at: address-0x44d000,as: Int32.self) }
        func index(_ slot: Int) throws -> Int {
            let n = Int(try world.integer(at: 0x194+slot*4,as: UInt32.self))
            guard actors.indices.contains(n) else { throw error("Actor binding") };return n
        }
        func read(_ r: OriginalBitmapDrawRead) throws { var e = OriginalFrontScreenEvent("read");e.read = r;try observe(e) }
        func blit(_ b: OriginalBitmapBlit) throws -> Int32 { var e = OriginalFrontScreenEvent("blit");e.blit = b;try observe(e);return try performBlit(b) }
        func bitmapDraw(_ token: UInt32,_ catalog: Bool,_ x: Int32,_ y: Int32,_ picture: Int32,_ key: UInt32,_ destination: UInt32) throws {
            try observe(.init("draw",[token,UInt32(bitPattern: x),UInt32(bitPattern: y),UInt32(bitPattern: picture),key,0,destination]))
            guard token != 0 else { throw error("Null bitmap") }
            let (record,surface) = try catalog ? catalogBitmap(token) : resourceBitmap(token)
            let input = try OriginalBitmapDrawInput(x: x,y: y,frame: picture,colorKey: key,mirrored: 0,sourceSurface: surface,targetSurface: destination,
                viewportWidth: g(0x44d78c),viewportHeight: g(0x44d790))
            try OriginalBitmapDrawing.draw(input,bitmap: record,observeRead: read,observeClip: { c in
                var e = OriginalFrontScreenEvent("clip");e.clip = c;try observe(e)
            },perform: blit)
        }
        func text(_ bytes: [UInt8],font: UInt32,x: Int32,y: Int32) throws {
            var x = x
            for c in bytes { try bitmapDraw(font,false,x,y,Int32(Int8(bitPattern: c)),1,UInt32(bitPattern: g(0x455608)));x &+= 9 }
        }
        func name(_ slot: Int) throws -> [UInt8] {
            var bytes: [UInt8] = [],offset = 0x44fcc0-0x44d000+11*slot
            while true {
                let c = try globals.integer(at: offset,as: UInt8.self)
                if c == 0 { break };bytes.append(c);offset += 1
            }
            if try g(0x450b4c+4*slot) == -1 {
                // Source concatenates into20 stack bytes, then checks a cookie.
                // Cross-cookie writes require outer stack provenance, not truncation.
                guard bytes.count <= 17 else { throw error("Bracketed name crosses original stack buffer") }
                bytes = [91]+bytes+[93]
            }
            return bytes
        }
        var slots: [(slot: Int,z: Int32)] = []
        for slot in 0..<400 where try world.integer(at: 4+slot,as: UInt8.self) != 0 {
            slots.append((slot,try actors[index(slot)].integer(at: 0x18,as: Int32.self)))
        }
        slots.sort { $0.z == $1.z ? $0.slot < $1.slot : $0.z < $1.z }
        let arena = Int(try g(0x44d024))
        for entry in slots {
            let a = try index(entry.slot),actor = actors[a]
            func i(_ offset: Int) throws -> Int32 { try actor.integer(at: offset,as: Int32.self) }
            let object = Int(try actor.integer(at: 0x368,as: UInt32.self))
            // Keep source gates lazy: invisible objects can have no current Frame.
            func f() throws -> OriginalStateRecord { try frame(object,i(0x70)) }
            func h(_ offset: Int) throws -> Int32 { try header(object).integer(at: offset,as: Int32.self) }
            let blink = try i(8),absolute = blink < 0 ? 0 &- blink : blink
            if try i(0x98) >= 0 && f().integer(at: 8,as: Int32.self) != 3005 && f().integer(at: 8,as: Int32.self) != 9997 && h(0x6f4) != 223 && h(0x6f4) != 224 && blink > -70 && absolute%4 < 2 {
                guard backgrounds.indices.contains(arena) else { throw error("Background binding") }
                let bg = backgrounds[arena]
                let x = try i(0x1c) &- bg.integer(at: 0x14,as: Int32.self)/2 &+ i(0x10) &- g(0x450bc4)
                let y = try i(0x18) &- bg.integer(at: 0x18,as: Int32.self)/2
                try bitmapDraw(bg.integer(at: 0x98c,as: UInt32.self),true,x,y,-1,1,target)
            }
            if absolute%4 < 2 && blink > -25 {
                try OriginalActorDrawing.draw(actor: actor,header: header(object),frame: f(),camera: g(0x450bc4),target: target,phase: phase,
                    bitmapWord: { token,offset in
                        try observe(.init("width",[token,offset]))
                        let (record,surface) = try catalogBitmap(token)
                        return try OriginalBitmapDrawing.word(offset,bitmap: record,surface: surface,observe: read)
                    },bitmapDraw: { try bitmapDraw($0,true,$1,$2,$3,$4,$5) },pointDraw: { x,y in
                        let token = UInt32(bitPattern: try g(0x44fd7c)),destination = UInt32(bitPattern: try g(0x455608))
                        try observe(.init("rectangle",[token,0,20,1,3,UInt32(bitPattern: x),UInt32(bitPattern: y),destination]))
                        let (record,surface) = try resourceBitmap(token)
                        try OriginalRectangleDrawing.draw(bitmap: record,surface: surface,target: destination,sourceX: 0,sourceY: 20,width: 1,height: 3,x: x,y: y,observeRead: read,perform: blit)
                    })
            }
            let lives = try i(0x30c)
            if lives > 1 {
                let digits: [UInt8] = lives > 9 ? [120,UInt8((lives/10)%10+48),UInt8(lives%10+48)] : [120,UInt8(lives%10+48)]
                let x = try i(0x1c) &- Int32(digits.count*9/2) &+ i(0x10) &- g(0x450bc4)
                let y = try i(0x18) &- f().integer(at: 0x54,as: Int32.self) &+ i(0x14) &- 7
                try text(digits,font: UInt32(bitPattern: g(0x44faf4)),x: x,y: y)
            }
            var label: [UInt8]?,fontAddress = 0x44faf4
            if try entry.slot < 20 || (i(0x364) != 5 && h(0x6f8) == 0) {
                if blink > -25 {
                    label = try entry.slot < 10 ? name(entry.slot) : [67,111,109]
                    if label?.isEmpty == false { fontAddress = try [1:0x44f888,2:0x44fcbc,3:0x44fb68,4:0x44faf8][Int(i(0x364))] ?? 0x44faf4 }
                }
            } else if try entry.slot >= 20 && blink > -25 && h(0x6f8) == 0 && i(0x364) == 5 {
                let id = try h(0x6f4)
                if id < 30 || id >= 50 || id == 38 { label = [67,111,109];fontAddress = 0x44fd80 }
            }
            if let label, !label.isEmpty {
                let width = Int32(truncatingIfNeeded: label.count) &* 9
                var x = try i(0x1c) &- Int32(bitPattern: UInt32(bitPattern: width)>>1) &+ i(0x10) &- g(0x450bc4)
                x = min(max(x,0),794 &- width)
                try text(label,font: UInt32(bitPattern: g(fontAddress)),x: x,y: i(0x18) &+ 3)
            }
            var effect = 0
            while try Int64(effect) < Int64(actors[a].integer(at: 0x36c,as: Int32.self)) {
                let offset = 0x3c0+effect*4,value = try actors[a].integer(at: offset,as: Int32.self)
                var picture: Int32?,dx: Int32 = 51,dy: Int32 = 40
                if value < 5 { picture = value }
                else if value >= 10 && value < 15 { picture = value-5;dx = 30;dy = 24 }
                else if value >= 20 && value < 29 { picture = (value-20)/2+10 }
                else if value >= 30 && value < 39 { picture = (value-30)/2+15;dx = 30;dy = 24 }
                if let picture {
                    let x = try actors[a].integer(at: offset-0x50,as: Int32.self) &+ i(0x1c) &- g(0x450bc4) &- dx
                    let y = try actors[a].integer(at: offset-0x28,as: Int32.self) &- dy
                    try bitmapDraw(UInt32(bitPattern: g(0x44f8fc)),false,x,y,picture,1,target)
                    try actors[a].write(value &+ 1,at: offset)
                } else {
                    let count = try actors[a].integer(at: 0x36c,as: Int32.self)
                    if Int64(effect) == Int64(count)-1 { try actors[a].write(count &- 1,at: 0x36c) }
                }
                effect += 1
            }
        }
    }
}
