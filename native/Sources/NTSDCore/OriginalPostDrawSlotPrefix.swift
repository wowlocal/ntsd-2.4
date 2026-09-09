public enum OriginalPostDrawSlotEvent: Equatable {
    case reconstruct(slot: Int, created: Int)
    case random(slot: Int, stream: Int32, range: Int32, result: Int32)
    case catalogSound(slot: Int, x: Int32, index: Int32)
}

/// Entire41f550..41fb0b for ONE slot; inactive slots exit at4214c6.
/// The enclosing loop must finish this slot's post-schedule/opoint/deletion
/// before advancing. This is deliberately not a scheduling pass over the pool.
/// Returns true at the post-scheduler continuation, false at the inactive exit.
/// State and retained caller index commit together on success. Observers must
/// buffer external effects until the enclosing tick commits.
public enum OriginalPostDrawSlotPrefix {
    @discardableResult
    public static func apply(state: inout OriginalMatchPreparation, slot: Int,
                             retainedObjectIndex: inout Int32?,
                             observe: (OriginalPostDrawSlotEvent) throws -> Void = { _ in }) throws -> Bool {
        let catalog = state.catalog
        guard try state.world.integer(at: 0x7d4, as: UInt32.self) == 0,
              let registry = catalog.registry.records[0x4d82380] else { throw error("Catalog binding") }
        return try apply(world: &state.world, actors: &state.actors, globals: &state.globals,
            slot: slot, retainedObjectIndex: &retainedObjectIndex, objectCount: registry.integer(at: 0, as: Int32.self),
            header: { index in
                guard catalog.objects.indices.contains(index) else { throw error("Object binding") }
                return catalog.objects[index].header
            }, frame: { index, number in
                guard catalog.objects.indices.contains(index), catalog.objects[index].frameStorage.indices.contains(Int(number)) else {
                    throw error("Frame binding")
                }
                return catalog.objects[index].frameStorage[Int(number)]
            }, observe: observe)
    }

    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Post-draw slot prefix: " + text) }

    @discardableResult
    static func apply(world: inout OriginalStateRecord, actors: inout [OriginalStateRecord], globals: inout OriginalStateRecord,
                      slot: Int, retainedObjectIndex: inout Int32?, objectCount: Int32,
                      header: (Int) throws -> OriginalStateRecord, frame: (Int, Int32) throws -> OriginalStateRecord,
                      observe: (OriginalPostDrawSlotEvent) throws -> Void = { _ in }) throws -> Bool {
        guard (0..<400).contains(slot) else { throw error("Slot extent") }
        return try withoutActuallyEscaping(header) { headers in
            try withoutActuallyEscaping(frame) { frames in
                try withoutActuallyEscaping(observe) { observer in
                    var body = Body(world: world, actors: actors, globals: globals, retained: retainedObjectIndex,
                                    slot: slot, objectCount: objectCount, header: headers, frame: frames, observe: observer)
                    let active = try body.run()
                    world = body.world; actors = body.actors; globals = body.globals; retainedObjectIndex = body.retained
                    return active
                }
            }
        }
    }

