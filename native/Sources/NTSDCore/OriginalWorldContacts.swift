public enum OriginalWorldContactsEvent: Equatable {
    case random(attacker: Int,defender: Int,stream: Int32,range: Int32,result: Int32)
    case reconstruct(slot: Int,created: Int)
}

/// Caller41eed8..41eefb and whole419380, including the mandatory4064d0 tail.
/// This collects ordered candidate contacts. The later hit-resolution passes
/// consume the original Actor buffers; this function does not apply damage.
public enum OriginalWorldContacts {
    public static func apply(state: inout OriginalMatchPreparation,
                             observe: (OriginalWorldContactsEvent) throws -> Void = { _ in }) throws {
        let catalog = state.catalog
        guard try state.world.integer(at: 0x7d4,as: UInt32.self) == 0,
              let registry = catalog.registry.records[0x4d82380] else { throw OriginalStateError.invalidStorage("Contact catalog binding") }
        let memory = OriginalContactFrameMemory(catalog.frameAllocations)
        try apply(world: &state.world,actors: &state.actors,globals: &state.globals,
            objectCount: try registry.integer(at: 0,as: Int32.self),header: { n in
                guard catalog.objects.indices.contains(n) else { throw OriginalStateError.invalidStorage("Contact Object binding") }
                return catalog.objects[n].header
            },frame: { n,f in
                guard catalog.objects.indices.contains(n),catalog.objects[n].frameStorage.indices.contains(Int(f)) else { throw OriginalStateError.invalidStorage("Contact Frame binding") }
                return catalog.objects[n].frameStorage[Int(f)]
            },heapWord: { try memory.word($0) },observe: observe)
    }
    static func apply(world: inout OriginalStateRecord,actors: inout [OriginalStateRecord],globals: inout OriginalStateRecord,
                      objectCount: Int32,header: @escaping (Int) throws -> OriginalStateRecord,
                      frame: @escaping (Int,Int32) throws -> OriginalStateRecord,heapWord: @escaping (UInt32) throws -> Int32,
                      observe: (OriginalWorldContactsEvent) throws -> Void = { _ in }) throws {
        var pass = OriginalContactPass(world: world,actors: actors,globals: globals,objectCount: objectCount,header: header,frame: frame,heapWord: heapWord)
        try pass.advance(observe: observe)
        world = pass.world;actors = pass.actors;globals = pass.globals
    }
}

/// Resolves original32-bit data references into native, mask-checked allocations.
/// No pointer normalization, kind-based filtering or host-pointer dereference.
struct OriginalContactFrameMemory {
    private let allocations: [OriginalFrameAllocation]
    init(_ allocations: [OriginalFrameAllocation]) { self.allocations = allocations.sorted { $0.address < $1.address } }
    func word(_ address: UInt32) throws -> Int32 {
        var low = 0,high = allocations.count
        while low < high { let mid = (low+high)/2;if allocations[mid].address <= address { low = mid+1 } else { high = mid } }
        guard low > 0 else { throw OriginalStateError.invalidStorage("Unknown contact box reference") }
        let allocation = allocations[low-1]
        return try allocation.storage.integer(at: Int(address-allocation.address),as: Int32.self)
    }
}

struct OriginalContactPass {
    var world: OriginalStateRecord
    var actors: [OriginalStateRecord]
    var globals: OriginalStateRecord
    let objectCount: Int32
    let header: (Int) throws -> OriginalStateRecord
    let frame: (Int,Int32) throws -> OriginalStateRecord
    let heapWord: (UInt32) throws -> Int32

    mutating func advance(observe: (OriginalWorldContactsEvent) throws -> Void = { _ in }) throws {
        if try globals.integer(at: 0x44d05c-0x44d000,as: Int32.self) == 2 { try globals.write(Int32(0),at: 0x44d05c-0x44d000) }
        else { try collect(mode: globals.integer(at: 0x451160-0x44d000,as: Int32.self),observe: observe) }
    }

