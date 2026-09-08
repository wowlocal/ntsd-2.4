import Foundation

public struct OriginalLoadingProgressEvent: Codable, Equatable {
    public enum Kind: String, Codable { case timeGetTime, Sleep }
    public let kind: Kind, arguments: [UInt32], returned: UInt32
}

/// The no-draw path of4242e0. Timer results are supplied by the platform.
/// Advancing into the animated loading screen is still outside this domain.
public enum OriginalLoadingProgress {
    public enum Request { case catalogOpen, update }
    public static func sample(time: () throws -> UInt32, observe: (OriginalLoadingProgressEvent) throws -> Void) throws -> UInt32 {
        let value = try time()
        try observe(.init(kind: .timeGetTime, arguments: [], returned: value))
        return value
    }
    public static func update(globals: inout OriginalStateRecord, time: () throws -> UInt32,
                              observe: (OriginalLoadingProgressEvent) throws -> Void = { _ in }) throws {
        let offset = 0x4511c0-OriginalMatchPreparation.globalBase
        func now() throws -> UInt32 {
            try sample(time: time,observe: observe)
        }
        var previous = try globals.integer(at: offset, as: UInt32.self)
        if previous == 0 { previous = try now(); try globals.write(previous, at: offset) }
        guard try now() &- previous <= 33 else {
            throw OriginalStateError.invalidStorage("Animated loading-progress continuation is not recovered")
        }
        let delay = Int32(bitPattern: try previous &- now() &+ 33)
        if delay > 0 { try observe(.init(kind: .Sleep, arguments: [UInt32(min(delay,5))], returned: 0)) }
    }
}

public struct OriginalInitialCatalogResources {
    public let catalog: OriginalLoadedCatalog, sounds: OriginalRegisteredSoundLoading
    public init(catalog: OriginalLoadedCatalog, sounds: OriginalRegisteredSoundLoading) {
        self.catalog = catalog; self.sounds = sounds
    }
}

/// Real first-loading41bc90..41c581, before input/menu/ordinary gameplay.
/// Resources remain owned by this result; no EXE addresses are host pointers.
public struct OriginalInitialLoading {
    public let globals: OriginalStateRecord, bootstrap: OriginalWorldBootstrap
    public let catalog: OriginalLoadedCatalog, registeredSounds: OriginalRegisteredSoundLoading
    public let commonSounds: [OriginalWaveLoadResult], interface: OriginalInitialInterfaceLoading
    public let paused: Bool, commands: [UInt8]

    /// Non-playback prologue; signed32-bit wrap/remainder is the original x86 rule.
    public static func begin(globals: inout OriginalStateRecord) throws -> Bool {
        let base = OriginalMatchPreparation.globalBase
        guard globals.bytes.count == OriginalMatchPreparation.globalSize,
              try globals.integer(at: 0x450b84-base, as: Int32.self) == 0 else {
            throw OriginalStateError.invalidStorage("Initial loading playback prologue is not recovered")
        }
        let phase = (try globals.integer(at: 0x450b90-base, as: Int32.self) &+ 1) % 2
        try globals.write(phase, at: 0x450b90-base)
        if phase == 0 {
            try globals.write(globals.integer(at: 0x44fb60-base, as: UInt32.self), at: 0x450bfc-base)
            try globals.write(globals.integer(at: 0x44fcb0-base, as: UInt32.self), at: 0x44fb60-base)
        }
        return try globals.integer(at: 0x450bfc-base, as: Int32.self) == 1
    }

