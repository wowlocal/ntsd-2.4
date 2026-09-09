public enum OriginalWorldPhysicsEvent: Equatable {
    case sound(slot: Int,event: OriginalActorPhysicsEvent)
    case reconstruct(slot: Int,created: Int)
    case random(slot: Int,stream: Int32,range: Int32,result: Int32)
}

/// Whole41e634..41eed1. Keeps ascending slot order, including newly activated
/// later slots and aliases. The death/respawn/reversion rules are original code.
public enum OriginalWorldPhysics {
    public static func apply(state: inout OriginalMatchPreparation,
                             observe: (OriginalWorldPhysicsEvent) throws -> Void = { _ in },
                             afterActorPhysics: (Int,OriginalStateRecord) throws -> Void = { _,_ in }) throws {
        let catalog = state.catalog
        guard try state.world.integer(at: 0x7d4,as: UInt32.self) == 0,let registry = catalog.registry.records[0x4d82380] else { throw error("Catalog binding") }
        try apply(world: &state.world,actors: &state.actors,globals: &state.globals,precision: state.arithmeticPrecision,objectCount: registry.integer(at: 0,as: Int32.self),header: { index in
            guard catalog.objects.indices.contains(index) else { throw error("Object binding") };return catalog.objects[index].header
        },frame: { index,number in
            guard catalog.objects.indices.contains(index),catalog.objects[index].frameStorage.indices.contains(Int(number)) else { throw error("Frame binding") }
            return catalog.objects[index].frameStorage[Int(number)]
        },observe: observe,afterActorPhysics: afterActorPhysics)
    }
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("World physics: "+text) }
    static func apply(world: inout OriginalStateRecord,actors: inout [OriginalStateRecord],globals: inout OriginalStateRecord,
                      precision: OriginalArithmeticPrecision = .bits64,objectCount: Int32,header: (Int) throws -> OriginalStateRecord,frame: (Int,Int32) throws -> OriginalStateRecord,
                      observe: (OriginalWorldPhysicsEvent) throws -> Void = { _ in },
                      afterActorPhysics: (Int,OriginalStateRecord) throws -> Void = { _,_ in }) throws {
        var ownedWorld = world,pool = actors,owned = globals
        func active(_ slot: Int) throws -> UInt8 { try ownedWorld.integer(at: 4+slot,as: UInt8.self) }
        func index(_ slot: Int) throws -> Int {
            let i = Int(try ownedWorld.integer(at: 0x194+slot*4,as: UInt32.self))
            guard pool.indices.contains(i) else { throw error("Actor binding") };return i
        }
        func i(_ actor: Int,_ offset: Int) throws -> Int32 { try pool[actor].integer(at: offset,as: Int32.self) }
        func object(_ actor: Int) throws -> Int { Int(try pool[actor].integer(at: 0x368,as: UInt32.self)) }
        func find(_ id: Int32) throws -> Int? {
            if objectCount <= 0 { return nil }
            for n in 0..<Int(objectCount) where try header(n).integer(at: 0x6f4,as: Int32.self) == id { return n };return nil
        }
        func state(_ actor: Int) throws -> Int32 { try frame(object(actor),i(actor,0x70)).integer(at: 8,as: Int32.self) }
        func draw(_ slot: Int,_ stream: Int32,_ range: Int32) throws -> Int32 {
            var random = OriginalRandom(table: try (0..<3000).map { try owned.integer(at: 0x44ff90-0x44d000+$0,as: UInt8.self) },
                index: Int(try owned.integer(at: 0x450bcc-0x44d000,as: Int32.self)),counter: Int(try owned.integer(at: 0x450c34-0x44d000,as: Int32.self)),
                source: "owned World physics",sourceSHA256: "")
            try random.validate();let result = Int32(random.next(Int(range)))
            try owned.write(Int32(random.index),at: 0x450bcc-0x44d000);try owned.write(Int32(random.counter),at: 0x450c34-0x44d000)
            try observe(.random(slot: slot,stream: stream,range: range,result: result));return result
        }
        for slot in 0..<400 where try active(slot) != 0 {
            let a = try index(slot),o = try object(a)
            var actor = pool[a]
            try OriginalActorPhysics.apply(actor: &actor,header: header(o),globals: &owned,precision: precision,frame: { try frame(o,$0) },observe: { try observe(.sound(slot: slot,event: $0)) })
            pool[a] = actor;try afterActorPhysics(slot,actor)
            if try state(a) == 9998 { try ownedWorld.write(UInt8(0),at: 4+slot) }
            if try state(a) == 14 && i(a,0x2fc) <= 0 && (i(a,0x2f4) >= 0 || i(a,0x364) == 5 || slot >= 20) && i(a,8) > 0 && i(a,8) < 5 {
                if try i(a,0x314) > 0 {
                    try pool[a].write(i(a,0x310),at: 0x30c);try pool[a].write(Int32(0),at: 0x308)
                    try pool[a].write(i(a,0x314),at: 0x304);try pool[a].write(i(a,0x304),at: 0x300);try pool[a].write(i(a,0x300),at: 0x2fc)
                    try pool[a].write(Int32(0),at: 0x314);try pool[a].write(Int32(0),at: 0x310);try pool[a].write(Int32(1),at: 0x364)
                    if try (30...36).contains(header(object(a)).integer(at: 0x6f4,as: Int32.self)) { try pool[a].write(Int32(140),at: 0x318) }
                    try pool[a].write(Int32(219),at: 0x70);try pool[a].write(Int32(0),at: 0x88);try pool[a].write(Int32(10),at: 0xb4)
                    // Failed allocation/lookup preserves all preceding revival writes.
                    if let free = try (50..<400).first(where: { try active($0) == 0 }),let replacement = try find(998) {
                        let b = try index(free)
                        try observe(.reconstruct(slot: slot,created: free));try pool[b].reconstructActor()
                        try pool[b].write(UInt32(replacement),at: 0x368)
                        try pool[b].write(header(replacement).integer(at: 0x90,as: Int32.self),at: 0x31c)
                        try pool[b].writeBinary64(580,at: 0x58);try pool[b].writeBinary64(-200,at: 0x60);try pool[b].writeBinary64(300,at: 0x68)
                        for offset in [0x10,0x14] { try pool[b].write(i(a,offset),at: offset) }
                        try pool[b].write(i(a,0x18) &+ 1,at: 0x18);try pool[b].write(i(a,0x364),at: 0x364)
                        for offset in [0x58,0x60,0x68] { try pool[b].writeBinary64(pool[a].binary64(at: offset),at: offset) }
                        try pool[b].write(Int32(6),at: 0x70) //41e929/41e932 uses ESI, the created slot
                        for offset in [0x40,0x48,0x50] { try pool[b].writeBinary64(0,at: offset) }
                        try pool[b].write(UInt8(0),at: 0x80);try ownedWorld.write(UInt8(1),at: 4+free)
                    }
                } else if try i(a,0x30c) < 2 { try ownedWorld.write(UInt8(0),at: 4+slot) }
                else {
                    try pool[a].write(i(a,0x30c) &- 1,at: 0x30c)
                    var x: Int32 = 0,z: Int32 = 0,count: Int32 = 0
                    for other in 0..<400 where try other != slot && active(other) == 1 {
                        let b = try index(other)
                        if try header(object(b)).integer(at: 0x6f8,as: Int32.self) == 0 && i(b,0x364) == i(a,0x364) {
                            x = try x &+ i(b,0x10);z = try z &+ i(b,0x18);count &+= 1
                        }
                    }
                    let rx = try draw(slot,144,51)
                    guard count != 0 else { throw error("Original respawn idiv by zero after RNG") }
                    try pool[a].writeBinary64(Double(x/count)+Double(rx)-26,at: 0x58)
                    let rz = try draw(slot,145,31);try pool[a].writeBinary64(Double(z/count)+Double(rz)-16,at: 0x68)
                    try pool[a].write(Int32(500),at: 0x308);try pool[a].write(i(a,0x304),at: 0x300);try pool[a].write(i(a,0x300),at: 0x2fc)
                    try pool[a].write(Int32(20),at: 8);try pool[a].write(Int32(212),at: 0x70)
                    try pool[a].write(Int32(-300),at: 0x14);try pool[a].writeBinary64(-300,at: 0x60);try pool[a].writeBinary64(0,at: 0x48)
                }
            }
            // This block still runs after deactivation and revival. It clears
            // the combo before attempting the source-ID lookup, even on failure.
            if try i(a,0x324) > -1 && pool[a].integer(at: 0xdc,as: UInt8.self) == 3 && i(a,0x14) == 0 && i(a,0x2fc) > 0 {
                try pool[a].write(UInt8(0),at: 0xdc)
                if let replacement = try find(i(a,0x324)) {
                    try pool[a].write(UInt32(replacement),at: 0x368);try pool[a].write(Int32(245),at: 0x70);try pool[a].write(Int32(-1),at: 0x324)
                    for linked in 0..<400 where try active(linked) != 0 {
                        let b = try index(linked)
                        if try i(b,0x2f4) == Int32(slot) && i(b,0x2fc) > 0 {
                            try pool[b].write(UInt32(replacement),at: 0x368);try pool[b].write(Int32(try i(b,0x14) < 0 ? 212 : 0),at: 0x70)
                        }
                    }
                }
            }
        }
        world = ownedWorld;actors = pool;globals = owned
    }
}
