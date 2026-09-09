import Foundation
import XCTest
import NTSDReferenceChecks

final class OriginalInitializedGameplayTests: XCTestCase {
    private func compare(_ control: Bool) throws {
        let suffix = control ? "-control" : ""
        func fixture(_ name: String) throws -> Data {
            try Data(contentsOf: XCTUnwrap(Bundle.module.url(forResource: name,withExtension: nil,subdirectory: "Fixtures")))
        }
        let data: Data
        if let directory = ProcessInfo.processInfo.environment["NTSD_INITIALIZED_GAMEPLAY_DIRECTORY"] {
            data = try Data(contentsOf: URL(fileURLWithPath: directory).appendingPathComponent("initialized-gameplay"+suffix+".json"))
        } else { data = try fixture("original-initialized-gameplay"+suffix+".json") }
        let r = try InitializedGameplayReference.compare(data,fixture: fixture),g = r.gameplay
        XCTAssertEqual(g.cases,8);XCTAssertEqual(g.controlSlots,2);XCTAssertEqual(g.physicsSlots,2);XCTAssertEqual(g.depthSlots,2)
        XCTAssertEqual(g.contactPasses,1);XCTAssertEqual(g.hitSlots,2);XCTAssertEqual(g.cpointStages,4);XCTAssertEqual(g.cameraPasses,1)
        XCTAssertEqual(g.drawingPasses,1);XCTAssertEqual(g.impulsePasses,1);XCTAssertEqual(g.parent.cases,50)
        print("INITIALIZED GAMEPLAY",suffix,"records",g.records,"bytes",g.bytes,"helpers",g.helpers,"checkpoints",g.checkpoints,
              "FPU checkpoints",r.fpuCheckpoints,"transitions",r.fpuTransitions)
    }
    func testOriginalInitializerAndOwnWholeContinuation() throws { try compare(false) }
    func testSameInitializedContinuationWithControlBacking() throws { try compare(true) }
}
