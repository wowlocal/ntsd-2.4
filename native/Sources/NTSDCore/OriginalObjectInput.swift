public enum OriginalObjectInputEvent: Equatable {
    case random(stream: Int32,range: Int32,result: Int32)
    case reconstruct(slot: Int)
}

/// Non-character input child 406ba0(World, slot), called by419a60 for slots
/// 10..399 whose Object type is nonzero and whose current Frame hit_Fa (+0x30)
/// is positive. The recovered domain is the hit_Fa values used by the original
/// DAT files: 1, 3, 4, 5, 7, 8, 10, 12 and 14. Values 2, 6, 9, 11, 13 and any
/// other positive value have original branches (spawn fans, frame steering)
/// that are not implemented here and stop as explicit boundaries.
public enum OriginalObjectInput {
    public static let recoveredHitFa: Set<Int32> = [1,3,4,5,7,8,10,12,14]

    public static func apply(slot: Int,state: inout OriginalMatchPreparation,
                             observe: (OriginalObjectInputEvent) throws -> Void = { _ in }) throws {
        let catalog = state.catalog
        guard try state.world.integer(at: 0x7d4,as: UInt32.self) == 0,
              let registry = catalog.registry.records[0x4d82380] else { throw error("Object-input catalog binding") }
        var pass = OriginalObjectInputPass(world: state.world,actors: state.actors,globals: state.globals,
                                           objects: catalog.objects,objectCount: try registry.integer(at: 0,as: Int32.self),
                                           precision: state.arithmeticPrecision)
        try pass.run(slot,observe: observe)
        state.world = pass.world; state.actors = pass.actors; state.globals = pass.globals
    }

    static func error(_ message: String) -> OriginalStateError { .invalidStorage(message) }
}

struct OriginalObjectInputPass {
    var world: OriginalStateRecord
    var actors: [OriginalStateRecord]
    var globals: OriginalStateRecord
    let objects: [OriginalLoadedObject]
    let objectCount: Int32
    let precision: OriginalArithmeticPrecision

    func error(_ message: String) -> OriginalStateError { OriginalObjectInput.error(message) }
    func active(_ slot: Int) throws -> UInt8 {
        guard (0..<400).contains(slot) else { throw error("Object-input activity outside slots 0..399") }
        return try world.integer(at: 4+slot,as: UInt8.self)
    }
    mutating func activate(_ slot: Int,_ value: UInt8) throws { try world.write(value,at: 4+slot) }
    func index(_ slot: Int) throws -> Int {
        guard (0..<400).contains(slot) else { throw error("Object-input Actor table outside slots 0..399") }
        let a = Int(try world.integer(at: 0x194+slot*4,as: UInt32.self))
        guard actors.indices.contains(a) else { throw error("Object-input Actor binding") }
        return a
    }
    func i(_ a: Int,_ o: Int) throws -> Int32 { try actors[a].integer(at: o,as: Int32.self) }
    func object(_ a: Int) throws -> Int {
        let n = Int(try actors[a].integer(at: 0x368,as: UInt32.self))
        guard objects.indices.contains(n) else { throw error("Object-input Object binding") }
        return n
    }
    func h(_ a: Int,_ o: Int) throws -> Int32 { try objects[object(a)].header.integer(at: o,as: Int32.self) }
    func frame(_ a: Int,_ o: Int) throws -> Int32 {
        let n = try object(a),f = try i(a,0x70)
        guard objects[n].frameStorage.indices.contains(Int(f)) else { throw error("Object-input Frame binding") }
        return try objects[n].frameStorage[Int(f)].integer(at: o,as: Int32.self)
    }
    func v(_ a: Int,_ o: Int) throws -> OriginalExtended { try OriginalExtended(actors[a].binary64(at: o),precision: precision) }
    func c(_ value: Double) throws -> OriginalExtended { try OriginalExtended(value,precision: precision) }
    mutating func put(_ a: Int,_ o: Int,_ value: Int32) throws { try actors[a].write(value,at: o) }
    mutating func store(_ a: Int,_ o: Int,_ value: OriginalExtended) throws { try actors[a].writeBinary64(value.double,at: o) }
    /// fld/fstp qword: exact except that a signaling NaN becomes quiet.
    mutating func copy(_ from: Int,_ to: Int,_ o: Int) throws {
        var bits = try actors[from].integer(at: o,as: UInt64.self)
        if bits & 0x7ff0000000000000 == 0x7ff0000000000000 && bits & 0xfffffffffffff != 0 { bits |= 1 << 51 }
        try actors[to].write(bits,at: o)
    }
    func abs(_ value: Int32) -> Int32 { value < 0 ? 0 &- value : value } // 4034e0; Int32.min stays negative.
    func free() throws -> Int? { try (50..<400).first { try active($0) == 0 } }
    func find(_ id: Int32) throws -> Int? {
        if objectCount > 0 { for n in 0..<Int(objectCount) where try objects[n].header.integer(at: 0x6f4,as: Int32.self) == id { return n } }
        return nil
    }
    mutating func draw(_ stream: Int32,_ range: Int32,observe: (OriginalObjectInputEvent) throws -> Void) throws -> Int32 {
        var rng = OriginalRandom(table: try (0..<3000).map { try globals.integer(at: 0x44ff90-0x44d000+$0,as: UInt8.self) },
            index: Int(try globals.integer(at: 0x450bcc-0x44d000,as: Int32.self)),counter: Int(try globals.integer(at: 0x450c34-0x44d000,as: Int32.self)),
            source: "owned object input",sourceSHA256: "")
        try rng.validate(); let result = Int32(rng.next(Int(range)))
        try globals.write(Int32(rng.index),at: 0x450bcc-0x44d000); try globals.write(Int32(rng.counter),at: 0x450c34-0x44d000)
        try observe(.random(stream: stream,range: range,result: result)); return result
    }

