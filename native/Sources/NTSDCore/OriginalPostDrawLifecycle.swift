public enum OriginalPostDrawLifecycleEvent: Equatable {
    case reconstruct(slot: Int, created: Int)
    case random(slot: Int, stream: Int32, range: Int32, result: Int32)
    case catalogSound(slot: Int, x: Int32, index: Int32)
    case builtinSound(slot: Int, x: Int32, index: Int32)
}

/// Retained caller words, separate from World/Actor state. Unknown Object indices
/// are required only when a failed catalog search actually dereferences them.
public struct OriginalPostDrawScratch: Equatable {
    public var fireSlot: Int32?, fireObject: Int32?, deathSlot: Int32?, weaponSlot: Int32?, weaponObject: Int32?, particleObject: Int32?
    public init(fireSlot: Int32? = nil, fireObject: Int32? = nil, deathSlot: Int32? = nil,
                weaponSlot: Int32? = nil, weaponObject: Int32? = nil, particleObject: Int32? = nil) {
        self.fireSlot = fireSlot; self.fireObject = fireObject; self.deathSlot = deathSlot
        self.weaponSlot = weaponSlot; self.weaponObject = weaponObject; self.particleObject = particleObject
    }
}

/// Entire interleaved41f550..4214d5 loop. Every slot completes prefix, scheduler,
/// opoint and the selected creation/lifetime continuation before the next slot.
/// All state and scratch commit together; observers must buffer external effects.
public enum OriginalPostDrawLifecycle {
    public static func apply(state: inout OriginalMatchPreparation, scratch: inout OriginalPostDrawScratch,
                             sse2: Bool = false, observe: (OriginalPostDrawLifecycleEvent) throws -> Void = { _ in }) throws {
        let catalog = state.catalog
        guard try state.world.integer(at: 0x7d4, as: UInt32.self) == 0,
              let registry = catalog.registry.records[0x4d82380] else { throw error("Catalog binding") }
        try apply(world: &state.world, actors: &state.actors, globals: &state.globals, scratch: &scratch,
            wholeLoop: true, slot: 0, precision: state.arithmeticPrecision, sse2: sse2,
            objectCount: registry.integer(at: 0, as: Int32.self), header: { index in
                guard catalog.objects.indices.contains(index) else { throw error("Object binding") }; return catalog.objects[index].header
            }, frame: { index, number in
                guard catalog.objects.indices.contains(index), catalog.objects[index].frameStorage.indices.contains(Int(number)) else { throw error("Frame binding") }
                return catalog.objects[index].frameStorage[Int(number)]
            }, observe: observe)
    }
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Post-draw lifecycle: " + text) }
    static func apply(world: inout OriginalStateRecord, actors: inout [OriginalStateRecord], globals: inout OriginalStateRecord,
                      scratch: inout OriginalPostDrawScratch, wholeLoop: Bool, slot: Int,
                      precision: OriginalArithmeticPrecision, sse2: Bool, objectCount: Int32,
                      header: (Int) throws -> OriginalStateRecord, frame: (Int, Int32) throws -> OriginalStateRecord,
                      observe: (OriginalPostDrawLifecycleEvent) throws -> Void = { _ in }) throws {
        guard (0..<400).contains(slot) else { throw error("Slot extent") }
        try withoutActuallyEscaping(header) { headers in
            try withoutActuallyEscaping(frame) { frames in
                try withoutActuallyEscaping(observe) { observer in
                    var body = Body(world: world, actors: actors, globals: globals, scratch: scratch, slot: slot,
                                    precision: precision, sse2: sse2, objectCount: objectCount, header: headers, frame: frames, observe: observer)
                    for selected in wholeLoop ? 0..<400 : slot..<slot+1 {
                        body.slot = selected
                        try body.run(prefix: wholeLoop)
                    }
                    world = body.world; actors = body.actors; globals = body.globals; scratch = body.scratch
                }
            }
        }
    }
    private struct Body {
        var world: OriginalStateRecord, actors: [OriginalStateRecord], globals: OriginalStateRecord
        var scratch: OriginalPostDrawScratch, slot: Int
        let precision: OriginalArithmeticPrecision, sse2: Bool, objectCount: Int32
        let header: (Int) throws -> OriginalStateRecord, frame: (Int, Int32) throws -> OriginalStateRecord
        let observe: (OriginalPostDrawLifecycleEvent) throws -> Void
        func index(_ slot: Int) throws -> Int {
            guard (0..<400).contains(slot) else { throw error("Actor slot extent") }
            let n = Int(try world.integer(at: 0x194+4*slot, as: UInt32.self))
            guard actors.indices.contains(n) else { throw error("Actor binding") }; return n
        }
        func active(_ slot: Int) throws -> UInt8 { try world.integer(at: 4+slot, as: UInt8.self) }
        func free() throws -> Int? { try (50..<400).first { try active($0) == 0 } }
        func i(_ a: Int, _ offset: Int) throws -> Int32 { try actors[a].integer(at: offset, as: Int32.self) }
        func object(_ a: Int) throws -> Int { Int(try actors[a].integer(at: 0x368, as: UInt32.self)) }
        func source(_ a: Int) throws -> Int32 { try header(object(a)).integer(at: 0x6f4, as: Int32.self) }
        func type(_ a: Int) throws -> Int32 { try header(object(a)).integer(at: 0x6f8, as: Int32.self) }
        func state(_ a: Int, _ offset: Int) throws -> Int32 { try frame(object(a), i(a, offset)).integer(at: 8, as: Int32.self) }
        func find(_ id: Int32) throws -> Int32? {
            if objectCount <= 0 { return nil }
            for n in 0..<Int(objectCount) where try header(n).integer(at: 0x6f4, as: Int32.self) == id { return Int32(n) }; return nil
        }
        func x(_ value: Double) throws -> OriginalExtended { try .init(value, precision: precision) }
        func decimal(_ a: Int, _ offset: Int) throws -> OriginalExtended { try x(actors[a].binary64(at: offset)) }
        mutating func put(_ a: Int, _ offset: Int, _ value: Int32) throws { try actors[a].write(value, at: offset) }
        mutating func number(_ a: Int, _ offset: Int, _ value: Double) throws { try actors[a].writeBinary64(value, at: offset) }
        mutating func construct(_ slot: Int, _ object: Int32) throws -> Int {
            let a = try index(slot), chosen = try header(Int(object))
            try observe(.reconstruct(slot: self.slot, created: slot)); try actors[a].reconstructActor()
            try put(a, 0x368, object); try number(a, 0x58, 580)
            try put(a, 0x31c, chosen.integer(at: 0x90, as: Int32.self)); try number(a, 0x60, -200); try number(a, 0x68, 300)
            try world.write(UInt8(1), at: 4+slot); return a
        }
        mutating func draw(_ stream: Int32, _ range: Int32) throws -> Int32 {
            let base = OriginalMatchPreparation.globalBase
            var random = OriginalRandom(table: try (0..<3000).map { try globals.integer(at: 0x44ff90-base+$0, as: UInt8.self) },
                index: Int(try globals.integer(at: 0x450bcc-base, as: Int32.self)),
                counter: Int(try globals.integer(at: 0x450c34-base, as: Int32.self)), source: "post-draw lifecycle", sourceSHA256: "")
            try random.validate(); let result = Int32(random.next(Int(range)))
            try globals.write(Int32(random.index), at: 0x450bcc-base); try globals.write(Int32(random.counter), at: 0x450c34-base)
            try observe(.random(slot: slot, stream: stream, range: range, result: result)); return result
        }
        mutating func sound(_ a: Int, _ value: Int32, builtin: Bool) throws {
            let px = try i(a, 0x10)
            if builtin {
                try observe(.builtinSound(slot: slot, x: px, index: value))
                try OriginalGameplaySound.queueBuiltin(x: px, index: value, globals: &globals)
            } else {
                try observe(.catalogSound(slot: slot, x: px, index: value))
                try OriginalGameplaySound.queueCatalog(x: px, index: value, globals: &globals)
            }
        }
        mutating func frameDraw(_ child: Int, _ stream: Int32, _ base: Int32, range: Int32 = 4) throws {
            let value = try draw(stream, range); try put(child, 0x70, value &+ base)
        }
        mutating func velocityDraw(_ child: Int, _ stream: Int32, _ range: Int32, base: Int32) throws {
            let value = try draw(stream, range); try number(child, 0x48, Double(-(value/2)-base))
        }
        mutating func weapon(_ parent: Int) throws -> Bool {
            guard try [1, 2, 4, 6].contains(type(parent)), try i(parent, 0x31c) < 0 else { return false }
            try put(parent, 0x31c, 0)
            let originalID = try source(parent)
            let count = [101: 7, 218: 7, 100: 5, 213: 5, 217: 5, 201: 3, 150: 13, 151: 15, 120: 3, 124: 3, 121: 4, 122: 9, 123: 9][Int(originalID)] ?? 0
            let soundID = try header(object(parent)).integer(at: 0xac, as: Int32.self)
            if soundID > -1 { try sound(parent, soundID, builtin: false) }
            for ordinal in 0..<count {
                guard let selected = try free() else { break }
                if let found = try find(999) { scratch.weaponObject = found }
                guard let retained = scratch.weaponObject else { throw error("Weapon Object index provenance") }
                let child = try construct(selected, retained)
                let rx = try draw(166, 7); try put(child, 0x10, rx &+ i(parent, 0x10) &- 3)
                let ry = try draw(167, 7); try put(child, 0x14, ry &+ i(parent, 0x14) &- 3)
                try put(child, 0x18, i(parent, 0x18))
                for (integer, value) in [(0x18, 0x68), (0x14, 0x60), (0x10, 0x58)] { try number(child, value, Double(i(child, integer))) }
                //Each independent ID check reloads the parent after construction
                //and preceding child writes. An alias can change which rules run.
                if try [150, 151, 213].contains(source(parent)) { try velocityDraw(child, 168, 20, base: 8) }
                if try [100, 201, 101, 120, 121, 122, 123, 124, 217, 218].contains(source(parent)) { try velocityDraw(child, 169, 8, base: 6) }
                let vx = try draw(170, 11); try number(child, 0x40, Double(vx)-5)
                if try source(parent) == 150 { try frameDraw(child, ordinal < 5 ? 171 : 172, ordinal < 5 ? 0 : 4) }
                if try source(parent) == 100 { try frameDraw(child, ordinal < 2 ? 173 : 174, ordinal < 2 ? 10 : 14) }
                if try source(parent) == 213 { try frameDraw(child, ordinal < 2 ? 175 : 176, ordinal < 2 ? 150 : 154) }
                if try source(parent) == 101 {
                    if ordinal < 5 { let base = try draw(177, 2)*4+20; try frameDraw(child, 178, base) }
                    else { try frameDraw(child, 179, 30) }
                }
                if try source(parent) == 151 {
                    try frameDraw(child, ordinal < 2 ? 180 : ordinal < 5 ? 181 : ordinal < 8 ? 182 : 183,
                                  ordinal < 2 ? 40 : ordinal < 5 ? 44 : ordinal < 8 ? 50 : 54)
                }
                if try source(parent) == 120 {
                    if ordinal < 2 { try frameDraw(child, 184, 54) }
                    else if ordinal < 5 { try frameDraw(child, 185, 30) }
                }
                if try source(parent) == 124 { try frameDraw(child, 186, 170) }
                if try source(parent) == 121 { try frameDraw(child, 187, 60) }
                if try source(parent) == 122 {
                    if ordinal < 1 { try frameDraw(child, 188, 70) }
                    else if ordinal < 3 { try frameDraw(child, 189, 80) }
                    else { try frameDraw(child, 190, 74); try velocityDraw(child, 191, 18, base: 4) }
                }
                if try source(parent) == 123 {
                    if ordinal < 1 { try frameDraw(child, 192, 160) }
                    else if ordinal < 3 { try frameDraw(child, 193, 164) }
                    else { try frameDraw(child, 194, 74); try velocityDraw(child, 195, 18, base: 4) }
                }
                if try [217, 218].contains(source(parent)) { try frameDraw(child, 196, 174) }
                scratch.weaponSlot = Int32(selected)
            }
            try world.write(UInt8(0), at: 4+slot)
            return true
        }
        mutating func command(_ parent: Int) throws {
            guard try slot < 10 && i(parent, 0x2fc) > 0 && type(parent) == 0 else { return }
            let fields = try [0x40c, 0x410, 0x414, 0x418].map { try i(parent, $0) }
            let command = fields == [9, 0, 9, 0] ? 100 : fields == [9, 9, 9, 9] ? 102 : fields == [9, 5, 9, 5] ? 104 : 0
            if command == 0 { return }
            for offset in [0x418, 0x414, 0x410, 0x40c, 0x408] { try put(parent, offset, 0) }
            let selected = try free(), object = try find(998)
            guard let selected, let object else { return }
            let child = try construct(selected, object)
            try put(child, 0x10, i(parent, 0x10)); try put(child, 0x14, 0); try put(child, 0x18, i(parent, 0x18))
            try put(child, 0x70, Int32(command-100))
            for (integer, value) in [(0x18, 0x68), (0x14, 0x60), (0x10, 0x58)] { try number(child, value, Double(i(child, integer))) }
            try number(child, 0x40, 0); try number(child, 0x48, 0)
            for target in 0..<400 where try active(target) == 1 {
                let actor = try index(target)
                if try i(actor, 0x2fc) <= 0 || type(actor) != 0 || i(actor, 0x364) != i(parent, 0x364) { continue }
                if command == 100 {
                    let rx = try draw(197, 81); try put(actor, 0x3fc, rx &+ i(child, 0x10) &- 40)
                    let rz = try draw(198, 81); try put(actor, 0x400, rz &+ i(child, 0x18) &- 40)
                } else { try put(actor, 0x404, command == 102 ? 1 : 0) }
            }
        }
        mutating func copyParticleCoordinates(_ parent: Int, _ child: Int) throws {
            for offset in [0x10, 0x14, 0x18] { try put(child, offset, i(parent, offset)) }
            //No final integer conversion: x/y integer fields deliberately retain
            //these copied values after the subsequent binary64 random offsets.
            try number(child, 0x68, actors[parent].binary64(at: 0x68))
        }
        mutating func late(_ parent: Int) throws {
            if try (state(parent, 0x78) == 13 || i(parent, 0x78) == 200) && state(parent, 0x70) != 13 && i(parent, 0x70) != 200 {
                try sound(parent, 15, builtin: true)
                if let object = try find(999) {
                    for n in 0..<15 {
                        guard let selected = try free() else { break }
                        let child = try construct(selected, object); try copyParticleCoordinates(parent, child)
                        let py = try decimal(parent, 0x60), ry = try draw(199, 29)
                        try number(child, 0x60, (py-x(Double(ry))).double)
                        let rx = try draw(200, 39)
                        try number(child, 0x58, (x(Double(rx-19))+decimal(parent, 0x58)).double)
                        try velocityDraw(child, 201, 20, base: 8)
                        let vx = try draw(202, 11)
                        try number(child, 0x40, ((x(Double(vx))-x(5))+(decimal(parent, 0x28)*x(0.5))).double)
                        try put(child, 0x70, n < 2 ? 120 : n < 5 ? 130 : n < 9 ? 125 : 135)
                        scratch.deathSlot = Int32(selected)
                    }
                }
            }
            if try [18, 19].contains(state(parent, 0x78)) {
                let current = try state(parent, 0x70)
                let count: Int
                if current == 18 || current == 19 { count = try draw(203, 4) == 0 ? 1 : 0 }
                else { count = 7 }
                for _ in 0..<count {
                    guard let selected = try free() else { break }
                    if let found = try find(999) { scratch.fireObject = found }
                    guard let object = scratch.fireObject else { throw error("Fire Object index provenance") }
                    let child = try construct(selected, object); try copyParticleCoordinates(parent, child)
                    let py = try decimal(parent, 0x60), ry = try draw(204, 29)
                    try number(child, 0x60, (py-x(Double(ry))).double)
                    let rx = try draw(205, 59)
                    try number(child, 0x58, (x(Double(rx-29))+decimal(parent, 0x58)).double)
                    try number(child, 0x48, -1)
                    let vx = try draw(206, 11)
                    try number(child, 0x40, ((x(Double(vx))-x(5))+decimal(parent, 0x40)).double)
                    try frameDraw(child, 207, 140, range: 1)
                    scratch.fireSlot = Int32(selected)
                }
            }
            try put(parent, 0x78, i(parent, 0x70))
        }
        mutating func run(prefix: Bool) throws {
            let observer = observe
            let converted: (OriginalPostDrawSlotEvent) throws -> Void = { event in
                switch event {
                case let .reconstruct(slot, created): try observer(.reconstruct(slot: slot, created: created))
                case let .random(slot, stream, range, result): try observer(.random(slot: slot, stream: stream, range: range, result: result))
                case let .catalogSound(slot, x, index): try observer(.catalogSound(slot: slot, x: x, index: index))
                }
            }
            if prefix {
                let active = try OriginalPostDrawSlotPrefix.apply(world: &world, actors: &actors, globals: &globals, slot: slot,
                    retainedObjectIndex: &scratch.particleObject, objectCount: objectCount, header: header, frame: frame, observe: converted)
                if !active { return }
            }
            let continuation = try OriginalPostDrawOpoint.apply(world: &world, actors: &actors, slot: slot,
                precision: precision, sse2: sse2, objectCount: objectCount, header: header, frame: frame, observe: converted)
            if continuation == .nextSlot { return }
            let parent = try index(slot)
            if try continuation == .weaponCreation && !weapon(parent) { try command(parent) }
            try late(parent)
        }
    }
}
