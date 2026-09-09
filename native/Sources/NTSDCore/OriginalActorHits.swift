public enum OriginalHitEvent: Equatable {
    case random(stream: Int32,range: Int32,result: Int32)
    case builtinSound(x: Int32,index: Int32),catalogSound(x: Int32,index: Int32)
    case crtRandom(before: UInt32,after: UInt32,result: UInt32)
    case reconstruct(slot: Int)
}

/// Hit resolution from42e100. The caller owns the game pool, mutable DAT heap
/// and the same-thread CRT state. Publishing these together makes failure atomic.
public enum OriginalActorHits {
    public static func apply(slot: Int,state: inout OriginalMatchPreparation,crt: inout OriginalCRTRandom,
                             sse2: Bool = false,observe: (OriginalHitEvent) throws -> Void = { _ in }) throws {
        var pass = try makePass(state: state,crt: crt,sse2: sse2)
        try pass.resolve(slot,observe: observe)
        publish(pass,state: &state,crt: &crt)
    }
    static func makePass(state: OriginalMatchPreparation,crt: OriginalCRTRandom,sse2: Bool) throws -> OriginalHitPass {
        let catalog = state.catalog
        guard try state.world.integer(at: 0x7d4,as: UInt32.self) == 0,
              let registry = catalog.registry.records[0x4d82380] else { throw OriginalStateError.invalidStorage("Hit catalog binding") }
        return OriginalHitPass(world: state.world,actors: state.actors,globals: state.globals,
            memory: OriginalContactFrameMemory(state.frameAllocations),crt: crt,
            objectCount: try registry.integer(at: 0,as: Int32.self),header: { n in
                guard catalog.objects.indices.contains(n) else { throw OriginalStateError.invalidStorage("Hit Object binding") }
                return catalog.objects[n].header
            },frame: { n,f in
                guard catalog.objects.indices.contains(n),catalog.objects[n].frameStorage.indices.contains(Int(f)) else { throw OriginalStateError.invalidStorage("Hit Frame binding") }
                return catalog.objects[n].frameStorage[Int(f)]
            },sse2: sse2)
    }
    static func publish(_ pass: OriginalHitPass,state: inout OriginalMatchPreparation,crt: inout OriginalCRTRandom) {
        state.world = pass.world;state.actors = pass.actors;state.globals = pass.globals
        state.frameAllocations = pass.memory.allocations;crt = pass.crt
    }
}

struct OriginalHitPass {
    var world: OriginalStateRecord
    var actors: [OriginalStateRecord]
    var globals: OriginalStateRecord
    var memory: OriginalContactFrameMemory
    var crt: OriginalCRTRandom
    let objectCount: Int32
    let header: (Int) throws -> OriginalStateRecord
    let frame: (Int,Int32) throws -> OriginalStateRecord
    let sse2: Bool
    var itrWords: [Int32] = []
    var itrPointer: UInt32?

