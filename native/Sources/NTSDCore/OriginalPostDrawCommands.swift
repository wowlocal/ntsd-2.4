public enum OriginalPostDrawCommandEvent: Equatable {
    case random(stream: Int32, range: Int32, result: Int32)
    case reconstruct(slot: Int)
    case resumeMusic(slot: Int, control: UInt32)
}

/// Entire4214d5..421a15. Command flags remain set here: their reset belongs
/// to the following HUD caller. All state and retained caller slot commit
/// atomically; observers must buffer device requests until the tick commits.
public enum OriginalPostDrawCommands {
    public static func apply(state: inout OriginalMatchPreparation, retainedSpawnSlot: inout Int32?,
                             sse2: Bool = false, library: OriginalLibStageCommands? = nil,
                             observe: (OriginalPostDrawCommandEvent) throws -> Void = { _ in }) throws {
        let catalog = state.catalog, backgrounds = state.backgrounds
        guard try state.world.integer(at: 0x7d4, as: UInt32.self) == 0,
              let registry = catalog.registry.records[0x4d82380] else { throw error("Catalog binding") }
        try apply(world: &state.world, actors: &state.actors, globals: &state.globals, retainedSpawnSlot: &retainedSpawnSlot,
            sse2: sse2, objectCount: registry.integer(at: 0, as: Int32.self), library: library, header: { n in
                guard catalog.objects.indices.contains(n) else { throw error("Object binding") }; return catalog.objects[n].header
            }, frame: { n, f in
                guard catalog.objects.indices.contains(n), catalog.objects[n].frameStorage.indices.contains(Int(f)) else { throw error("Frame binding") }
                return catalog.objects[n].frameStorage[Int(f)]
            }, background: { n in
                guard backgrounds.indices.contains(Int(n)) else { throw error("Background binding") }; return backgrounds[Int(n)]
            }, observe: observe)
    }
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Post-draw commands: "+text) }
    static func apply(world: inout OriginalStateRecord, actors: inout [OriginalStateRecord], globals: inout OriginalStateRecord,
                      retainedSpawnSlot: inout Int32?, sse2: Bool, objectCount: Int32, library: OriginalLibStageCommands? = nil,
                      header: (Int) throws -> OriginalStateRecord, frame: (Int, Int32) throws -> OriginalStateRecord,
                      background: (Int32) throws -> OriginalStateRecord,
                      observe: (OriginalPostDrawCommandEvent) throws -> Void = { _ in }) throws {
        try withoutActuallyEscaping(header) { headers in
            try withoutActuallyEscaping(frame) { frames in
                try withoutActuallyEscaping(background) { backgrounds in
                    try withoutActuallyEscaping(observe) { observer in
                        var body = Body(world: world, actors: actors, globals: globals, retainedSlot: retainedSpawnSlot,
                            sse2: sse2, objectCount: objectCount, library: library, header: headers, frame: frames, background: backgrounds, observe: observer)
                        try body.run()
                        world = body.world; actors = body.actors; globals = body.globals; retainedSpawnSlot = body.retainedSlot
                    }
                }
            }
        }
    }
    private struct Body {
        var world: OriginalStateRecord, actors: [OriginalStateRecord], globals: OriginalStateRecord
        var retainedSlot: Int32?
        let sse2: Bool, objectCount: Int32
        let library: OriginalLibStageCommands?
        let header: (Int) throws -> OriginalStateRecord, frame: (Int, Int32) throws -> OriginalStateRecord
        let background: (Int32) throws -> OriginalStateRecord
        let observe: (OriginalPostDrawCommandEvent) throws -> Void
        func index(_ slot: Int) throws -> Int {
            guard (0..<400).contains(slot) else { throw error("Actor slot extent") }
            let n = Int(try world.integer(at: 0x194+4*slot, as: UInt32.self))
            guard actors.indices.contains(n) else { throw error("Actor binding") }; return n
        }
        func active(_ slot: Int) throws -> UInt8 { try world.integer(at: 4+slot, as: UInt8.self) }
        func global(_ address: Int) throws -> Int32 { try globals.integer(at: address-0x44d000, as: Int32.self) }
        func i(_ actor: Int, _ offset: Int) throws -> Int32 { try actors[actor].integer(at: offset, as: Int32.self) }
        func object(_ actor: Int) throws -> Int { Int(try actors[actor].integer(at: 0x368, as: UInt32.self)) }
        func h(_ actor: Int, _ offset: Int) throws -> Int32 { try header(object(actor)).integer(at: offset, as: Int32.self) }
        mutating func put(_ actor: Int, _ offset: Int, _ value: Int32) throws { try actors[actor].write(value, at: offset) }
        mutating func draw(_ stream: Int32, _ range: Int32) throws -> Int32 {
            var random = OriginalRandom(table: try (0..<3000).map { try globals.integer(at: 0x44ff90-0x44d000+$0, as: UInt8.self) },
                index: Int(try global(0x450bcc)), counter: Int(try global(0x450c34)), source: "post-draw commands", sourceSHA256: "")
            try random.validate(); let result = Int32(random.next(Int(range)))
            try globals.write(Int32(random.index), at: 0x450bcc-0x44d000)
            try globals.write(Int32(random.counter), at: 0x450c34-0x44d000)
            try observe(.random(stream: stream, range: range, result: result)); return result
        }
        mutating func spawn(requestedObjectID: Int32? = nil) throws {
            var candidates: [Int] = []
            if objectCount > 0 {
                for n in 0..<Int(objectCount) {
                    let id = try header(n).integer(at: 0x6f4, as: Int32.self)
                    if let requestedObjectID {
                        // The DLL reads the first header ID before testing zero,
                        // accepts every exact match, and performs no208 draw.
                        if requestedObjectID == 0 { return }
                        if id != requestedObjectID { continue }
                    } else {
                        if id < 100 || id >= 200 { continue }
                        if try id == 122 && draw(208, 2) == 0 { continue }
                    }
                    candidates.append(n)
                }
            }
            for candidate in candidates {
                if let free = try (50..<400).first(where: { try active($0) == 0 }) { retainedSlot = Int32(free) }
                // Even a full pool consumes all four draws before reading the
                // retained slot. Do not skip the attempt or invent an index.
                let arena = try global(0x44d024), coarseX = try draw(209, 30)
                let width = try background(arena).integer(at: 0, as: Int32.self)
                let x0 = coarseX &* ((width &- 60)/30), fineX = try draw(210, 30)
                let x = x0 &+ fineX &+ 30, coarseZ = try draw(211, 30), bg = try background(arena)
                let span = try bg.integer(at: 8, as: Int32.self) &- bg.integer(at: 4, as: Int32.self) &- 60
                let z0 = coarseZ &* (span/30), fineZ = try draw(212, 30)
                let z = try fineZ &+ background(arena).integer(at: 4, as: Int32.self) &+ z0 &+ 30
                guard let retainedSlot else { throw error("Retained caller slot provenance") }
                let slot = Int(retainedSlot), actor = try index(slot)
                try observe(.reconstruct(slot: slot)); try actors[actor].reconstructActor()
                try put(actor, 0x368, Int32(candidate))
                try actors[actor].writeBinary64(Double(x), at: 0x58)
                try put(actor, 0x31c, header(candidate).integer(at: 0x90, as: Int32.self))
                try actors[actor].writeBinary64(-500, at: 0x60); try actors[actor].writeBinary64(Double(z), at: 0x68)
                try world.write(UInt8(1), at: 4+slot)
                for other in 0..<400 where try active(other) != 0 { try actors[index(other)].write(UInt8(0), at: 0xf0+slot) }
                for offset in [0x40, 0x48, 0x50] { try actors[index(slot)].writeBinary64(0, at: offset) }
                if try h(index(slot), 0x6f4) == 122 { try put(index(slot), 0x2fc, 200) }
                for (integer, binary) in [(0x10, 0x58), (0x14, 0x60), (0x18, 0x68)] {
                    let a = try index(slot)
                    try put(a, integer, OriginalCoordinateConversion.integer(actors[a].binary64(at: binary), sse2: sse2))
                }
            }
        }
        mutating func recover(_ slot: Int) throws {
            let a = try index(slot)
            if try global(0x450bb8) == 2 {
                let type = try h(a, 0x6f8)
                if [1, 2, 4, 6].contains(type) { try put(a, 0x31c, -1) }
                else if try global(0x451160) == 1 && i(a, 0x364) == 5 && type == 0 && h(a, 0x6f4) != 300 {
                    try put(a, 0x2fc, 0); try put(a, 0x308, 0)
                }
            }
            if try global(0x450bc0) == 1 && (global(0x451160) != 1 || (slot < 8 && i(a, 0x364) == 1)) {
                if try i(a, 0x304) < 500 { try put(a, 0x304, 500) }
                try put(a, 0x300, i(a, 0x304)); try put(a, 0x2fc, i(a, 0x300)); try put(a, 0x308, 500)
                let control = UInt32(bitPattern: try global(0x44f044))
                if control != 0 { try observe(.resumeMusic(slot: slot, control: control)) }
            }
            if try i(a, 0xe0)/1000 == 1 && i(a, 0x2fc) > 0 {
                try put(a, 0xe0, i(a, 0xe0) &- 1)
                if try i(a, 0xe0)%8 == 0 {
                    if try i(a, 0x2fc) < i(a, 0x300) {
                        if try i(a, 0x2fc) < i(a, 0x300) &- 8 { try put(a, 0x2fc, i(a, 0x2fc) &+ 8) }
                        else { try put(a, 0x2fc, i(a, 0x300)) }
                    } else { try put(a, 0xe0, 0) }
                }
                if try i(a, 0xe0)%1000 == 0 { try put(a, 0xe0, 0) }
            }
            if try i(a, 0xe4) > 0 && i(a, 0x2fc) > 0 {
                try put(a, 0xe4, i(a, 0xe4) &- 1)
                if try i(a, 0xe4)%8 == 0 && i(a, 0x2fc) < i(a, 0x300) {
                    try put(a, 0x2fc, i(a, 0x2fc) &+ 8)
                    if try i(a, 0x2fc) > i(a, 0x300) { try put(a, 0x2fc, i(a, 0x300)); try put(a, 0xe4, 0) }
                }
            }
            if try frame(object(a), i(a, 0x70)).integer(at: 8, as: Int32.self) == 1700 { try put(a, 0xe0, 1100) }
            if try active(slot) != 0 {
                for offset in [0x2e8, 0x2ec, 0x2f0] { try put(a, offset, 1000) }
                try put(a, 0x2e4, 0); try actors[a].write(UInt8(0), at: 0xeb)
            }
        }
        mutating func run() throws {
            if try global(0x450bb8) == 1 { try spawn() }
            else if let library, try global(0x450bb8) == 3 { try spawn(requestedObjectID: library.requestedObjectID) }
            for slot in 0..<400 where try active(slot) != 0 { try recover(slot) }
        }
    }
}
