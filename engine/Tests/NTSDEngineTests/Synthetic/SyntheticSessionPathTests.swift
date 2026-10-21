import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDRuntime

/// ENGINE_SPLIT E7d, rung 1: the pack's catalog and the rest of the first
/// loading through the engine's application session types, as the runtime
/// runs them, instead of `loadWithFiles` with test-made backing
/// (SyntheticContentPackTests). The front menu's START reaches
/// `OriginalMacRuntimeLoading.run` (OriginalMacRuntimeLoading.swift:202-247):
/// the loading session's common sounds, `OriginalApplicationCatalogSession.load`
/// with the runtime's heap allocations and file buffers, the 400-slot pool, the
/// first input step and the loaded menu, over the packages
/// `OriginalRuntimeLoadingPackages` reads from the pack's content location
/// (the identity computed from its manifests). Every value is computed by the
/// engine; the catalog checksum is the one `loadWithFiles` computes.
final class SyntheticSessionPathTests: XCTestCase {
    typealias Pack = SyntheticContentPack

    func testFirstLoadingRunsTheCatalogAndPoolThroughTheSessionTypes() throws {
        try Pack.withWrittenPack { root, pack in
            try MainActor.assumeIsolated {
                let run = try SyntheticRun(root: root, pack: pack)
                try run.run(limit: 5) { run.committed == 5 }
                try run.clickStart()
                var stepped: [SyntheticRun.Stepped] = []
                while run.cycles == 0 && stepped.count < 40 { stepped.append(try run.step()) }
                XCTAssertEqual(stepped.last, .loaded(.menu), "the first loading returns the loaded menu")
                XCTAssertEqual(run.committed, 12, "committed front-menu iterations before the request to load")
                let loading = try XCTUnwrap(run.loading), match = try XCTUnwrap(run.match)
                let catalog = match.catalog
                // The same catalog `loadWithFiles` builds from the same package (E7c's pinned checksum).
                XCTAssertEqual(catalog.checksum, SyntheticContentPackTests.pinnedCatalogChecksum)
                XCTAssertEqual(try catalog.objects.map { try $0.header.integer(at: 0x6f4, as: Int32.self) },
                               Pack.characters.map(\.id) + Pack.items.map(\.id))
                XCTAssertEqual(try catalog.objects.map { try $0.header.integer(at: 0x6f8, as: Int32.self) },
                               Pack.characters.map { _ in 0 } + Pack.items.map { _ in 1 })
                XCTAssertEqual(try catalog.backgrounds[0].integer(at: 0, as: Int32.self), 1000, "the background's width")
                XCTAssertEqual(match.actors.count, 400)
                // What the runtime served the loading (engine-counted).
                let c = loading.counts
                syntheticLog("E7D rung1 counts allocations \(c.allocations) bitmapRequests \(c.bitmapRequests) files \(c.files) audioRequests \(c.audioRequests) times \(c.times) messages \(c.messages)")
                XCTAssertEqual([c.allocations, c.bitmapRequests, c.files, c.audioRequests], Self.pinnedCounts)
                // Globals the loading wrote: the common sounds' count (OriginalInitialSoundLoading.swift:77),
                // the first-loading and menu-bitmap flags cleared (OriginalInitialInterfaceLoading.swift:95,
                // OriginalMenuResourceLoading.swift:89), the mode screen kept, World+0 2.
                XCTAssertEqual(try [run.global(0x45843c), run.global(0x44d05c), run.global(0x44d07c), run.global(0x44d020), run.global(0x458b00)],
                               [18, 0, 0, 10, 2])
                XCTAssertEqual(run.log.shown, [])
                let frame = try XCTUnwrap(run.presented())
                syntheticLog("E7D rung1 frame \(frame.width)x\(frame.height) \(SyntheticDigest.sha256(frame))")
                XCTAssertEqual([frame.width, frame.height], [800, 600])
                XCTAssertEqual(SyntheticDigest.sha256(frame), Self.pinnedModeScreenFrame)
            }
        }
    }
    /// Allocations, bitmap requests, files and audio requests served to the first loading.
    static let pinnedCounts = [791, 967, 45, 77]
    /// The mode screen after the first loading.
    static let pinnedModeScreenFrame = "0016462c3844443638da5817a61823de0472581b88a835f7b31e0664d6c5e9e2"
}