    func index(_ slot: Int) throws -> Int {
        guard (0..<400).contains(slot) else { throw OriginalStateError.invalidStorage("Hit slot extent") }
        let a = Int(try world.integer(at: 0x194+slot*4,as: UInt32.self))
        guard actors.indices.contains(a) else { throw OriginalStateError.invalidStorage("Hit Actor binding") };return a
    }
    func i(_ a: Int,_ o: Int) throws -> Int32 { try actors[a].integer(at: o,as: Int32.self) }
    func b(_ a: Int,_ o: Int) throws -> UInt8 { try actors[a].integer(at: o,as: UInt8.self) }
    func v(_ a: Int,_ o: Int) throws -> OriginalExtended { try OriginalExtended(actors[a].binary64(at: o)) }
    func object(_ a: Int) throws -> Int { Int(try actors[a].integer(at: 0x368,as: UInt32.self)) }
    func h(_ a: Int,_ o: Int) throws -> Int32 { try header(object(a)).integer(at: o,as: Int32.self) }
    func f(_ a: Int,_ o: Int,_ at: Int = 0x70) throws -> Int32 { try frame(object(a),i(a,at)).integer(at: o,as: Int32.self) }
    func field(_ f: OriginalStateRecord,_ o: Int) throws -> Int32 { try f.integer(at: o,as: Int32.self) }
    func it(_ o: Int) throws -> Int32 {
        if let pointer = itrPointer { return try memory.word(pointer &+ UInt32(truncatingIfNeeded: o)) }
        return itrWords[o/4]
    }
    mutating func interaction(_ o: Int,_ value: Int32) throws {
        if let pointer = itrPointer { try memory.write(value,at: pointer &+ UInt32(truncatingIfNeeded: o)) }
        else { itrWords[o/4] = value }
    }
    mutating func put(_ a: Int,_ o: Int,_ value: Int32) throws { try actors[a].write(value,at: o) }
    mutating func byte(_ a: Int,_ o: Int,_ value: UInt8) throws { try actors[a].write(value,at: o) }
    mutating func store(_ a: Int,_ o: Int,_ value: OriginalExtended) throws { try actors[a].writeBinary64(value.double,at: o) }
    mutating func number(_ a: Int,_ o: Int,_ value: Double) throws { try actors[a].writeBinary64(value,at: o) }
    mutating func add(_ a: Int,_ o: Int,_ value: Int32) throws { try put(a,o,i(a,o) &+ value) }
    func constant(_ value: Double) throws -> OriginalExtended { try OriginalExtended(value) }
    func find(_ id: Int32) throws -> Int? {
        if objectCount > 0 { for n in 0..<Int(objectCount) where try header(n).integer(at: 0x6f4,as: Int32.self) == id { return n } };return nil
    }
    mutating func draw(_ stream: Int32,_ range: Int32,observe: (OriginalHitEvent) throws -> Void) throws -> Int32 {
        guard range != 0 else { throw OriginalStateError.invalidStorage("Original hit RNG division by zero") }
        var rng = OriginalRandom(table: try (0..<3000).map { try globals.integer(at: 0x44ff90-0x44d000+$0,as: UInt8.self) },
            index: Int(try globals.integer(at: 0x450bcc-0x44d000,as: Int32.self)),counter: Int(try globals.integer(at: 0x450c34-0x44d000,as: Int32.self)),source: "owned hits",sourceSHA256: "")
        try rng.validate();let result = Int32(rng.next(Int(range)))
        try globals.write(Int32(rng.index),at: 0x450bcc-0x44d000);try globals.write(Int32(rng.counter),at: 0x450c34-0x44d000)
        try observe(.random(stream: stream,range: range,result: result));return result
    }
    mutating func sound(_ a: Int,_ n: Int32,catalog: Bool = false,observe: (OriginalHitEvent) throws -> Void) throws {
        let x = try i(a,0x10)
        if catalog { try observe(.catalogSound(x: x,index: n));try OriginalGameplaySound.queueCatalog(x: x,index: n,globals: &globals) }
        else { try observe(.builtinSound(x: x,index: n));try OriginalGameplaySound.queueBuiltin(x: x,index: n,globals: &globals) }
    }
    mutating func crtDraw(observe: (OriginalHitEvent) throws -> Void) throws -> Int32 {
        let before = crt.state,result = crt.next();try observe(.crtRandom(before: before,after: crt.state,result: result));return Int32(result)
    }

