import Foundation
import NTSDCore

/// Uses recorded stimuli, then compares the prelude before the existing complete
/// preparation/recording comparison. No expected post-state becomes native input.
public enum MatchPreludeReference {
    public struct Result {
        public var replay = ReplayInitializationReference.Result()
        public var cases = 0, bytes = 0, formatCalls = 0, soundCalls = 0, fills = 0
    }
    private struct Blob: Decodable { let count: Int, deflate: String }
    private struct Event: Decodable {
        let kind: String, loop: Bool?, resource: UInt32?, vtableOffset: Int?, arguments: [UInt32]?
        let x: Int32?, y: Int32?, width: Int32?, height: Int32?, color: UInt32?
        func native() throws -> OriginalMatchPreludeEvent {
            switch kind {
            case "local-time": return .localTime
            case "sound-request":
                guard let loop else { throw error("Missing sound loop") }
                return .soundRequest(loop: loop)
            case "sound-method":
                guard let resource, let vtableOffset, let arguments else { throw error("Missing sound method") }
                return .soundMethod(resource: resource, vtableOffset: vtableOffset, arguments: arguments)
            case "fill-rectangle":
                guard let resource, let x, let y, let width, let height, let color else { throw error("Missing rectangle") }
                return .fillRectangle(resource: resource, x: x, y: y, width: width, height: height, color: color)
            default: throw error("Unknown prelude event")
            }
        }
    }
    private struct Format: Decodable { let caller: String, format: String, result: Int, bytes: String }
    private struct Prelude: Decodable {
        let localTime: OriginalLocalTime, deviceResult: UInt32, beforeGlobals: String, afterGlobals: String
        let fileName: String, events: [Event], formats: [Format]
    }
    private struct Case: Decodable { let label: String, prelude: Prelude }
    private struct Corpus: Decodable { let dllSHA256: String, cases: [Case], blobs: [String: Blob] }
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Match prelude reference: \(text)") }

    public static func compare(loaded: Data, corpora: [Data],
                               onFinished: (Int, OriginalLoadedCatalog, inout OriginalMatchPreparation) throws -> Void = { _, _, _ in }) throws -> Result {
        let inputs = try corpora.map { try JSONDecoder().decode(Corpus.self, from: MatchPreparationReference.unpack($0)) }
        guard inputs.allSatisfy({ $0.dllSHA256 == "c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d" }) else { throw error("Unknown CRT") }
        var result = Result()
        result.replay = try ReplayInitializationReference.compare(loaded: loaded, corpora: corpora, onFinished: onFinished) { corpusIndex, caseIndex, state in
            let corpus = inputs[corpusIndex], item = corpus.cases[caseIndex], prelude = item.prelude
            func check(_ key: String) throws {
                guard let value = corpus.blobs[key], value.count == OriginalMatchPreparation.globalSize else { throw error("Global blob") }
                let bytes = try MatchPreparationReference.inflate(value.deflate, count: value.count)
                guard MatchPreparationReference.digest(Data(bytes)) == key else { throw error("Blob digest") }
                let expected = try OriginalStateRecord(bytes: bytes, defined: [Bool](repeating: true, count: bytes.count))
                if state.globals != expected {
                    let offset = bytes.indices.first { state.globals.bytes[$0] != bytes[$0] || !state.globals.defined[$0] }!
                    throw error("\(item.label) globals+\(String(offset, radix: 16)): byte/mask mismatch")
                }
                result.bytes += bytes.count
            }
            try check(prelude.beforeGlobals)
            var events: [OriginalMatchPreludeEvent] = []
            let name = try OriginalMatchPrelude.apply(globals: &state.globals, localTime: prelude.localTime) { events.append($0) }
            guard name == prelude.fileName, events == (try prelude.events.map { try $0.native() }) else { throw error("\(item.label): filename/event order") }
            // The CRT executes in the reference VM. Native output is compared
            // above; preserve the reference's formatting entry/return evidence.
            guard prelude.formats.count == 2 || prelude.formats.count == 3,
                  prelude.formats.first?.caller == "0x42d0a7", prelude.formats.first?.format == "%4d%02d%02d_%02d%02d%02d",
                  prelude.formats.last?.caller == "0x42d1b5", prelude.formats.last?.format == "%s.lfr",
                  prelude.formats.last?.result == name.utf8.count,
                  prelude.formats.last?.bytes == (Array(name.utf8)+[0]).map({ String(format: "%02x", $0) }).joined(),
                  [0, 0x80004005].contains(prelude.deviceResult) else { throw error("Formatting/device witness") }
            if prelude.formats.count == 3 {
                guard prelude.formats[1].caller == "0x42d0e6", prelude.formats[1].format == "%d" else { throw error("Stage sprintf") }
            }
            try check(prelude.afterGlobals)
            result.cases += 1; result.formatCalls += prelude.formats.count
            result.soundCalls += prelude.events.filter { $0.kind == "sound-method" }.count
            result.fills += prelude.events.filter { $0.kind == "fill-rectangle" }.count
        }
        return result
    }
}