    private struct Body {
        var world: OriginalStateRecord, actors: [OriginalStateRecord], globals: OriginalStateRecord
        var retained: Int32?
        let slot: Int, objectCount: Int32
        let header: (Int) throws -> OriginalStateRecord, frame: (Int, Int32) throws -> OriginalStateRecord
        let observe: (OriginalPostDrawSlotEvent) throws -> Void
        func active(_ slot: Int) throws -> UInt8 { try world.integer(at: 4+slot, as: UInt8.self) }
        func index(_ slot: Int) throws -> Int {
            let value = Int(try world.integer(at: 0x194+4*slot, as: UInt32.self))
            guard actors.indices.contains(value) else { throw error("Actor binding") }; return value
        }
        func i(_ actor: Int, _ offset: Int) throws -> Int32 { try actors[actor].integer(at: offset, as: Int32.self) }
        func object(_ actor: Int) throws -> Int { Int(try actors[actor].integer(at: 0x368, as: UInt32.self)) }
        func type(_ actor: Int) throws -> Int32 { try header(object(actor)).integer(at: 0x6f8, as: Int32.self) }
        func currentState(_ actor: Int) throws -> Int32 { try frame(object(actor), i(actor, 0x70)).integer(at: 8, as: Int32.self) }
        func g(_ address: Int) throws -> Int32 { try globals.integer(at: address-OriginalMatchPreparation.globalBase, as: Int32.self) }
        func find(_ id: Int32) throws -> Int32? {
            if objectCount <= 0 { return nil }
            for index in 0..<Int(objectCount) {
                if try header(index).integer(at: 0x6f4, as: Int32.self) == id { return Int32(index) }
            }
            return nil
        }
        mutating func put(_ actor: Int, _ offset: Int, _ value: Int32) throws { try actors[actor].write(value, at: offset) }
        mutating func number(_ actor: Int, _ offset: Int, _ value: Double) throws { try actors[actor].writeBinary64(value, at: offset) }
        mutating func draw(_ stream: Int32, _ range: Int32) throws -> Int32 {
            let base = OriginalMatchPreparation.globalBase
            var random = OriginalRandom(table: try (0..<3000).map { try globals.integer(at: 0x44ff90-base+$0, as: UInt8.self) },
                index: Int(try g(0x450bcc)), counter: Int(try g(0x450c34)), source: "post-draw slot prefix", sourceSHA256: "")
            try random.validate()
            let result = Int32(random.next(Int(range)))
            try globals.write(Int32(random.index), at: 0x450bcc-base)
            try globals.write(Int32(random.counter), at: 0x450c34-base)
            try observe(.random(slot: slot, stream: stream, range: range, result: result))
            return result
        }
        mutating func particles(_ parent: Int) throws {
            for ordinal in 0..<5 {
                guard let free = try (50..<400).first(where: { try active($0) == 0 }) else { break }
                if let found = try find(ordinal == 4 ? 218 : 217) { retained = found }
                //41f734 consumes the old caller +70 on lookup failure. It does
                //not skip creation or silently choose a default Object.
                guard let retained else { throw error("Retained catalog index provenance") }
                let replacement = Int(retained), child = try index(free)
                let chosenHeader = try header(replacement)
                try observe(.reconstruct(slot: slot, created: free))
                try actors[child].reconstructActor()
                try put(child, 0x368, retained)
                let weaponHP = try chosenHeader.integer(at: 0x90, as: Int32.self)
                try number(child, 0x58, 580)
                try put(child, 0x31c, weaponHP)
                try number(child, 0x60, -200); try number(child, 0x68, 300)
                try world.write(UInt8(1), at: 4+free)
                //Reload parent fields after every construction/RNG call: an
                //inactive slot may share its Actor allocation with the parent.
                let rx = try draw(155, 7)
                try put(child, 0x10, rx &+ i(parent, 0x10) &- 3)
                let ry = try draw(156, 7)
                try put(child, 0x14, ry &+ i(parent, 0x14) &- 9)
                try put(child, 0x18, i(parent, 0x18) &+ 1)
                for (integer, decimal) in [(0x18, 0x68), (0x14, 0x60), (0x10, 0x58)] {
                    try number(child, decimal, Double(i(child, integer)))
                }
                let vy = try draw(157, 15)
                try number(child, 0x48, Double(0 &- (vy/2))-5)
                try put(child, 0xec, 6)
                if ordinal == 0 || ordinal == 2 { let value = try draw(158, 2); try number(child, 0x50, Double(value)+3) }
                else if ordinal == 1 || ordinal == 3 { let value = try draw(159, 2); try number(child, 0x50, -3-Double(value)) }
                else { try number(child, 0x50, 1) }
                if ordinal < 2 { let value = try draw(160, 3); try number(child, 0x40, -10-Double(value)) }
                else if ordinal < 4 { let value = try draw(161, 3); try number(child, 0x40, Double(value)+10) }
                else { let value = try draw(162, 7); try number(child, 0x40, Double(value)-3) }
                let nextFrame = try draw(164, 4); try put(child, 0x70, nextFrame)
                let facing = try draw(165, 2); try actors[child].write(UInt8(truncatingIfNeeded: facing), at: 0x80)
            }
        }
        mutating func resources(_ actor: Int) throws {
            if try i(actor, 0x2fc) > 0 && i(actor, 0x2fc) < i(actor, 0x300) && g(0x450bd0) == 0 {
                try put(actor, 0x2fc, i(actor, 0x2fc) &+ 1)
            }
            if try i(actor, 0x320) < 0 && g(0x450bd0) == 0 {
                let divisor = try i(actor, 0x340), damage: Int32 = divisor > 0 ? 900/divisor : 9
                try put(actor, 0x2fc, i(actor, 0x2fc) &- damage)
                try put(actor, 0x300, i(actor, 0x300) &- (damage/3))
                if try i(actor, 0x2fc) < 0 { try put(actor, 0x2fc, 0) }
                if try i(actor, 0x300) < 0 { try put(actor, 0x300, 0) }
                try put(actor, 0x34c, i(actor, 0x34c) &+ 9)
            }
            if try i(actor, 0x2f4) != -1 && i(actor, 0x308) >= 150 { return }
            if try i(actor, 0x308) >= 500 || g(0x450bd4) != 0 || i(actor, 8) < 0 { return }
            var hp = try min(i(actor, 0x2fc), 500)
            let source = try header(object(actor)).integer(at: 0x6f4, as: Int32.self)
            if source == 51 || source == 52 { hp /= 2 }
            let amount = (Int32(500) &- hp)/100 &+ 1
            try put(actor, 0x308, i(actor, 0x308) &+ amount)
        }
        mutating func run() throws -> Bool {
            if try active(slot) == 0 { return false }
            let actorIndex = try index(slot)
            if try type(actorIndex) == 0 && currentState(actorIndex) == 9995 {
                if let replacement = try find(50) { try put(actorIndex, 0x368, replacement) }
                try put(actorIndex, 0x70, 0)
            }
            let state = try currentState(actorIndex)
            if (8000..<9000).contains(state) {
                if let replacement = try find(state &- 8000) { try put(actorIndex, 0x368, replacement) }
                try put(actorIndex, 0x70, 0); try put(actorIndex, 0x318, 140)
            }
            if try type(actorIndex) == 0 && currentState(actorIndex) == 9996 && i(actorIndex, 0x88) == 1 {
                try particles(actorIndex)
            }
            if try type(actorIndex) == 0 { try resources(actorIndex) }
            let objectIndex = try object(actorIndex), mode = try g(0x451160)
            var actor = actors[actorIndex]
            try OriginalActorScheduler.apply(actor: &actor, header: header(objectIndex), globals: &globals,
                mode: mode, slot: Int32(slot), frame: { try frame(objectIndex, $0) }, observe: { event in
                    switch event {
                    case let .catalogSound(x, index): try observe(.catalogSound(slot: slot, x: x, index: index))
                    }
                })
            actors[actorIndex] = actor
            return true
        }
    }
}