    // Frozen collision Frame at entry; a contact can rebind the live Object/frame.
    // The loop count and buffer contents are read again after every contact.
    mutating func resolve(_ attacker: Int,observe: (OriginalHitEvent) throws -> Void = { _ in }) throws {
        let a = try index(attacker),attackObject = try object(a),attackNumber = try i(a,0x7c)
        //The source computes the pointer before this gate but does not read it.
        if try i(a,0x2e4) <= 0 { return }
        let attackFrame = try frame(attackObject,attackNumber)
        var contact: Int32 = 0
        while try contact < i(a,0x2e4) {
            let n = Int32(try actors[a].integer(at: Int(Int32(0x2d0) &+ contact),as: Int8.self))
            if try n > field(attackFrame,0x128) &- 1 { return }
            let defender = Int(try i(a,Int(Int32(0x280) &+ contact &* 4))),d = try index(defender)
            let bodyObject = try object(d),bodyNumber = try i(d,0x7c)
            defer { contact &+= 1 }
            if try actors[d].integer(at: 0xf0+attacker,as: Int8.self) > 0 { continue }
            if try b(a,0xeb) != 0 && h(d,0x6f8) == 0 { return }
            let bodyFrame = try frame(bodyObject,bodyNumber)
            if try f(d,0x88,0x7c) == 2 {
                let owner = try index(Int(i(d,0x90)))
                if try i(owner,0x8c) == defender && f(owner,0xb4,0x7c) == 0 { continue }
            }
            itrPointer = try attackFrame.integer(at: 0x130,as: UInt32.self) &+ UInt32(bitPattern: n &* 80)
            if try it(0) == 0 && it(0x2c) == 21 && [18,19].contains(f(d,8)) { return }
            var copy = true
            if try it(0) == 5 && i(a,0x98) < 0 {
                let ownerSlot = Int(try i(a,0xa0)),owner = try index(ownerSlot)
                if try i(owner,0x9c) == attacker {
                    let strength = try f(owner,0xe8,0x7c)
                    copy = false
                    if strength > 0 && ownerSlot != defender {
                        itrWords = try (0..<5).map { try it($0*4) }
                        for word in 5..<20 { itrWords.append(try h(a,Int(Int32(0xb0) &+ strength &* 80 &+ Int32(word*4)))) }
                        itrWords[0] = 0;itrPointer = nil
                    }
                }
            }
            if copy { itrWords = try (0..<20).map { try it($0*4) };itrPointer = nil }
            if try i(a,0x320) > 0 && it(0) == 4 {
                try interaction(0,0)
                if try (v(a,0x40) > constant(0) && b(a,0x80) == 1) || (v(a,0x40) < constant(0) && b(a,0x80) == 0) { try interaction(0x14,0 &- it(0x14)) }
            }
            if try it(0) == 0 { try dropHeavy(attacker,defender,stream: 236,observe: observe) }
            if try h(d,0x6f8) == 2 { try interaction(0x14,it(0x14)/2);try interaction(0x18,it(0x18)/2) }
            if try it(0) == 9 && (h(d,0x6f8) == 0 || [1002,2000].contains(f(d,8))) {
                try interaction(0,0);if try h(d,0x6f8) == 0 { try put(a,0x2fc,0) }
            }
            var spark: Int32 = 0
            if try it(0) == 0 {
                if try guarded(a,d,bodyFrame) { try guardHit(attacker,defender,bodyFrame,observe: observe) }
                else if try damageHit(attacker,defender,bodyFrame,spark: &spark,observe: observe) { return }
            } else { try specialHit(attacker,defender,observe: observe) }
            if try it(0) == 0 { try hitSpark(attacker,defender,style: spark,observe: observe) }
        }
    }