    /// The inline constructor-and-copy prefix shared by the spawning cases:
    /// 4061d0, Object, +0x31c from the header, then the parent's owner, position,
    /// team and binary64 position. Returns the new Actor index.
    mutating func spawn(_ free: Int,_ n: Int,from s: Int,observe: (OriginalObjectInputEvent) throws -> Void) throws -> Int {
        let a = try index(free)
        try actors[a].reconstructActor(); try observe(.reconstruct(slot: free))
        try actors[a].write(UInt32(n),at: 0x368)
        try actors[a].writeBinary64(580,at: 0x58); try actors[a].writeBinary64(-200,at: 0x60); try actors[a].writeBinary64(300,at: 0x68)
        try put(a,0x31c,objects[n].header.integer(at: 0x90,as: Int32.self))
        for o in [0x354,0x10,0x14,0x18,0x364] { try put(a,o,i(s,o)) }
        for o in [0x58,0x60,0x68] { try copy(s,a,o) }
        try put(a,0x70,0)
        return a
    }

    mutating func run(_ slot: Int,observe: (OriginalObjectInputEvent) throws -> Void) throws {
        let hit = try frame(index(slot),0x30)
        guard OriginalObjectInput.recoveredHitFa.contains(hit) else {
            throw OriginalLoaderError.outsideVerifiedDomain("Object input hit_Fa \(hit) is not recovered")
        }
        switch hit {
        case 8: try burst(slot,observe: observe)
        case 5: try escort(slot,observe: observe)
        case 10: try drift(slot)
        default:
            if hit == 7 { try trail(slot,observe: observe) }
            guard try target(slot,hit) else { return }
            try steer(slot,hit)
        }
    }

    /// hit_Fa 8 (407232..40768e): split into3+ clay birds aimed at random enemies.
    mutating func burst(_ slot: Int,observe: (OriginalObjectInputEvent) throws -> Void) throws {
        let s = try index(slot)
        var enemies: [Int32] = []
        for k in 0..<400 where try active(k) != 0 {
            let t = try index(k)
            if try h(t,0x6f8) == 0 && i(t,0x364) != i(s,0x364) && i(t,0x2fc) > 0 { enemies.append(Int32(k)) }
        }
        let n = Int32(enemies.count), count = n <= 4 ? 3 : (n-3)/2+3
        for _ in 0..<count {
            guard let free = try free(), let bird = try find(0xe1) else { continue }
            let s = try index(slot), a = try spawn(free,bird,from: s,observe: observe)
            try store(a,0x40,c(Double(draw(3,0x15,observe: observe) &- 11)))
            try store(a,0x48,c(3)-c(Double(draw(5,0x18,observe: observe)))*c(0.25))
            try store(a,0x50,c(3)-c(Double(draw(6,0x18,observe: observe)))*c(0.25))
            try actors[a].write(actors[s].integer(at: 0x80,as: UInt8.self),at: 0x80)
            try put(a,0x3f8,n == 0 ? Int32(slot) : enemies[Int(draw(7,n,observe: observe))])
            try activate(free,1)
        }
        try activate(slot,0)
    }

    /// hit_Fa 5 (407ad5..407d3b): one Object219 per living allied character.
    mutating func escort(_ slot: Int,observe: (OriginalObjectInputEvent) throws -> Void) throws {
        for k in 0..<400 {
            guard try active(k) == 1 else { continue }
            let t = try index(k), s = try index(slot)
            guard try h(t,0x6f8) == 0, try i(t,0x364) == i(s,0x364), try i(t,0x2fc) > 0,
                  let free = try free(), let n = try find(0xdb) else { continue }
            let a = try spawn(free,n,from: s,observe: observe)
            try store(a,0x40,c(Double((i(index(k),0x10) &- i(a,0x10))/50)))
            try actors[a].writeBinary64(0,at: 0x48); try actors[a].writeBinary64(0,at: 0x50)
            try actors[a].write(UInt8(0),at: 0x80); try put(a,0x3f8,Int32(k))
            try activate(free,1)
        }
        try activate(slot,0)
    }

