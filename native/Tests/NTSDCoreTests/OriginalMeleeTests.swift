import Foundation
import XCTest
@testable import NTSDCore

final class OriginalMeleeTests: XCTestCase {
    private struct Corpus: Decodable {
        let exeSHA256: String, headers: [Fields], definitions: [[String]], voiceDefinitions: [String]
        let projectileDefinitions: [ProjectileDefinition]?
        let random: OriginalRandom, randomSamples: [Sample], cases: [Case]
        struct Sample: Decodable { let range: Int, value: Int, index: Int, counter: Int }
        struct Case: Decodable {
            let localPlayer: Int?
            let label: String, initial: [[String: Double]], inputs: [[UInt8]], states: [MeleeState]
        }
    }
    private func corpus(_ name: String = "original-combat") throws -> Corpus {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try JSONDecoder().decode(Corpus.self, from: Data(contentsOf: url))
    }
    private func engine(_ corpus: Corpus, initial: [[String: Double]]) throws -> OriginalMelee {
        let states = try initial.enumerated().map { i, changes -> FighterState in
            var state = FighterState()
            state.x = Double(450 + 35 * i); state.facing = i; state.renderFacing = i
            var values = try JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as! [String: Any]
            for (key, value) in changes { values[key] = value }
            for (integer, fp) in [("ix", "x"), ("iy", "y"), ("iz", "z")] {
                values[integer] = Int((values[fp] as! NSNumber).doubleValue)
            }
            values["renderFrame"] = values["frame"]
            return try JSONDecoder().decode(FighterState.self, from: JSONSerialization.data(withJSONObject: values))
        }
        return try OriginalMelee(headers: corpus.headers, definitions: corpus.definitions,
                                 voiceDefinitions: corpus.voiceDefinitions, random: corpus.random, initial: states, projectileDefinitions: corpus.projectileDefinitions)
    }
    func testMeleeAgainstOriginalX86() throws {
        let reference = try corpus()
        XCTAssertEqual(reference.exeSHA256, "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        var count = 0
        for test in reference.cases {
            var world = try engine(reference, initial: test.initial)
            XCTAssertEqual(test.inputs.count, test.states.count)
            for (tick, masks) in test.inputs.enumerated() {
                let actual = try world.tick(masks.map(FighterInput.init(rawValue:)))
                XCTAssertEqual(actual, test.states[tick], "\(test.label), tick \(tick)")
                guard actual == test.states[tick] else { return }
                count += 1
            }
        }
        XCTAssertEqual(count, 3_709)
        XCTAssertEqual(reference.cases.count, 466)
    }
    func testProjectilesAgainstOriginalX86() throws {
        let reference = try corpus("original-projectiles")
        XCTAssertEqual(reference.exeSHA256, "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        var count = 0
        for test in reference.cases {
            var world = try engine(reference, initial: test.initial)
            world.selectPlayer(test.localPlayer ?? 0)
            XCTAssertEqual(test.inputs.count, test.states.count)
            for (tick, masks) in test.inputs.enumerated() {
                let actual = try world.tick(masks.map(FighterInput.init(rawValue:)))
                XCTAssertEqual(actual, test.states[tick], "\(test.label), tick \(tick)")
                guard actual == test.states[tick] else { return }
                count += 1
            }
        }
        XCTAssertEqual(count, 2_010)
        XCTAssertEqual(reference.cases.count, 20)
    }
    func testUnsupportedAttackPreservesLiveObjectsAndSpentChakra() throws {
        let reference = try corpus("original-projectiles")
        var world = try engine(reference, initial: [["frame": 212, "y": -500, "x": 400], ["x": 580]])
        for tick in 0..<22 {
            let input: FighterInput = tick > 2 ? [] : [.defend, .left, .attack][tick]
            try world.tick([[], input])
        }
        XCTAssertEqual(world.state.projectiles?.count, 5)
        XCTAssertEqual(world.state.mpSpent, [0, 100])
        let before = world.state, random = world.random
        var untouched = world
        XCTAssertThrowsError(try world.tick([.attack, []]))
        XCTAssertEqual(world.state, before)
        XCTAssertEqual(world.random, random)
        XCTAssertEqual(try world.tick([[], []]), try untouched.tick([[], []]))
    }
    func testReplayRandomAgainstOriginalX86IncludingWraparound() throws {
        let reference = try corpus()
        var random = reference.random
        try random.validate()
        for (i, sample) in reference.randomSamples.enumerated() {
            XCTAssertEqual(random.next(sample.range), sample.value, "sample \(i)")
            XCTAssertEqual(random.index, sample.index, "sample \(i)")
            XCTAssertEqual(random.counter, sample.counter, "sample \(i)")
        }
        XCTAssertEqual(reference.randomSamples.count, 6_500)
    }
    func testUnsupportedTechniqueRollsBackBothActorsAndRandom() throws {
        let reference = try corpus()
        // Naruto consumes attack RNG first. Sasuke's airborne attack then
        // crosses the current domain. No partial tick may escape to the app.
        var world = try engine(reference, initial: [[:], ["frame": 212, "y": -20]])
        let before = world.state, random = world.random
        XCTAssertThrowsError(try world.tick([.attack, .attack]))
        XCTAssertEqual(world.state, before)
        XCTAssertEqual(world.random, random)
        // A rejected input must not poison the next valid tick's edge buffers.
        var fresh = try engine(reference, initial: [[:], ["frame": 212, "y": -20]])
        XCTAssertEqual(try world.tick([.attack, []]), try fresh.tick([.attack, []]))
    }
}
