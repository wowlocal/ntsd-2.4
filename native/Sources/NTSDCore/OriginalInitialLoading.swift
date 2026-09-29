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

    /// 41bcd0..41bdce: the phase/pause prologue and, while a recording plays
    /// (450b84), its controls; signed 32-bit wrap/remainder is the original x86 rule.
    public static func begin(globals: inout OriginalStateRecord,
                             store: (Int, [UInt8]) throws -> Void = { _, _ in }) throws -> Bool {
        let base = OriginalMatchPreparation.globalBase
        guard globals.bytes.count == OriginalMatchPreparation.globalSize else {
            throw OriginalStateError.invalidStorage("Initial loading global extent")
        }
        var candidate = globals
        func write(_ value: UInt32, _ address: Int) throws {
            try candidate.write(value, at: address-base)
            try store(address,(0..<4).map { UInt8(truncatingIfNeeded:value >> ($0*8)) })
        }
        let phase = (try candidate.integer(at: 0x450b90-base, as: Int32.self) &+ 1) % 2
        try write(UInt32(bitPattern:phase),0x450b90)
        if phase == 0 {
            try write(candidate.integer(at: 0x44fb60-base, as: UInt32.self),0x450bfc)
            try write(candidate.integer(at: 0x44fcb0-base, as: UInt32.self),0x44fb60)
        }
        let paused = try candidate.integer(at: 0x450bfc-base, as: Int32.self) == 1
        if try candidate.integer(at: 0x450b84-base, as: Int32.self) != 0 { try playbackControls() }
        globals = candidate
        return paused

        /// 41bd31..41c04b: F6 toggles 44d030 (its key byte reset to "up").
        /// Left/Right take the playback camera (450b74) from the following
        /// camera (x 450bc4, speed 450bc8) and steer it by 5; Down gives it back.
        /// While taken, its x 450b7c advances by the speed 450b78, which decays
        /// to 6/7 (the camera step 450b7c/450b74 is OriginalWorldCamera's).
        func playbackControls() throws {
            func key(_ code: Int) throws -> UInt8 { try candidate.integer(at: 0x455378+code-base, as: UInt8.self) }
            func g(_ address: Int) throws -> Int32 { try candidate.integer(at: address-base, as: Int32.self) }
            func set(_ address: Int, _ value: Int32) throws { try write(UInt32(bitPattern: value), address) }
            if try key(0x75) == 0x64 {
                let toggled = 1 &- (try g(0x44d030))
                try candidate.write(UInt8(0x75), at: 0x4553ed-base); try store(0x4553ed, [0x75])
                try set(0x44d030, toggled)
            }
            let left = try key(0x25), right = try key(0x27)
            var speed: Int32
            if left == 0x64 || right == 0x64 {
                if try g(0x450b74) == 0 {
                    try set(0x450b7c, g(0x450bc4)); speed = try g(0x450bc8); try set(0x450b74, 1)
                } else { speed = try g(0x450b78) }
                if left == 0x64 { speed = speed &- 5 }
                if right == 0x64 { speed = speed &+ 5 }
            } else { speed = try g(0x450b78) }
            if try key(0x28) == 0x64 {
                try set(0x450b74, 0); try set(0x450b78, 0)
            } else if try g(0x450b74) == 0 {
                try set(0x450b78, 0)
            } else {
                try set(0x450b7c, g(0x450b7c) &+ speed)
                try set(0x450b78, (speed &* 6)/7)
            }
        }
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
                            audio: OriginalWaveRequest.Factory? = nil,
                            afterPrologue: (OriginalStateRecord, Bool) throws -> Void = { _, _ in },
                            afterCommonWave: (Int, OriginalWaveLoadResult, OriginalStateRecord) throws -> Void = { _, _, _ in },
                            afterCommon: (OriginalStateRecord) throws -> Void = { _ in },
                            afterCatalog: (OriginalStateRecord) throws -> Void = { _ in },
                            afterCatalogContinuation: (OriginalInitialLoadingContinuation) throws -> Void = { _ in },
                            afterPool: (OriginalWorldBootstrap, Bool) throws -> Void = { _, _ in },
                            afterInterfaceBitmap: (Int, OriginalStateRecord) throws -> Void = { _, _ in },
                            observeCommon: (OriginalInitialSoundEvent) throws -> Void = { _ in },
                            observeProgress: @escaping (OriginalLoadingProgressEvent) throws -> Void = { _ in },
                            observeInterface: (OriginalInterfaceEvent) throws -> Void = { _ in }) throws -> Self {
        let base = OriginalMatchPreparation.globalBase
        guard try initialGlobals.integer(at: 0x44d05c-base, as: Int32.self) == 1,
              try initialGlobals.integer(at: 0x458438-base, as: Int32.self) == 0 else {
            throw OriginalStateError.invalidStorage("First loading requires flag1 and an empty sound registry")
        }
        let prefix = try OriginalInitialLoadingCommon.load(globals:initialGlobals,targetSurface:targetSurface,
            fileSource:fileSource,platform:wavePlatform,audio:audio,afterPrologue:afterPrologue,
            afterWave:afterCommonWave,observe:observeCommon)
        var globals = prefix.globals
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
        let continuation = try OriginalInitialLoadingContinuation(prefix: prefix, resources: loaded, world: world, globals: globals)
        try afterCatalogContinuation(continuation)
        return try continuation.completeWithProvidedInterface(actorBacking: actorBacking,
            allocateInterface: allocateInterface, interfaceSource: interfaceSource, interfaceDevice: interfaceDevice,
            afterPool: afterPool, afterBitmap: afterInterfaceBitmap, observeInterface: observeInterface)
    }
}
