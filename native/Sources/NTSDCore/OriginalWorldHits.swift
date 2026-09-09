///41eefb..41f2ac: type0 hits, item creation, then signed-positive-type hits.
/// No second contact collection occurs between these two ascending passes.
public enum OriginalWorldHits {
    public static func apply(state: inout OriginalMatchPreparation,crt: inout OriginalCRTRandom,
                             retainedSpawnSlot: Int32? = nil,sse2: Bool = false,
                             observe: (OriginalHitEvent) throws -> Void = { _ in },
                             afterHit: (Int,OriginalStateRecord) throws -> Void = { _,_ in }) throws {
        var pass = try OriginalActorHits.makePass(state: state,crt: crt,sse2: sse2)
        let backgrounds = state.backgrounds
        try pass.advance(retainedSpawnSlot: retainedSpawnSlot,background: { n in
            guard backgrounds.indices.contains(Int(n)) else { throw OriginalStateError.invalidStorage("Hit item background binding") }
            return backgrounds[Int(n)]
        },observe: observe,afterHit: afterHit)
        OriginalActorHits.publish(pass,state: &state,crt: &crt)
    }
}
extension OriginalHitPass {
    mutating func advance(retainedSpawnSlot: Int32? = nil,background: (Int32) throws -> OriginalStateRecord,
                          observe: (OriginalHitEvent) throws -> Void = { _ in },
                          afterHit: (Int,OriginalStateRecord) throws -> Void = { _,_ in }) throws {
        try globals.write(Int32(0),at: 0x45115c-0x44d000)
        for slot in 0..<400 where try world.integer(at: 4+slot,as: UInt8.self) != 0 {
            let type = try h(index(slot),0x6f8)
            if [1,2,4,6].contains(type) {
                let offset = 0x45115c-0x44d000;try globals.write(globals.integer(at: offset,as: Int32.self) &+ 1,at: offset)
            }
            if type == 0 { try resolve(slot,observe: observe);try afterHit(slot,actors[index(slot)]) }
        }
        if try globals.integer(at: 0x45115c-0x44d000,as: Int32.self) < 4 && draw(146,200,observe: observe) == 0 {
            let free = try (50..<400).first { try world.integer(at: 4+$0,as: UInt8.self) == 0 }
            var candidates: [Int] = []
            let mode = try globals.integer(at: 0x451160-0x44d000,as: Int32.self)
            if objectCount > 0 {
                for n in 0..<Int(objectCount) {
                    let id = try header(n).integer(at: 0x6f4,as: Int32.self)
                    if id < 100 || id >= 200 { continue }
                    if [122,123].contains(id) {
                        let include = try draw(147,2,observe: observe)
                        if include == 0 || [1,2,3,4].contains(mode) { continue }
                    }
                    candidates.append(n)
                }
            }
            let arena = try globals.integer(at: 0x44d024-0x44d000,as: Int32.self)
            let override = try globals.integer(at: 0x450bb4-0x44d000,as: Int32.self)
            let coarseX = try draw(override == 0 ? 148 : 150,30,observe: observe)
            let width = try override == 0 ? background(arena).integer(at: 0,as: Int32.self) : override
            let x0 = coarseX &* ((width &- 60)/30),fineX = try draw(override == 0 ? 149 : 151,30,observe: observe)
            let x = x0 &+ fineX &+ 30,coarseZ = try draw(152,30,observe: observe)
            let bg = try background(arena)
            let span = try bg.integer(at: 8,as: Int32.self) &- bg.integer(at: 4,as: Int32.self) &- 60
            let z0 = coarseZ &* (span/30),fineZ = try draw(153,30,observe: observe)
            let z = try fineZ &+ bg.integer(at: 4,as: Int32.self) &+ z0 &+ 30
            let selected = try draw(154,Int32(candidates.count),observe: observe)
            //41ef92 retains caller scratch when the pool is full; it does not
            //skip spawning. Its value must come from that caller's prior writes.
            guard let slot = free ?? retainedSpawnSlot.map(Int.init) else { throw OriginalStateError.invalidStorage("Item spawn needs retained caller slot provenance") }
            let created = try index(slot),object = candidates[Int(selected)]
            try observe(.reconstruct(slot: slot));try actors[created].reconstructActor()
            try put(created,0x368,Int32(object));try number(created,0x58,Double(x));try number(created,0x60,-500)
            try put(created,0x31c,header(object).integer(at: 0x90,as: Int32.self));try number(created,0x68,Double(z))
            try world.write(UInt8(1),at: 4+slot)
            for other in 0..<400 where try world.integer(at: 4+other,as: UInt8.self) != 0 { try byte(index(other),0xf0+slot,0) }
            for offset in [0x40,0x48,0x50] { try number(index(slot),offset,0) }
            if try h(index(slot),0x6f4) == 122 { try put(index(slot),0x2fc,200) }
            for (integer,binary) in [(0x10,0x58),(0x14,0x60),(0x18,0x68)] { try put(index(slot),integer,OriginalCoordinateConversion.integer(v(index(slot),binary),sse2: sse2)) }
            try put(index(slot),0x354,99)
        }
        for slot in 0..<400 where try world.integer(at: 4+slot,as: UInt8.self) != 0 {
            if try h(index(slot),0x6f8) > 0 { try resolve(slot,observe: observe);try afterHit(slot,actors[index(slot)]) }
        }
    }
}
