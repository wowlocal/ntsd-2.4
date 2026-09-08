/// Original41e339..41e634: ascending400-slot control, then state400/401
/// teleport and500/501 transformation. Object references are non-null ordinals;
/// the World table may alias Actor allocations. This is one stage, not a tick.
public enum OriginalWorldControl {
    public static func apply(state: inout OriginalMatchPreparation,
                             observe: (Int,OriginalActorControlEvent) throws -> Void = { _,_ in },
                             afterActorControl: (Int,OriginalStateRecord) throws -> Void = { _,_ in }) throws {
        let catalog = state.catalog
        guard try state.world.integer(at: 0x7d4,as: UInt32.self) == 0,
              let registry = catalog.registry.records[0x4d82380] else {
            throw OriginalStateError.invalidStorage("World control catalog binding")
        }
        try apply(world: state.world,actors: &state.actors,globals: &state.globals,
                  objectCount: registry.integer(at: 0,as: Int32.self),header: { index in
            guard catalog.objects.indices.contains(index) else { throw error("Object binding") }
            return catalog.objects[index].header
        },frame: { index,number in
            guard catalog.objects.indices.contains(index),catalog.objects[index].frameStorage.indices.contains(Int(number)) else { throw error("Frame binding") }
            return catalog.objects[index].frameStorage[Int(number)]
        },observe: observe,afterActorControl: afterActorControl)
    }

    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("World control: "+text) }

    static func apply(world: OriginalStateRecord,actors: inout [OriginalStateRecord],globals: inout OriginalStateRecord,
                      objectCount: Int32,header: (Int) throws -> OriginalStateRecord,
                      frame: (Int,Int32) throws -> OriginalStateRecord,
                      observe: (Int,OriginalActorControlEvent) throws -> Void = { _,_ in },
                      afterActorControl: (Int,OriginalStateRecord) throws -> Void = { _,_ in }) throws {
        var pool = actors,owned = globals
        func index(_ slot: Int) throws -> Int {
            let i = Int(try world.integer(at: 0x194+slot*4,as: UInt32.self))
            guard pool.indices.contains(i) else { throw error("Actor binding") };return i
        }
        func active(_ slot: Int) throws -> Bool { try world.integer(at: 4+slot,as: UInt8.self) != 0 }
        func object(_ i: Int) throws -> Int { Int(try pool[i].integer(at: 0x368,as: UInt32.self)) }
        func state(_ i: Int) throws -> Int32 {
            try frame(object(i),pool[i].integer(at: 0x70,as: Int32.self)).integer(at: 8,as: Int32.self)
        }
        for slot in 0..<400 where try active(slot) {
            let i = try index(slot),o = try object(i)
            // Only this helper owns a detached Actor; commit it before the
            // surrounding World rules inspect or mutate any aliased allocation.
            var actor = pool[i]
            try OriginalActorControl.apply(actor: &actor,header: header(o),globals: &owned,
                frame: { try frame(o,$0) },observe: { try observe(slot,$0) })
            pool[i] = actor;try afterActorControl(slot,actor)
            if try state(i) == 400,try owned.integer(at: 0x450bd8-0x44d000,as: Int32.self) == 0 {
                try teleport(world: world,actors: &pool,slot: slot,kind: 1,header: header)
            }
            if try state(i) == 401,try owned.integer(at: 0x450bd8-0x44d000,as: Int32.self) == 0 {
                try teleport(world: world,actors: &pool,slot: slot,kind: 2,header: header)
            }
            if try state(i) == 500 {
                if try pool[i].integer(at: 0x33c,as: Int32.self) == -1 || pool[i].integer(at: 0x324,as: Int32.self) > -1 {
                    try pool[i].write(Int32(0),at: 0x70)
                }
            }
            if try state(i) == 501 {
                let target = try pool[i].integer(at: 0x33c,as: Int32.self)
                if target <= -1 || objectCount <= 0 { continue }
                var replacement: Int?
                for n in 0..<Int(objectCount) where try header(n).integer(at: 0x6f4,as: Int32.self) == target { replacement = n;break }
                guard let replacement else { continue }
                try pool[i].write(header(object(i)).integer(at: 0x6f4,as: Int32.self),at: 0x324)
                try pool[i].write(UInt32(replacement),at: 0x368)
                try pool[i].write(Int32(0),at: 0x70)
                for linked in 0..<400 where try active(linked) {
                    let j = try index(linked)
                    if try pool[j].integer(at: 0x2f4,as: Int32.self) == Int32(slot),try pool[j].integer(at: 0x2fc,as: Int32.self) > 0 {
                        try pool[j].write(pool[i].integer(at: 0x368,as: UInt32.self),at: 0x368)
                        try pool[j].write(Int32(try pool[j].integer(at: 0x14,as: Int32.self) < 0 ? 212 : 0),at: 0x70)
                    }
                }
            }
        }
        actors = pool;globals = owned
    }

    /// Whole403270..4034d3. Strict comparisons preserve the first slot on ties.
    /// Nearest enemy is capped at10000; farthest ally starts at-1. The signed
    /// Manhattan metric, abs and coordinate writes retain Int32 wraparound.
    static func teleport(world: OriginalStateRecord,actors: inout [OriginalStateRecord],slot: Int,kind: Int32,
                         header: (Int) throws -> OriginalStateRecord) throws {
        if kind != 1 && kind != 2 { return }
        func index(_ n: Int) throws -> Int {
            let i = Int(try world.integer(at: 0x194+n*4,as: UInt32.self))
            guard actors.indices.contains(i) else { throw error("Teleport Actor binding") };return i
        }
        func absWrap(_ x: Int32) -> Int32 { x < 0 ? 0 &- x : x }
        let i = try index(slot)
        var selected: Int?,distance: Int32 = kind == 1 ? 10000 : -1
        for n in 0..<400 where try n != slot && world.integer(at: 4+n,as: UInt8.self) != 0 {
            let j = try index(n),o = Int(try actors[j].integer(at: 0x368,as: UInt32.self))
            if try header(o).integer(at: 0x6f8,as: Int32.self) != 0 { continue }
            let same = try actors[j].integer(at: 0x364,as: Int32.self) == actors[i].integer(at: 0x364,as: Int32.self)
            if try same != (kind == 2) || actors[j].integer(at: 0x2fc,as: Int32.self) <= 0 { continue }
            let dz = try actors[j].integer(at: 0x18,as: Int32.self) &- actors[i].integer(at: 0x18,as: Int32.self)
            let dx = try actors[j].integer(at: 0x10,as: Int32.self) &- actors[i].integer(at: 0x10,as: Int32.self)
            let d = absWrap(dz) &+ absWrap(dx)
            if kind == 1 ? d < distance : d > distance { selected = j;distance = d }
        }
        try actors[i].write(Int32(0),at: 0x14)
        if let j = selected {
            try actors[i].write(actors[j].integer(at: 0x18,as: Int32.self) &+ Int32(1),at: 0x18)
            let x = try actors[j].integer(at: 0x10,as: Int32.self),delta: Int32 = kind == 1 ? 120 : 60
            let facing = try actors[i].integer(at: 0x80,as: UInt8.self)
            try actors[i].write(facing == 0 ? x &- delta : x &+ delta,at: 0x10)
            try actors[i].writeBinary64(Double(actors[i].integer(at: 0x10,as: Int32.self)),at: 0x58)
            try actors[i].writeBinary64(Double(actors[i].integer(at: 0x18,as: Int32.self)),at: 0x68)
        }
        try actors[i].writeBinary64(0,at: 0x60)
        for offset in [0x50,0x48,0x40] { try actors[i].writeBinary64(0,at: offset) }
    }
}
