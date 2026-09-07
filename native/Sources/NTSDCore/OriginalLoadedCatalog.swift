import Foundation

public struct OriginalCatalogChildObservation {
    public let request: OriginalCatalogLoadRequest
    public let decoded: String
    public let initialChecksum: UInt32, checksum: UInt32
    public let bitmapCount: Int, soundCount: Int, frameOccurrences: Int
    public let soundBytes: [UInt8]
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
                initialChecksum: UInt32 = 0, fill: UInt8 = 0xa5,
                parentBacking: [Int: OriginalStateRecord], backgroundBacking: [OriginalStateRecord],
                stageBacking: [OriginalStateRecord],
                fileSource: (String) throws -> [UInt8], bitmapSource: (String) throws -> OriginalBitmapInput,
                frameAllocation: (OriginalFrameAllocationKind, Int) throws -> UInt32? = { _, _ in nil },
                onChild: (OriginalCatalogChildObservation) throws -> Void = { _ in },
                onStage: (String, Int, Int?, OriginalStateRecord) throws -> Void = { _, _, _, _ in }) throws {
        guard fileName.unicodeScalars.allSatisfy({ $0.value <= 255 }), backgroundBacking.count == 101,
              backgroundBacking.allSatisfy({ $0.bytes.count == OriginalBackgroundLoader.recordSize }),
              parentBacking[0x4d81060] == backgroundBacking[99], parentBacking[0x4d819f0] == backgroundBacking[100] else {
            throw OriginalStateError.invalidStorage("Loaded catalog backing/filename mismatch")
        }
        var resources = OriginalLoaderResources()
        resources.checksum = initialChecksum
        var objects: [OriginalLoadedObject] = [], backgrounds = backgroundBacking
        var stageLoader = try OriginalStageLoader(backing: stageBacking)
        let registry = try OriginalCatalogRegistry(source: source, fileName: fileName.unicodeScalars.map { UInt8($0.value) },
                                                   initialChecksum: initialChecksum, backing: parentBacking) { request, checksum in
            resources.checksum = checksum
            var decoded: String?, occurrences = 0
            switch request.kind {
            case .bitmap:
                let path = request.path!, input = try bitmapSource(path)
                guard input.path == path, request.index == resources.bitmaps.count else {
                    throw OriginalStateError.invalidStorage("Embedded bitmap request order/provider mismatch")
                }
                resources.bitmaps.append(try OriginalLoadedBitmap.construct(input, optional: false, fill: fill))
            case .progress:
                break // frozen-clock loading progress has no catalog-data effect
            case .object:
                let path = request.path!
                decoded = try OriginalDATDecoder.decode(fileSource(path), fileName: path, translation: translation)
                guard request.index == objects.count else { throw OriginalStateError.invalidStorage("Object ordinal differs") }
                var loader = OriginalObjectLoader(); loader.resources = resources
                objects.append(try loader.load(decoded: decoded!, id: request.id!, type: request.objectType!,
                                               headerBacking: Array(repeating: fill, count: 0x7a4), tailBacking: Array(repeating: fill, count: 0x3c),
                                               bitmapFill: fill, frameBacking: Array(repeating: fill, count: 400*0x178),
                                               frameAllocation: frameAllocation, bitmapSource: bitmapSource,
                                               onFrame: { _ in occurrences += 1 }))
                resources = loader.resources
            case .background:
                let path = request.path!, index = request.index!
                decoded = try OriginalDATDecoder.decode(fileSource(path), fileName: path, translation: translation)
                var loader = OriginalBackgroundLoader(); loader.resources = resources
                backgrounds[index] = try loader.parse(decoded: decoded!, backing: backgrounds[index], bitmapFill: fill, bitmapSource: bitmapSource)
                resources = loader.resources
            case .stages:
                let path = "data\\stage.dat"
                decoded = try OriginalDATDecoder.decode(fileSource(path), fileName: path, translation: translation)
                try stageLoader.load(decoded: decoded!, onCheckpoint: onStage)
            }
            if let decoded {
                try onChild(.init(request: request, decoded: decoded, initialChecksum: checksum, checksum: resources.checksum,
                                  bitmapCount: resources.bitmaps.count, soundCount: resources.sounds.count,
                                  frameOccurrences: occurrences, soundBytes: resources.sounds.bytes))
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
}
