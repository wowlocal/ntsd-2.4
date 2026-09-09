public enum OriginalPostDrawOpointContinuation: UInt32 {
    case weaponCreation = 0x4203b4
    case lateCreation = 0x420e93
    case nextSlot = 0x4214c6
}

/// Entire41fb0b..4203b4, plus the original early frame lifetime exits.
/// Runs for one slot AFTER its scheduler. An opoint attempt skips the weapon
/// creation block even when the pool/catalog cannot supply a new object.
/// The enclosing caller must follow the returned continuation before advancing.
public enum OriginalPostDrawOpoint {
    public static func apply(state: inout OriginalMatchPreparation, slot: Int, sse2: Bool = false,
                             observe: (OriginalPostDrawSlotEvent) throws -> Void = { _ in }) throws -> OriginalPostDrawOpointContinuation {
        let catalog = state.catalog
        guard try state.world.integer(at: 0x7d4, as: UInt32.self) == 0,
              let registry = catalog.registry.records[0x4d82380] else { throw error("Catalog binding") }
        return try apply(world: &state.world, actors: &state.actors, slot: slot, precision: state.arithmeticPrecision,
            sse2: sse2, objectCount: registry.integer(at: 0, as: Int32.self), header: { index in
                guard catalog.objects.indices.contains(index) else { throw error("Object binding") }
                return catalog.objects[index].header
            }, frame: { index, number in
                guard catalog.objects.indices.contains(index), catalog.objects[index].frameStorage.indices.contains(Int(number)) else {
                    throw error("Frame binding")
                }
                return catalog.objects[index].frameStorage[Int(number)]
            }, observe: observe)
    }
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Post-draw opoint: " + text) }

