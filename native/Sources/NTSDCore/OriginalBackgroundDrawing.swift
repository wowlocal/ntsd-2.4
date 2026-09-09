/// Whole41a250 and arena99 child41a050. Bitmap clipping/drawing and415160
/// fill construction execute natively; actual raster devices remain bindings.
public enum OriginalBackgroundDrawing {
    public static func draw(backgrounds: inout [OriginalStateRecord],globals: OriginalStateRecord,target: UInt32,
        bitmap: (UInt32) throws -> (OriginalStateRecord,UInt32),
        fillBacking: () throws -> [UInt8],
        performFill: (OriginalSurfaceFillRequest) throws -> Int32,
        performBlit: (OriginalBitmapBlit) throws -> Int32,
        observe: (OriginalFrontScreenEvent) throws -> Void = { _ in }) throws {
        func g(_ address: Int) throws -> Int32 { try globals.integer(at: address-0x44d000,as: Int32.self) }
        let arena = Int(try g(0x44d024))
        guard backgrounds.indices.contains(arena) else { throw error("Arena binding") }
        var bg = backgrounds[arena]
        func value(_ offset: Int,_ layer: Int = 0) throws -> Int32 { try bg.integer(at: offset+4*layer,as: Int32.self) }
        func draw(_ token: UInt32,_ x: Int32,_ y: Int32,_ key: UInt32) throws {
            try observe(.init("draw",[token,UInt32(bitPattern: x),UInt32(bitPattern: y),UInt32.max,key,0,target]))
            guard token != 0 else { throw error("Null bitmap") }
            let (record,surface) = try bitmap(token)
            let input = try OriginalBitmapDrawInput(x: x,y: y,frame: -1,colorKey: key,mirrored: 0,sourceSurface: surface,targetSurface: target,
                viewportWidth: g(0x44d78c),viewportHeight: g(0x44d790))
            try OriginalBitmapDrawing.draw(input,bitmap: record,observeRead: { r in
                var e = OriginalFrontScreenEvent("read");e.read = r;try observe(e)
            },observeClip: { c in
                var e = OriginalFrontScreenEvent("clip");e.clip = c;try observe(e)
            },perform: { b in
                var e = OriginalFrontScreenEvent("blit");e.blit = b;try observe(e);return try performBlit(b)
            })
        }
        func fill(_ x: Int32,_ y: Int32,_ width: Int32,_ height: Int32,_ color: UInt32) throws {
            let request = try OriginalSurfaceFilling.request(target: UInt32(bitPattern: g(0x455608)),x: x,y: y,width: width,height: height,color: color,backing: fillBacking())
            guard request.target != 0 else { throw error("Null fill target") }
            var event = OriginalFrontScreenEvent("fill");event.fill = request;try observe(event);_ = try performFill(request)
        }
        if arena == 99 {
            let camera = try g(0x450bc4)
            // Embedded BG99 pointers use the same index+1 representation.
            try draw(UInt32(bitPattern: value(0x918)),250 &- camera/100,120,0)
            for x in stride(from: Int32(0),to: 4000,by: 500) { try draw(UInt32(bitPattern: value(0x91c)),x &- ((camera &* 7)/10) &+ 30,175,1) }
            try fill(0,326,794,20,0x3f3f3f);try fill(0,345,794,156,0x575757);try fill(0,471,794,30,0x3f3f3f)
            var x = (Int32(900) &- camera)%70
            try fill(0,328,794,2,0x373737)
            while x < 793 { try fill(x,292,1,37,0x577fa7);try fill(x &+ 1,292,1,37,0x2f4357);x &+= 70 }
            try fill(0,310,794,1,0x577fa7);try fill(0,311,794,1,0x2f4357)
            try fill(0,290,794,1,0x577fa7);try fill(0,291,794,1,0x2f4357)
            for x in stride(from: Int32(0),to: 3200,by: 320) { try draw(UInt32(bitPattern: value(0x914)),x &- camera &+ 10,390,0) }
        } else {
            var layer = 0
            while try Int32(layer) < value(0x1c) {
                let color = UInt32(bitPattern: try value(0x89c,layer))
                if color != 0 {
                    let colors: [UInt32:UInt32] = [0x175317:0x104f10,0x575347:0x5a4e4b,0x977757:0x9a6e5a,0x473f1f:0x423818]
                    try fill(value(0x4dc,layer),value(0x554,layer),value(0x464,layer),value(0x5cc,layer),colors[color] ?? color)
                } else {
                    let step = try value(0x644,layer)
                    func offset() throws -> Int32 {
                        let divisor = try value(0) &- 794,product = try (value(0x464,layer) &- 794) &* g(0x450bc4)
                        guard divisor != 0,!(product == Int32.min && divisor == -1) else { throw error("Original parallax division fault") }
                        return 0 &- (product/divisor)
                    }
                    // In the nonloop branch the division precedes the animation
                    // gate; in the looping branch it follows that gate.
                    let shift = step == 0 ? (try value(0) > 794 ? offset() : 0) : 0
                    let period = try value(0x7ac,layer)
                    if period > 0 {
                        let counter = try (value(0x824,layer) &+ 1)%period
                        try bg.write(counter,at: 0x824+4*layer)
                        if try counter < value(0x6bc,layer) || counter > value(0x734,layer) { layer += 1;continue }
                    }
                    if step == 0 { try draw(UInt32(bitPattern: value(0x914,layer)),value(0x4dc,layer) &+ shift,value(0x554,layer),UInt32(bitPattern: value(0x3ec,layer))) }
                    else {
                        let shift = try offset(),end = try value(0x464,layer)
                        var x = try value(0x4dc,layer),visited = Set<Int32>()
                        while x < end {
                            // Negative steps and wrapped additions are original
                            // arithmetic. Stop only on a repeated loop position.
                            guard visited.insert(x).inserted else { throw error("Original repeating layer loop") }
                            try draw(UInt32(bitPattern: value(0x914,layer)),x &+ shift,value(0x554,layer),UInt32(bitPattern: value(0x3ec,layer)))
                            x &+= step
                        }
                    }
                }
                layer += 1
            }
        }
        backgrounds[arena] = bg
    }
    private static func error(_ detail: String) -> OriginalStateError { .invalidStorage("Background drawing: "+detail) }
}
