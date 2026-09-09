import Foundation
import XCTest
import NTSDReferenceChecks

final class OriginalPausedGameplayTests: XCTestCase {
    private func compare(_ control: Bool) throws {
        let suffix = control ? "-control" : ""
        func fixture(_ name: String) throws -> Data {
            try Data(contentsOf: XCTUnwrap(Bundle.module.url(forResource:name,withExtension:nil,subdirectory:"Fixtures")))
        }
        func own(_ name: String) throws -> Data { try fixture("original-"+name+suffix+".json") }
        let data: Data
        if let directory = ProcessInfo.processInfo.environment["NTSD_PAUSED_GAMEPLAY_DIRECTORY"] {
            data = try Data(contentsOf: URL(fileURLWithPath:directory).appendingPathComponent("paused-gameplay"+suffix+".json"))
        } else { data = try own("paused-gameplay") }
        let result = try InitializedGameplayReference.compare(own("initialized-gameplay"),fixture:fixture,
            postDraw:own("gameplay-lifecycle"),commands:own("gameplay-commands"),hud:own("gameplay-hud"),
            notices:own("gameplay-notices"),resultRecording:own("gameplay-result-recording"),
            resultLayout:own("gameplay-result-layout"),returned:own("gameplay-return"),
            compareGameplayBody:true,continuous:own("continuous-gameplay"),paused:data)
        let g = result.gameplay
        XCTAssertEqual(g.continuousCalls,16);XCTAssertEqual(g.bodyPasses,1);XCTAssertEqual(g.bodyCheckpoints,19)
        XCTAssertEqual(g.pauseSequenceCalls,14);XCTAssertEqual(g.pausedRenderingCalls,8)
        XCTAssertEqual(g.pausedEvents,control ? 15121 : 14337)
        XCTAssertEqual(g.pausedHelpers,control ? 3602 : 3490)
        XCTAssertEqual(g.records,3000280);XCTAssertEqual(g.bytes,9685070146);XCTAssertEqual(g.checkpoints,651)
        XCTAssertEqual(result.fpuCheckpoints,20368)
        print("PAUSED GAMEPLAY",suffix,"records",g.records,"bytes",g.bytes,"helpers",g.helpers,"checkpoints",g.checkpoints,
              "calls",g.pauseSequenceCalls,"paused",g.pausedRenderingCalls,"pause events",g.pausedEvents,
              "pause helpers",g.pausedHelpers,"FPU checkpoints",result.fpuCheckpoints,"transitions",result.fpuTransitions)
    }
    func testOwnPauseSingleStepAndResume() throws { try compare(false) }
    func testOwnPauseSingleStepAndResumeWithControlBacking() throws { try compare(true) }
}