    static func apply(world: inout OriginalStateRecord, actors: inout [OriginalStateRecord], slot: Int,
                      precision: OriginalArithmeticPrecision, sse2: Bool, objectCount: Int32,
                      header: (Int) throws -> OriginalStateRecord, frame: (Int, Int32) throws -> OriginalStateRecord,
                      observe: (OriginalPostDrawSlotEvent) throws -> Void = { _ in }) throws -> OriginalPostDrawOpointContinuation {
        guard (0..<400).contains(slot) else { throw error("Slot extent") }
        return try withoutActuallyEscaping(header) { headers in
            try withoutActuallyEscaping(frame) { frames in
                try withoutActuallyEscaping(observe) { observer in
                    var body = Body(world: world, actors: actors, slot: slot, precision: precision, sse2: sse2,
                                    objectCount: objectCount, header: headers, frame: frames, observe: observer)
                    let result = try body.run()
                    world = body.world; actors = body.actors
                    return result
                }
            }
        }
    }
    private struct Body {
        var world: OriginalStateRecord, actors: [OriginalStateRecord]
        let slot: Int, precision: OriginalArithmeticPrecision, sse2: Bool, objectCount: Int32
        let header: (Int) throws -> OriginalStateRecord, frame: (Int, Int32) throws -> OriginalStateRecord
        let observe: (OriginalPostDrawSlotEvent) throws -> Void
        func index(_ slot: Int) throws -> Int {
            guard (0..<400).contains(slot) else { throw error("Linked slot extent") }
            let value = Int(try world.integer(at: 0x194+4*slot, as: UInt32.self))
            guard actors.indices.contains(value) else { throw error("Actor binding") }; return value
        }
        func active(_ slot: Int) throws -> UInt8 { try world.integer(at: 4+slot, as: UInt8.self) }
        func i(_ actor: Int, _ offset: Int) throws -> Int32 { try actors[actor].integer(at: offset, as: Int32.self) }
        func b(_ actor: Int, _ offset: Int) throws -> UInt8 { try actors[actor].integer(at: offset, as: UInt8.self) }
        func object(_ actor: Int) throws -> Int { Int(try actors[actor].integer(at: 0x368, as: UInt32.self)) }
        func type(_ actor: Int) throws -> Int32 { try header(object(actor)).integer(at: 0x6f8, as: Int32.self) }
        func source(_ actor: Int) throws -> Int32 { try header(object(actor)).integer(at: 0x6f4, as: Int32.self) }
        func current(_ actor: Int) throws -> OriginalStateRecord { try frame(object(actor), i(actor, 0x70)) }
        func x(_ value: Double) throws -> OriginalExtended { try .init(value, precision: precision) }
        func decimal(_ actor: Int, _ offset: Int) throws -> OriginalExtended { try x(actors[actor].binary64(at: offset)) }
        mutating func put(_ actor: Int, _ offset: Int, _ value: Int32) throws { try actors[actor].write(value, at: offset) }
        mutating func number(_ actor: Int, _ offset: Int, _ value: Double) throws { try actors[actor].writeBinary64(value, at: offset) }
        mutating func byte(_ actor: Int, _ offset: Int, _ value: UInt8) throws { try actors[actor].write(value, at: offset) }
        mutating func launchDead(_ actor: Int) throws {
            try put(actor, 0x70, 186); try number(actor, 0x48, -3); try number(actor, 0x30, -3)
            try number(actor, 0x60, -1); try put(actor, 0x14, -1)
        }
        func find(_ id: Int32) throws -> Int? {
            if objectCount <= 0 { return nil }
            for n in 0..<Int(objectCount) where try header(n).integer(at: 0x6f4, as: Int32.self) == id { return n }
            return nil
        }
        mutating func run() throws -> OriginalPostDrawOpointContinuation {
            let parent = try index(slot), initialFrame = try i(parent, 0x70)
            if initialFrame/100 == 11 || initialFrame/100 == 12 {
                for linked in 0..<400 where try active(linked) == 1 {
                    let actor = try index(linked)
                    if try i(actor, 0x2f4) == Int32(slot) { try put(actor, 8, 1100 &- i(parent, 0x70)) }
                }
                try put(parent, 8, 1100 &- i(parent, 0x70)); try put(parent, 0x70, 0)
                return .nextSlot
            }
            if initialFrame < 0 || initialFrame >= 400 {
                try put(parent, 0x70, 0); try world.write(UInt8(0), at: 4+slot)
                return .nextSlot
            }
            if try type(parent) == 0 && i(parent, 0x2fc) <= 0 && (initialFrame < 12 || initialFrame == 110 || initialFrame == 111) {
                try launchDead(parent)
            }
            if try type(parent) == 0 && i(parent, 0x14) == 0 && actors[parent].binary64(at: 0x60) == 0 &&
                actors[parent].binary64(at: 0x48) == 0 && actors[parent].binary64(at: 0x30) == 0 {
                let number = try i(parent, 0x70)
                if ((180...189).contains(number) && number != 184) || (212...214).contains(number) { try launchDead(parent) }
            }
            //CallerSP+38 retains this Frame's address even if construction
            //through an aliased free slot replaces the parent's Object/frame.
            let opoint = try current(parent)
            func op(_ offset: Int) throws -> Int32 { try opoint.integer(at: offset, as: Int32.self) }
            if try op(0x58) <= 0 || op(0x70) <= 0 || i(parent, 0x88) != 0 { return .weaponCreation }
            if try i(parent, 0xb4) != 0 && type(parent) == 0 { return .weaponCreation }
            let packed = try op(0x74), count: Int32 = packed > 10 ? packed/10 : 1, direction = packed > 10 ? packed%10 : packed
            var created: [Int] = []
            for ordinal in 0..<Int(count) {
                //Both searches run in the original, but catalog reads do not
                //modify state. A failed search stops the whole opoint attempt.
                let free = try (50..<400).first { try active($0) == 0 }, replacement = try find(op(0x70))
                guard let free, let replacement else { break }
                created.append(free)
                let child = try index(free), selected = try header(replacement)
                try observe(.reconstruct(slot: slot, created: free))
                try actors[child].reconstructActor()
                try put(child, 0x368, Int32(replacement)); try number(child, 0x58, 580)
                try put(child, 0x31c, selected.integer(at: 0x90, as: Int32.self))
                try number(child, 0x60, -200); try number(child, 0x68, 300)
                try put(child, 0x354, i(parent, 0x354))
                for other in 0..<400 where try active(other) != 0 { try byte(index(other), 0xf0+free, 0) }
                try world.write(UInt8(1), at: 4+free)
                let now = try current(parent)
                let y = try i(parent, 0x14) &- now.integer(at: 0x54, as: Int32.self) &+ op(0x60)
                let centerX = try now.integer(at: 0x50, as: Int32.self)
                let px = try b(parent, 0x80) == 0 ? i(parent, 0x10) &- centerX &+ op(0x5c) : centerX &- op(0x5c) &+ i(parent, 0x10)
                try put(child, 0x10, px); try put(child, 0x14, y)
                try put(child, 0x364, i(parent, 0x364))
                try number(child, 0x68, (decimal(parent, 0x68)+x(1)).double)
                try number(child, 0x60, Double(i(child, 0x14)))
                try put(child, 0x70, op(0x64)); try number(child, 0x48, Double(op(0x6c))); try number(child, 0x50, 0)
                let childState = try current(child).integer(at: 8, as: Int32.self), childSource = try source(child)
                if [3000, 1002, 3006].contains(childState) && childSource != 223 && childSource != 224 {
                    if try b(parent, 0xcd) != 0 && b(parent, 0xce) == 0 { try number(child, 0x50, -2.5) }
                    else if try b(parent, 0xcd) == 0 && b(parent, 0xce) != 0 { try number(child, 0x50, 2.5) }
                    if try source(child) == 211 { try number(child, 0x50, (decimal(child, 0x50)*x(0.25)).double) }
                }
                if try type(child) == 0 {
                    let owner = try i(parent, 0x2f4)
                    try put(child, 0x2f4, owner > -1 ? owner : Int32(slot)); try put(child, 8, i(parent, 8))
                }
                if direction == 0 { try byte(child, 0x80, b(parent, 0x80)) }
                else if direction == 1 { try byte(child, 0x80, 1 &- b(parent, 0x80)) }
                else { try byte(child, 0x80, 0) }
                let speed = try x(Double(op(0x68)))
                try number(child, 0x40, (b(child, 0x80) == 0 ? speed : -speed).double)
                try number(child, 0x58, Double(i(child, 0x10)))
                if count > 1 {
                    //42010a/114/116/11a round separately. Keep the extended
                    //spread across the vz store and the following vx branch.
                    let spread = try (x(Double(ordinal))*x(10))/(x(Double(count))-x(1))-x(5)
                    try number(child, 0x50, (spread+decimal(child, 0x50)).double)
                    let vx = try decimal(child, 0x40), zero = try x(0)
                    let adjusted = (vx > zero && spread > zero) || (vx < zero && spread < zero) ? vx-spread : vx+spread
                    try number(child, 0x40, adjusted.double)
                }
                if try type(parent) == 3 && current(parent).integer(at: 8, as: Int32.self) == 3003 {
                    let owner = Int(try i(parent, 0))
                    try byte(index(owner), 0xf0+free, 10)
                    let reloadedOwner = Int(try i(parent, 0))
                    guard (0..<400).contains(reloadedOwner) else { throw error("Owner vrest extent") }
                    try byte(child, 0xf0+reloadedOwner, 10)
                }
                if try source(child) == 5 || source(child) == 52 {
                    for offset in [0x2fc, 0x304, 0x300] { try put(child, offset, 10) }; try put(child, 0x308, 5)
                }
                for (decimal, integer) in [(0x58, 0x10), (0x60, 0x14), (0x68, 0x18)] {
                    let value = try actors[child].binary64(at: decimal)
                    try put(child, integer, OriginalCoordinateConversion.integer(value, sse2: sse2))
                }
                if try op(0x58) == 2 {
                    try put(parent, 0x98, 1); try put(child, 0x98, -1)
                    try put(parent, 0x9c, Int32(free)); try put(child, 0xa0, Int32(slot)); try put(child, 0x364, i(parent, 0x364))
                }
            }
            if created.count > 1 {
                let half = created.count/2
                for n in created.indices {
                    let actor = try index(created[n])
                    if created.count%2 == 0 {
                        if n < half-1 { try put(actor, 0xec, Int32((half-n)*2-2)) }
                        else if n > half { try put(actor, 0xec, Int32((n-half)*2)) }
                    } else {
                        if n < half { try put(actor, 0xec, Int32((half-n)*2)) }
                        else if n > half { try put(actor, 0xec, Int32((n-half)*2)) }
                    }
                    for previous in 0..<n {
                        try byte(actor, 0xf0+created[previous], 40)
                        try byte(index(created[previous]), 0xf0+created[n], 40)
                    }
                }
            }
            return .lateCreation
        }
    }
}
