import XCTest
import NTSDCore

/// GOAL_100.md, the Stage finale gap. After the last stage group (5-x) the
/// stage logic writes menu 300 (437860's 438991, ported as
/// `OriginalMissionStage.setTail`; its 300 write is compared in the Mission
/// corpus cases set-24 and set-229). 429730 then calls 437220 for menu 300
/// (429e7a..429e91). That screen is not recovered: the port's character
/// screen stops at its "Other menu dispatcher" boundary. This test records
/// the gap; it must change when 437220 is ported.
final class OriginalStageFinaleTests: XCTestCase {
    private func screen(menu: Int32) throws -> Result<OriginalCharacterScreenExit,Error> {
        let helpers = OriginalWarSetupNativeTests()
        var state = try helpers.initial(helpers.catalog())
        try helpers.set(&state,0x451160,1)   // Stage mode
        try helpers.set(&state,0x44d020,menu)
        try helpers.set(&state,0x450c2c,1)
        return Result {
            try OriginalCharacterScreen.advance(state:&state,selectionAtEntry:0,target:0x26006000,
                input:.init(dcResult:0,dc:0x70000000,methodResult:-1,drawResults:[-1],shellResult:33),
                fillBacking:[UInt8](repeating:0xa5,count:100),draw:{ _,_ in })
        }
    }

    func testMenu300AfterTheLastStageGroupStopsAtTheUnrecoveredScreen() throws {
        guard case .failure(let error) = try screen(menu: 300) else { return XCTFail("menu 300 unexpectedly handled") }
        XCTAssertTrue(String(describing:error).contains("Other menu dispatcher"),"\(error)")
    }
}
