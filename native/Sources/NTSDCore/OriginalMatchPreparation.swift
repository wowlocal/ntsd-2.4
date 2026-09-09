import Foundation

public enum OriginalMatchPreparationEvent {
    case reconstruct(Int)
    case random(stream: Int32, range: Int32, result: Int32, beforeIndex: Int, beforeCounter: Int, index: Int, counter: Int)
    case releaseLayers(Int), loadLayers(Int), resetInput, resumeMusic, musicPath
}

/// Common menu-confirmed preparation, EXE 42d1ff..42d6ed. Prelude/replay have
/// separate implementations. The music continuation composes the shared player;
/// an enabled path requires its caller to provide that continuation.
/// Actor/Object/World references are non-null ordinals; BG refs are index+1.
public struct OriginalMatchPreparation {
    public static let globalBase = 0x44d000
    public static let globalSize = 0x458440 - globalBase
    /// Explicit arithmetic context; historical fixtures default to CW037f precision.
    /// Original startup selects53 bits; threading/Windows provenance is separate.
    public var arithmeticPrecision: OriginalArithmeticPrecision
    public var world: OriginalStateRecord
    public var actors: [OriginalStateRecord]
    /// Supplied global state with explicit initialization provenance. This is
    /// not a recovered default for the entire Windows startup/menu sequence.
    public var globals: OriginalStateRecord
    /// PAUSE/score/HUD resources constructed by the preceding initial loading.
    public var interface: OriginalInitialInterfaceLoading
    /// Live DAT allocations. Original hit processing can write a held weapon's
    /// raw ITR; those writes survive subsequent contacts and ticks.
    public internal(set) var frameAllocations: [OriginalFrameAllocation]
    /// Own loaded Object records, including inline Frame storage. Heap-backed
    /// Frame mutations are exposed separately by frameAllocations.
    public var loadedObjects: [OriginalLoadedObject] { catalog.objects }
    public internal(set) var backgrounds: [OriginalStateRecord]
    public var bitmaps: [OriginalLoadedBitmap] { backgroundLoader.bitmaps }
    public var releasedBitmaps: Set<Int> { backgroundLoader.releasedBitmaps }
    public internal(set) var releasedBitmapOrder: [Int] = []
    let catalog: OriginalLoadedCatalog
    var backgroundLoader: OriginalBackgroundLoader

    public init(catalog: OriginalLoadedCatalog, bootstrap: OriginalWorldBootstrap, globals: OriginalStateRecord,
                interface: OriginalInitialInterfaceLoading = .init(),arithmeticPrecision: OriginalArithmeticPrecision = .bits64) throws {
        guard globals.bytes.count == Self.globalSize else { throw Self.error("Global storage size") }
        self.arithmeticPrecision = arithmeticPrecision
        self.catalog = catalog
        frameAllocations = catalog.frameAllocations
        world = bootstrap.world; actors = bootstrap.actors; self.globals = globals
        self.interface = interface
        backgrounds = catalog.backgrounds
        backgroundLoader = OriginalBackgroundLoader()
        backgroundLoader.resources = catalog.resources
    }

    /// Declared background input for controlled preparation boundaries.
    /// Loading and application callers normally retain their loaded DAT value.
    public mutating func setBackgroundPerspectiveInput(_ value: Int32, background: Int) throws {
        guard backgrounds.indices.contains(background) else { throw Self.error("Background input binding") }
        try backgrounds[background].write(value, at: 0xc)
    }

    /// No selected-player defaults are invented here. Before entry, the caller
    /// supplies 451288 status codes, base-slot Object/team/activity and mode,
    /// arena selection and RNG state. Unsupported preparation rolls back storage.
    public mutating func prepare(mode: Int32, bitmapFill: UInt8 = 0xa5,
                                 bitmapSource: (String) throws -> OriginalBitmapInput,
                                 music: (inout OriginalMatchPreparation) throws -> Void = { state in
                                     guard try state.globals.integer(at: 0x44d010-OriginalMatchPreparation.globalBase, as: Int32.self) == 0 else {
                                         throw OriginalLoaderError.outsideVerifiedDomain("Enabled match music caller is not connected")
                                     }
                                 },
                                 observe: (OriginalMatchPreparationEvent) throws -> Void = { _ in }) throws {
        var candidate = self
        var library: OriginalLibStageCommands?
        try candidate.consume(mode: mode, library: &library, uninitializedPerspective: nil, bitmapFill: bitmapFill, bitmapSource: bitmapSource, music: music, observe: observe)
        self = candidate
    }

