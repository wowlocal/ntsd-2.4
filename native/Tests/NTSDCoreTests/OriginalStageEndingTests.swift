import XCTest
@testable import NTSDCore

/// STAGE_ENDING.md: whole 437220 against `tools/oracle_stage_ending.py`
/// (Unicorn, real 437220 and 431c70, declared inputs). Every case compares the
/// ordered 43f010/415160/431c70 calls with their arguments, every written
/// global and Actor byte, and that nothing else is written.
final class OriginalStageEndingTests: XCTestCase {
    private struct Fixture: Decodable {
        struct Case: Decodable {
            struct Event: Decodable { let kind: String; let this: UInt32?; let arguments: [UInt32]? }
            let label: String, globals: [String: Int32], keys: [[UInt8]], events: [Event]
            let globalWrites: [[Int]], actorWrites: [[Int]]
        }
        let exeSHA256: String, frames: [[Int32]], target: UInt32, fillTarget: UInt32, bitmap: UInt32
        let resetRanges: [[Int]], actorFill: UInt8, cases: [Case]
    }

    func testWholeEndingScreenMatchesTheOriginal() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "original-stage-ending", withExtension: "json", subdirectory: "Fixtures"))
        let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
        XCTAssertEqual(fixture.exeSHA256, "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        XCTAssertEqual(fixture.cases.count, 581)
        let helpers = OriginalWarSetupNativeTests(), base = OriginalMatchPreparation.globalBase
        let template = try helpers.initial(helpers.catalog())
        var ending = try OriginalStateRecord(bytes: [UInt8](repeating: 0xa5, count: 0x1f50), defined: [Bool](repeating: false, count: 0x1f50))
        for (i, frame) in fixture.frames.enumerated() {
            for (field, value) in zip([0x10, 0x7e0, 0xfb0, 0x1780], frame) { try ending.write(value, at: field+i*4) }
        }
        var events = 0, writes = 0
        for c in fixture.cases {
            var state = template
            try state.globals.write(fixture.fillTarget, at: 0x455608-base)
            for range in fixture.resetRanges { for a in range[0]..<range[1] { try state.globals.write(UInt8(0xa5), at: a-base) } }
            for (address, value) in c.globals { try state.globals.write(value, at: Int(address.dropFirst(2), radix: 16)!-base) }
            for seat in 0..<8 {
                try state.world.write(UInt32(seat), at: 0x194+seat*4)
                state.actors[seat] = try OriginalStateRecord(bytes: [UInt8](repeating: fixture.actorFill, count: OriginalStateRecord.actorSize),
                                                             defined: [Bool](repeating: true, count: OriginalStateRecord.actorSize))
                try state.actors[seat].write(c.keys[seat][0], at: 0xd1); try state.actors[seat].write(c.keys[seat][1], at: 0xca)
            }
            let before = state
            var observed: [OriginalStageEnding.Event] = []
            try OriginalStageEnding.advance(state: &state, target: fixture.target, ending: ending) { observed.append($0) }
            let expected: [OriginalStageEnding.Event] = try c.events.map { e in
                let a = (e.arguments ?? []).map { Int32(bitPattern: $0) }
                switch e.kind {
                case "draw":
                    XCTAssertEqual(e.this, fixture.bitmap, c.label); XCTAssertEqual(a[3], 0, c.label); XCTAssertEqual(a[4], 0, c.label)
                    return .draw(x: a[0], y: a[1], frame: a[2], target: UInt32(bitPattern: a[5]))
                case "fill": return .fill(x: a[0], y: a[1], width: a[2], height: a[3], color: UInt32(bitPattern: a[4]))
                case "resetInput": return .resetInput
                default: throw OriginalStateError.invalidStorage("Unknown oracle event \(e.kind)")
                }
            }
            XCTAssertEqual(observed, expected, c.label); events += expected.count
            var expectedGlobals = before.globals.bytes
            for w in c.globalWrites { expectedGlobals[w[0]-base] = UInt8(w[1]) }
            XCTAssertEqual(state.globals.bytes, expectedGlobals, c.label)
            for seat in 0..<8 {
                var bytes = before.actors[seat].bytes
                for w in c.actorWrites where w[0] == seat { bytes[w[1]] = UInt8(w[2]) }
                XCTAssertEqual(state.actors[seat].bytes, bytes, "\(c.label) seat \(seat)")
            }
            for index in 8..<state.actors.count where state.actors[index] != before.actors[index] { XCTFail("\(c.label): Actor \(index) written") }
            XCTAssertEqual(state.world, before.world, c.label)
            writes += c.globalWrites.count + c.actorWrites.count
        }
        XCTAssertEqual(events, 7171)
        print("Stage ending matches original: \(fixture.cases.count) cases, \(events) calls, \(writes) written bytes")
    }
}
