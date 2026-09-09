import Foundation
import XCTest
import NTSDReferenceChecks

final class OriginalGameplayHitsTests: XCTestCase {
    private func compare(_ control: Bool) throws {
        let suffix = control ? "-control" : ""
        func fixture(_ name: String) throws -> Data {
            let url = try XCTUnwrap(Bundle.module.url(forResource: "original-"+name+suffix,withExtension: "json",subdirectory: "Fixtures"))
            return try Data(contentsOf: url)
        }
        let links: Data
        if let directory = ProcessInfo.processInfo.environment["NTSD_GAMEPLAY_HITS_DIRECTORY"] {
            links = try Data(contentsOf: URL(fileURLWithPath: directory).appendingPathComponent("gameplay-hits"+suffix+".json"))
        } else { links = try fixture("gameplay-hits") }
        let r = try MatchLaunchReference.compare(launch: fixture("match-launch"),selection: fixture("match-selection"),character: fixture("character-screen"),cycle: fixture("menu-cycle"),
            returning: fixture("menu-return"),screen: fixture("mode-screen"),startup: fixture("menu-startup"),menu: fixture("menu-loading"),loading: fixture("menu-loading-state"),
            catalog: fixture("menu-loading-catalog"),sounds: fixture("menu-loading-sounds"),gameplayControl: fixture("gameplay-physics"),gameplayPhysics: true,gameplayLinks: fixture("gameplay-links"),gameplayContacts: fixture("gameplay-contacts"),gameplayHits: links)
        XCTAssertEqual(r.cases,8);XCTAssertEqual(r.controlSlots,2);XCTAssertEqual(r.physicsSlots,2);XCTAssertEqual(r.depthSlots,2);XCTAssertEqual(r.contactPasses,1);XCTAssertEqual(r.hitSlots,2);XCTAssertEqual(r.parent.cases,50)
        print("GAMEPLAY HITS",suffix,"records",r.records,"bytes",r.bytes,"helpers",r.helpers,"checkpoints",r.checkpoints)
    }
    func testOwnLaunchThroughBothHitPassesAndItemDecision() throws { try compare(false) }
    func testSameWholeContinuationWithRampAndReverseAddresses() throws { try compare(true) }
}