    /// The installed library changes three sites inside this same whole caller.
    /// Preserve the requested ID and original register clobber; commit both
    /// native game state and library state only after the operation succeeds.
    public mutating func prepareUsingBundledLibrary(mode: Int32, library: inout OriginalLibStageCommands,
        uninitializedPerspective: ((Int32) throws -> Int32)? = nil,
        bitmapFill: UInt8 = 0xa5, bitmapSource: (String) throws -> OriginalBitmapInput,
        music: (inout OriginalMatchPreparation) throws -> Void = { state in
            guard try state.globals.integer(at: 0x44d010-Self.globalBase, as: Int32.self) == 0 else {
                throw OriginalLoaderError.outsideVerifiedDomain("Enabled match music caller is not connected")
            }
        }, observe: (OriginalMatchPreparationEvent) throws -> Void = { _ in }) throws {
        var candidate = self, nextLibrary: OriginalLibStageCommands? = library
        try candidate.consume(mode: mode, library: &nextLibrary, uninitializedPerspective: uninitializedPerspective, bitmapFill: bitmapFill,
            bitmapSource: bitmapSource, music: music, observe: observe)
        self = candidate; library = nextLibrary!
    }

    private mutating func consume(mode: Int32, library: inout OriginalLibStageCommands?,
                                  uninitializedPerspective: ((Int32) throws -> Int32)?, bitmapFill: UInt8,
                                  bitmapSource: (String) throws -> OriginalBitmapInput,
                                  music: (inout OriginalMatchPreparation) throws -> Void,
                                  observe: (OriginalMatchPreparationEvent) throws -> Void) throws {
        guard world.bytes.count == OriginalStateRecord.worldPrefixSize, actors.count == 400,
              actors.allSatisfy({ $0.bytes.count == OriginalStateRecord.actorSize }),
              try world.integer(at: 0x7d4, as: UInt32.self) == 0 else { throw Self.error("World/catalog binding") }
        for slot in 0..<400 {
            guard try world.integer(at: 0x194+slot*4, as: UInt32.self) == slot else { throw Self.error("Actor table binding") }
        }
        var table: [UInt8] = []
        for address in 0x44ff90..<(0x44ff90+3000) {
            table.append(try globals.integer(at: address-Self.globalBase, as: UInt8.self))
        }
        var random = OriginalRandom(table: table, index: Int(try global(0x450bcc)), counter: Int(try global(0x450c34)),
                                    source: "supplied match-preparation state", sourceSHA256: "")
        try random.validate()
        func draw(_ stream: Int32, _ range: Int32) throws -> Int32 {
            let beforeIndex = random.index, beforeCounter = random.counter
            let value = Int32(random.next(Int(range)))
            try observe(.random(stream: stream, range: range, result: value, beforeIndex: beforeIndex,
                                beforeCounter: beforeCounter, index: random.index, counter: random.counter))
            return value
        }
        let backgroundCount = try catalog.registry.records[0x4d82380]!.integer(at: 4, as: Int32.self)
        releasedBitmapOrder = []
        guard (0...99).contains(backgroundCount) else { throw Self.error("Background count") }
        for slot in 10..<400 { try world.write(UInt8(0), at: 4+slot) }
        var background = try global(0x44d024)
        if try global(0x44d028) == 1 {
            background = try draw(0xda, backgroundCount &- 2)
            if background == backgroundCount &- 3 { background = 99 }
            try setGlobal(0x44d024, background)
        }
        guard (0..<backgroundCount).contains(background) || background == 99 else { throw Self.error("Selected arena") }
        for seat in 0..<8 {
            let status = try global(0x451288+seat*4)
            if status <= 0 { continue }
            let slot = status > 10 ? seat+10 : seat
            let objectIndex = Int(try actors[seat].integer(at: 0x368, as: UInt32.self))
            guard catalog.objects.indices.contains(objectIndex) else { throw Self.error("Selected Object binding") }
            let team = try actors[seat].integer(at: 0x364, as: Int32.self)
            try observe(.reconstruct(slot))
            try actors[slot].reconstructActor()
            try actors[slot].write(UInt32(objectIndex), at: 0x368)
            try actors[slot].write(catalog.objects[objectIndex].header.integer(at: 0x90, as: UInt32.self), at: 0x31c)
            try actors[slot].write(team, at: 0x364)
            try world.write(UInt8(1), at: 4+slot)
            try actors[slot].write(Int32(75), at: 8)
            let arena = backgrounds[Int(background)]
            let width = try arena.integer(at: 0, as: Int32.self)
            let lower = try arena.integer(at: 4, as: Int32.self), upper = try arena.integer(at: 8, as: Int32.self)
            func perspective() throws -> Int32 {
                do { return try arena.integer(at: 0xc, as: Int32.self) }
                catch OriginalStateError.undefinedBytes {
                    guard let uninitializedPerspective else { throw OriginalStateError.undefinedBytes(offset: 0xc, count: 4) }
                    return try uninitializedPerspective(background)
                }
            }
            if status > 10, library != nil {
                library!.requestedObjectID = try perspective()
            }
            var randomX = try draw(status > 10 ? 0xdb : 0xdd, width/2)
            if status <= 10, library != nil {
                library!.requestedObjectID = try perspective()
                //10001b48 overwrites live ECX after the RNG result was saved
                //there. The original42d483 therefore adds this ID, not randomX.
                randomX = library!.requestedObjectID
            }
            let x = randomX &+ (width/4)
            let z = try draw(status > 10 ? 0xdc : 0xde, upper &- lower) &+ lower
            try actors[slot].write(x, at: 0x10)
            try actors[slot].write(Int32(0), at: 0x14)
            try actors[slot].write(z, at: 0x18)
            try actors[slot].writeBinary64(Double(x), at: 0x58)
            try actors[slot].writeBinary64(0, at: 0x60)
            try actors[slot].writeBinary64(Double(z), at: 0x68)
            try actors[slot].write(Int32(mode == 1 ? 500 : 200), at: 0x308)
            try actors[slot].write(Int32(slot), at: 0x354)
        }
        for slot in 0..<400 where try active(slot) {
            if try actors[slot].integer(at: 0x364, as: Int32.self) == 0 {
                try actors[slot].write(Int32(slot+10), at: 0x364)
            }
        }
        for address in stride(from: 0x450c04, through: 0x450c28, by: 4) { try setGlobal(address, 0) }
        if library != nil { try globals.write(UInt8(3), at: 0x450bb8-Self.globalBase) }
        for index in 0..<Int(backgroundCount) {
            try observe(.releaseLayers(index))
            releasedBitmapOrder += try backgroundLoader.releaseLayers(in: &backgrounds[index])
        }
        if background != 99 {
            try observe(.loadLayers(Int(background)))
            try backgroundLoader.loadLayers(in: &backgrounds[Int(background)], bitmapFill: bitmapFill, bitmapSource: bitmapSource)
        }
        try setGlobal(0x44d034, 1)
        try setGlobal(0x450bbc, 0)
        try setGlobal(0x450bdc, 0)
        if mode == 1 {
            for slot in 0..<400 where try active(slot) {
                let objectIndex = Int(try actors[slot].integer(at: 0x368, as: UInt32.self))
                guard catalog.objects.indices.contains(objectIndex) else { throw Self.error("Active Object binding") }
                if try catalog.objects[objectIndex].header.integer(at: 0x6f8, as: Int32.self) == 0 {
                    let x = try draw(0xdf, 30) &+ 50
                    try actors[slot].write(x, at: 0x10)
                    try actors[slot].writeBinary64(Double(x), at: 0x58)
                }
            }
        }
        // Every original417170 draw commits immediately. Publish the accumulated
        // cursor before the music child observes this state, and retain any
        // changes made by that child instead of overwriting them at the return.
        try setGlobal(0x450bcc, Int32(random.index))
        try setGlobal(0x450c34, Int32(random.counter))
        if mode == 0 {
            try observe(.resumeMusic)
            if try globals.integer(at: 0x44eed0-Self.globalBase, as: UInt8.self) != 0 {
                try observe(.musicPath)
                try music(&self)
            }
        }
        for slot in 20..<400 where try !active(slot) {
            try observe(.reconstruct(slot))
            try actors[slot].reconstructActor()
        }
        try observe(.resetInput)
        try resetOriginalInput()
    }