    /// hit_Fa 10 (407f22..407fcc): accelerate along x, clamp, face the motion.
    mutating func drift(_ slot: Int) throws {
        let s = try index(slot), zero = try c(0)
        try store(s,0x40,zero <= v(s,0x40) ? v(s,0x40)+c(1.1) : v(s,0x40)-c(1.1))
        try clamp(s,0x40,30,-30)
        if try c(3) < v(s,0x60) { try actors[s].writeBinary64(3,at: 0x60) }
        try face(s)
    }

    /// hit_Fa 7 prefix (407d59..407f14): a copy of the same Object id at frame40.
    mutating func trail(_ slot: Int,observe: (OriginalObjectInputEvent) throws -> Void) throws {
        guard let free = try free() else { return }
        let s = try index(slot)
        guard let n = try find(h(s,0x6f4)) else { return }
        let a = try spawn(free,n,from: s,observe: observe)
        try put(a,0x70,40)
        for o in [0x40,0x48,0x50] { try actors[a].writeBinary64(0,at: o) }
        try actors[a].write(UInt8(0),at: 0x80)
        try activate(free,1)
    }

    /// 40704d..407226: keep a valid target or choose the nearest living enemy
    /// character outside the owner's team. No target clears the Object's HP.
    mutating func target(_ slot: Int,_ hit: Int32) throws -> Bool {
        let s = try index(slot), owner = try i(s,0x2f8)
        var ownerTeam: Int32 = -1
        if owner >= 0, try active(Int(owner)) == 1 { ownerTeam = try i(index(Int(owner)),0x364) }
        if [4,5,6,7].contains(hit) { return true }
        func lying(_ t: Int) throws -> Bool { try frame(t,8) == 14 || abs(i(t,8)) > 2 }
        let current = try i(s,0x3f8)
        if current != -1, try active(Int(current)) != 0 {
            let t = try index(Int(current))
            if try i(t,0x2fc) > 0, try !lying(t), try i(t,0x364) != i(s,0x364), ownerTeam != (try i(t,0x364)) { return true }
        }
        var best: Int32 = 10000
        for k in 0..<400 where k != slot {
            guard try active(k) != 0 else { continue }
            let t = try index(k), s = try index(slot)
            guard try h(t,0x6f8) == 0 else { continue }
            let team = try i(t,0x364)
            guard try team != i(s,0x364), ownerTeam != team else { continue }
            if try lying(t), try i(s,0x3f8) != -1 { continue }
            guard try i(t,0x2fc) > 0 else { continue }
            let d = try abs(i(t,0x18) &- i(s,0x18)) &+ abs(i(t,0x10) &- i(s,0x10))
            if d < best { try put(s,0x3f8,Int32(k)); best = d }
        }
        let s2 = try index(slot)
        if try i(s2,0x3f8) == -1 { try put(s2,0x2fc,0); return false }
        return true
    }

    mutating func clamp(_ a: Int,_ o: Int,_ high: Double,_ low: Double) throws {
        if try c(high) < v(a,o) { try actors[a].writeBinary64(high,at: o) }
        if try c(low) > v(a,o) { try actors[a].writeBinary64(low,at: o) }
    }
    mutating func face(_ a: Int) throws { try actors[a].write(UInt8(try c(0) < v(a,0x40) ? 0 : 1),at: 0x80) }
    /// Signed x/z approach step; the second comparison sees the unchanged ints.
    mutating func approach(_ s: Int,_ t: Int,_ field: Int,_ velocity: Int,_ margin: Int32,_ step: Double) throws {
        if try i(t,field) > i(s,field) &+ margin { try store(s,velocity,v(s,velocity)+c(step)) }
        if try i(t,field) < i(s,field) &- margin { try store(s,velocity,v(s,velocity)-c(step)) }
    }
    /// Height tracking of a character target: two passes against target y.
    mutating func height(_ s: Int,_ t: Int,offset: Double,step: Double) throws {
        if try v(s,0x60)+c(offset) < v(t,0x60) { try store(s,0x60,v(s,0x60)+c(step)) }
        if try v(s,0x60)+c(offset) > v(t,0x60) { try store(s,0x60,v(s,0x60)-c(step)) }
    }