    func active(_ slot: Int) throws -> UInt8 {
        guard (0..<400).contains(slot) else { throw OriginalStateError.invalidStorage("Contact activity extent") }
        return try world.integer(at: 4+slot,as: UInt8.self)
    }
    func index(_ slot: Int) throws -> Int {
        guard (0..<400).contains(slot) else { throw OriginalStateError.invalidStorage("Contact slot extent") }
        let a = Int(try world.integer(at: 0x194+slot*4,as: UInt32.self))
        guard actors.indices.contains(a) else { throw OriginalStateError.invalidStorage("Contact Actor binding") };return a
    }
    func i(_ a: Int,_ offset: Int) throws -> Int32 { try actors[a].integer(at: offset,as: Int32.self) }
    func b(_ a: Int,_ offset: Int) throws -> UInt8 { try actors[a].integer(at: offset,as: UInt8.self) }
    func object(_ a: Int) throws -> Int { Int(try actors[a].integer(at: 0x368,as: UInt32.self)) }
    func h(_ a: Int,_ offset: Int) throws -> Int32 { try header(object(a)).integer(at: offset,as: Int32.self) }
    func f(_ a: Int,_ offset: Int,_ frameOffset: Int = 0x70) throws -> Int32 { try frame(object(a),i(a,frameOffset)).integer(at: offset,as: Int32.self) }
    mutating func put(_ a: Int,_ offset: Int,_ value: Int32) throws { try actors[a].write(value,at: offset) }
    mutating func store(_ a: Int,_ offset: Int,_ value: Double) throws { try actors[a].writeBinary64(value,at: offset) }
    static func magnitude(_ value: Int32) -> Int32 { value < 0 ? 0 &- value : value }
    mutating func draw(_ attacker: Int,_ defender: Int,_ stream: Int32,
                       observe: (OriginalWorldContactsEvent) throws -> Void) throws -> Int32 {
        var random = OriginalRandom(table: try (0..<3000).map { try globals.integer(at: 0x44ff90-0x44d000+$0,as: UInt8.self) },
            index: Int(try globals.integer(at: 0x450bcc-0x44d000,as: Int32.self)),counter: Int(try globals.integer(at: 0x450c34-0x44d000,as: Int32.self)),source: "owned contacts",sourceSHA256: "")
        try random.validate();let result = Int32(random.next(2))
        try globals.write(Int32(random.index),at: 0x450bcc-0x44d000);try globals.write(Int32(random.counter),at: 0x450c34-0x44d000)
        try observe(.random(attacker: attacker,defender: defender,stream: stream,range: 2,result: result));return result
    }
    //4171c0: signed wrapped differences and STRICT inequalities. A conventional
    // rectangle intersection/absolute-distance rewrite changes overflow cases.
    static func overlaps(_ a: [Int32],_ b: [Int32]) -> Bool {
        b[0] &- a[0] < a[2] && a[0] &- b[0] < b[2] && b[1] &- a[1] < a[3] && a[1] &- b[1] < b[3]
    }
    func positioned(_ a: Int,_ box: [Int32]) throws -> [Int32] {
        let x = try b(a,0x80) == 0 ? i(a,0x10) &- f(a,0x50,0x7c) &+ box[0] : f(a,0x50,0x7c) &+ i(a,0x10) &- box[2] &- box[0]
        return try [x,i(a,0x14) &- f(a,0x54,0x7c) &+ box[1],box[2],box[3]]
    }
    //417200: count gates use current frames, bounds and centers collision frames.
    func broadphase(_ attacker: Int,_ defender: Int) throws -> Bool {
        let a = try index(attacker),d = try index(defender)
        guard try f(a,0x128) != 0,try f(d,0x12c) != 0,try i(a,0xec) <= 0,
              try actors[d].integer(at: 0xf0+attacker,as: Int8.self) <= 0 else { return false }
        let attack = try positioned(a,(0..<4).map { try f(a,0x138+$0*4,0x7c) })
        let body = try positioned(d,(0..<4).map { try f(d,0x148+$0*4,0x7c) })
        return Self.overlaps(body,attack)
    }
    //417400: retain the two entry Frame references, but reload live Actor fields
    // after every write/RNG. In particular distinct World slots can alias.
    mutating func pair(_ attacker: Int,_ defender: Int,mode: Int32,
                       observe: (OriginalWorldContactsEvent) throws -> Void = { _ in }) throws {
        let a = try index(attacker),d = try index(defender)
        let attackFrame = try frame(object(a),i(a,0x7c)),bodyFrame = try frame(object(d),i(d,0x7c))
        let count = try attackFrame.integer(at: 0x128,as: Int32.self)
        guard count > 0 else { return }
        interaction: for itr in 0..<Int(count) {
            let pointer = try attackFrame.integer(at: 0x130,as: UInt32.self) &+ UInt32(truncatingIfNeeded: itr*80)
            let words = heapWord
            func it(_ offset: UInt32) throws -> Int32 { try words(pointer &+ offset) }
            let bodyCount = try bodyFrame.integer(at: 0x12c,as: Int32.self)
            guard bodyCount > 0 else { continue }
            for bodyIndex in 0..<Int(bodyCount) {
                let attackID = try h(a,0x6f4)
                if try [200,203,205,206,207,215,216].contains(attackID) && h(d,0x6f4) == 209 && it(0) != 9 { continue interaction }
                let kind = try it(0)
                if try kind == 3 && h(d,0x6f8) != 0 { continue interaction }
                if kind == 0 {
                    let effect = try it(0x2c)
                    if try effect == 4 && h(d,0x6f8) == 0 { continue interaction }
                    if try effect == 20 && (h(d,0x6f8) != 0 || [18,19].contains(f(d,8,0x78))) { continue interaction }
                    if try effect == 21 && [18,19].contains(f(d,8,0x78)) { continue interaction }
                    if try effect == 30 && (200...202).contains(i(d,0x70)) { continue interaction }
                    if try effect == 2 && f(a,8,0x78) == 19 && f(d,8,0x78) == 18 { continue interaction }
                }
                if try kind == 8 && h(d,0x6f8) != 0 { continue interaction }
                if try i(d,8) != 0 && kind != 8 && kind != 14 { continue interaction }
                if try kind < 4 || kind == 6 || (kind == 9 && h(d,0x6f8) == 0) || [10,11,15,16].contains(kind) {
                    let defenderState = try f(d,8)
                    if defenderState != 13 && defenderState != 10 {
                        let special = try h(d,0x6f4) == 212 && (attackID != 212 || (i(d,0x70)%10 == 5 && i(a,0x70)%10 == 0))
                        if try !special && i(a,0x364) == i(d,0x364) && i(a,0x364) != 0 && kind != 8 {
                            let fire = try f(a,8) == 18 && ![21,22].contains(it(0x2c))
                            let projectile = try h(a,0x6f8) == 0 && h(d,0x6f8) == 3 && b(a,0x80) != b(d,0x80)
                            if try !fire && !projectile && ![1,2,4,6].contains(h(d,0x6f8)) { continue interaction }
                        }
                    }
                }
                if kind == 5 {
                    let owner = try index(Int(i(a,0xa0)))
                    if try i(owner,0x364) == i(d,0x364) && i(owner,0x364) != 0 && f(d,8) != 13 && ![1,2,4,6].contains(h(d,0x6f8)) {
                        if try h(d,0x6f4) != 212 || (attackID == 212 && (i(d,0x70)%10 != 5 || i(a,0x70)%10 != 0)) { continue interaction }
                    }
                }
                let bodyPointer = try bodyFrame.integer(at: 0x134,as: UInt32.self) &+ UInt32(truncatingIfNeeded: bodyIndex*40)
                let bodyKind = try words(bodyPointer)
                let body = try positioned(d,(1...4).map { try words(bodyPointer &+ UInt32($0*4)) })
                let attack = try positioned(a,(1...4).map { try it(UInt32($0*4)) })
                let width = try it(0x48),zwidth: Int32 = width == 0 ? 15 : width,delta = try i(a,0x18) &- i(d,0x18)
                guard Self.overlaps(body,attack),delta < zwidth,delta > 0 &- zwidth else { continue }
                var status = 0
                if try f(d,8) == 12 && it(0x1c) <= 40 && kind != 10 && kind != 11 { status = 2 }
                if mode == 1 {
                    var allowed = try (h(a,0x6f8) == 0 || [201,202].contains(h(a,0x6f4))) && i(a,0x364) != 5
                    if try i(a,0x98) < 0 {
                        let slot = Int(try i(a,0xa0))
                        if try active(slot) == 1 {
                            let owner = try index(slot)
                            if try h(owner,0x6f8) == 0 && i(owner,0x364) != 5 { allowed = true }
                        }
                    }
                    if bodyKind >= 1000 && !allowed { status = 2 }
                }
                if try it(0x24) == 0 && ![1,2,7].contains(kind) && !(f(d,8,0x7c) == 1004 && (h(a,0x6f8) <= 0 || i(a,0x98) < 0)) && status == 0 {
                    var distance = try Self.magnitude(i(a,0x10) &- i(d,0x10))
                    if try i(a,0x98) < 0 {
                        let owner = Int(try i(a,0xa0))
                        distance = try owner == defender ? 2000 : Self.magnitude(i(index(owner),0x10) &- i(d,0x10))
                    }
                    let previous = try i(a,0x2e8)
                    if distance > previous { continue }
                    if try distance == previous && draw(attacker,defender,133,observe: observe) != 0 { continue }
                    try put(a,0x2e8,distance);try put(a,0x280,Int32(defender));try actors[a].write(UInt8(truncatingIfNeeded: itr),at: 0x2d0);try put(a,0x2e4,1)
                    continue
                }
                guard try i(a,0x2e4) < 20,status == 0 else { continue }
                if try f(d,8,0x7c) == 1004 && (h(a,0x6f8) <= 0 || i(a,0x98) < 0) && ![2,7,10].contains(kind) { status = 2 }
                if kind == 1 {
                    let distance = try Self.magnitude(i(a,0x10) &- i(d,0x10)),previous = try i(d,0x2ec)
                    if distance < previous { try put(d,0x2ec,distance) }
                    else if try distance == previous && draw(attacker,defender,134,observe: observe) == 0 { try put(d,0x2ec,distance) }
                    else { status = 2 }
                }
                if try kind == 4 && i(a,0x320) != 0 && status != 2 { status = 1 }
                if kind == 1 {
                    let direction = try (b(a,0xd0) != 0 && i(a,0x10) < i(d,0x10)) || (b(a,0xcf) != 0 && i(a,0x10) >= i(d,0x10))
                    if try direction && f(d,8) == 16 && status != 2 { status = 1 }
                } else if kind != 2 && kind != 7 && status != 2 { status = 1 }
                if kind == 2 {
                    if try i(a,0x98) == 0 && b(a,0xd1) != 0 && b(a,0xca) == 0 && f(d,8) == 1004 && status != 2 { status = 1 }
                    if try b(a,0xd1) != 0 && b(a,0xca) == 0 && f(d,8) == 2004 && status != 2 { status = 1 }
                }
                let pickup = try kind == 7 && b(a,0xd1) != 0 && b(a,0xca) == 0 && f(d,8) == 1004 && status != 2
                if pickup || status == 1 {
                    // Each count is read again after the preceding write. Signed
                    // negative counts can address earlier bytes within the Actor.
                    try put(a,Int(Int32(0x280) &+ (i(a,0x2e4) &* 4)),Int32(defender))
                    try actors[a].write(UInt8(truncatingIfNeeded: itr),at: Int(Int32(0x2d0) &+ i(a,0x2e4)))
                    try put(a,0x2e4,i(a,0x2e4) &+ 1)
                }
            }
        }
    }
    mutating func collect(mode: Int32,observe: (OriginalWorldContactsEvent) throws -> Void = { _ in }) throws {
        for slot in 0..<400 where try active(slot) != 0 {
            let a = try index(slot)
            try put(a,0x7c,i(a,0x70))
            if try f(a,0x128) == 0 || (f(a,8) == 1001 && f(index(Int(i(a,0xa0))),0xe8) == 0) { try put(a,0xec,0) }
        }
        for attacker in 0..<400 where try active(attacker) != 0 {
            for defender in (attacker+1)..<400 where try active(defender) != 0 {
                let a = try index(attacker),d = try index(defender)
                for (actor,slot) in [(a,defender),(d,attacker)] {
                    let rest = try actors[actor].integer(at: 0xf0+slot,as: Int8.self)
                    if rest > 0 { try actors[actor].write(rest &- 1,at: 0xf0+slot) }
                }
                if try broadphase(attacker,defender) { try pair(attacker,defender,mode: mode,observe: observe) }
                if try broadphase(defender,attacker) { try pair(defender,attacker,mode: mode,observe: observe) }
            }
        }
        try fusion(observe: observe)
    }
}
