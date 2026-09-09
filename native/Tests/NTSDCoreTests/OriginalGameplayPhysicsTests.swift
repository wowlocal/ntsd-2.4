import Foundation
import XCTest
import NTSDReferenceChecks

final class OriginalGameplayPhysicsTests: XCTestCase {
    private func compare(_ control: Bool) throws {
        let suffix = control ? "-control" : ""
        func fixture(_ name: String) throws -> Data {
            let url = try XCTUnwrap(Bundle.module.url(forResource: "original-"+name+suffix,withExtension: "json",subdirectory: "Fixtures"))
            return try Data(contentsOf: url)
        }
        let gameplay: Data
        if let directory = ProcessInfo.processInfo.environment["NTSD_GAMEPLAY_PHYSICS_DIRECTORY"] {
            gameplay = try Data(contentsOf: URL(fileURLWithPath: directory).appendingPathComponent("gameplay-entry"+suffix+".json"))
        } else { gameplay = try fixture("gameplay-physics") }
        let r = try MatchLaunchReference.compare(launch: fixture("match-launch"),selection: fixture("match-selection"),character: fixture("character-screen"),cycle: fixture("menu-cycle"),
            returning: fixture("menu-return"),screen: fixture("mode-screen"),startup: fixture("menu-startup"),menu: fixture("menu-loading"),loading: fixture("menu-loading-state"),
            catalog: fixture("menu-loading-catalog"),sounds: fixture("menu-loading-sounds"),gameplayControl: gameplay,gameplayPhysics: true)
        XCTAssertEqual(r.cases,8);XCTAssertEqual(r.controlSlots,2);XCTAssertEqual(r.physicsSlots,2);XCTAssertEqual(r.parent.cases,50)
        print("GAMEPLAY PHYSICS",suffix,"records",r.records,"bytes",r.bytes,"helpers",r.helpers,"checkpoints",r.checkpoints)
    }
    func testOwnLaunchThroughControlAndPhysics() throws { try compare(false) }
    func testSamePhysicsWithRampAndReverseAddresses() throws { try compare(true) }
}
