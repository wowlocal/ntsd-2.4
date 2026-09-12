import Foundation

public struct OriginalCatalogChildObservation {
    public let request: OriginalCatalogLoadRequest
    public let decoded: String
    public let initialChecksum: UInt32, checksum: UInt32
    public let bitmapCount: Int, soundCount: Int, frameOccurrences: Int
    public let soundBytes: [UInt8]
    /// Values produced by the completed child, before the parent stores its
    /// result. These snapshots do not publish a complete catalog or file session.
    public let object: OriginalLoadedObject?
    public let bitmaps: [OriginalLoadedBitmap]
    public let frameAllocations: [OriginalFrameAllocation]
}

/// Actual child loaders composed at the original 4122f0 request boundaries.
/// This is loading state, not selected-match initialization or a game loop.
public struct OriginalLoadedCatalog {
    let resources: OriginalLoaderResources
    public let registry: OriginalCatalogRegistry
    public let objects: [OriginalLoadedObject]
    public let backgrounds: [OriginalStateRecord]
    public let stages: [OriginalStateRecord]
    public let bitmaps: [OriginalLoadedBitmap]
    public let frameAllocations: [OriginalFrameAllocation]
    public let checksum: UInt32, soundCount: Int
    public let soundBytes: [UInt8]

    /// Bitmap provider resolves both file paths and the four embedded EXE keys.
    /// Raw Frame addresses may be supplied by a reference allocator; the native
    /// default uses a logical 32-bit arena, never host pointers.
    public init(source: [UInt8], fileName: String, translation: OriginalFileTranslation,
                initialChecksum: UInt32 = 0, initialSoundBytes: [UInt8]? = nil, fill: UInt8 = 0xa5,
                parentBacking: [Int: OriginalStateRecord], backgroundBacking: [OriginalStateRecord],
                stageBacking: [OriginalStateRecord],
                fileSource: (String) throws -> [UInt8], bitmapSource: (String) throws -> OriginalBitmapInput,
                constructBitmap: OriginalLoadedBitmap.Constructor? = nil,
                frameAllocation: (OriginalFrameAllocationKind, Int) throws -> UInt32? = { _, _ in nil },
                weaponSoundAllocation: OriginalWeaponSoundPathAllocation.Allocate = { _, _ in nil },
                onNewSound: (String, OriginalSoundRegistration) throws -> Void = { _, _ in },
                onMirror: (OriginalBitmapMirrorRequest) throws -> Void = { _ in },
                onProgress: (OriginalLoadingProgress.Request) throws -> Void = { _ in },
                onChecksum: (_ path: String, _ checksum: UInt32) throws -> Void = { _, _ in },
                onSoundCache: ([UInt8], Int) throws -> Void = { _, _ in },
                onMessage: (_ path: String, _ checksum: UInt32) throws -> Void = { _, _ in },
                onChild: (OriginalCatalogChildObservation) throws -> Void = { _ in },
                onStage: (String, Int, Int?, OriginalStateRecord) throws -> Void = { _, _, _, _ in }) throws {
        try self.init(source: { source }, fileName: fileName, translation: translation,
            initialChecksum: initialChecksum, initialSoundBytes: initialSoundBytes, fill: fill,
            parentBacking: parentBacking, backgroundBacking: backgroundBacking, stageBacking: stageBacking,
            fileSource: fileSource, bitmapSource: bitmapSource, constructBitmap: constructBitmap,
            frameAllocation: frameAllocation, weaponSoundAllocation: weaponSoundAllocation, onNewSound: onNewSound, onMirror: onMirror,
            onProgress: onProgress, onChecksum: onChecksum, onSoundCache: onSoundCache,
            onMessage: onMessage, onChild: onChild, onStage: onStage)
    }

