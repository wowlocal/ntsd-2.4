import Foundation
import XCTest
import NTSDReferenceChecks

final class OriginalGameplayImpulsesTests: XCTestCase {
    private func compare(_ control: Bool) throws {
        let suffix = control ? "-control" : ""
        func fixture(_ name: String) throws -> Data {
            let url = try XCTUnwrap(Bundle.module.url(forResource: "original-"+name+suffix,withExtension: "json",subdirectory: "Fixtures"))
            return try Data(contentsOf: url)
        }
        let impulses: Data
        if let directory = ProcessInfo.processInfo.environment["NTSD_GAMEPLAY_IMPULSES_DIRECTORY"] {
            impulses = try Data(contentsOf: URL(fileURLWithPath: directory).appendingPathComponent("gameplay-impulses"+suffix+".json"))
        } else { impulses = try fixture("gameplay-impulses") }
        let r = try MatchLaunchReference.compare(launch: fixture("match-launch"),selection: fixture("match-selection"),character: fixture("character-screen"),cycle: fixture("menu-cycle"),
            returning: fixture("menu-return"),screen: fixture("mode-screen"),startup: fixture("menu-startup"),menu: fixture("menu-loading"),loading: fixture("menu-loading-state"),
            catalog: fixture("menu-loading-catalog"),sounds: fixture("menu-loading-sounds"),gameplayControl: fixture("gameplay-physics"),gameplayPhysics: true,gameplayLinks: fixture("gameplay-links"),gameplayContacts: fixture("gameplay-contacts"),gameplayHits: fixture("gameplay-hits"),gameplayCPoints: fixture("gameplay-cpoints"),gameplayCamera: fixture("gameplay-camera"),gameplayDrawing: fixture("gameplay-drawing"),gameplayImpulses: impulses)
        XCTAssertEqual(r.cases,8);XCTAssertEqual(r.controlSlots,2);XCTAssertEqual(r.physicsSlots,2);XCTAssertEqual(r.depthSlots,2);XCTAssertEqual(r.contactPasses,1);XCTAssertEqual(r.hitSlots,2);XCTAssertEqual(r.cpointStages,4);XCTAssertEqual(r.cameraPasses,1);XCTAssertEqual(r.drawingPasses,1);XCTAssertEqual(r.impulsePasses,1);XCTAssertEqual(r.parent.cases,50)
        print("GAMEPLAY IMPULSES",suffix,"records",r.records,"bytes",r.bytes,"helpers",r.helpers,"checkpoints",r.checkpoints)
    }
    func testOwnLaunchThroughPostDrawTextAndImpulses() throws { try compare(false) }
    func testSameWholeContinuationWithRampAndReverseAddresses() throws { try compare(true) }
}
