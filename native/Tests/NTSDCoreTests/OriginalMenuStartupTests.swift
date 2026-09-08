import Foundation
import XCTest
import NTSDReferenceChecks

final class OriginalMenuStartupTests: XCTestCase {
    private func compare(_ control: Bool) throws {
        let suffix = control ? "-control" : ""
        func fixture(_ name: String) throws -> Data {
            let url = try XCTUnwrap(Bundle.module.url(forResource: "original-"+name+suffix,withExtension: "json",subdirectory: "Fixtures"))
            return try Data(contentsOf: url)
        }
        let result = try MenuStartupReference.compare(startup: fixture("menu-startup"),menu: fixture("menu-loading"),
            loading: fixture("menu-loading-state"),catalog: fixture("menu-loading-catalog"),sounds: fixture("menu-loading-sounds"))
        XCTAssertEqual(result.parent.menu.cases,119)
        XCTAssertEqual(result.parent.loading.catalog.catalog.objects,137)
        XCTAssertEqual(result.localCalls,1)
        XCTAssertEqual(result.receivedCalls,1)
        XCTAssertEqual(result.musicCalls,5)
        XCTAssertEqual(result.constructors,11)
        XCTAssertEqual(result.checkpoints,22)
        XCTAssertEqual(result.events,68)
        XCTAssertEqual(result.records,3412)
        XCTAssertEqual(result.bytes,5_948_634)
    }
    func testOwnMenuLoadingContinuesThroughInputRoundAndCharacterMenuResources() throws { try compare(false) }
    func testSameStartupWithRetainedRampResourcesAndReverseActorAddresses() throws { try compare(true) }
}
