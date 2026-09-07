import Foundation
import XCTest
@testable import NTSDCore

final class OriginalMovementTests: XCTestCase {
    private struct Corpus: Decodable {
        let exeSHA256: String, header: Fields, definitions: [String], cases: [Case]
        struct Case: Decodable {
            let label: String, initial: [String: Double], inputs: [UInt8], states: [MovementState]
        }
    }
    func testMovementAgainstOriginalX86() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "original-movement", withExtension: "json", subdirectory: "Fixtures"))
        let corpus = try JSONDecoder().decode(Corpus.self, from: Data(contentsOf: url))
        XCTAssertEqual(corpus.exeSHA256, "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        var count = 0
        for c in corpus.cases {
            var initial = MovementState()
            initial.x = c.initial["x"] ?? initial.x; initial.z = c.initial["z"] ?? initial.z
            initial.ix = Int(initial.x); initial.iz = Int(initial.z)
            var engine = try OriginalMovement(header: corpus.header, definitions: corpus.definitions, initial: initial)
            XCTAssertEqual(c.inputs.count, c.states.count)
            for (i, mask) in c.inputs.enumerated() {
                let actual = engine.tick(MovementInput(rawValue: mask))
                XCTAssertEqual(actual, c.states[i], "\(c.label), tick \(i)")
                count += 1
                if actual != c.states[i] { break }
            }
        }
        XCTAssertGreaterThan(count, 2_000)
    }

    private struct Presentation: Decodable {
        let clock: [Clock], layers: [Fields], background: [Background]
        struct Clock: Decodable { let start: UInt32, now: UInt32, baseline: UInt32, ticks: Int }
        struct Background: Decodable {
            let camera: Int, draws: [Draw]
            struct Draw: Decodable, Equatable { let layer: Int, x: Int, y: Int, transparency: Int }
        }
    }
    func testTimerAndDistrictDrawCallsAgainstX86() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "original-presentation", withExtension: "json", subdirectory: "Fixtures"))
        let corpus = try JSONDecoder().decode(Presentation.self, from: Data(contentsOf: url))
        var clock = OriginalClock(), previousStart: UInt32?
        for sample in corpus.clock {
            if previousStart != sample.start { clock.reset(); _ = clock.ticks(at: sample.start); previousStart = sample.start }
            XCTAssertEqual(clock.ticks(at: sample.now), sample.ticks, "now=\(sample.now)")
            XCTAssertEqual(clock.baseline, sample.baseline)
        }
        var layers = corpus.layers.map { OriginalBackgroundLayer(fields: $0) }
        for (tick, frame) in corpus.background.enumerated() {
            var actual: [Presentation.Background.Draw] = []
            for index in layers.indices {
                layers[index].tick()
                let layer = layers[index]
                if layer.visible {
                    actual.append(.init(layer: index, x: layer.x(camera: frame.camera), y: layer.fields.integer("y"),
                                        transparency: layer.fields.integer("transparency")))
                }
            }
            XCTAssertEqual(actual, frame.draws, "District tick \(tick)")
        }
    }
}
