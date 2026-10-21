import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDRuntime

/// MEMORY_LOADING L13: the loading packages are read on a thread of their own
/// and taken where they were read, in the same order: the values are the ones
/// read in sequence, and the first failing package in that order decides.
/// ENGINE_SPLIT E4c-2: its synthetic tests moved to the engine's NTSDEngineTests (same class name).
final class OriginalLoadingReadAheadTests: XCTestCase {
    struct Failed: Error, Equatable { let name: String }

    func testReadAheadPackagesEqualTheOnesReadInSequence() throws {
        let bundle = Bundle.main
        let ahead = try OriginalConcurrentInputs.Background { OriginalRuntimeLoadingPackages(in: bundle) }.get()
        let (catalog, loading, interface, menu, arena) = try ahead.values()
        XCTAssertEqual(catalog, try OriginalApplicationCatalogInputs.bundled(in: bundle))
        XCTAssertEqual(loading, try OriginalApplicationLoadingInputs.bundled(in: bundle))
        XCTAssertEqual(interface, try OriginalApplicationInterfaceInputs.bundled(in: bundle))
        XCTAssertEqual(menu, try OriginalApplicationMenuInputs.bundledWithWar(in: bundle))
        let sequential = try OriginalApplicationArenaInputs.bundled(in: bundle)
        XCTAssertEqual(arena.bitmaps.keys.sorted(), sequential.bitmaps.keys.sorted())
        XCTAssertTrue(arena.bitmaps.allSatisfy { sequential.bitmaps[$0.key] == $0.value })
    }

    func testTheFirstFailingPackageInBundledOrderDecides() throws {
        let bundle = Bundle.main
        let real = OriginalRuntimeLoadingPackages(in: bundle)
        let names = ["catalog", "loading", "interface", "menu", "arena"]
        // Every pair of failing packages: the earlier one in bundled's order is thrown.
        for first in 0..<names.count {
            for second in first..<names.count {
                func pick<T>(_ k: Int, _ value: Result<T, Error>) -> Result<T, Error> {
                    k == first || k == second ? .failure(Failed(name: names[k])) : value
                }
                let packages = OriginalRuntimeLoadingPackages(catalog: pick(0, real.catalog), loading: pick(1, real.loading),
                    interface: pick(2, real.interface), menu: pick(3, real.menu), arena: pick(4, real.arena))
                XCTAssertThrowsError(try packages.values()) { XCTAssertEqual($0 as? Failed, Failed(name: names[first])) }
            }
        }
        XCTAssertNoThrow(try real.values())
    }
}