    /// Shared body of original 431c70; menu action 5 uses the same reset.
    mutating func resetOriginalInput() throws {
        for address in stride(from: 0x4513a4, through: 0x4513bc, by: 4) { try setGlobal(address, 0) }
        for slot in 0..<8 {
            try setGlobal(0x451320+slot*4, 0)
            let actor = try world.integer(at: 0x194+slot*4,as: UInt32.self)
            guard actor < actors.count else { throw Self.error("Input reset Actor binding") }
            for offset in [0xd3, 0xd2, 0xd1, 0xcf, 0xd0, 0xce, 0xcd] { try actors[Int(actor)].write(UInt8(0), at: offset) }
        }
        for address in 0x455378..<(0x455378+300) { try globals.write(UInt8(0x75), at: address-Self.globalBase) }
    }

    func active(_ slot: Int) throws -> Bool { try world.integer(at: 4+slot, as: UInt8.self) != 0 }
    func global(_ address: Int) throws -> Int32 { try globals.integer(at: address-Self.globalBase, as: Int32.self) }
    mutating func setGlobal(_ address: Int, _ value: Int32) throws { try globals.write(value, at: address-Self.globalBase) }
    static func error(_ text: String) -> OriginalLoaderError { .outsideVerifiedDomain("Match preparation: \(text)") }
}