    /// Deferred file delivery preserves the parent's built-in-resource/time/open
    /// order. No original CRT or file handle is part of the native runtime.
    public init(source: () throws -> [UInt8], fileName: String, translation: OriginalFileTranslation,
                initialChecksum: UInt32 = 0, initialSoundBytes: [UInt8]? = nil, fill: UInt8 = 0xa5,
                parentBacking: [Int: OriginalStateRecord], backgroundBacking: [OriginalStateRecord],
                stageBacking: [OriginalStateRecord],
                fileSource: (String) throws -> [UInt8], bitmapSource: (String) throws -> OriginalBitmapInput,
                constructBitmap: OriginalLoadedBitmap.Constructor? = nil,
                frameAllocation: (OriginalFrameAllocationKind, Int) throws -> UInt32? = { _, _ in nil },
                weaponSoundAllocation: OriginalWeaponSoundPathAllocation.Allocate = { _, _ in nil },
                onNewSound: (String, OriginalSoundRegistration) throws -> Void = { _, _ in },
                onMirror: (OriginalBitmapMirrorRequest) throws -> Void = { _ in },
                onProgress: (OriginalLoadingProgress.Request) throws -> Void = { _ in },
                onChecksum: (_ path: String, _ checksum: UInt32) throws -> Void = { _, _ in },
                onSoundCache: ([UInt8], Int) throws -> Void = { _, _ in },
                onMessage: (_ path: String, _ checksum: UInt32) throws -> Void = { _, _ in },
                onChild: (OriginalCatalogChildObservation) throws -> Void = { _ in },
                onStage: (String, Int, Int?, OriginalStateRecord) throws -> Void = { _, _, _, _ in }) throws {
        try self.init(source: source, fileName: fileName, translation: translation,
            initialChecksum: initialChecksum, initialSoundBytes: initialSoundBytes, fill: fill,
            parentBacking: parentBacking, backgroundBacking: backgroundBacking, stageBacking: stageBacking,
            fileSource: fileSource, bitmapSource: bitmapSource, constructBitmap: constructBitmap,
            frameAllocation: frameAllocation, weaponSoundAllocation: weaponSoundAllocation, onNewSound: onNewSound, onMirror: onMirror,
            onProgress: onProgress, onChecksum: onChecksum, onSoundCache: onSoundCache,
            onMessage: onMessage, onChild: onChild, onStage: onStage, fileSession: nil)
    }

    /// Load all children from one owned file session. Every parser consumes the
    /// bytes produced by its preceding decoder; registry close precedes Stage.
    /// This result publishes catalog and files together. Callers must also stage
    /// graphics/audio/global callbacks until the enclosing iteration commits.
    public static func loadWithFiles(files: OriginalLoadingFiles, fileName: String,
                initialChecksum: UInt32 = 0, initialSoundBytes: [UInt8]? = nil, fill: UInt8 = 0xa5,
                parentBacking: [Int: OriginalStateRecord], backgroundBacking: [OriginalStateRecord],
                stageBacking: [OriginalStateRecord],
                fileSource: @escaping (String) throws -> [UInt8],
                fileAllocation: @escaping OriginalLoadingFiles.Allocate,
                onFile: @escaping OriginalLoadingFiles.Observe = { _ in },
                bitmapSource: (String) throws -> OriginalBitmapInput,
                constructBitmap: OriginalLoadedBitmap.Constructor? = nil,
                frameAllocation: (OriginalFrameAllocationKind, Int) throws -> UInt32? = { _, _ in nil },
                weaponSoundAllocation: OriginalWeaponSoundPathAllocation.Allocate = { _, _ in nil },
                onNewSound: (String, OriginalSoundRegistration) throws -> Void = { _, _ in },
                onMirror: (OriginalBitmapMirrorRequest) throws -> Void = { _ in },
                onProgress: (OriginalLoadingProgress.Request) throws -> Void = { _ in },
                onChecksum: (_ path: String, _ checksum: UInt32) throws -> Void = { _, _ in },
                onSoundCache: ([UInt8], Int) throws -> Void = { _, _ in },
                onMessage: (_ path: String, _ checksum: UInt32) throws -> Void = { _, _ in },
                onChild: (OriginalCatalogChildObservation) throws -> Void = { _ in },
                onStage: (String, Int, Int?, OriginalStateRecord) throws -> Void = { _, _, _, _ in }) throws -> (catalog: Self, files: OriginalLoadingFiles) {
        let session = FileSession(files: files, source: fileSource, allocate: fileAllocation, observe: onFile)
        let translation = files.translation
        let catalog = try Self(source: { try session.openCatalog(fileName) }, fileName: fileName, translation: translation,
            initialChecksum: initialChecksum, initialSoundBytes: initialSoundBytes, fill: fill,
            parentBacking: parentBacking, backgroundBacking: backgroundBacking, stageBacking: stageBacking,
            fileSource: fileSource, bitmapSource: bitmapSource, constructBitmap: constructBitmap,
            frameAllocation: frameAllocation, weaponSoundAllocation: weaponSoundAllocation, onNewSound: onNewSound, onMirror: onMirror,
            onProgress: onProgress, onChecksum: onChecksum, onSoundCache: onSoundCache,
            onMessage: onMessage, onChild: onChild, onStage: onStage, fileSession: session)
        return (catalog, session.files)
    }

