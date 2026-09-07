import Foundation
import NTSDCore

struct Corpus: Decodable {
    var headers: [Fields], definitions: [[String]], voiceDefinitions: [String], random: OriginalRandom, cases: [Case]
    var randomSamples: [RandomSample]
    var projectileDefinitions: [ProjectileDefinition]?
    struct RandomSample: Decodable { var range: Int, value: Int, index: Int, counter: Int }
    struct Case: Decodable {
        var localPlayer: Int?
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
        var engine = try OriginalMelee(headers: corpus.headers, definitions: corpus.definitions, voiceDefinitions: corpus.voiceDefinitions, random: corpus.random, initial: initial, projectileDefinitions: corpus.projectileDefinitions)
        engine.selectPlayer(test.localPlayer ?? 0)
        for (tick, masks) in test.inputs.enumerated() {
            let actual = try engine.tick(masks.map(FighterInput.init(rawValue:)))
            let expected = test.states[tick]
            guard actual == expected else {
                let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
                print("Mismatch \(test.label) tick \(tick)")
                let a = try JSONSerialization.jsonObject(with: encoder.encode(actual))
                let e = try JSONSerialization.jsonObject(with: encoder.encode(expected))
                func differences(_ a: Any?, _ e: Any?, path: String) {
                    if let a = a as? [String:Any], let e = e as? [String:Any] {
                        for k in Set(a.keys).union(e.keys).sorted() { differences(a[k], e[k], path: path + "." + k) }
                    } else if let a = a as? [Any], let e = e as? [Any] {
                        if a.count != e.count { print(path, "count actual", a.count, "expected", e.count) }
                        for i in 0..<min(a.count,e.count) { differences(a[i],e[i],path: path + "[\(i)]") }
                    } else if String(describing: a) != String(describing: e) {
                        print(path, "actual", a ?? "missing", "expected", e ?? "missing")
                    }
                }
                differences(a,e,path: "state")
                exit(1)
            }
            count += 1
        }
    }
    print("Exact original combat comparison: \(count) ticks, \(corpus.cases.count) sequences; \(corpus.randomSamples.count) RNG samples")
} catch { fputs("Combat check failed: \(error)\n", stderr); exit(1) }
