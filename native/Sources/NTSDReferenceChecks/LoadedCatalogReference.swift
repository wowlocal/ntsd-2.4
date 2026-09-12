import Foundation
import Compression
import CryptoKit
import NTSDCore

/// Full catalog comparison against a single execution of 4122f0 and its children.
/// Only established header/registry/device pointers are rebound. Raw Frame words,
/// including partially overwritten pointers, are compared without normalization.
public enum LoadedCatalogReference {
    public struct Result {
        public let objects: Int, backgrounds: Int, stages: Int, phases: Int, frames: Int
        public let bitmaps: Int, allocations: Int, bytes: Int, checksum: UInt32
        public let fileEvents: Int, weaponSoundAllocations: Int, weaponSoundBytes: Int
    }
    private struct Blob: Decodable { let count: Int, deflate: String }
    private struct Record: Decodable { let initial: String, bytes: String, defined: String }
    private struct Bitmap: Decodable { let address: UInt32, path: String, optional: UInt32, storage: Record }
    private struct Allocation: Decodable { let address: UInt32, size: Int, kind: String, caller: String, storage: Record }
    private struct Child: Decodable {
        let kind: OriginalCatalogLoadRequest.Kind, path: String, index: Int?, id: Int32?, objectType: Int32?
        let source: String, decoded: String, initialChecksum: UInt32, checksum: UInt32
        let bitmapStart: Int, bitmapEnd: Int, allocationStart: Int, allocationEnd: Int
        let soundCount: Int, soundBytes: String, frameOccurrences: Int?, storage: Record?
    }
    private struct Event: Decodable {
        let kind: String, bitmap: Int?, normalAddress: UInt32?
        let path: String?, mode: String?, handle: UInt32?
        let present: Bool?, width: Int32?, height: Int32?
    }
    private struct Corpus: Decodable {
        let exeSHA256: String, crtSHA256: String, fileName: String, source: String
        let translation: OriginalFileTranslation, bitmapFill: UInt8, surfaceAddress: UInt32
        let objectAddresses: [UInt32], initialChecksum: UInt32, checksum: UInt32
        let outerTokens: [String], requests: [OriginalCatalogLoadRequest], children: [Child]
        let regions: [Int: Record], stages: [Record], stageIDs: [Int], phaseIDs: [[Int]]
        let bitmaps: [Bitmap], allocations: [Allocation], soundCount: Int, soundBytes: String
        let assets: [OriginalBitmapInput], events: [Event], blobs: [String: Blob]
    }
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Loaded catalog reference: \(text)") }
    public static func compare(_ data: Data, initialSoundBytes: [UInt8]? = nil,
                               useLoadingFiles: Bool = false,
                               onFile: @escaping OriginalLoadingFiles.Observe = { _ in },
                               onLoadingFiles: (OriginalLoadingFiles) throws -> Void = { _ in },
                               onProgress: (OriginalLoadingProgress.Request) throws -> Void = { _ in },
                               onNewSound: (String, OriginalSoundRegistration) throws -> Void = { _, _ in },
                               onLoaded: (OriginalLoadedCatalog) throws -> Void = { _ in }) throws -> Result {
        struct Packed: Decodable { let deflate: String?, count: Int?, sha256: String? }
        let packed = try JSONDecoder().decode(Packed.self, from: data)
        var decoded = data
        if let encoded = packed.deflate {
            guard let count = packed.count, (1...50_000_000).contains(count), let source = Data(base64Encoded: encoded) else { throw error("Invalid fixture envelope") }
            var output = [UInt8](repeating: 0, count: count+1)
            let size = output.withUnsafeMutableBufferPointer { dst in
                source.withUnsafeBytes { src in
                    compression_decode_buffer(dst.baseAddress!, dst.count, src.bindMemory(to: UInt8.self).baseAddress!, src.count, nil, COMPRESSION_ZLIB)
                }
            }
            guard size == count else { throw error("Fixture envelope length") }
            output.removeLast(); decoded = Data(output)
            guard SHA256.hash(data: decoded).map({ String(format: "%02x", $0) }).joined() == packed.sha256 else { throw error("Fixture envelope digest") }
        }
        let corpus = try JSONDecoder().decode(Corpus.self, from: decoded)
        guard corpus.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c",
              corpus.crtSHA256 == "c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d",
              corpus.stages.count == 60, !corpus.children.isEmpty else { throw error("Unknown or incomplete corpus") }
        func blob(_ digest: String) throws -> [UInt8] {
            guard let item = corpus.blobs[digest], (0...2_000_000).contains(item.count),
                  let packed = Data(base64Encoded: item.deflate) else { throw error("Invalid/missing blob") }
            var output = [UInt8](repeating: 0, count: item.count + 1)
            let count = output.withUnsafeMutableBufferPointer { dst in
                packed.withUnsafeBytes { src in
                    compression_decode_buffer(dst.baseAddress!, dst.count, src.bindMemory(to: UInt8.self).baseAddress!, src.count, nil, COMPRESSION_ZLIB)
                }
            }
            guard count == item.count else { throw error("DEFLATE length mismatch") }
            output.removeLast()
            guard SHA256.hash(data: Data(output)).map({ String(format: "%02x", $0) }).joined() == digest else { throw error("Blob digest mismatch") }
            return output
        }
        func record(_ item: Record, initial: Bool = false) throws -> OriginalStateRecord {
            let bytes = try blob(initial ? item.initial : item.bytes)
            if initial { return try .init(bytes: bytes, defined: Array(repeating: false, count: bytes.count)) }
            let mask = try blob(item.defined)
            guard mask.allSatisfy({ $0 <= 1 }) else { throw error("Invalid mask") }
            return try .init(bytes: bytes, defined: mask.map { $0 == 1 })
        }
        var bytes = 0, weaponSoundAllocations = 0, weaponSoundBytes = 0
        func check(_ actual: OriginalStateRecord, _ expected: OriginalStateRecord, _ label: String) throws {
            guard actual.bytes.count == expected.bytes.count else { throw error("\(label): record size") }
            if let offset = actual.bytes.indices.first(where: { actual.bytes[$0] != expected.bytes[$0] || actual.defined[$0] != expected.defined[$0] }) {
                throw error("\(label)+\(String(offset, radix: 16)): byte/mask mismatch (\(actual.bytes[offset])/\(actual.defined[offset]) vs \(expected.bytes[offset])/\(expected.defined[offset]))")
            }
            bytes += actual.bytes.count
        }
        let bgBase = 0x4d45db0, bgSize = OriginalBackgroundLoader.recordSize
        let parent = try Dictionary(uniqueKeysWithValues: OriginalCatalogRegistry.regionSizes.keys.map { offset in
            guard let item = corpus.regions[offset] else { throw error("Missing parent region") }
            return (offset, try record(item, initial: true))
        })
        let backgrounds = try (0..<101).map { index -> OriginalStateRecord in
            guard let item = corpus.regions[bgBase+index*bgSize] else { throw error("Missing BG region") }
            return try record(item, initial: true)
        }
        // Initial stage allocations are uniform in this corpus; retain explicit
        // bytes/masks and share immutable backing until each sparse initializer.
        var initialCache: [String: OriginalStateRecord] = [:]
        let stageBacking = try corpus.stages.map { item -> OriginalStateRecord in
            if let cached = initialCache[item.initial] { return cached }
            let value = try record(item, initial: true); initialCache[item.initial] = value; return value
        }
        let assets = Dictionary(uniqueKeysWithValues: corpus.assets.map { ($0.path, $0) })
        let frameKinds: [String: OriginalFrameAllocationKind] = ["0x410935": .sound, "0x4114ab": .interactions, "0x411b85": .bodies]
        let frameAllocations = corpus.allocations.filter { frameKinds[$0.caller] != nil }
        let weaponSlots = ["0x40fbe6": 0, "0x40fc65": 1, "0x40fce8": 2]
        let bitmapAddresses = corpus.bitmaps.map(\.address)
        guard Set(bitmapAddresses).count == bitmapAddresses.count,
              Set(corpus.objectAddresses).count == corpus.objectAddresses.count else { throw error("Aliased allocation identities") }
        var childIndex = 0, fileIndex = 0, allocationIndex = 0, occurrences = 0
        var stageIDs: [Int] = [], phaseIDs: [[Int]] = []
        // These older raw corpora declare fopen/fclose and image metadata.
        // Their CRT scanner runs separately. Compare only that observed order;
        // native refill buffers are explicit inputs, not old private FILE proof.
        let ordered = corpus.events.filter { ["open", "close", "bitmap-load"].contains($0.kind) }
        var orderedIndex = 0, openIndex = 0, allocationOrder = 0, bitmapOrder = 0
        func nextAllocation(_ kind: String, _ count: Int) throws -> Allocation {
            guard allocationOrder < corpus.allocations.count else { throw error("Extra allocation") }
            let expected = corpus.allocations[allocationOrder]
            guard expected.kind == kind, expected.size == count else { throw error("Allocation order/size at \(allocationOrder)") }
            allocationOrder += 1
            return expected
        }
        let opens = corpus.events.filter { $0.kind == "open" }
        if useLoadingFiles && opens.isEmpty { throw error("File comparison requires the immutable full raw corpus") }
        func nextEvent(_ kind: String) throws -> Event {
            guard orderedIndex < ordered.count, ordered[orderedIndex].kind == kind else {
                throw error("File/bitmap event \(orderedIndex): expected \(kind)")
            }
            defer { orderedIndex += 1 }
            return ordered[orderedIndex]
        }
        func fileSource(_ path: String) throws -> [UInt8] {
            guard fileIndex < corpus.children.count, corpus.children[fileIndex].path == path else { throw error("File request order: \(path)") }
            defer { fileIndex += 1 }
            return try blob(corpus.children[fileIndex].source)
        }
        func bitmapSource(_ path: String) throws -> OriginalBitmapInput {
            guard let input = assets[path] else { throw error("Missing bitmap boundary \(path)") }
            return input
        }
        func observedBitmapSource(_ path: String) throws -> OriginalBitmapInput {
            let input = try bitmapSource(path)
            if useLoadingFiles {
                let allocation = try nextAllocation("bitmap", 0x1f50)
                guard bitmapOrder < bitmapAddresses.count, allocation.address == bitmapAddresses[bitmapOrder] else { throw error("Bitmap allocation identity/order") }
                bitmapOrder += 1
                let expected = try nextEvent("bitmap-load")
                guard expected.path == path, expected.present == input.present,
                      expected.width == input.width, expected.height == input.height else {
                    throw error("Bitmap metadata/file interleaving: \(path)")
                }
            }
            return input
        }
        func frameAllocation(_ kind: OriginalFrameAllocationKind, _ size: Int) throws -> UInt32? {
            guard allocationIndex < frameAllocations.count else { throw error("Extra Frame allocation") }
            let expected = frameAllocations[allocationIndex]
            guard frameKinds[expected.caller] == kind, expected.kind == "malloc", expected.size == size else { throw error("Frame allocation order/size") }
            if useLoadingFiles {
                let allocation = try nextAllocation("malloc", size)
                guard allocation.address == expected.address, allocation.caller == expected.caller else { throw error("Frame allocation interleaving") }
            }
            allocationIndex += 1
            return expected.address
        }
        func weaponSoundAllocation(_ slot: Int, _ count: Int) throws -> UInt32? {
            guard useLoadingFiles else { return nil }
            let expected = try nextAllocation("malloc", count)
            guard weaponSlots[expected.caller] == slot else { throw error("Weapon path allocation slot/order") }
            return expected.address
        }
        func onChild(_ observation: OriginalCatalogChildObservation) throws {
            guard childIndex < corpus.children.count else { throw error("Extra child") }
            let item = corpus.children[childIndex], request = observation.request
            guard request.kind == item.kind, request.index == item.index, request.id == item.id, request.objectType == item.objectType,
                  (request.kind == .stages || request.path == item.path),
                  observation.initialChecksum == item.initialChecksum, observation.checksum == item.checksum,
                  observation.bitmapCount == item.bitmapEnd, observation.soundCount == item.soundCount,
                  observation.soundBytes == (try blob(item.soundBytes)),
                  observation.decoded.unicodeScalars.map({ UInt8($0.value) }) == (try blob(item.decoded)),
                  observation.frameOccurrences == (item.frameOccurrences ?? 0) else { throw error("Child \(childIndex) \(item.path): order/decoder/shared state") }
            occurrences += observation.frameOccurrences
            childIndex += 1
        }
        func onStage(_ kind: String, _ stage: Int, _ phase: Int?, _ record: OriginalStateRecord) throws {
            if kind == "initialized" { stageIDs.append(stage) }
            else if kind == "phase", let phase { phaseIDs.append([stage, phase]) }
            else { throw error("Unknown Stage checkpoint") }
        }
        let catalog: OriginalLoadedCatalog
        if useLoadingFiles {
            var registryDelivered = false
            let result = try OriginalLoadedCatalog.loadWithFiles(files: .init(translation: corpus.translation), fileName: corpus.fileName,
                initialChecksum: corpus.initialChecksum, initialSoundBytes: initialSoundBytes, fill: corpus.bitmapFill,
                parentBacking: parent, backgroundBacking: backgrounds, stageBacking: stageBacking,
                fileSource: { path in
                    if !registryDelivered {
                        guard path == corpus.fileName else { throw error("Registry source order") }
                        registryDelivered = true
                        return try blob(corpus.source)
                    }
                    // A temporary can only come from this native session's writes.
                    guard path != OriginalLoadingFiles.temporaryPath else { throw error("Expected temporary requested as input") }
                    return try fileSource(path)
                }, fileAllocation: { path, mode in
                    guard openIndex < opens.count else { throw error("Extra file allocation") }
                    let expected = opens[openIndex]
                    guard expected.path == path, expected.mode == mode, let token = expected.handle else {
                        throw error("File allocation order: \(path)/\(mode)")
                    }
                    openIndex += 1
                    // Old fopen handles are opaque identities. These disjoint
                    // native buffer tokens do not assert the old CRT ABI.
                    return .init(token: token, buffer: 0x54001000 + UInt32(openIndex)*0x20000,
                                 descriptor: token, capacity: 65536, readLimit: 4096)
                }, onFile: { event in
                    switch event.kind {
                    case .openFile:
                        let expected = try nextEvent("open")
                        guard event.path == expected.path, event.mode == expected.mode,
                              event.arguments == [expected.handle!] else { throw error("File open request") }
                    case .closeReadFile, .closeOutputDescriptor:
                        let expected = try nextEvent("close")
                        guard event.arguments.last == expected.handle, event.result == 0 else { throw error("File close request") }
                    case .readFile, .writeFile: break // Not observed by this older source adapter.
                    }
                    try onFile(event)
                }, bitmapSource: observedBitmapSource, frameAllocation: frameAllocation, weaponSoundAllocation: weaponSoundAllocation,
                onNewSound: onNewSound, onProgress: onProgress, onChild: onChild, onStage: onStage)
            guard registryDelivered, orderedIndex == ordered.count, openIndex == opens.count,
                  allocationOrder == corpus.allocations.count, bitmapOrder == bitmapAddresses.count,
                  result.files.streams.count == opens.count,
                  result.files.streams.values.allSatisfy({ $0.closed }),
                  result.files.files[OriginalLoadingFiles.temporaryPath] == Array("Do not erase this file.".utf8) else {
                throw error("Whole catalog file completion")
            }
            catalog = result.catalog
            try onLoadingFiles(result.files)
        } else {
            catalog = try OriginalLoadedCatalog(source: blob(corpus.source), fileName: corpus.fileName, translation: corpus.translation,
                initialChecksum: corpus.initialChecksum, initialSoundBytes: initialSoundBytes, fill: corpus.bitmapFill,
                parentBacking: parent, backgroundBacking: backgrounds, stageBacking: stageBacking,
                fileSource: fileSource, bitmapSource: bitmapSource, frameAllocation: frameAllocation, weaponSoundAllocation: weaponSoundAllocation,
                onNewSound: onNewSound, onProgress: onProgress, onChild: onChild, onStage: onStage)
        }
        guard childIndex == corpus.children.count, fileIndex == childIndex, allocationIndex == frameAllocations.count,
              catalog.registry.requests == corpus.requests, catalog.registry.outerTokens.map({ $0.map { String(format: "%02x", $0) }.joined() }) == corpus.outerTokens,
              catalog.checksum == corpus.checksum, catalog.soundCount == corpus.soundCount, catalog.soundBytes == (try blob(corpus.soundBytes)),
              stageIDs == corpus.stageIDs, phaseIDs == corpus.phaseIDs,
              catalog.objects.count == corpus.objectAddresses.count, catalog.bitmaps.count == corpus.bitmaps.count else { throw error("Final catalog inventory/shared state") }
        func bindBitmap(_ storage: inout OriginalStateRecord, at offset: Int, ordinal: Bool = false, nullable: Bool = false) throws {
            guard storage.defined[offset..<(offset+4)].allSatisfy({ $0 }) else { return }
            let pointer = try storage.integer(at: offset, as: UInt32.self)
            if nullable && pointer == 0 { return }
            guard pointer != 0, let index = bitmapAddresses.firstIndex(of: pointer) else { throw error("Unknown bitmap pointer") }
            try storage.write(UInt32(index + (ordinal ? 0 : 1)), at: offset)
        }
        for offset in [0, 0x4d82380] {
            var expected = try record(corpus.regions[offset]!)
            if offset == 0 {
                for (index, address) in corpus.objectAddresses.enumerated() {
                    guard try expected.integer(at: index*4, as: UInt32.self) == address else { throw error("Object table pointer") }
                    try expected.write(UInt32(index), at: index*4)
                }
            }
            try check(catalog.registry.records[offset]!, expected, "parent \(offset)")
        }
        for index in 0..<101 {
            var expected = try record(corpus.regions[bgBase+index*bgSize]!)
            if index == 99 {
                var parentRecord = expected
                for offset in [0x98c, 0x914, 0x918, 0x91c] {
                    try bindBitmap(&parentRecord, at: offset, ordinal: true)
                    try bindBitmap(&expected, at: offset)
                }
                try check(catalog.registry.records[0x4d81060]!, parentRecord, "parent BG99")
            } else if index == 100 {
                try check(catalog.registry.records[0x4d819f0]!, expected, "parent BG100")
            } else if index != 100 {
                try bindBitmap(&expected, at: 0x98c, nullable: true)
                for i in 0..<30 { try bindBitmap(&expected, at: 0x914+i*4, nullable: true) }
            }
            try check(catalog.backgrounds[index], expected, "BG \(index)")
        }
        let allocationMap = Dictionary(uniqueKeysWithValues: corpus.allocations.map { ($0.address, $0) })
        for item in corpus.children where item.kind == .object {
            let object = catalog.objects[item.index!]
            let pathAllocations = corpus.allocations[item.allocationStart..<item.allocationEnd].filter { weaponSlots[$0.caller] != nil }
            guard object.weaponSoundAllocations.count == pathAllocations.count else { throw error("Weapon path allocation inventory") }
            for (actual, source) in zip(object.weaponSoundAllocations, pathAllocations) {
                guard actual.slot == weaponSlots[source.caller], actual.token == (useLoadingFiles ? source.address : nil),
                      actual.storage == (try record(source.storage)) else { throw error("Weapon path allocation full bytes/masks") }
                weaponSoundAllocations += 1; weaponSoundBytes += actual.storage.bytes.count
            }
            var expected = try record(item.storage!)
            for offset in [0x6fc, 0x728] { try bindBitmap(&expected, at: offset) }
            let sheets = Int(try expected.integer(at: 0x498, as: Int32.self))
            guard (1...10).contains(sheets) else { throw error("Object sheets") }
            for slot in 1...sheets { try bindBitmap(&expected, at: 0x750+slot*4); try bindBitmap(&expected, at: 0x778+slot*4) }
            for ordinal in 0..<3 {
                let pointer = try expected.integer(at: 0x98+ordinal*4, as: UInt32.self)
                if pointer == 0 {
                    guard object.weaponSoundPaths[ordinal] == nil else { throw error("Weapon sound nullability") }
                } else {
                    guard let allocation = allocationMap[pointer], allocation.kind == "malloc" else { throw error("Weapon string allocation") }
                    let raw = try blob(allocation.storage.bytes).prefix { $0 != 0 }
                    guard object.weaponSoundPaths[ordinal]?.unicodeScalars.map({ UInt8($0.value) }) == Array(raw) else { throw error("Weapon string bytes") }
                    try expected.write(UInt32(ordinal+1), at: 0x98+ordinal*4)
                }
            }
            let records = [object.header] + object.frameStorage + [object.nameTail]
            try check(.init(bytes: records.flatMap(\.bytes), defined: records.flatMap(\.defined)), expected, item.path)
        }
        for index in 0..<60 { try check(catalog.stages[index], record(corpus.stages[index]), "Stage \(index)") }
        for (index, bitmap) in corpus.bitmaps.enumerated() {
            let actual = catalog.bitmaps[index]
            var expected = try record(bitmap.storage)
            guard actual.input.path == bitmap.path, actual.optional == (bitmap.optional != 0),
                  try expected.integer(at: 0, as: UInt32.self) == (actual.input.present ? corpus.surfaceAddress : 0) else { throw error("Bitmap \(index) boundary") }
            try expected.write(UInt32(actual.input.present ? 1 : 0), at: 0)
            try check(actual.storage, expected, "bitmap \(index)")
            let blits = corpus.events.filter { $0.kind == "mirror-blit" && $0.bitmap == index }
            let origin = blits.first?.normalAddress.flatMap { bitmapAddresses.firstIndex(of: $0) }
            guard blits.count <= 1, actual.mirroredFrom == origin, blits.isEmpty || origin != nil else { throw error("Mirror request \(index)") }
        }
        guard catalog.frameAllocations.count == frameAllocations.count else { throw error("Frame heap count") }
        for (index, expected) in frameAllocations.enumerated() {
            let actual = catalog.frameAllocations[index]
            guard actual.address == expected.address, actual.kind == frameKinds[expected.caller] else { throw error("Frame heap identity") }
            try check(actual.storage, record(expected.storage), "Frame heap \(index)")
        }
        try onLoaded(catalog)
        return .init(objects: catalog.objects.count, backgrounds: corpus.children.filter { $0.kind == .background }.count,
                     stages: stageIDs.count, phases: phaseIDs.count, frames: occurrences, bitmaps: catalog.bitmaps.count,
                     allocations: catalog.frameAllocations.count, bytes: bytes, checksum: catalog.checksum,
                     fileEvents: useLoadingFiles ? opens.count*2 : 0,
                     weaponSoundAllocations: weaponSoundAllocations, weaponSoundBytes: weaponSoundBytes)
    }
}