    mutating func dropHeavy(_ attacker: Int,_ defender: Int,stream: Int32,observe: (OriginalHitEvent) throws -> Void) throws {
        let a = try index(attacker),d = try index(defender)
        if try i(d,0x98) == 2 {
            let weapon = try index(Int(i(d,0x9c)))
            if try i(weapon,0xa0) == defender && i(weapon,0x98) == -2 {
                try byte(a,0xf0+Int(i(d,0x9c)),45);try put(d,0x98,0)
                try byte(d,0xf0+Int(i(d,0x9c)),30);try put(index(Int(i(d,0x9c))),0x98,0)
                let next = try draw(stream,6,observe: observe)
                try put(index(Int(i(d,0x9c))),0x70,next);try number(index(Int(i(d,0x9c))),0x48,-1)
            }
        }
    }
    func guarded(_ a: Int,_ d: Int,_ body: OriginalStateRecord) throws -> Bool {
        let defense = try it(0x40)
        if try defense != 100 && ![8,11,12,13,14,16,18].contains(field(body,8)) {
            let id = try h(d,0x6f4),effect = try it(0x2c),attackID = try h(a,0x6f4)
            let penetrates = [2,3].contains(effect/10) || [2,3].contains(effect) || [214,208].contains(attackID)
            if try id == 37 && i(d,0xb8) <= 15 && !penetrates { return true }
            if try id == 6 && i(d,0xb8) <= 1 && !penetrates && (i(d,0x70) < 20 || [5,4,7].contains(f(d,8))) { return true }
            if try id == 52 && i(d,0xb8) <= 15 && ![214,208].contains(attackID) { return true }
        }
        return try field(body,8) == 7 && defense <= 60 && i(d,0x2fc) > 0 && (b(a,0x80) != b(d,0x80) || it(0x14) < 0 || [124,220,221,222].contains(h(a,0x6f4)))
    }
    // Shared damage/statistic writes. Guard divides the scaled injury by10.
    mutating func damage(_ a: Int,_ d: Int,guarded: Bool = false) throws {
        let type = try h(d,0x6f8)
        if type == 6 { return }
        var injury = try it(0x44)
        let divisor = try i(d,0x340)
        if divisor > 0 { injury = (injury &* 100)/divisor }
        if guarded { injury /= 10 }
        if try i(d,0x2fc) > 0 && injury >= i(d,0x2fc) && type == 0 && i(d,0x2f4) == -1 {
            try add(index(Int(i(a,0x354))),0x358,1)
            let team = try i(d,0x344)
            if (1...2).contains(team) { let o = 0x451b60-0x44d000+Int(team)*4;try globals.write(globals.integer(at: o,as: Int32.self) &+ 1,at: o) }
        }
        try add(d,0x2fc,0 &- injury);try add(d,0x300,0 &- (injury/3));try add(d,0x34c,injury)
        if try h(d,0x6f8) == 0 && i(d,0x2f4) == -1 { try add(index(Int(i(a,0x354))),0x348,injury) }
        let team = try i(d,0x344)
        if (1...2).contains(team) { let o = 0x451b68-0x44d000+Int(team)*4;try globals.write(globals.integer(at: o,as: Int32.self) &+ injury,at: o) }
    }
    mutating func durability(_ d: Int) throws {
        if try [1,2,4,6].contains(h(d,0x6f8)) { try add(d,0x31c,0 &- it(0x44));if try it(0x40) == 100 { try put(d,0x31c,-1) } }
    }

    //43187a: CRT draws belong to the retained thread, independent of417170.
    mutating func hitSpark(_ attacker: Int,_ defender: Int,style: Int32,observe: (OriginalHitEvent) throws -> Void) throws {
        let a = try index(attacker),d = try index(defender)
        let az = try i(a,0x18),dz = try i(d,0x18),slot: Int
        if try az < dz || world.integer(at: 4+attacker,as: UInt8.self) == 0 { slot = defender }
        else if az > dz { slot = attacker } else { slot = max(attacker,defender) }
        let owner = try index(slot)
        if try i(owner,0x36c) >= 10 { return }
        try add(owner,0x36c,1);let n = try i(owner,0x36c) &- 1
        try put(owner,Int(Int32(0x3c0) &+ n &* 4),style &* 20 &+ (it(0x1c) > 60 ? 0 : 10))
        let centerX = try f(a,0x50),centerY = try f(a,0x54)
        let x = try b(a,0x80) == 0 ? min(i(a,0x10) &- centerX &+ it(0xc) &+ it(4),i(d,0x10)) : max(centerX &- it(0xc) &- it(4) &+ i(a,0x10),i(d,0x10))
        try put(owner,Int(Int32(0x370) &+ n &* 4),x)
        var y = try it(0x10)/2 &+ i(a,0x14) &+ it(8) &- centerY
        let low = try i(d,0x14) &- centerY
        if y < low { y = (y &+ low)/2 } else if try y > i(d,0x14) { y = try (y &+ i(d,0x14))/2 }
        let ry = try crtDraw(observe: observe)%9
        try put(owner,Int(Int32(0x398) &+ n &* 4),ry &+ i(a,0x18) &+ y &- 4)
        let rx = try crtDraw(observe: observe)%9
        try add(owner,Int(Int32(0x370) &+ n &* 4),rx &- 4)
    }
}
