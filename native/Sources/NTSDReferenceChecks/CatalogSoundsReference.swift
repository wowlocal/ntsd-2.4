import Foundation
import NTSDCore

public enum CatalogSoundsReference {
    public struct Result {
        public let catalog: LoadedCatalogReference.Result
        public let calls: Int, sources: Int, weaponCalls: Int, frameCalls: Int, bytes: Int, events: Int, restores: Int
    }
    private struct Blob: Decodable { let count: Int, deflate: String }
    private struct Record: Decodable { let bytes: String, defined: String }
    private struct Source: Decodable { let path: String, sha256: String, bytes: Int }
    private struct Call: Decodable {
        let index: Int, kind: OriginalSoundRegistration.Kind, path: [UInt8], file: String, input: OriginalWavePlatform
        let beforeGlobals: String, afterGlobals: String, cacheBefore: String, objectPath: String
        let outputBefore: UInt32, outputAfter: UInt32, returned: UInt32, entrySP: UInt32, stackAfter: UInt32, returnAddress: UInt32
        let savedBefore: [UInt32], savedAfter: [UInt32], temporary: Record?, temporaryLive: Bool
        let first: Record, second: Record?, format: Record?, descriptor: Record?, events: [OriginalWaveEvent], volume: [UInt32]
    }
    private struct Corpus: Decodable { let exeSHA256: String, calls: [Call], sources: [Source], blobs: [String: Blob], finalBuffers: String }
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Catalog sounds reference: \(text)") }
    public static func compare(catalog: Data, sounds: Data, initialSoundBytes: [UInt8]? = nil,
                               onProgress: (OriginalLoadingProgress.Request) throws -> Void = { _ in },
                               onLoaded: (OriginalLoadedCatalog, OriginalRegisteredSoundLoading) throws -> Void = { _, _ in }) throws -> Result {
        let corpus = try JSONDecoder().decode(Corpus.self, from: MatchPreparationReference.unpack(sounds))
        guard corpus.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c",
              !corpus.calls.isEmpty, Set(corpus.sources.map(\.path)).count == corpus.sources.count else { throw error("Source identity") }
        var blobs: [String: [UInt8]] = [:], calls = 0, bytes = 0, events = 0, restores = 0, weapons = 0
        var loader = OriginalRegisteredSoundLoading(), loadedCatalog: OriginalLoadedCatalog?
        func blob(_ key: String) throws -> [UInt8] {
            if let cached = blobs[key] { return cached }
            guard let b = corpus.blobs[key], (0...2_000_000).contains(b.count) else { throw error("Blob extent") }
            let raw = try MatchPreparationReference.inflate(b.deflate, count: b.count)
            guard MatchPreparationReference.digest(Data(raw)) == key else { throw error("Blob digest") }
            blobs[key] = raw; return raw
        }
        let sources = Dictionary(uniqueKeysWithValues: corpus.sources.map { ($0.path,$0) })
        for source in corpus.sources {
            guard try blob(source.sha256).count == source.bytes else { throw error("Source file length/hash") }
        }
        func check(_ actual: OriginalStateRecord?, _ expected: Record?, _ label: String) throws {
            guard (actual == nil) == (expected == nil) else { throw error(label+" presence") }
            guard let actual, let expected else { return }
            let raw = try blob(expected.bytes), mask = try blob(expected.defined)
            guard raw.count == actual.bytes.count, mask.count == raw.count, mask.allSatisfy({ $0 < 2 }) else { throw error(label+" extent/mask") }
            if let offset = raw.indices.first(where: { actual.bytes[$0] != raw[$0] || actual.defined[$0] != (mask[$0] == 1) }) {
                throw error("\(label)+\(String(offset,radix:16)): byte/mask mismatch")
            }
            bytes += raw.count
        }
        let compared = try LoadedCatalogReference.compare(catalog, initialSoundBytes: initialSoundBytes, onProgress: onProgress, onNewSound: { objectPath, request in
            guard calls < corpus.calls.count else { throw error("Extra native sound registration") }
            let item = corpus.calls[calls]
            guard item.index == calls, request.index == item.index, request.kind == item.kind,
                  request.path.unicodeScalars.map({ UInt8($0.value) }) == item.path, item.objectPath == objectPath,
                  sources[request.path]?.sha256 == item.file, request.cacheBefore == (try blob(item.cacheBefore)),
                  item.returnAddress == (item.kind == .weapon ? 0x40be1d : 0x410a4d),
                  item.stackAfter == item.entrySP+8, item.savedBefore.count == 4, item.savedAfter == item.savedBefore else {
                throw error("Registration\(calls): source/cache/kind/real caller ABI")
            }
            let before = try blob(item.beforeGlobals), after = try blob(item.afterGlobals)
            guard before.count == OriginalMatchPreparation.globalSize, after.count == before.count else { throw error("Global extent") }
            var globals = try OriginalStateRecord(bytes: before, defined: [Bool](repeating: true,count: before.count))
            let base = OriginalMatchPreparation.globalBase, destination = 0x452948+item.index*4
            guard try globals.integer(at: 0x458438-base, as: UInt32.self) == item.index,
                  try globals.integer(at: destination-base, as: UInt32.self) == item.outputBefore,
                  Array(before[(0x455638-base)..<(0x458438-base)]) == request.cacheBefore else { throw error("Real registration globals") }
            let device = try globals.integer(at: 0x44eecc-base, as: UInt32.self)
            var wave: [OriginalWaveEvent] = [], volume: [[UInt32]] = []
            try loader.load(request, device: device, outputBefore: item.outputBefore, platform: item.input,
                fileSource: { path in
                    guard path == request.path else { throw error("WAV file request") }
                    return try blob(item.file)
                }, onWave: { wave.append($0) }, onVolume: { volume.append($0) })
            guard let native = loader.buffers[request.index], native.exit == .returned, native.returned == item.returned,
                  native.output == item.outputAfter, native.temporaryLive == item.temporaryLive,
                  wave == item.events, volume == [item.volume] else { throw error("Sound\(calls) result/events/ownership") }
            try check(native.temporary,item.temporary,"Sound\(calls) temporary")
            try check(native.first,item.first,"Sound\(calls) first")
            try check(native.second,item.second,"Sound\(calls) second")
            try check(native.format,item.format,"Sound\(calls) format")
            try check(native.descriptor,item.descriptor,"Sound\(calls) descriptor")
            try globals.write(native.output,at: destination-base)
            guard globals.bytes == after else { throw error("Wave\(calls) changed unrelated globals") }
            bytes += before.count*2; events += wave.count+volume.count
            restores += wave.filter { $0.kind == .restore }.count
            if item.kind == .weapon { weapons += 1 }
            calls += 1
        }, onLoaded: { loaded in
            loadedCatalog = loaded
            guard loaded.soundCount == calls, calls == corpus.calls.count, loader.buffers.count == calls else { throw error("Final registry/buffer inventory") }
        })
        let final = try blob(corpus.finalBuffers)
        guard final.count == calls*4 else { throw error("Final buffer-array extent") }
        for index in 0..<calls {
            let expected = (0..<4).reduce(UInt32(0)) { $0 | UInt32(final[index*4+$1]) << ($1*8) }
            guard loader.buffers[index]?.output == expected else { throw error("Final buffer slot") }
        }
        bytes += final.count
        guard let loadedCatalog else { throw error("Missing native catalog") }
        try onLoaded(loadedCatalog, loader)
        return .init(catalog: compared, calls: calls, sources: sources.count, weaponCalls: weapons, frameCalls: calls-weapons,
                     bytes: bytes, events: events, restores: restores)
    }
}
