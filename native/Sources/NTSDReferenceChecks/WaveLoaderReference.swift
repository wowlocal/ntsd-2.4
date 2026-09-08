import Foundation
import NTSDCore

public enum WaveLoaderReference {
    public struct Result {
        public var sources = 0, cases = 0, bytes = 0, events = 0, restores = 0, messages = 0, leaks = 0, invalidContinuations = 0
        public var startupPasses = 0, startupLoads = 0
    }
    private struct Blob: Decodable { let count: Int, deflate: String }
    private struct Record: Decodable { let bytes: String, defined: String }
    private struct Source: Decodable { let path: String, sha256: String, bytes: Int }
    private struct Case: Decodable {
        let label: String, path: [UInt8], file: String, input: OriginalWavePlatform
        let outputBefore: UInt32, outputAfter: UInt32, beforeGlobals: String, afterGlobals: String
        let temporary: Record?, temporaryLive: Bool, first: Record, second: Record?, format: Record?, descriptor: Record?
        let events: [OriginalWaveEvent], exit: OriginalWaveExit, returned: UInt32?, stackAfter: UInt32, savedRegisters: [UInt32]
    }
    private struct Startup: Decodable {
        let mode: UInt32, targetSurface: UInt32, beforeGlobals: String, afterGlobals: String, loads: [Case]
        let events: [OriginalInitialSoundEvent], endPC: String, stackAfter: UInt32
    }
    private struct Corpus: Decodable { let exeSHA256: String, sources: [Source], cases: [Case], startups: [Startup], blobs: [String: Blob] }
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Wave reference: \(text)") }
    public static func compare(_ input: Data) throws -> Result {
        let corpus = try JSONDecoder().decode(Corpus.self, from: MatchPreparationReference.unpack(input))
        guard corpus.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c",
              corpus.sources.count == 409, Set(corpus.sources.map(\.path)).count == 409 else { throw error("Source identity/inventory") }
        var result = Result(), cache: [String: [UInt8]] = [:]
        func blob(_ key: String) throws -> [UInt8] {
            if let raw = cache[key] { return raw }
            guard let b = corpus.blobs[key] else { throw error("Missing blob") }
            let raw = try MatchPreparationReference.inflate(b.deflate, count: b.count)
            guard MatchPreparationReference.digest(Data(raw)) == key else { throw error("Blob digest") }
            cache[key] = raw; return raw
        }
        func check(_ actual: OriginalStateRecord?, _ expected: Record?, _ label: String) throws {
            guard (actual == nil) == (expected == nil) else { throw error(label+" presence") }
            guard let actual, let expected else { return }
            let raw = try blob(expected.bytes), mask = try blob(expected.defined)
            guard raw.count == mask.count, raw.count == actual.bytes.count, mask.allSatisfy({ $0 < 2 }) else { throw error(label+" extent/mask") }
            if let index = raw.indices.first(where: { raw[$0] != actual.bytes[$0] || (mask[$0] == 1) != actual.defined[$0] }) {
                throw error("\(label)+\(String(index, radix: 16)): \(actual.bytes[index])/\(actual.defined[index]) vs \(raw[index])/\(mask[index])")
            }
            result.bytes += raw.count
        }
        for (index, item) in corpus.cases.enumerated() {
            let file = try blob(item.file)
            if index < corpus.sources.count {
                let source = corpus.sources[index]
                guard Array(source.path.utf8) == item.path, source.sha256 == item.file, source.bytes == file.count else { throw error("Original file provenance") }
                result.sources += 1
            }
            var events: [OriginalWaveEvent] = []
            let native = try OriginalWaveLoader.load(path: item.path, file: file, output: item.outputBefore, platform: item.input) { events.append($0) }
            guard native.output == item.outputAfter, native.returned == item.returned, native.exit == item.exit,
                  native.temporaryLive == item.temporaryLive else { throw error(item.label+" return/ownership") }
            if events != item.events {
                let i = zip(events, item.events).enumerated().first { $0.element.0 != $0.element.1 }?.offset
                throw error("\(item.label) event \(i.map(String.init) ?? "count"): \(i.map { String(describing: events[$0]) } ?? "\(events.count) vs \(item.events.count)")")
            }
            try check(native.temporary, item.temporary, item.label+" temporary")
            try check(native.first, item.first, item.label+" first")
            try check(native.second, item.second, item.label+" second")
            try check(native.format, item.format, item.label+" format")
            try check(native.descriptor, item.descriptor, item.label+" descriptor")
            let before = try blob(item.beforeGlobals), after = try blob(item.afterGlobals)
            guard before.count == OriginalMatchPreparation.globalSize, after.count == before.count else { throw error("Global extent") }
            var globals = try OriginalStateRecord(bytes: before, defined: [Bool](repeating: true, count: before.count))
            let offset = Int(item.input.destination)-OriginalMatchPreparation.globalBase
            guard try globals.integer(at: offset, as: UInt32.self) == item.outputBefore,
                  try globals.integer(at: 0x44eecc-OriginalMatchPreparation.globalBase, as: UInt32.self) == item.input.device else { throw error("Supplied input slots") }
            try globals.write(native.output, at: offset)
            guard globals.bytes == after else { throw error(item.label+" unrelated globals changed") }
            result.bytes += before.count*2
            if item.exit == .returned {
                guard item.stackAfter == 0x1000f008, item.savedRegisters == [0x11111111,0x22222222,0x33333333,0x44444444] else { throw error("Real ret4/ABI witness") }
            } else {
                guard item.input.createResult != 0, item.returned == nil, item.stackAfter == 0x1000ee3c else { throw error("Invalid CreateSoundBuffer continuation boundary") }
                result.invalidContinuations += 1
            }
            result.cases += 1; result.events += events.count
            result.restores += events.filter { $0.kind == .restore }.count
            result.messages += events.filter { $0.kind == .message }.count
            if native.temporaryLive { result.leaks += 1 }
        }
        let sourceHashes = Dictionary(uniqueKeysWithValues: corpus.sources.map { ($0.path,$0.sha256) })
        for startup in corpus.startups {
            let before = try blob(startup.beforeGlobals)
            var globals = try OriginalStateRecord(bytes: before, defined: [Bool](repeating: true, count: before.count))
            guard startup.loads.count == 18, startup.endPC == "0x41bfeb", startup.stackAfter == 0x1000effc,
                  try globals.integer(at: 0x458348-OriginalMatchPreparation.globalBase, as: UInt32.self) == startup.mode else { throw error("Startup context") }
            var events: [OriginalInitialSoundEvent] = []
            try OriginalInitialSoundLoading.load(globals: &globals, targetSurface: startup.targetSurface, fileSource: { path in
                guard let key = sourceHashes[path] else { throw error("Startup source path") }
                return try blob(key)
            }, platform: { index, path, destination in
                let item = startup.loads[index]
                guard item.path == Array(path.utf8), item.input.destination == destination,
                      item.file == sourceHashes[path] else { throw error("Startup source/destination") }
                return item.input
            }, afterWave: { index, native, state in
                let item = startup.loads[index]
                guard native.exit == .returned, native.returned == item.returned, native.output == item.outputAfter,
                      native.temporaryLive == item.temporaryLive,
                      item.stackAfter == 0x1000f000, item.savedRegisters == [0x11111111,0x22222222,startup.targetSurface,0x453f50] else { throw error("Startup child return/ownership/ABI") }
                try check(native.temporary, item.temporary, item.label+" startup temporary")
                try check(native.first, item.first, item.label+" startup first")
                try check(native.second, item.second, item.label+" startup second")
                try check(native.format, item.format, item.label+" startup format")
                try check(native.descriptor, item.descriptor, item.label+" startup descriptor")
                guard try state.bytes == blob(item.afterGlobals) else { throw error("Startup child globals") }
                result.bytes += state.bytes.count; result.startupLoads += 1
            }) { events.append($0) }
            guard events == startup.events else {
                let i = zip(events,startup.events).enumerated().first { $0.element.0 != $0.element.1 }?.offset
                throw error("Startup event at \(i.map(String.init) ?? "count")")
            }
            guard try globals.bytes == blob(startup.afterGlobals) else { throw error("Startup final globals") }
            result.bytes += globals.bytes.count*2; result.events += events.count; result.startupPasses += 1
            result.restores += events.filter { $0.wave?.kind == .restore }.count
            result.messages += events.filter { $0.wave?.kind == .message }.count
        }
        return result
    }
}