    private init(source: () throws -> [UInt8], fileName: String, translation: OriginalFileTranslation,
                initialChecksum: UInt32 = 0, initialSoundBytes: [UInt8]? = nil, fill: UInt8 = 0xa5,
                parentBacking: [Int: OriginalStateRecord], backgroundBacking: [OriginalStateRecord],
                stageBacking: [OriginalStateRecord],
                fileSource: (String) throws -> [UInt8], bitmapSource: (String) throws -> OriginalBitmapInput,
                constructBitmap: OriginalLoadedBitmap.Constructor? = nil,
                frameAllocation: (OriginalFrameAllocationKind, Int) throws -> UInt32? = { _, _ in nil },
                weaponSoundAllocation: OriginalWeaponSoundPathAllocation.Allocate = { _, _ in nil },
                onNewSound: (String, OriginalSoundRegistration) throws -> Void = { _, _ in },
                onMirror: (OriginalBitmapMirrorRequest) throws -> Void = { _ in },
                onProgress: (OriginalLoadingProgress.Request) throws -> Void = { _ in },
                onChecksum: (_ path: String, _ checksum: UInt32) throws -> Void = { _, _ in },
                onSoundCache: ([UInt8], Int) throws -> Void = { _, _ in },
                onMessage: (_ path: String, _ checksum: UInt32) throws -> Void = { _, _ in },
                onChild: (OriginalCatalogChildObservation) throws -> Void = { _ in },
                onStage: (String, Int, Int?, OriginalStateRecord) throws -> Void = { _, _, _, _ in }, fileSession: FileSession?) throws {
        guard fileName.unicodeScalars.allSatisfy({ $0.value <= 255 }), backgroundBacking.count == 101,
              backgroundBacking.allSatisfy({ $0.bytes.count == OriginalBackgroundLoader.recordSize }),
              parentBacking[0x4d81060] == backgroundBacking[99], parentBacking[0x4d819f0] == backgroundBacking[100] else {
            throw OriginalStateError.invalidStorage("Loaded catalog backing/filename mismatch")
        }
        var resources = OriginalLoaderResources()
        resources.checksum = initialChecksum
        if let initialSoundBytes { resources.sounds = try OriginalSoundRegistry(bytes: initialSoundBytes) }
        var objects: [OriginalLoadedObject] = [], backgrounds = backgroundBacking
        var stageLoader = try OriginalStageLoader(backing: stageBacking)
        let registry = try OriginalCatalogRegistry(source: source, fileName: fileName.unicodeScalars.map { UInt8($0.value) },
                                                   initialChecksum: initialChecksum, backing: parentBacking,
                                                   beforeRead: { try onProgress(.catalogOpen) },
                                                   onRead: fileSession.map { session in { try session.readCatalog($0) } },
                                                   onChecksum: { try onChecksum(fileName, $0) },
                                                   onClose: { try fileSession?.closeCatalog() }) { request, checksum in
            resources.checksum = checksum
            var decoded: String?, occurrences = 0
            func parseFile(_ path: String, kind: OriginalCatalogLoadRequest.Kind,
                           consume: (String, ((Int) throws -> Void)?) throws -> Void) throws {
                if let fileSession { try fileSession.parse(path, kind: kind) { text, read in
                    decoded = text; try consume(text, read)
                } } else {
                    let text = try OriginalDATDecoder.decode(fileSource(path), fileName: path, translation: translation)
                    decoded = text; try consume(text, nil)
                }
            }
            switch request.kind {
            case .bitmap:
                let path = request.path!
                guard request.index == resources.bitmaps.count else {
                    throw OriginalStateError.invalidStorage("Embedded bitmap request order/provider mismatch")
                }
                if let constructBitmap {
                    resources.bitmaps.append(try .checkedConstruction(constructBitmap(path, false, Array(repeating: fill, count: 0x1f50)), path: path, optional: false))
                } else {
                    let input = try bitmapSource(path)
                    guard input.path == path else { throw OriginalStateError.invalidStorage("Embedded bitmap request order/provider mismatch") }
                    resources.bitmaps.append(try .construct(input, optional: false, fill: fill))
                }
            case .progress:
                try onProgress(.update) // Caller owns timer/global/device progress state.
            case .object:
                let path = request.path!
                try parseFile(path, kind: .object) { text, read in
                guard request.index == objects.count else { throw OriginalStateError.invalidStorage("Object ordinal differs") }
                var loader = OriginalObjectLoader(); loader.resources = resources
                objects.append(try loader.load(decoded: text, id: request.id!, type: request.objectType!,
                                               headerBacking: Array(repeating: fill, count: 0x7a4), tailBacking: Array(repeating: fill, count: 0x3c),
                                               bitmapFill: fill, frameBacking: Array(repeating: fill, count: 400*0x178),
                                               frameAllocation: frameAllocation, weaponSoundAllocation: weaponSoundAllocation, bitmapSource: bitmapSource,
                                               constructBitmap: constructBitmap,
                                               onMirror: onMirror,
                                               onProgress: { try onProgress(.update) },
                                               onRead: read,
                                               onChecksum: { try onChecksum(path, $0) },
                                               onSoundCache: onSoundCache,
                                               onMessage: { try onMessage(path, $0) },
                                               onNewSound: { try onNewSound(path, $0) },
                                               onFrame: { _ in occurrences += 1 }))
                resources = loader.resources
                }
            case .background:
                let path = request.path!, index = request.index!
                try parseFile(path, kind: .background) { text, read in
                var loader = OriginalBackgroundLoader(); loader.resources = resources
                backgrounds[index] = try loader.parse(decoded: text, backing: backgrounds[index], bitmapFill: fill,
                                                       constructBitmap: constructBitmap, onRead: read,
                                                       onChecksum: { try onChecksum(path, $0) }, bitmapSource: bitmapSource)
                resources = loader.resources
                }
            case .stages:
                let path = "data\\stage.dat"
                try parseFile(path, kind: .stages) { text, read in
                    try stageLoader.load(decoded: text, onRead: read, onCheckpoint: onStage)
                }
            }
            if let decoded {
                try onChild(.init(request: request, decoded: decoded, initialChecksum: checksum, checksum: resources.checksum,
                                  bitmapCount: resources.bitmaps.count, soundCount: resources.sounds.count,
                                  frameOccurrences: occurrences, soundBytes: resources.sounds.bytes,
                                  object: request.kind == .object ? objects.last : nil,
                                  bitmaps: resources.bitmaps, frameAllocations: resources.frameHeap.allocations))
            }
            return resources.checksum
        }
        // The parent-only study binds known non-null pointers to ordinals (0 is
        // valid). Expose all loaded BG with the shared bitmap index+1 encoding so
        // a later BG consumer does not confuse resource zero with a null pointer.
        // The registry itself retains its established parent-only representation.
        backgrounds[99] = registry.records[0x4d81060]!
        for offset in [0x98c, 0x914, 0x918, 0x91c] {
            let ordinal = try backgrounds[99].integer(at: offset, as: UInt32.self)
            try backgrounds[99].write(ordinal + 1, at: offset)
        }
        backgrounds[100] = registry.records[0x4d819f0]!
        self.registry = registry; self.objects = objects; self.backgrounds = backgrounds; self.stages = stageLoader.records
        self.bitmaps = resources.bitmaps; self.frameAllocations = resources.frameHeap.allocations
        self.resources = resources
        self.checksum = registry.checksum; self.soundCount = resources.sounds.count; self.soundBytes = resources.sounds.bytes
    }
    private final class FileSession {
        var files: OriginalLoadingFiles
        let source: OriginalLoadingFiles.Source, allocate: OriginalLoadingFiles.Allocate, observe: OriginalLoadingFiles.Observe
        var catalog: UInt32?
        init(files: OriginalLoadingFiles, source: @escaping OriginalLoadingFiles.Source,
             allocate: @escaping OriginalLoadingFiles.Allocate, observe: @escaping OriginalLoadingFiles.Observe) {
            self.files = files; self.source = source; self.allocate = allocate; self.observe = observe
        }
        func openCatalog(_ path: String) throws -> [UInt8] {
            let token = try files.open(path, mode: "r", source: source, allocate: allocate, observe: observe)
            catalog = token
            return files.streams[token]!.input
        }
        func readCatalog(_ position: Int) throws {
            guard let catalog else { throw OriginalStateError.invalidStorage("Catalog file is unavailable") }
            try files.scannerAccess(catalog, position: position, observe: observe)
        }
        func closeCatalog() throws {
            guard let catalog else { throw OriginalStateError.invalidStorage("Catalog file is unavailable") }
            try files.close(catalog, observe: observe)
        }
        func parse(_ path: String, kind: OriginalCatalogLoadRequest.Kind,
                   consume: (String, @escaping (Int) throws -> Void) throws -> Void) throws {
            switch kind {
            case .object: try files.withObject(path, source: source, allocate: allocate, observe: observe, consume: consume)
            case .background: try files.withBackground(path, source: source, allocate: allocate, observe: observe, consume: consume)
            case .stages: try files.withStage(source: source, allocate: allocate, observe: observe, consume: consume)
            default: throw OriginalStateError.invalidStorage("Non-file catalog child")
            }
        }
    }

}
