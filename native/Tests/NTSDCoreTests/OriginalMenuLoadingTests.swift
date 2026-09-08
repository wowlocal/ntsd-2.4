import Foundation
import XCTest
import NTSDReferenceChecks

final class OriginalMenuLoadingTests: XCTestCase {
    private func compare(_ control: Bool) throws {
        let suffix = control ? "-control" : ""
        func fixture(_ name: String) throws -> Data {
            let url = try XCTUnwrap(Bundle.module.url(forResource: "original-"+name+suffix,withExtension: "json",subdirectory: "Fixtures"))
            return try Data(contentsOf: url)
        }
        let r = try MenuLoadingReference.compare(menu: fixture("menu-loading"),loading: fixture("menu-loading-state"),
            catalog: fixture("menu-loading-catalog"),sounds: fixture("menu-loading-sounds"))
        XCTAssertEqual(r.menu.cases,119)
        XCTAssertEqual(r.menu.phases,547)
        XCTAssertEqual(r.menu.returns,114)
        XCTAssertEqual(r.menu.loading,1)
        XCTAssertEqual(r.loading.commonLoads,18)
        XCTAssertEqual(r.loading.catalog.calls,400)
        XCTAssertEqual(r.loading.catalog.catalog.objects,137)
        XCTAssertEqual(r.loading.catalog.catalog.frames,15388)
        XCTAssertEqual(r.loading.catalog.catalog.checksum,31_475_378)
        XCTAssertEqual(r.loading.poolConstructors,408)
        XCTAssertEqual(r.loading.interfaceConstructors,10)
        XCTAssertEqual(r.loading.records,930)
        XCTAssertEqual(r.loading.bytes,3152264)
        XCTAssertEqual(r.draws,1)
        XCTAssertEqual(r.reads,control ? 10 : 5)
        XCTAssertEqual(r.clips,control ? 2 : 1)
        XCTAssertEqual(r.blits,control ? 2 : 1)
        XCTAssertEqual(r.helpers,control ? 3 : 2)
        XCTAssertEqual(r.records,28)
        XCTAssertEqual(r.bytes,256568)
    }
    func testOwnEarlyMenuStateContinuesIntoFullInitialLoading() throws { try compare(false) }
    func testOwnMenuLoadingWithReverseAllocationsAndBltPresentation() throws { try compare(true) }
}
