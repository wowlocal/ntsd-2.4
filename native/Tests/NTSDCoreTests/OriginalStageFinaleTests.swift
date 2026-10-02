import XCTest
import NTSDCore

/// GOAL_100.md P0a, the Stage finale. After the last stage group (5-x) the
/// stage logic writes menu 300 (437860's 438991, ported as
/// `OriginalMissionStage.setTail`; compared in the Mission corpus cases set-24
/// and set-229). 429730 then calls 437220 for menu 300 (429e7a..429e91), the
/// ENDING screen (OriginalStageEnding, compared in OriginalStageEndingTests).
/// This drives the whole finale through the character screen's dispatcher:
/// each page opens, a seat's Attack closes it, and after the last page the
/// menu returns to 10 with the input reset.
final class OriginalStageFinaleTests: XCTestCase {
    private struct Frame { var draws: [OriginalCharacterScreenDraw] = []; var fills = 0 }

    private func frame(_ state: inout OriginalMatchPreparation) throws -> (OriginalCharacterScreenExit, Frame) {
        var seen = Frame()
        let exit = try OriginalCharacterScreen.advance(state: &state, selectionAtEntry: 0, target: 0x26006000,
            input: .init(dcResult: 0, dc: 0x70000000, methodResult: -1, drawResults: [-1], shellResult: 33),
            fillBacking: [UInt8](repeating: 0xa5, count: 100), draw: { d, _ in seen.draws.append(d) },
            observe: { e in if e.kind == "fill" { seen.fills += 1 } })
        return (exit, seen)
    }

    func testStageFinaleShowsTheEndingPagesAndReturnsToTheMainMenu() throws {
        let helpers = OriginalWarSetupNativeTests(), base = OriginalMatchPreparation.globalBase
        var state = try helpers.initial(helpers.catalog())
        for (address, value): (Int, Int32) in [(0x451160, 1), (0x44d020, 300), (0x450c2c, 1), (0x450c30, 0), (0x451190, 0x20004000),
                                               (0x451b20, 0), (0x451b24, 0), (0x451b28, 0), (0x451b2c, 0), (0x457580, 1)] {
            try helpers.set(&state, address, value)
        }
        for address in stride(from: 0x4513a4, through: 0x4513bc, by: 4) { try helpers.set(&state, address, 7) }
        let seat = Int(try state.world.integer(at: 0x194, as: UInt32.self))
        func press(_ down: Bool) throws {
            try state.actors[seat].write(UInt8(down ? 1 : 0), at: 0xd1); try state.actors[seat].write(UInt8(0), at: 0xca)
        }
        try press(false)
        var pages: [Int32] = []
        for page in 1...4 {
            // Thirteen opening frames: the page, then the wipe's thirteen bands.
            for step in 1...13 {
                let (exit, seen) = try frame(&state)
                XCTAssertEqual(exit, .returned)
                XCTAssertEqual(seen.draws.first?.bitmap, .menu(0x20004000)); XCTAssertEqual(seen.draws.first?.frame, Int32(page))
                XCTAssertEqual(seen.fills, 13); XCTAssertEqual(try helpers.word(state, 0x451b24), Int32(step))
            }
            pages.append(try helpers.word(state, 0x451b28))
            try press(true)
            _ = try frame(&state); XCTAssertEqual(try helpers.word(state, 0x451b20), 1)
            try press(false)
            for _ in 1...12 { let (_, seen) = try frame(&state); XCTAssertEqual(seen.fills, 13) }
            XCTAssertEqual(try helpers.word(state, 0x451b20), 0)
        }
        XCTAssertEqual(pages, [1, 2, 3, 4])
        XCTAssertEqual(try helpers.word(state, 0x44d020), 10)
        XCTAssertEqual(try helpers.word(state, 0x451b28), 0); XCTAssertEqual(try helpers.word(state, 0x457580), 0)
        XCTAssertEqual(try helpers.word(state, 0x4513a4), 0, "431c70 input reset")
        XCTAssertEqual(try state.globals.integer(at: 0x455378-base, as: UInt8.self), 0x75)
    }

    func testFinaleLevelsOneAndTwoStartAtFrameZeroAndSkipFrameOne() throws {
        let helpers = OriginalWarSetupNativeTests()
        var state = try helpers.initial(helpers.catalog())
        for (address, value): (Int, Int32) in [(0x451160, 1), (0x44d020, 300), (0x450c2c, 1), (0x450c30, 2), (0x451190, 0x20004000),
                                               (0x451b20, 0), (0x451b24, 13), (0x451b28, 1), (0x451b2c, 0)] {
            try helpers.set(&state, address, value)
        }
        let (_, seen) = try frame(&state)
        XCTAssertEqual(seen.draws.first?.frame, 2)
        XCTAssertEqual(try helpers.word(state, 0x451b28), 2)
    }
}