    /// 407fcf..408910 for the recovered values 1, 3, 4, 7, 12 and 14.
    mutating func steer(_ slot: Int,_ hit: Int32) throws {
        let s = try index(slot)
        // Read only where the EXE reads it: 4/7 skip the search and may hold -1.
        func resolve() throws -> Int {
            let target = try i(s,0x3f8)
            guard target != -1 else { throw OriginalLoaderError.outsideVerifiedDomain("Object input target -1 reads World+0x190 as an Actor") }
            return try index(Int(target))
        }
        if hit == 1 {
            let t = try resolve()
            try approach(s,t,0x10,0x40,0,0.85)
            try approach(s,t,0x18,0x50,7,0.3)
            try store(s,0x48,v(s,0x48)/c(1.4))
            if try h(t,0x6f8) == 0 { try height(s,t,offset: 10,step: 1.2) }
            else if try v(s,0x60) > c(0) { try store(s,0x60,v(s,0x60)+c(1)) }
            try clamp(s,0x40,13,-13); try clamp(s,0x50,2,-2)
            if try c(1) < v(s,0x60) { try actors[s].writeBinary64(1,at: 0x60) }
            try face(s); return
        }
        if hit == 4, case let t = try resolve(), try i(t,0x2fc) > 0 {
            let x = try i(s,0x10), y = try i(s,0x14), z = try i(s,0x18)
            if try x > i(t,0x10) &+ -30 && x < i(t,0x10) &+ 30 && y > i(t,0x14) &+ -80 && y < i(t,0x14)
                && z > i(t,0x18) &+ -10 && z < i(t,0x18) &+ 10 {
                for o in [0x40,0x48,0x50] { try actors[s].writeBinary64(0,at: o) }
                try put(s,0x70,60); try put(t,0xe4,100); return
            }
        }
        if hit != 3, try i(s,0x2fc) > 0, try active(slot) == 1 {
            let t = try resolve()
            try approach(s,t,0x10,0x40,0,0.7)
            if hit == 7 { try approach(s,t,0x10,0x40,0,0.7) }
            try approach(s,t,0x18,0x50,5,0.4)
            if hit == 7 { try rise(s,cap: false) }
            else if hit != 14 {
                try store(s,0x48,v(s,0x48)/c(1.4))
                if try h(t,0x6f8) == 0 { try height(s,t,offset: 40,step: 1) }
                else if try v(s,0x60) > c(0) { try store(s,0x60,v(s,0x60)+c(1)) }
            }
            try clamp(s,0x40,14,-14)
            if try c(1.4) < v(s,0x60) { try actors[s].writeBinary64(1.4,at: 0x60) }
            if hit == 14 { try clamp(s,0x50,1.5,-1.5) } else { try clamp(s,0x50,2.2,-2.2) }
            try face(s)
            if hit == 14 { try flap(s) }
            return
        }
        if hit == 3 {
            let t = try resolve()
            try approach(s,t,0x10,0x40,0,0.7)
            try approach(s,t,0x18,0x50,10,0.17)
            try clamp(s,0x40,16,-16); try clamp(s,0x50,2.4,-2.4)
            return
        }
        // Not alive or not normally active: accelerate along the current motion.
        guard try i(s,0x2fc) <= 0 || active(slot) == 0 else { return }
        try store(s,0x40,try c(0) <= v(s,0x40) ? v(s,0x40)+c(2) : v(s,0x40)-c(2))
        try clamp(s,0x40,17,-17)
        if hit == 7 { try rise(s,cap: true) }
        else if try c(1.4) < v(s,0x60) { try actors[s].writeBinary64(1.4,at: 0x60) }
        try face(s)
    }

    /// hit_Fa 7 vertical motion: +0.4 while vy < 4, integrate y, and stop at
    /// frame60 once the stale integer y is below -25. The unguarded branch
    /// (40877f path) also pins the integer y to -25.
    mutating func rise(_ s: Int,cap: Bool) throws {
        if try c(4) > v(s,0x48) { try store(s,0x48,v(s,0x48)+c(0.4)) }
        try store(s,0x60,v(s,0x48)+v(s,0x60))
        guard try i(s,0x14) > -25 else { return }
        try put(s,0x70,60)
        if cap { try put(s,0x14,-25) }
        for o in [0x50,0x40,0x48] { try actors[s].writeBinary64(0,at: o) }
    }

    /// hit_Fa 14 wing frames: +50 below |vx| 8 from frames under10, else -50 above40.
    mutating func flap(_ s: Int) throws {
        var speed = try v(s,0x40); if speed < (try c(0)) { speed = -speed }
        let frame = try i(s,0x70)
        if speed < (try c(8)) { if frame < 10 { try put(s,0x70,frame &+ 50) } }
        else if frame > 40 { try put(s,0x70,frame &- 50) }
    }
}
