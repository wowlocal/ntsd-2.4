public enum OriginalWorldLinksEvent: Equatable {
    case random(slot: Int,stream: Int32,range: Int32,result: Int32)
}

/// Whole417f80..4187a3. The first pass clamps type0 depth; the second places,
/// consumes and throws held objects. It is called twice by the original tick.
public enum OriginalWorldLinks {
    public static func apply(state: inout OriginalMatchPreparation,sse2Conversion: Bool = false,
                             observe: (OriginalWorldLinksEvent) throws -> Void = { _ in },
                             afterDepth: (Int,OriginalStateRecord) throws -> Void = { _,_ in }) throws {
        let catalog = state.catalog,backgrounds = state.backgrounds
        guard try state.world.integer(at: 0x7d4,as: UInt32.self) == 0 else { throw error("Catalog binding") }
        try apply(world: state.world,actors: &state.actors,globals: &state.globals,sse2Conversion: sse2Conversion,precision: state.arithmeticPrecision,
            header: { index in
                guard catalog.objects.indices.contains(index) else { throw error("Object binding") };return catalog.objects[index].header
            },frame: { index,number in
                guard catalog.objects.indices.contains(index),catalog.objects[index].frameStorage.indices.contains(Int(number)) else { throw error("Frame binding") }
                return catalog.objects[index].frameStorage[Int(number)]
            },background: { index in
                guard backgrounds.indices.contains(Int(index)) else { throw error("Background binding") };return backgrounds[Int(index)]
            },observe: observe,afterDepth: afterDepth)
    }
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("World links: "+text) }
    static func apply(world: OriginalStateRecord,actors: inout [OriginalStateRecord],globals: inout OriginalStateRecord,
                      sse2Conversion: Bool = false,precision: OriginalArithmeticPrecision = .bits64,header: (Int) throws -> OriginalStateRecord,
                      frame: (Int,Int32) throws -> OriginalStateRecord,background: (Int32) throws -> OriginalStateRecord,
                      observe: (OriginalWorldLinksEvent) throws -> Void = { _ in },
                      afterDepth: (Int,OriginalStateRecord) throws -> Void = { _,_ in }) throws {
        var pool = actors,owned = globals
        func active(_ slot: Int) throws -> UInt8 { try world.integer(at: 4+slot,as: UInt8.self) }
        func index(_ slot: Int) throws -> Int {
            let n = Int(try world.integer(at: 0x194+slot*4,as: UInt32.self))
            guard pool.indices.contains(n) else { throw error("Actor binding") };return n
        }
        func i(_ a: Int,_ offset: Int) throws -> Int32 { try pool[a].integer(at: offset,as: Int32.self) }
        func b(_ a: Int,_ offset: Int) throws -> UInt8 { try pool[a].integer(at: offset,as: UInt8.self) }
        func object(_ a: Int) throws -> Int { Int(try pool[a].integer(at: 0x368,as: UInt32.self)) }
        func h(_ a: Int,_ offset: Int) throws -> Int32 { try header(object(a)).integer(at: offset,as: Int32.self) }
        func current(_ a: Int) throws -> OriginalStateRecord { try frame(object(a),i(a,0x70)) }
        func f(_ a: Int,_ offset: Int) throws -> Int32 { try current(a).integer(at: offset,as: Int32.self) }
        func put(_ a: Int,_ offset: Int,_ value: Int32) throws { try pool[a].write(value,at: offset) }
        func constant(_ value: Double) throws -> OriginalExtended { try OriginalExtended(value,precision: precision) }
        func v(_ a: Int,_ offset: Int) throws -> Double { try pool[a].binary64(at: offset) }
        func store(_ a: Int,_ offset: Int,_ value: Double) throws { try pool[a].writeBinary64(value,at: offset) }
        func draw(_ slot: Int,_ stream: Int32,_ range: Int32) throws -> Int32 {
            var random = OriginalRandom(table: try (0..<3000).map { try owned.integer(at: 0x44ff90-0x44d000+$0,as: UInt8.self) },
                index: Int(try owned.integer(at: 0x450bcc-0x44d000,as: Int32.self)),counter: Int(try owned.integer(at: 0x450c34-0x44d000,as: Int32.self)),source: "owned World links",sourceSHA256: "")
            try random.validate();let result = Int32(random.next(Int(range)))
            try owned.write(Int32(random.index),at: 0x450bcc-0x44d000);try owned.write(Int32(random.counter),at: 0x450c34-0x44d000)
            try observe(.random(slot: slot,stream: stream,range: range,result: result));return result
        }
        func exhausted(_ a: Int,_ holder: Int,_ slot: Int,_ stream: Int32) throws {
            try put(holder,0x98,0);try put(a,0x98,0);try put(holder,0x9c,0);try put(a,0xa0,0)
            try put(a,0x70,0);try store(a,0x48,-8);try store(a,0x40,Double(draw(slot,stream,7) &- 3))
            try put(holder,0x70,0);try put(a,0x31c,0)
        }
        for slot in 0..<400 where try active(slot) != 0 {
            let a = try index(slot)
            if try h(a,0x6f8) == 0 {
                let bg = try background(owned.integer(at: 0x44d024-0x44d000,as: Int32.self))
                let low = Double(try bg.integer(at: 4,as: Int32.self)),high = Double(try bg.integer(at: 8,as: Int32.self))
                guard try v(a,0x68).isFinite else { throw error("Nonfinite depth") }
                if try low > v(a,0x68) { try store(a,0x68,low) }
                if try high < v(a,0x68) { try store(a,0x68,high) }
                try put(a,0x18,OriginalCoordinateConversion.integer(v(a,0x68),sse2: sse2Conversion))
                try afterDepth(slot,pool[a])
            }
        }
        for slot in 0..<400 where try active(slot) != 0 {
            let a = try index(slot)
            if try i(a,0x98) >= 0 { continue }
            let owner = try i(a,0xa0)
            guard (0..<400).contains(owner),try active(Int(owner)) != 0 else { try put(a,0x98,0);continue }
            let holder = try index(Int(owner))
            guard try i(holder,0x9c) == Int32(slot) else { try put(a,0x98,0);continue }
            if try f(holder,8) == 17 {
                if try h(a,0x6f4) == 122 && i(a,0x2fc) > 0 {
                    try put(a,0x2fc,i(a,0x2fc) &- 1)
                    if try i(a,0x2fc)%5 == 0 {
                        try put(holder,0x300,i(holder,0x300) &+ 2);try put(holder,0x2fc,i(holder,0x2fc) &+ 4)
                        if try i(holder,0x300) > i(holder,0x304) { try put(holder,0x300,i(holder,0x304)) }
                        if try i(holder,0x2fc) > i(holder,0x300) { try put(holder,0x2fc,i(holder,0x300)) }
                    }
                    if try i(a,0x2fc)%6 == 0 {
                        try put(holder,0x308,i(holder,0x308) &+ 5)
                        if try i(holder,0x308) > 500 { try put(holder,0x308,500) }
                    }
                    if try i(a,0x2fc) <= 0 { try exhausted(a,holder,slot,136);continue }
                }
                if try h(a,0x6f4) == 123 && i(a,0x2fc) > 0 {
                    try put(a,0x2fc,i(a,0x2fc) &- 2);try put(holder,0x308,i(holder,0x308) &+ 3)
                    if try i(holder,0x308) > 500 { try put(holder,0x308,500) }
                    if try i(a,0x2f4) > -1 && i(a,0x308) > 150 { try put(holder,0x308,150) }
                    if try i(a,0x2fc) <= 0 { try exhausted(a,holder,slot,137);continue }
                }
            }
            // Keep the original holder wpoint address across changes to either
            // Actor's frame. With aliases the later center reads use the new frame.
            let holderFrame = try current(holder)
            func wp(_ offset: Int) throws -> Int32 { try holderFrame.integer(at: 0xd8+offset,as: Int32.self) }
            try put(a,0x70,wp(0xc));try pool[a].write(b(holder,0x80),at: 0x80);try put(a,0xb4,i(holder,0xb4))
            let x = try b(holder,0x80) == 0 ? i(holder,0x10) &- f(holder,0x50) &+ wp(4) : f(holder,0x50) &- wp(4) &+ i(holder,0x10)
            let y = try i(holder,0x14) &- f(holder,0x54) &+ wp(8)
            let heldFrame = try current(a)
            func heldPoint(_ offset: Int) throws -> Int32 { try heldFrame.integer(at: 0xd8+offset,as: Int32.self) }
            if try b(a,0x80) == 0 { try put(a,0x10,f(a,0x50) &- heldPoint(4) &+ x) }
            else { try put(a,0x10,heldPoint(4) &- f(a,0x50) &+ x) }
            try put(a,0x14,f(a,0x54) &- heldPoint(8) &+ y);try put(a,0x18,i(holder,0x18))
            if try wp(0x14) == 0 { try put(a,0x18,i(a,0x18) &+ 1);try put(a,0x14,i(a,0x14) &- 1) }
            else { try put(a,0x18,i(a,0x18) &- 1);try put(a,0x14,i(a,0x14) &+ 1) }
            for (from,to) in [(0x18,0x68),(0x10,0x58),(0x14,0x60)] { try store(a,to,Double(i(a,from))) }
            if try [12,10].contains(f(holder,8)) {
                try put(holder,0x98,0);try put(a,0x98,0);try put(a,0x70,draw(slot,138,16))
                if try i(holder,0x20) == 1 {
                    try store(a,0x48,v(holder,0x30));try store(a,0x40,(constant(v(holder,0x28))/constant(3)).double)
                } else {
                    try store(a,0x48,v(holder,0x48));try store(a,0x40,(constant(v(holder,0x40))/constant(3)).double)
                }
                if try v(a,0x60) > -2 { try store(a,0x60,-2) }
            }
            if try wp(0x18) != 0 && [1,4,6].contains(h(a,0x6f8)) {
                try put(a,0x2f8,owner);try put(a,0x70,40)
                try store(a,0x40,Double(b(holder,0x80) == 0 ? wp(0x18) : 0 &- wp(0x18)));try store(a,0x48,Double(wp(0x1c)))
                try put(holder,0x98,0);try put(a,0x98,0)
                if try b(holder,0xcd) != 0 && b(holder,0xce) == 0 { try store(a,0x50,Double(0 &- wp(0x20))) }
                else if try b(holder,0xcd) == 0 && b(holder,0xce) != 0 { try store(a,0x50,Double(wp(0x20))) }
            }
            if try wp(0x18) != 0 && h(a,0x6f8) == 2 {
                try put(a,0x70,draw(slot,139,6))
                try store(a,0x40,Double(b(holder,0x80) == 0 ? wp(0x18) : 0 &- wp(0x18)));try store(a,0x48,Double(wp(0x1c)))
                try put(holder,0x98,0);try put(a,0x98,0)
                if try b(holder,0xcd) != 0 && b(holder,0xce) == 0 { try store(a,0x50,Double(0 &- wp(0x20))) }
                else if try b(holder,0xcd) == 0 && b(holder,0xce) != 0 { try store(a,0x50,Double(wp(0x20))) }
            }
            if try wp(0) == 3 {
                try put(a,0x98,0);try put(holder,0x98,0);try put(a,0x70,draw(slot,140,6))
                try store(a,0x40,Double(draw(slot,141,7) &- 3));try store(a,0x48,Double(0 &- draw(slot,142,4)))
                try store(a,0x50,(constant(Double(draw(slot,143,5) &- 2))/constant(5)).double)
            }
        }
        actors = pool;globals = owned
    }
}
