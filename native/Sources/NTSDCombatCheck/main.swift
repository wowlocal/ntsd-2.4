import Foundation
import NTSDCore

struct Corpus: Decodable {
    var headers: [Fields], definitions: [[String]], voiceDefinitions: [String], random: OriginalRandom, cases: [Case]
    var randomSamples: [RandomSample]
    struct RandomSample: Decodable { var range: Int, value: Int, index: Int, counter: Int }
    struct Case: Decodable {
        var label: String, initial: [[String: Double]], inputs: [[UInt8]], states: [MeleeState]
    }
}
do {
    let corpus = try JSONDecoder().decode(Corpus.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
    var count = 0
    var random = corpus.random
    for sample in corpus.randomSamples {
        guard random.next(sample.range) == sample.value, random.index == sample.index, random.counter == sample.counter else {
            fputs("Original RNG mismatch\n", stderr); exit(1)
        }
    }
    for test in corpus.cases {
        let initial = try test.initial.enumerated().map { i, changes -> FighterState in
            var state = FighterState()
            state.x = Double(450 + 35*i); state.ix = Int(state.x); state.facing = i; state.renderFacing = i
            var values = try JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as! [String: Any]
            for (key,value) in changes { values[key] = value }
            for (integer,fp) in [("ix","x"),("iy","y"),("iz","z")] { values[integer] = Int((values[fp] as! NSNumber).doubleValue) }
            values["renderFrame"] = values["frame"]
            return try JSONDecoder().decode(FighterState.self, from: JSONSerialization.data(withJSONObject: values))
        }
        var engine = try OriginalMelee(headers: corpus.headers, definitions: corpus.definitions, voiceDefinitions: corpus.voiceDefinitions, random: corpus.random, initial: initial)
        for (tick, masks) in test.inputs.enumerated() {
            let actual = try engine.tick(masks.map(FighterInput.init(rawValue:)))
            let expected = test.states[tick]
            guard actual == expected else {
                let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
                print("Mismatch \(test.label) tick \(tick)")
                print("actual", String(data: try encoder.encode(actual), encoding: .utf8)!)
                print("expected", String(data: try encoder.encode(expected), encoding: .utf8)!)
                exit(1)
            }
            count += 1
        }
    }
    print("Exact original combat comparison: \(count) ticks, \(corpus.cases.count) sequences; \(corpus.randomSamples.count) RNG samples")
} catch { fputs("Combat check failed: \(error)\n", stderr); exit(1) }
