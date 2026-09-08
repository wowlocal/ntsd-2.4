import Foundation
import NTSDCore

/// CRT-generated tables are native inputs to the existing catalog/match/replay
/// comparison. Expected original tables are only compared, never installed.
public enum RandomInitializationReference {
    public struct Result {
        public var match = MatchPreludeReference.Result()
        public var tables = 0, seedCalls = 0, tableCalls = 0, interveningCalls = 0, bytes = 0
    }
    private struct Blob: Decodable { let count: Int, deflate: String }
    private struct Call: Decodable { let before: UInt32, after: UInt32, result: UInt32? }
    private struct Initialization: Decodable {
        let milliseconds: UInt32?, interveningDrawCount: Int, seed: Call?
        let beforeState: UInt32, afterState: UInt32, intervening: [Call], tableCalls: [Call]
        let beforeGlobals: String, afterGlobals: String, caller: String
        let preservedRegisters: [UInt32], stackAfter: UInt32, timerCalls: Int
    }
    private struct Write: Decodable { let address: UInt32, bytes: String }
    private struct Case: Decodable {
        let label: String, randomInitialization: Initialization
        let stimulus: [Write], replayStimulus: [Write]
    }
    private struct Source: Decodable { let kind: String }
    private struct Corpus: Decodable {
        let crtInitialState: UInt32, globalInitial: String, randomSource: Source
        let cases: [Case], blobs: [String: Blob]
    }
    private static func error(_ message: String) -> OriginalStateError {
        .invalidStorage("Random initialization reference: \(message)")
    }

    public static func compare(loaded: Data, corpora: [Data]) throws -> Result {
        let inputs = try corpora.map { try JSONDecoder().decode(Corpus.self, from: MatchPreparationReference.unpack($0)) }
        func blob(_ corpus: Corpus, _ key: String) throws -> [UInt8] {
            guard let value = corpus.blobs[key], value.count == OriginalMatchPreparation.globalSize else { throw error("Global blob") }
            let bytes = try MatchPreparationReference.inflate(value.deflate, count: value.count)
            guard MatchPreparationReference.digest(Data(bytes)) == key else { throw error("Global digest") }
            return bytes
        }
        for corpus in inputs {
            guard corpus.crtInitialState == 1, corpus.randomSource.kind == "PE/BSS, then real CRT-generated table" else {
                throw error("Initial CRT provenance")
            }
            let initial = try blob(corpus, corpus.globalInitial)
            for (address, count) in [(0x44ff90, 3001), (0x450bcc, 4), (0x450c34, 4)] {
                let start = address-OriginalMatchPreparation.globalBase
                guard initial[start..<(start+count)].allSatisfy({ $0 == 0 }) else { throw error("Initial RNG BSS") }
            }
            // All later table bytes must be produced by the implementation.
            // Tail-byte replay controls and index/counter stimuli stay explicit.
            for item in corpus.cases {
                for write in item.stimulus+item.replayStimulus {
                    guard write.bytes.utf8.count % 2 == 0 else { throw error("Stimulus width") }
                    let end = UInt64(write.address)+UInt64(write.bytes.utf8.count/2)
                    guard end <= 0x44ff90 || write.address >= 0x450b48 else { throw error("Supplied table bytes") }
                }
            }
        }
        var generators = [OriginalCRTRandom](repeating: .init(), count: inputs.count)
        var result = Result()
        result.match = try MatchPreludeReference.compare(loaded: loaded, corpora: corpora, beforePrelude: { corpusIndex, caseIndex, state in
            let corpus = inputs[corpusIndex], item = corpus.cases[caseIndex], rng = item.randomInitialization
            func check(_ key: String) throws {
                let expected = try blob(corpus, key)
                guard state.globals.bytes == expected, state.globals.defined.allSatisfy({ $0 }) else {
                    let offset = expected.indices.first { state.globals.bytes[$0] != expected[$0] || !state.globals.defined[$0] }!
                    throw error("\(item.label) globals+\(String(offset, radix: 16)): byte/mask mismatch")
                }
                result.bytes += expected.count
            }
            func draw(_ call: Call, using generator: inout OriginalCRTRandom) throws {
                guard generator.state == call.before else { throw error("CRT draw before state") }
                let value = generator.next()
                guard value == call.result, generator.state == call.after else { throw error("CRT draw result/after state") }
            }
            try check(rng.beforeGlobals)
            guard generators[corpusIndex].state == rng.beforeState,
                  rng.caller == ["0x427a2c", "0x427a71"][caseIndex % 2],
                  rng.preservedRegisters == [0x11111111, 0x22222222, 0x33333333, 0x44444444],
                  rng.stackAfter == 0x1000f000, rng.tableCalls.count == 3000,
                  rng.interveningDrawCount == rng.intervening.count else { throw error("State/caller/ABI witness") }
            if let milliseconds = rng.milliseconds {
                guard let seed = rng.seed, seed.result == nil, seed.before == generators[corpusIndex].state,
                      rng.timerCalls == 1 else { throw error("Startup srand witness") }
                try generators[corpusIndex].seedFromStartup(milliseconds: milliseconds, globals: &state.globals)
                guard generators[corpusIndex].state == seed.after else { throw error("Seed state") }
                result.seedCalls += 1
            } else {
                guard rng.seed == nil, rng.timerCalls == 0 else { throw error("Unexpected reseed") }
            }
            for call in rng.intervening { try draw(call, using: &generators[corpusIndex]) }
            // Independently compare every actual DLL result/state, then the EXE
            // table-writing function and its complete globals/masks.
            var trace = generators[corpusIndex]
            for call in rng.tableCalls { try draw(call, using: &trace) }
            try generators[corpusIndex].rebuildGameTable(globals: &state.globals)
            guard generators[corpusIndex] == trace, trace.state == rng.afterState else { throw error("Table final CRT state") }
            try check(rng.afterGlobals)
            result.tables += 1; result.tableCalls += rng.tableCalls.count
            result.interveningCalls += rng.intervening.count
        })
        return result
    }
}