    public static func load(globals initialGlobals: OriginalStateRecord, world: OriginalStateRecord,
                            actorBacking: [[UInt8]], targetSurface: UInt32,
                            fileSource: (String) throws -> [UInt8],
                            wavePlatform: (Int, String, UInt32) throws -> OriginalWavePlatform,
                            loadCatalog: (UInt32, [UInt8], (OriginalLoadingProgress.Request) throws -> Void) throws -> OriginalInitialCatalogResources,
                            time: @escaping () throws -> UInt32,
                            allocateInterface: (Int) throws -> OriginalInterfaceAllocation,
                            interfaceSource: (Int, String) throws -> OriginalBitmapInput,
                            interfaceDevice: (Int) throws -> (surface: UInt32, colorKeyResult: Int32),
                            afterPrologue: (OriginalStateRecord, Bool) throws -> Void = { _, _ in },
                            afterCommonWave: (Int, OriginalWaveLoadResult, OriginalStateRecord) throws -> Void = { _, _, _ in },
                            afterCommon: (OriginalStateRecord) throws -> Void = { _ in },
                            afterCatalog: (OriginalStateRecord) throws -> Void = { _ in },
                            afterPool: (OriginalWorldBootstrap, Bool) throws -> Void = { _, _ in },
                            afterInterfaceBitmap: (Int, OriginalStateRecord) throws -> Void = { _, _ in },
                            observeCommon: (OriginalInitialSoundEvent) throws -> Void = { _ in },
                            observeProgress: @escaping (OriginalLoadingProgressEvent) throws -> Void = { _ in },
                            observeInterface: (OriginalInterfaceEvent) throws -> Void = { _ in }) throws -> Self {
        let base = OriginalMatchPreparation.globalBase
        var globals = initialGlobals, common: [OriginalWaveLoadResult] = []
        guard try globals.integer(at: 0x44d05c-base, as: Int32.self) == 1,
              try globals.integer(at: 0x458438-base, as: Int32.self) == 0 else {
            throw OriginalStateError.invalidStorage("First loading requires flag1 and an empty sound registry")
        }
        let paused = try begin(globals: &globals)
        try afterPrologue(globals,paused)
        try OriginalInitialSoundLoading.load(globals: &globals, targetSurface: targetSurface,
            fileSource: fileSource, platform: wavePlatform, afterWave: { i, wave, state in
                common.append(wave); try afterCommonWave(i,wave,state)
            }, observe: observeCommon)
        try afterCommon(globals)
        // The cache span includes later globals (graphics device, present mode).
        // Supply their existing bytes; initializing the whole span to zero loses them.
        let checksum = try globals.integer(at: 0x44f620-base, as: UInt32.self)
        let cache = Array(globals.bytes[(0x455638-base)..<(0x458438-base)])
        let loaded = try loadCatalog(checksum,cache) { request in
            switch request {
            case .catalogOpen: _ = try OriginalLoadingProgress.sample(time: time, observe: observeProgress)
            case .update: try OriginalLoadingProgress.update(globals: &globals, time: time, observe: observeProgress)
            }
        }
        let catalog = loaded.catalog
        guard !catalog.objects.isEmpty, catalog.soundBytes.count == cache.count,
              catalog.soundCount == loaded.sounds.buffers.count else {
            throw OriginalStateError.invalidStorage("Loaded catalog and enabled sound ownership")
        }
        try globals.write(catalog.checksum, at: 0x44f620-base)
        for (i,byte) in catalog.soundBytes.enumerated() { try globals.write(byte,at: 0x455638-base+i) }
        try globals.write(Int32(catalog.soundCount),at: 0x458438-base)
        for index in 0..<catalog.soundCount {
            guard let wave = loaded.sounds.buffers[index] else { throw OriginalStateError.invalidStorage("Missing registered sound") }
            try globals.write(wave.output,at: 0x452948-base+index*4)
        }
        try afterCatalog(globals)
        var bootstrap = try OriginalWorldBootstrap(world: world, actorBacking: actorBacking)
        try afterPool(bootstrap,false)
        try bootstrap.activateStagingActors(firstObjectWord90: catalog.objects[0].header.integer(at: 0x90, as: Int32.self))
        try afterPool(bootstrap,true)
        var interface = OriginalInitialInterfaceLoading()
        try interface.load(globals: &globals, allocate: allocateInterface, source: interfaceSource,
                           deviceResult: interfaceDevice, afterBitmap: afterInterfaceBitmap, observe: observeInterface)
        return .init(globals: globals, bootstrap: bootstrap, catalog: catalog, registeredSounds: loaded.sounds,
                     commonSounds: common, interface: interface, paused: paused, commands: [UInt8](repeating: 0,count: 20))
    }
}
