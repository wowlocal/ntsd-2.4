import Foundation
import XCTest
import NTSDReferenceChecks

final class OriginalGameplayReturnTests: XCTestCase {
    private func compare(_ control: Bool) throws {
        let suffix = control ? "-control" : ""
        func fixture(_ name: String) throws -> Data {
            try Data(contentsOf: XCTUnwrap(Bundle.module.url(forResource: name,withExtension: nil,subdirectory: "Fixtures")))
        }
        let data: Data
        if let directory = ProcessInfo.processInfo.environment["NTSD_GAMEPLAY_RETURN_DIRECTORY"] {
            data = try Data(contentsOf: URL(fileURLWithPath: directory).appendingPathComponent("gameplay-return"+suffix+".json"))
        } else { data = try fixture("original-gameplay-return"+suffix+".json") }
        let r = try InitializedGameplayReference.compare(fixture("original-initialized-gameplay"+suffix+".json"),fixture: fixture,postDraw: fixture("original-gameplay-lifecycle"+suffix+".json"),commands: fixture("original-gameplay-commands"+suffix+".json"),hud: fixture("original-gameplay-hud"+suffix+".json"),notices: fixture("original-gameplay-notices"+suffix+".json"),resultRecording: fixture("original-gameplay-result-recording"+suffix+".json"),resultLayout: fixture("original-gameplay-result-layout"+suffix+".json"),returned: data)
        let g = r.gameplay
        XCTAssertEqual(g.cases,8);XCTAssertEqual(g.controlSlots,2);XCTAssertEqual(g.physicsSlots,2);XCTAssertEqual(g.depthSlots,2)
        XCTAssertEqual(g.contactPasses,1);XCTAssertEqual(g.hitSlots,2);XCTAssertEqual(g.cpointStages,4);XCTAssertEqual(g.cameraPasses,1)
        XCTAssertEqual(g.drawingPasses,1);XCTAssertEqual(g.impulsePasses,1);XCTAssertEqual(g.lifecyclePasses,1);XCTAssertEqual(g.commandPasses,1);XCTAssertEqual(g.hudPasses,1);XCTAssertEqual(g.noticePasses,1);XCTAssertEqual(g.parent.cases,50)
        XCTAssertEqual(g.resultRecordingPasses,1);XCTAssertEqual(g.resultLayoutPasses,1);XCTAssertEqual(g.gameplayReturns,1);XCTAssertEqual(r.fpuCheckpoints,1614)
        print("GAMEPLAY RETURN",suffix,"records",g.records,"bytes",g.bytes,"helpers",g.helpers,"checkpoints",g.checkpoints,
              "FPU checkpoints",r.fpuCheckpoints,"transitions",r.fpuTransitions)
    }
    func testWholeReturnOnOwnInitializedMatch() throws { try compare(false) }
    func testWholeReturnOnOwnInitializedMatchWithControlBacking() throws { try compare(true) }
}
